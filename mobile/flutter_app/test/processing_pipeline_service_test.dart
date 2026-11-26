import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_edit_overrides.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/reframe_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:cutawan_mobile/services/processing_job_service.dart';
import 'package:cutawan_mobile/services/processing_pipeline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.cutawan.mobile/media');
  const sourceSha = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const oldTargetUri = 'content://media/external/video/media/9100';
  const otherClipUri = 'content://media/external/video/media/9102';
  const newTargetUri = 'content://media/external/video/media/9201';
  const newTargetSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test(
    'targeted rerender replaces only the requested clip after preserving verified peers',
    () async {
      final root = await Directory.systemTemp.createTemp('cutawan-targeted-rerender-');
      final repository = LocalProjectRepository(rootDirectory: root);
      final now = DateTime.utc(2026, 11, 26, 12);
      final source = VideoAssetMetadata(
        uri: 'content://media/external/video/media/42',
        displayName: 'targeted-rerender.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 500000,
        durationMs: 10000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      );
      final project = CutawanProject.create(
        source: source,
        preferences: const ClipPreferences(
          requestedClipCount: 2,
          captionsEnabled: false,
        ),
        now: now,
      );

      final target = ClipCandidate(
        id: 'clip_one',
        startMs: 0,
        endMs: 3000,
        score: 90,
        title: 'Target clip',
        hook: 'Target hook',
        summary: 'Target summary',
        explanations: const ['Test evidence'],
        transcriptText: 'Hello world',
        averageAudioEnergy: 0.3,
        peakVisualChange: 0.4,
      );
      final peer = ClipCandidate(
        id: 'clip_two',
        startMs: 5000,
        endMs: 8000,
        score: 80,
        title: 'Peer clip',
        hook: 'Peer hook',
        summary: 'Peer summary',
        explanations: const ['Test evidence'],
        transcriptText: 'Another moment',
        averageAudioEnergy: 0.2,
        peakVisualChange: 0.5,
      );
      final candidateSet = CandidateSet(
        schemaVersion: CandidateSet.currentSchemaVersion,
        sourceDurationMs: source.durationMs,
        createdAtUtc: now,
        candidates: [target, peer],
        transcriptEvidence: true,
        audioEvidence: true,
        visualEvidence: true,
        rankingEngine: 'test-fixture',
      );
      final transcript = CutawanTranscript(
        schemaVersion: CutawanTranscript.currentSchemaVersion,
        language: 'en',
        text: 'Hello world',
        sourceDurationMs: source.durationMs,
        createdAtUtc: now,
        segments: const [
          TranscriptSegment(
            text: 'Hello world',
            startMs: 0,
            endMs: 1200,
            words: [
              TranscriptWord(text: 'Hello', startMs: 0, endMs: 500, probability: 0.95),
              TranscriptWord(text: 'world', startMs: 600, endMs: 1100, probability: 0.95),
            ],
          ),
        ],
        audioEnergy: const [],
        visualSamples: const [],
        wordTimingReliable: true,
        whisperModelId: 'whisper-base',
      );
      final reframe = ReframePlan(
        schemaVersion: ReframePlan.currentSchemaVersion,
        sourceDurationMs: source.durationMs,
        aspectRatio: 9 / 16,
        shots: const [
          ReframeShot(
            startMs: 0,
            endMs: 10000,
            mode: 'fit',
            confidence: 1,
          ),
        ],
        focusTrack: null,
        fallbackReason: 'Deterministic test fixture',
        engine: 'test-fixture',
      );

      await repository.save(project);
      await repository.saveTranscript(project.id, transcript);
      await repository.saveCandidates(project.id, candidateSet);
      await repository.saveReframePlan(project.id, reframe);
      await repository.saveClipEditOverrides(
        project.id,
        const ClipEditOverrides(
          clipId: 'clip_two',
          framingMode: ClipFramingMode.fullFrame,
        ),
      );

      Map<String, Object?> previousExport({
        required String clipId,
        required String uri,
        required int startMs,
        required int endMs,
        required DateTime createdAt,
      }) =>
          <String, Object?>{
            'clipId': clipId,
            'projectId': project.id,
            'title': clipId,
            'outputUri': uri,
            'displayName': 'CUTAWAN_$clipId.mp4',
            'sha256': sourceSha,
            'sizeBytes': 8192,
            'durationMs': endMs - startMs,
            'width': 1080,
            'height': 1920,
            'hasAudio': false,
            'fullyDecodeValidated': true,
            'decodedVideoBuffers': 90,
            'decodedAudioBuffers': 0,
            'validated': true,
            'startMs': startMs,
            'endMs': endMs,
            'createdAtUtc': createdAt.toIso8601String(),
          };

      await repository.saveExportRecord(
        project.id,
        previousExport(
          clipId: target.id,
          uri: oldTargetUri,
          startMs: target.startMs,
          endMs: target.endMs,
          createdAt: now,
        ),
      );
      await repository.saveExportRecord(
        project.id,
        previousExport(
          clipId: peer.id,
          uri: otherClipUri,
          startMs: peer.startMs,
          endMs: peer.endMs,
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );

      final jobs = ProcessingJobService(
        repository: repository,
        fingerprintVideo: (_) async => sourceSha,
        hasActiveBackgroundRender: (_) async => false,
      );

      // Seed a checkpoint for the untouched peer using the same render
      // fingerprint inputs as ProcessingPipelineService.
      final peerEdit = await repository.loadClipEditOverrides(project.id, peer.id);
      final peerShots = peerEdit!.toExportShots(
        durationMs: peer.durationMs,
        sourceAspectRatio: 1920 / 1080,
        targetAspectRatio: 9 / 16,
        clipStartMs: peer.startMs,
      );
      final peerFingerprint = jobs.stageFingerprint(
        sourceSha256: sourceSha,
        stage: 'render_${peer.id}',
        configuration: <String, Object?>{
          'candidate': peer.toJson(),
          'aspectRatio': 9 / 16,
          'sourceAspectRatio': 1920 / 1080,
          'reframeShots': peerShots,
          'clipEditOverrides': peerEdit.toJson(),
          'resolution': project.preferences.resolution,
          'renderer': 'androidx-media3-transformer-1.11.1-reframe-v2-black-fade-v1',
          'subtitleStyle': project.preferences.captionStyleId,
          'subtitleAnimation': project.preferences.captionAnimationId,
          'captionStyle': null,
          'captionTimingOffsetMs': project.preferences.captionTimingOffsetMs,
          'captionCues': const [],
          'captionRenderer': 'media3-canvas-overlay-rtl-v1',
        },
      );
      await jobs.saveCheckpoint(
        project.id,
        stage: 'render_${peer.id}',
        fingerprint: peerFingerprint,
        artifactPaths: ['exports/${peer.id}.json'],
      );

      final nativeCalls = <MethodCall>[];
      final deletedUris = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call);
        switch (call.method) {
          case 'inspectVideo':
            return source.toJson();
          case 'getAvailableStorageBytes':
            return 1024 * 1024 * 1024;
          case 'getCompletedRender':
            return null;
          case 'startRender':
            return <String, Object?>{'renderId': 'render_targeted_clip'};
          case 'getRenderProgress':
            return <String, Object?>{
              'renderId': 'render_targeted_clip',
              'status': 'completed',
              'progress': 100,
              'error': '',
              'result': <String, Object?>{
                'outputUri': newTargetUri,
                'displayName': 'CUTAWAN_clip_one_revised.mp4',
                'sha256': newTargetSha,
                'sizeBytes': 12288,
                'durationMs': target.durationMs,
                'width': 1080,
                'height': 1920,
                'hasAudio': false,
                'fullyDecodeValidated': true,
                'decodedVideoBuffers': 120,
                'decodedAudioBuffers': 0,
                'validated': true,
              },
            };
          case 'verifyExport':
            final args = call.arguments as Map;
            return <String, Object?>{
              'valid': true,
              'sha256': args['sha256'],
              'sizeBytes': args['sizeBytes'],
              'durationMs': args['durationMs'],
              'width': args['width'],
              'height': args['height'],
              'hasVideo': true,
              'hasAudio': false,
              'fullyDecodeValidated': true,
              'decodedVideoBuffers': 90,
              'decodedAudioBuffers': 0,
            };
          case 'deleteExport':
            deletedUris.add((call.arguments as Map)['outputUri'] as String);
            return true;
          case 'acknowledgeCompletedRender':
          case 'releaseRender':
            return true;
          default:
            return null;
        }
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      try {
        final result = await ProcessingPipelineService(
          repository: repository,
          jobs: jobs,
        ).run(
          projectId: project.id,
          onlyClipId: target.id,
          transcribe: (_) async {},
          discover: (_) async {},
          analyzeFraming: (_) async {},
        );

        expect(result.exportedCount, 1);
        expect(result.skippedCount, 1);
        expect(result.candidatesCount, 2);

        final startCalls = nativeCalls.where((call) => call.method == 'startRender').toList();
        expect(startCalls, hasLength(1));
        expect((startCalls.single.arguments as Map)['clipId'], target.id);

        final verifyCalls =
            nativeCalls.where((call) => call.method == 'verifyExport').toList();
        expect(verifyCalls, hasLength(1));
        expect((verifyCalls.single.arguments as Map)['outputUri'], otherClipUri);

        expect(deletedUris, contains(oldTargetUri));
        expect(deletedUris, isNot(contains(otherClipUri)));

        final exports = await repository.loadExportRecords(project.id);
        final targetExport = exports.singleWhere((record) => record['clipId'] == target.id);
        final peerExport = exports.singleWhere((record) => record['clipId'] == peer.id);
        expect(targetExport['outputUri'], newTargetUri);
        expect(targetExport['sha256'], newTargetSha);
        expect(peerExport['outputUri'], otherClipUri);
        expect(peerExport['sha256'], sourceSha);

        final manifest = File(
          '${root.path}/artifacts/${project.id}/exports/manifest.json',
        );
        expect(await manifest.exists(), isTrue);
        expect((await repository.load(project.id))!.job.status, ProjectJobStatus.completed);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await root.delete(recursive: true);
      }
    },
  );
}
