import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../domain/project_contract.dart';
import 'android_video_picker.dart';
import 'local_project_repository.dart';

class ProcessingCancelled implements Exception {
  const ProcessingCancelled();

  @override
  String toString() => 'Processing was cancelled.';
}

class ProcessingJobService {
  ProcessingJobService({
    required LocalProjectRepository repository,
    Future<String> Function(String uri)? fingerprintVideo,
    Future<bool> Function(String projectId)? hasActiveBackgroundRender,
  })  : _repository = repository,
        _fingerprintVideo =
            fingerprintVideo ?? AndroidVideoPicker.fingerprintVideo,
        _hasActiveBackgroundRender =
            hasActiveBackgroundRender ?? _queryActiveBackgroundRender;

  final LocalProjectRepository _repository;
  final Future<String> Function(String uri) _fingerprintVideo;
  final Future<bool> Function(String projectId) _hasActiveBackgroundRender;

  static const MethodChannel _backgroundRenderChannel =
      MethodChannel('com.cutawan.mobile/media');

  static Future<bool> _queryActiveBackgroundRender(String projectId) async {
    try {
      return await _backgroundRenderChannel.invokeMethod<bool>(
            'hasActiveBackgroundRender',
            <String, Object?>{'projectId': projectId},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static bool isSha256(String value) {
    if (value.length != 64) return false;
    for (final unit in value.codeUnits) {
      final valid = (unit >= 48 && unit <= 57) || (unit >= 97 && unit <= 102);
      if (!valid) return false;
    }
    return true;
  }

  Future<String> fingerprintSource(CutawanProject project) =>
      _fingerprintVideo(project.source.uri);

  String stageFingerprint({
    required String sourceSha256,
    required String stage,
    Object? configuration,
  }) {
    final payload = <String, Object?>{
      'pipelineVersion': 'cutawan-pipeline-v1',
      'stage': stage,
      'sourceSha256': sourceSha256,
      'configuration': configuration,
    };
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  Future<bool> isCancellationRequested(String projectId) async {
    final project = await _repository.load(projectId);
    return project == null ||
        project.job.cancelRequested ||
        project.job.status == ProjectJobStatus.cancelled;
  }

  Future<void> begin(String projectId) async {
    await _repository.saveJobState(
      projectId,
      status: ProjectJobStatus.running,
      stage: 'queued',
      progress: 0,
      cancelRequested: false,
    );
  }

  Future<void> setStage(
    String projectId, {
    required String stage,
    required double progress,
  }) async {
    if (await isCancellationRequested(projectId)) {
      throw const ProcessingCancelled();
    }
    await _repository.saveJobState(
      projectId,
      status: ProjectJobStatus.running,
      stage: stage,
      progress: progress.clamp(0.0, 0.99).toDouble(),
    );
  }

  Future<void> saveCheckpoint(
    String projectId, {
    required String stage,
    required String fingerprint,
    required List<String> artifactPaths,
  }) =>
      _repository.saveStageCheckpoint(
        projectId,
        stage: stage,
        fingerprint: fingerprint,
        artifactPaths: artifactPaths,
      );

  Future<bool> hasCheckpoint(
    String projectId, {
    required String stage,
    required String fingerprint,
  }) =>
      _repository.hasValidStageCheckpoint(
        projectId,
        stage: stage,
        fingerprint: fingerprint,
      );

  Future<void> complete(String projectId) async {
    await _repository.saveJobState(
      projectId,
      status: ProjectJobStatus.completed,
      stage: 'complete',
      progress: 1,
      cancelRequested: false,
    );
  }

  Future<void> cancel(String projectId) async {
    await _repository.saveJobState(
      projectId,
      status: ProjectJobStatus.cancelled,
      stage: 'cancelled',
      cancelRequested: true,
    );
  }

  Future<void> fail(String projectId, {required String stage}) async {
    final project = await _repository.load(projectId);
    if (project == null) return;
    await _repository.saveJobState(
      projectId,
      status: ProjectJobStatus.failed,
      stage: 'failed_$stage',
      cancelRequested: false,
    );
  }

  Future<void> recoverInterruptedJobs() async {
    final projects = await _repository.listProjects();
    for (final project in projects) {
      if (project.job.status != ProjectJobStatus.running) continue;
      // A durable WorkManager worker may still be queued/running even though
      // the Flutter Activity/process that started it has been destroyed.
      final backgroundWorkIsActive =
          await _hasActiveBackgroundRender(project.id);
      if (backgroundWorkIsActive) continue;
      final interruptedStage = project.job.stage.trim();
      final safeStage = interruptedStage.isEmpty
          ? 'unknown'
          : interruptedStage.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_').substring(
              0,
              interruptedStage.length > 96 ? 96 : interruptedStage.length,
            );
      await _repository.saveJobState(
        project.id,
        status: ProjectJobStatus.failed,
        stage: 'interrupted_after_process_death:$safeStage',
        cancelRequested: false,
      );
    }
  }
}
