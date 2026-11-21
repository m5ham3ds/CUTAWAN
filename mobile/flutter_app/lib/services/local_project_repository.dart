import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/project_contract.dart';
import '../domain/transcript_contract.dart';
import '../domain/clip_candidate.dart';
import '../domain/reframe_contract.dart';
import '../domain/clip_edit_overrides.dart';

class LocalProjectRepository {
  LocalProjectRepository({Directory? rootDirectory})
      : _rootDirectoryOverride = rootDirectory;

  final Directory? _rootDirectoryOverride;

  Future<Directory> _projectsDirectory() async {
    final root = _rootDirectoryOverride ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}'
          '${Platform.pathSeparator}cutawan_projects',
        );
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<void> save(CutawanProject project) async {
    _validateId(project.id);
    if (project.schemaVersion != CutawanProject.currentSchemaVersion) {
      throw StateError('Cannot persist an unsupported project schema.');
    }
    final validationError = project.preferences.validate();
    if (validationError != null) {
      throw FormatException(validationError);
    }
    final directory = await _projectsDirectory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}${project.id}.json',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(project.toJson()),
      flush: true,
    );
    await temporary.rename(target.path);
  }

  Future<CutawanProject?> load(String projectId) async {
    _validateId(projectId);
    final directory = await _projectsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$projectId.json',
    );
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Project file root must be a JSON object.');
    }
    return CutawanProject.fromJson(decoded);
  }

  Future<List<CutawanProject>> listProjects() async {
    final directory = await _projectsDirectory();
    final projects = <CutawanProject>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      final decoded = jsonDecode(await entity.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Invalid project file: ${entity.path}');
      }
      projects.add(CutawanProject.fromJson(decoded));
    }
    projects.sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return projects;
  }

  Future<CutawanProject> cancelJob(String projectId) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    if (!project.job.canCancel) {
      throw StateError('This job can no longer be cancelled.');
    }
    final now = DateTime.now().toUtc();
    final updated = project.copyWith(
      updatedAtUtc: now,
      job: project.job.copyWith(
        status: ProjectJobStatus.cancelled,
        stage: 'cancelled_by_user',
        cancelRequested: true,
        updatedAtUtc: now,
      ),
    );
    await save(updated);
    return updated;
  }

  Future<CutawanProject> refreshSource(
    String projectId,
    VideoAssetMetadata source,
  ) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    final updated = project.copyWith(
      source: source,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<Directory> _artifactDirectory(String projectId) async {
    _validateId(projectId);
    final root = await _projectsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}$projectId',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> saveTranscript(
    String projectId,
    CutawanTranscript transcript,
  ) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    transcript.validate();
    if ((transcript.sourceDurationMs - project.source.durationMs).abs() > 1000) {
      throw const FormatException('Transcript duration does not match its source project.');
    }
    final directory = await _artifactDirectory(projectId);
    final target = File(
      '${directory.path}${Platform.pathSeparator}transcript.json',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(transcript.toJson()), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  Future<CutawanTranscript?> loadTranscript(String projectId) async {
    final directory = await _artifactDirectory(projectId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}transcript.json',
    );
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Transcript artifact root must be a JSON object.');
    }
    return CutawanTranscript.fromJson(decoded);
  }

  Future<void> saveCandidates(
    String projectId,
    CandidateSet candidateSet,
  ) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    candidateSet.validate();
    if ((candidateSet.sourceDurationMs - project.source.durationMs).abs() > 1000) {
      throw const FormatException('Candidate duration does not match its source project.');
    }
    final directory = await _artifactDirectory(projectId);
    final target = File(
      '${directory.path}${Platform.pathSeparator}candidates.json',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(candidateSet.toJson()), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  Future<CandidateSet?> loadCandidates(String projectId) async {
    final directory = await _artifactDirectory(projectId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}candidates.json',
    );
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Candidate artifact root must be a JSON object.');
    }
    return CandidateSet.fromJson(decoded);
  }

  Future<void> saveReframePlan(String projectId, ReframePlan plan) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    plan.validate();
    if ((plan.sourceDurationMs - project.source.durationMs).abs() > 1000) {
      throw const FormatException('Reframe-plan duration does not match its source project.');
    }
    final directory = await _artifactDirectory(projectId);
    final target = File(
      '${directory.path}${Platform.pathSeparator}reframe.json',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(plan.toJson()), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  Future<ReframePlan?> loadReframePlan(String projectId) async {
    final directory = await _artifactDirectory(projectId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}reframe.json',
    );
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Reframe artifact root must be a JSON object.');
    }
    return ReframePlan.fromJson(decoded);
  }

  Future<void> saveClipEditOverrides(
    String projectId,
    ClipEditOverrides overrides,
  ) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    overrides.validate();
    final candidates = await loadCandidates(projectId);
    if (candidates == null ||
        !candidates.candidates.any((item) => item.id == overrides.clipId)) {
      throw StateError('The edited clip does not belong to this project.');
    }
    final directory = await _artifactDirectory(projectId);
    final target = File(
      '${directory.path}${Platform.pathSeparator}clip_edit_${overrides.clipId}.json',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(overrides.toJson()), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  Future<ClipEditOverrides?> loadClipEditOverrides(
    String projectId,
    String clipId,
  ) async {
    _validateId(projectId);
    if (!_isSafeToken(clipId, maxLength: 160)) {
      throw const FormatException('Clip ID is invalid.');
    }
    final directory = await _artifactDirectory(projectId);
    final file = File(
      '${directory.path}${Platform.pathSeparator}clip_edit_${clipId}.json',
    );
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Clip edit artifact root must be a JSON object.');
    }
    final overrides = ClipEditOverrides.fromJson(decoded);
    if (overrides.clipId != clipId) {
      throw const FormatException('Clip edit artifact does not match its file name.');
    }
    return overrides;
  }

  Future<void> delete(String projectId) async {
    _validateId(projectId);
    final directory = await _projectsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$projectId.json',
    );
    if (await file.exists()) {
      await file.delete();
    }
    final artifacts = Directory(
      '${directory.path}${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}$projectId',
    );
    if (await artifacts.exists()) {
      await artifacts.delete(recursive: true);
    }
  }


  Future<CutawanProject> saveJobState(
    String projectId, {
    ProjectJobStatus? status,
    String? stage,
    double? progress,
    bool? cancelRequested,
  }) async {
    final project = await load(projectId);
    if (project == null) {
      throw StateError('Project not found: $projectId');
    }
    final value = progress ?? project.job.progress;
    if (!value.isFinite || value < 0 || value > 1) {
      throw const FormatException('Job progress must be between 0 and 1.');
    }
    final now = DateTime.now().toUtc();
    final updated = project.copyWith(
      updatedAtUtc: now,
      job: project.job.copyWith(
        status: status,
        stage: stage,
        progress: value,
        cancelRequested: cancelRequested,
        updatedAtUtc: now,
      ),
    );
    await save(updated);
    return updated;
  }

  Future<void> saveStageCheckpoint(
    String projectId, {
    required String stage,
    required String fingerprint,
    required List<String> artifactPaths,
  }) async {
    if (!_isSafeToken(stage, maxLength: 160) || !_isSha256(fingerprint)) {
      throw const FormatException('Checkpoint stage or fingerprint is invalid.');
    }
    final directory = await _artifactDirectory(projectId);
    final rootPath = await directory.resolveSymbolicLinks();
    final paths = <String>[];
    for (final relative in artifactPaths) {
      final normalized = relative.replaceAll('\\', '/');
      if (normalized.isEmpty || normalized.startsWith('/') ||
          normalized.split('/').any((part) => part == '..' || part == '.' || part.isEmpty)) {
        throw const FormatException('Checkpoint artifact path is unsafe.');
      }
      final file = File('${directory.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}');
      final resolved = await file.resolveSymbolicLinks().catchError((_) => '');
      if (resolved.isEmpty ||
          !resolved.startsWith(rootPath + Platform.pathSeparator) ||
          !await file.exists() || await file.length() <= 0) {
        throw FormatException('Checkpoint artifact is missing or outside its project: $relative');
      }
      paths.add(normalized);
    }
    final target = File('${directory.path}${Platform.pathSeparator}checkpoint_$stage.json');
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode({
      'schemaVersion': 1,
      'stage': stage,
      'fingerprint': fingerprint,
      'artifactPaths': paths,
      'completedAtUtc': DateTime.now().toUtc().toIso8601String(),
    }), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<bool> hasValidStageCheckpoint(
    String projectId, {
    required String stage,
    required String fingerprint,
  }) async {
    if (!_isSafeToken(stage, maxLength: 160) || !_isSha256(fingerprint)) {
      return false;
    }
    final directory = await _artifactDirectory(projectId);
    final target = File('${directory.path}${Platform.pathSeparator}checkpoint_$stage.json');
    if (!await target.exists()) {
      return false;
    }
    try {
      final decoded = jsonDecode(await target.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['stage'] != stage ||
          decoded['fingerprint'] != fingerprint ||
          decoded['artifactPaths'] is! List<dynamic>) {
        return false;
      }
      final rootPath = await directory.resolveSymbolicLinks();
      for (final raw in decoded['artifactPaths'] as List<dynamic>) {
        if (raw is! String) {
          return false;
        }
        final normalized = raw.replaceAll('\\', '/');
        if (normalized.isEmpty || normalized.startsWith('/') ||
            normalized.split('/').any((part) => part == '..' || part == '.' || part.isEmpty)) {
          return false;
        }
        final file = File('${directory.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}');
        final resolved = await file.resolveSymbolicLinks().catchError((_) => '');
        if (resolved.isEmpty ||
            !resolved.startsWith(rootPath + Platform.pathSeparator) ||
            !await file.exists() || await file.length() <= 0) {
          return false;
        }
      }
      return true;
    } on FormatException {
      return false;
    } on FileSystemException {
      return false;
    } on TypeError {
      return false;
    }
  }

  Future<String> exportFilePath(String projectId, String clipId) async {
    if (!_isSafeToken(clipId, maxLength: 160)) {
      throw const FormatException('Clip ID is invalid.');
    }
    final directory = await _exportDirectory(projectId);
    return '${directory.path}${Platform.pathSeparator}$clipId.mp4';
  }

  Future<String> subtitleFilePath(
    String projectId,
    String clipId, {
    required String extension,
  }) async {
    if (!_isSafeToken(clipId, maxLength: 160) ||
        (extension != 'srt' && extension != 'ass')) {
      throw const FormatException('Subtitle path is invalid.');
    }
    final directory = await _subtitleDirectory(projectId);
    return '${directory.path}${Platform.pathSeparator}$clipId.$extension';
  }

  Future<void> saveExportRecord(
    String projectId,
    Map<String, Object?> record,
  ) async {
    final clipId = record['clipId'];
    final uri = record['outputUri'];
    final digest = record['sha256'];
    final size = record['sizeBytes'];
    final duration = record['durationMs'];
    final width = record['width'];
    final height = record['height'];
    if (clipId is! String || !_isSafeToken(clipId, maxLength: 160) ||
        uri is! String || uri.trim().isEmpty ||
        digest is! String || !_isSha256(digest) ||
        size is! num || size < 2048 ||
        duration is! num || duration <= 0 ||
        width is! num || width <= 0 ||
        height is! num || height <= 0 ||
        record['validated'] != true) {
      throw const FormatException('Export record is incomplete or unvalidated.');
    }
    final directory = await _exportDirectory(projectId);
    final target = File('${directory.path}${Platform.pathSeparator}$clipId.json');
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(record), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<List<Map<String, dynamic>>> loadExportRecords(String projectId) async {
    final directory = await _exportDirectory(projectId);
    final records = <Map<String, dynamic>>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith('.json') ||
          entity.uri.pathSegments.last == 'manifest.json') {
        continue;
      }
      final decoded = jsonDecode(await entity.readAsString());
      if (decoded is Map<String, dynamic>) {
        records.add(decoded);
      }
    }
    records.sort((a, b) =>
        (b['createdAtUtc'] as String? ?? '').compareTo(a['createdAtUtc'] as String? ?? ''));
    return records;
  }

  Future<void> saveExportManifest(
    String projectId,
    Map<String, Object?> manifest,
  ) async {
    final directory = await _exportDirectory(projectId);
    final target = File('${directory.path}${Platform.pathSeparator}manifest.json');
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(manifest), flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<Directory> _exportDirectory(String projectId) async {
    final artifacts = await _artifactDirectory(projectId);
    final directory = Directory('${artifacts.path}${Platform.pathSeparator}exports');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _subtitleDirectory(String projectId) async {
    final artifacts = await _artifactDirectory(projectId);
    final directory = Directory('${artifacts.path}${Platform.pathSeparator}subtitles');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  bool _isSafeToken(String value, {required int maxLength}) =>
      value.isNotEmpty &&
      value.length <= maxLength &&
      value.codeUnits.every(
        (unit) =>
            (unit >= 48 && unit <= 57) ||
            (unit >= 65 && unit <= 90) ||
            (unit >= 97 && unit <= 122) ||
            unit == 45 ||
            unit == 95,
      );

  bool _isSha256(String value) =>
      value.length == 64 &&
      value.codeUnits.every(
        (unit) =>
            (unit >= 48 && unit <= 57) ||
            (unit >= 97 && unit <= 102),
      );

  void _validateId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,160}$').hasMatch(id)) {
      throw const FormatException('Project ID is invalid.');
    }
  }
}
