import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/caption_catalog.dart';
import '../domain/clip_edit_overrides.dart';
import '../domain/clip_preferences.dart';
import '../domain/project_contract.dart';
import 'android_video_picker.dart';
import 'caption_sidecar_generator.dart';
import 'local_project_repository.dart';
import 'processing_job_service.dart';
import 'video_export_service.dart';

class ProcessingPipelineResult {
  const ProcessingPipelineResult({
    required this.sourceSha256,
    required this.exportedCount,
    required this.skippedCount,
    required this.candidatesCount,
  });

  final String sourceSha256;
  final int exportedCount;
  final int skippedCount;
  final int candidatesCount;
}

class ProcessingPipelineService {
  ProcessingPipelineService({
    required LocalProjectRepository repository,
    ProcessingJobService? jobs,
    VideoExportService? exporter,
    CaptionSidecarGenerator? captions,
  })  : _repository = repository,
        _jobs = jobs ?? ProcessingJobService(repository: repository),
        _exporter = exporter ?? VideoExportService(),
        _captions = captions ?? const CaptionSidecarGenerator();

  final LocalProjectRepository _repository;
  final ProcessingJobService _jobs;
  final VideoExportService _exporter;
  final CaptionSidecarGenerator _captions;
  DateTime _lastProgressWrite = DateTime.fromMillisecondsSinceEpoch(0);

  Future<ProcessingPipelineResult> run({
    required String projectId,
    required Future<void> Function(CutawanProject project) transcribe,
    required Future<void> Function(CutawanProject project) discover,
    required Future<void> Function(CutawanProject project) analyzeFraming,
    void Function(String stage, double progress)? onProgress,
    void Function(String renderId)? onRenderStarted,
  }) async {
    var currentStage = 'inspecting';
    try {
      await _jobs.begin(projectId);
      final loadedProject = await _repository.load(projectId);
      if (loadedProject == null) {
        throw StateError('Project not found: $projectId');
      }
      var project = loadedProject;
      final sourceSha = await _jobs.fingerprintSource(project);
      if (!ProcessingJobService.isSha256(sourceSha)) {
        throw const FormatException('Source SHA-256 fingerprint is invalid.');
      }

      await _stage(
        project,
        sourceSha256: sourceSha,
        stage: 'inspecting',
        progress: 0.04,
        fingerprintConfiguration: 'android-media-metadata-v1',
        artifacts: const [],
        onProgress: onProgress,
        work: () async {
          final inspected = await AndroidVideoPicker.inspectVideo(project.source.uri);
          final source = project.source;
          final changed = source.sizeBytes != inspected.sizeBytes ||
              source.durationMs != inspected.durationMs ||
              source.width != inspected.width ||
              source.height != inspected.height ||
              source.rotationDegrees != inspected.rotationDegrees ||
              source.mimeType != inspected.mimeType;
          if (changed) {
            await _repository.refreshSource(project.id, inspected);
            project = (await _repository.load(project.id))!;
          }
        },
      );

      currentStage = 'transcribing';
      await _stage(
        project,
        sourceSha256: sourceSha,
        stage: 'transcribing',
        progress: 0.12,
        fingerprintConfiguration: 'whisper-base-word-timestamps-v1',
        artifacts: const ['transcript.json'],
        onProgress: onProgress,
        work: () async {
          await transcribe(project);
          final transcript = await _repository.loadTranscript(project.id);
          if (transcript == null || !transcript.wordTimingReliable) {
            throw StateError('Transcription did not produce reliable word timings.');
          }
        },
      );

      currentStage = 'discovering';
      await _stage(
        project,
        sourceSha256: sourceSha,
        stage: 'discovering',
        progress: 0.42,
        fingerprintConfiguration: {
          'requestedClipCount': project.preferences.requestedClipCount,
          'durationMode': project.preferences.durationMode.name,
          'customMinimumSeconds': project.preferences.customMinimumSeconds,
          'customMaximumSeconds': project.preferences.customMaximumSeconds,
          'engine': 'evidence-ranking-qwen-optional-v1',
        },
        artifacts: const ['candidates.json'],
        onProgress: onProgress,
        work: () async {
          await discover(project);
          final candidates = await _repository.loadCandidates(project.id);
          if (candidates == null) {
            throw StateError('Candidate discovery did not persist its result.');
          }
        },
      );

      currentStage = 'reframing';
      await _stage(
        project,
        sourceSha256: sourceSha,
        stage: 'reframing',
        progress: 0.53,
        fingerprintConfiguration: {
          'aspectRatio': project.preferences.aspectRatio.name,
          'speakerTrackingEnabled': project.preferences.speakerTrackingEnabled,
          'engine': 'conservative-frame-reframe-v1',
        },
        artifacts: const ['reframe.json'],
        onProgress: onProgress,
        work: () async {
          await analyzeFraming(project);
          final plan = await _repository.loadReframePlan(project.id);
          if (plan == null) {
            throw StateError('Reframe analysis did not persist a plan.');
          }
        },
      );

      final transcript = await _repository.loadTranscript(projectId);
      final candidates = await _repository.loadCandidates(projectId);
      final reframe = await _repository.loadReframePlan(projectId);
      if (transcript == null || candidates == null || reframe == null) {
        throw StateError('A required analysis artifact is missing before rendering.');
      }
      transcript.validate();
      candidates.validate();
      reframe.validate();

      currentStage = 'captioning';
      final srtPaths = <String, String>{};
      final assPaths = <String, String>{};
      final captionArtifacts = <String>[];
      final captionFingerprint = _jobs.stageFingerprint(
        sourceSha256: sourceSha,
        stage: 'captioning',
        configuration: {
          'enabled': project.preferences.captionsEnabled,
          'style': project.preferences.captionStyleId,
          'animation': project.preferences.captionAnimationId,
          'aspectRatio': _aspectRatio(project),
          'fontFamily': project.preferences.captionFontFamily,
          'fontScale': project.preferences.captionFontScale,
          'positionY': project.preferences.captionPositionY,
          'textColor': project.preferences.mainTextColor,
          'highlightColor': project.preferences.highlightColor,
          'uppercase': project.preferences.captionUppercase,
          'bold': project.preferences.captionBold,
          'timingOffsetMs': project.preferences.captionTimingOffsetMs,
          'candidates': candidates.candidates
              .map((item) => item.toJson())
              .toList(growable: false),
        },
      );
      final captionsValid = await _jobs.hasCheckpoint(
        projectId,
        stage: 'captioning',
        fingerprint: captionFingerprint,
      );
      if (!captionsValid) {
        await _jobs.setStage(projectId, stage: 'captioning', progress: 0.60);
        onProgress?.call('captioning', 0.60);
        if (project.preferences.captionsEnabled) {
          final style = _resolveCaptionStyle(project.preferences);
          for (final candidate in candidates.candidates) {
            final generated = _captions.generate(
              transcript: transcript,
              candidate: candidate,
              style: style,
              aspectRatio: _aspectRatio(project),
              animationId: project.preferences.captionAnimationId,
              timingOffsetMs: project.preferences.captionTimingOffsetMs,
            );
            if (generated.srt.isEmpty || generated.ass.isEmpty) {
              throw StateError('Subtitle generation returned no timed words for ${candidate.id}.');
            }
            final srtPath = await _repository.subtitleFilePath(
              projectId,
              candidate.id,
              extension: 'srt',
            );
            final assPath = await _repository.subtitleFilePath(
              projectId,
              candidate.id,
              extension: 'ass',
            );
            await File(srtPath).writeAsString(generated.srt, encoding: utf8, flush: true);
            await File(assPath).writeAsString(generated.ass, encoding: utf8, flush: true);
            srtPaths[candidate.id] = srtPath;
            assPaths[candidate.id] = assPath;
            captionArtifacts
              ..add('subtitles/${candidate.id}.srt')
              ..add('subtitles/${candidate.id}.ass');
          }
        }
        await _jobs.saveCheckpoint(
          projectId,
          stage: 'captioning',
          fingerprint: captionFingerprint,
          artifactPaths: captionArtifacts,
        );
      } else if (project.preferences.captionsEnabled) {
        for (final candidate in candidates.candidates) {
          srtPaths[candidate.id] = await _repository.subtitleFilePath(
            projectId,
            candidate.id,
            extension: 'srt',
          );
          assPaths[candidate.id] = await _repository.subtitleFilePath(
            projectId,
            candidate.id,
            extension: 'ass',
          );
        }
      }

      final captionCuesByClip = <String, List<Map<String, Object?>>>{};
      final captionStyle = project.preferences.captionsEnabled
          ? _resolveCaptionStyle(project.preferences)
          : null;
      final captionStylePayload = captionStyle == null
          ? null
          : <String, Object?>{
              'fontFamily': captionStyle.fontFamily,
              'fontScale': captionStyle.fontScale,
              'uppercase': captionStyle.uppercase,
              'textColor': captionStyle.textColor,
              'highlightColor': captionStyle.highlightColor,
              'highlightBoxColor': captionStyle.highlightBoxColor,
              'outlineColor': captionStyle.outlineColor,
              'outlineWidth': captionStyle.outlineWidth,
              'shadow': captionStyle.shadow,
              'bold': captionStyle.bold,
              'positionY': captionStyle.positionY,
            };
      if (captionStyle != null) {
        for (final candidate in candidates.candidates) {
          final generated = _captions.generate(
            transcript: transcript,
            candidate: candidate,
            style: captionStyle,
            aspectRatio: _aspectRatio(project),
            animationId: project.preferences.captionAnimationId,
            timingOffsetMs: project.preferences.captionTimingOffsetMs,
          );
          if (generated.cues.isEmpty) {
            throw StateError('Caption overlay cues are missing for ${candidate.id}.');
          }
          captionCuesByClip[candidate.id] = generated.cues;
        }
      }
      currentStage = 'rendering';
      var exported = 0;
      var skipped = 0;
      final records = <Map<String, Object?>>[];
      final total = candidates.candidates.length;
      for (var index = 0; index < total; index++) {
        final candidate = candidates.candidates[index];
        final stageName = 'render_${candidate.id}';
        final sourceAspectRatio = _sourceAspectRatio(project);
        final targetAspectRatio = _aspectRatio(project);
        final clipEdit = await _repository.loadClipEditOverrides(
              projectId,
              candidate.id,
            ) ??
            ClipEditOverrides(clipId: candidate.id);
        final manualShots = clipEdit.toExportShots(
          durationMs: candidate.durationMs,
          sourceAspectRatio: sourceAspectRatio,
          targetAspectRatio: targetAspectRatio,
        );
        final clipReframeShots = manualShots.isNotEmpty
            ? manualShots
            : reframe.shots
                .where((shot) =>
                    shot.endMs > candidate.startMs &&
                    shot.startMs < candidate.endMs)
                .map((shot) {
                  final clippedStart = shot.startMs > candidate.startMs
                      ? shot.startMs
                      : candidate.startMs;
                  final clippedEnd = shot.endMs < candidate.endMs
                      ? shot.endMs
                      : candidate.endMs;
                  return <String, Object?>{
                    'startMs': clippedStart - candidate.startMs,
                    'endMs': clippedEnd - candidate.startMs,
                    'mode': shot.mode,
                    'region': shot.region?.toJson(),
                  };
                }).toList(growable: false);
        final fingerprint = _jobs.stageFingerprint(
          sourceSha256: sourceSha,
          stage: stageName,
          configuration: {
            'candidate': candidate.toJson(),
            'aspectRatio': targetAspectRatio,
            'sourceAspectRatio': sourceAspectRatio,
            'reframeShots': clipReframeShots,
            'clipEditOverrides': clipEdit.toJson(),
            'resolution': project.preferences.resolution,
            'renderer': 'androidx-media3-transformer-1.11.1-reframe-v1',
            'subtitleStyle': project.preferences.captionStyleId,
            'subtitleAnimation': project.preferences.captionAnimationId,
            'captionStyle': captionStylePayload,
            'captionTimingOffsetMs': project.preferences.captionTimingOffsetMs,
            'captionCues': captionCuesByClip[candidate.id] ?? const [],
            'captionRenderer': 'media3-canvas-overlay-rtl-v1',
          },
        );
        final validCheckpoint = await _jobs.hasCheckpoint(
          projectId,
          stage: stageName,
          fingerprint: fingerprint,
        );
        if (validCheckpoint) {
          final previous = await _repository.loadExportRecords(projectId);
          Map<String, dynamic>? existing;
          for (final record in previous) {
            if (record['clipId'] == candidate.id) {
              existing = record;
              break;
            }
          }
          if (existing != null && existing['validated'] == true) {
            final outputUri = existing['outputUri'];
            final hash = existing['sha256'];
            final size = existing['sizeBytes'];
            final duration = existing['durationMs'];
            final width = existing['width'];
            final height = existing['height'];
            if (outputUri is String &&
                hash is String &&
                size is num &&
                duration is num &&
                width is num &&
                height is num &&
                await _exporter.verifyExport(
                  outputUri: outputUri,
                  sha256: hash,
                  sizeBytes: size.toInt(),
                  durationMs: duration.toInt(),
                  width: width.toInt(),
                  height: height.toInt(),
                )) {
              records.add(existing);
              skipped++;
              onProgress?.call(
                'rendering',
                0.62 + 0.28 * (index + 1) / total,
              );
              continue;
            }
          }
        }

        final outputPath = await _repository.exportFilePath(projectId, candidate.id);
        final artifacts = <String>['exports/${candidate.id}.json'];
        if (project.preferences.captionsEnabled) {
          artifacts
            ..add('subtitles/${candidate.id}.srt')
            ..add('subtitles/${candidate.id}.ass');
        }
        final progress = total == 0 ? 0.9 : 0.62 + 0.28 * index / total;
        await _jobs.setStage(
          projectId,
          stage: 'rendering_${candidate.id}',
          progress: progress,
        );
        onProgress?.call('rendering', progress);

        final freeBytes = await AndroidVideoPicker.availableStorageBytes();
        final estimatedBytes = (
          project.source.sizeBytes *
              (candidate.durationMs / project.source.durationMs) *
              2.2
        ).round() + 32 * 1024 * 1024;
        if (freeBytes < estimatedBytes) {
          throw StateError(
            'Insufficient free storage for ${candidate.id}: '
            '$freeBytes bytes available; approximately $estimatedBytes required.',
          );
        }

        final rendered = await _exporter.renderClip(
          clipId: candidate.id,
          sourceUri: project.source.uri,
          startMs: candidate.startMs,
          endMs: candidate.endMs,
          aspectRatio: _aspectRatio(project),
          sourceAspectRatio: sourceAspectRatio,
          reframeShots: clipReframeShots,
          captionCues: captionCuesByClip[candidate.id] ?? const [],
          captionStyle: captionStylePayload,
          captionAnimationId: project.preferences.captionAnimationId,
          outputPath: outputPath,
          shouldCancel: () => _jobs.isCancellationRequested(projectId),
          onStarted: onRenderStarted,
          onProgress: (fraction) {
            final value = 0.62 + 0.28 * (index + fraction) / total;
            onProgress?.call('rendering', value);
            _persistProgress(projectId, 'rendering_${candidate.id}', value);
          },
        );
        if (!rendered.validated ||
            rendered.outputUri.isEmpty ||
            rendered.sizeBytes < 2048 ||
            rendered.durationMs <= 0 ||
            rendered.width <= 0 ||
            rendered.height <= 0 ||
            !ProcessingJobService.isSha256(rendered.sha256) ||
            !rendered.fullyDecodeValidated ||
            rendered.decodedVideoBuffers <= 0 ||
            (rendered.hasAudio && rendered.decodedAudioBuffers <= 0)) {
          throw StateError('Rendered MP4 failed the output validation gate.');
        }

        final record = <String, Object?>{
          'clipId': candidate.id,
          'projectId': projectId,
          'title': candidate.title,
          'outputUri': rendered.outputUri,
          'displayName': rendered.displayName,
          'sha256': rendered.sha256,
          'sizeBytes': rendered.sizeBytes,
          'durationMs': rendered.durationMs,
          'width': rendered.width,
          'height': rendered.height,
          'hasAudio': rendered.hasAudio,
          'fullyDecodeValidated': rendered.fullyDecodeValidated,
          'decodedVideoBuffers': rendered.decodedVideoBuffers,
          'decodedAudioBuffers': rendered.decodedAudioBuffers,
          'validated': true,
          'startMs': candidate.startMs,
          'endMs': candidate.endMs,
          'subtitleSrtPath': srtPaths[candidate.id],
          'subtitleAssPath': assPaths[candidate.id],
          'renderer': 'androidx-media3-transformer-1.11.1',
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        };
        await _repository.saveExportRecord(projectId, record);
        await _jobs.saveCheckpoint(
          projectId,
          stage: stageName,
          fingerprint: fingerprint,
          artifactPaths: artifacts,
        );
        records.add(record);
        exported++;
      }

      currentStage = 'validating';
      await _jobs.setStage(projectId, stage: 'validating', progress: 0.96);
      onProgress?.call('validating', 0.96);
      if (records.length != candidates.candidates.length) {
        throw StateError('The export manifest is missing one or more candidate clips.');
      }
      await _repository.saveExportManifest(projectId, {
        'schemaVersion': 1,
        'sourceSha256': sourceSha,
        'renderer': 'androidx-media3-transformer-1.11.1',
        'candidateCount': candidates.candidates.length,
        'exportedCount': records.length,
        'exports': records,
        'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      });
      await _jobs.complete(projectId);
      onProgress?.call('complete', 1);
      return ProcessingPipelineResult(
        sourceSha256: sourceSha,
        exportedCount: exported,
        skippedCount: skipped,
        candidatesCount: candidates.candidates.length,
      );
    } on ProcessingCancelled {
      await _jobs.cancel(projectId);
      rethrow;
    } on VideoExportCancelled {
      await _jobs.cancel(projectId);
      rethrow;
    } catch (error) {
      await _jobs.fail(projectId, stage: currentStage);
      rethrow;
    }
  }

  Future<void> _stage(
    CutawanProject project, {
    required String stage,
    required double progress,
    required Object fingerprintConfiguration,
    required List<String> artifacts,
    required Future<void> Function() work,
    required void Function(String stage, double progress)? onProgress,
    required String sourceSha256,
  }) async {
    final fingerprint = _jobs.stageFingerprint(
      sourceSha256: sourceSha256,
      stage: stage,
      configuration: fingerprintConfiguration,
    );
    if (await _jobs.hasCheckpoint(
      project.id,
      stage: stage,
      fingerprint: fingerprint,
    )) {
      return;
    }
    await _jobs.setStage(project.id, stage: stage, progress: progress);
    onProgress?.call(stage, progress);
    await work();
    if (await _jobs.isCancellationRequested(project.id)) {
      throw const ProcessingCancelled();
    }
    await _jobs.saveCheckpoint(
      project.id,
      stage: stage,
      fingerprint: fingerprint,
      artifactPaths: artifacts,
    );
  }

  void _persistProgress(String projectId, String stage, double progress) {
    final now = DateTime.now();
    if (now.difference(_lastProgressWrite).inMilliseconds < 1200) return;
    _lastProgressWrite = now;
    unawaited(
      _repository.saveJobState(
        projectId,
        status: ProjectJobStatus.running,
        stage: stage,
        progress: progress.clamp(0.0, 0.99).toDouble(),
      ).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  static CaptionStylePreset _resolveCaptionStyle(ClipPreferences preferences) {
    final base = captionStylePresets.firstWhere(
      (preset) => preset.id == preferences.captionStyleId,
      orElse: () => captionStylePresets.first,
    );
    return CaptionStylePreset(
      id: base.id,
      name: base.name,
      fontFamily: preferences.captionFontFamily ?? base.fontFamily,
      fontScale: preferences.captionFontScale > 0
          ? preferences.captionFontScale
          : base.fontScale,
      uppercase: preferences.captionUppercase ?? base.uppercase,
      textColor: preferences.mainTextColor,
      highlightColor: preferences.highlightColor,
      highlightBoxColor: base.highlightBoxColor,
      outlineColor: base.outlineColor,
      outlineWidth: base.outlineWidth,
      shadow: base.shadow,
      bold: preferences.captionBold ?? base.bold,
      positionY: preferences.captionPositionY >= 0
          ? preferences.captionPositionY
          : base.positionY,
      wordsPerGroup: base.wordsPerGroup,
    );
  }

  static double _sourceAspectRatio(CutawanProject project) {
    final source = project.source;
    final rotated = source.rotationDegrees.abs() % 180 != 0;
    final width = rotated ? source.height : source.width;
    final height = rotated ? source.width : source.height;
    if (width <= 0 || height <= 0) {
      throw const FormatException('Source dimensions are invalid for reframing.');
    }
    return width / height;
  }

  static double _aspectRatio(CutawanProject project) {
    final source = project.source;
    final rotated = source.rotationDegrees.abs() % 180 != 0;
    final width = rotated ? source.height : source.width;
    final height = rotated ? source.width : source.height;
    return switch (project.preferences.aspectRatio) {
      ClipAspectRatio.portrait916 => 9 / 16,
      ClipAspectRatio.square11 => 1,
      ClipAspectRatio.landscape169 => 16 / 9,
      ClipAspectRatio.original => width / height,
    };
  }
}
