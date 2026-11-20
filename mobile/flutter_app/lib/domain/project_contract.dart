import 'dart:math';

import 'clip_preferences.dart';

enum ProjectJobStatus { prepared, running, completed, cancelled, failed }

class VideoAssetMetadata {
  const VideoAssetMetadata({
    required this.uri,
    required this.displayName,
    required this.mimeType,
    required this.sizeBytes,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.importedAtUtc,
  });

  final String uri;
  final String displayName;
  final String mimeType;
  final int sizeBytes;
  final int durationMs;
  final int width;
  final int height;
  final int rotationDegrees;
  final DateTime importedAtUtc;

  factory VideoAssetMetadata.fromJson(Map<String, dynamic> json) {
    final uri = json['uri'] as String?;
    final displayName = json['displayName'] as String?;
    final durationMs = (json['durationMs'] as num?)?.toInt() ?? 0;
    final width = (json['width'] as num?)?.toInt() ?? 0;
    final height = (json['height'] as num?)?.toInt() ?? 0;
    final sizeBytes = (json['sizeBytes'] as num?)?.toInt() ?? 0;
    final parsedUri = uri == null ? null : Uri.tryParse(uri);
    final validContentUri = parsedUri?.scheme == 'content' &&
        (parsedUri?.authority.isNotEmpty ?? false);
    final validPrivateFileUri = parsedUri?.scheme == 'file' &&
        (parsedUri?.authority.isEmpty ?? false) &&
        (parsedUri?.path.startsWith('/') ?? false);
    if (!validContentUri && !validPrivateFileUri) {
      throw const FormatException(
        'Video source must be a persisted content:// URI or an app-private file:// URI.',
      );
    }
    if (displayName == null || displayName.trim().isEmpty) {
      throw const FormatException('Video display name is missing.');
    }
    if (durationMs <= 0 || width <= 0 || height <= 0 || sizeBytes < 0) {
      throw const FormatException('Video metadata is incomplete or invalid.');
    }
    return VideoAssetMetadata(
      uri: uri,
      displayName: displayName,
      mimeType: json['mimeType'] as String? ?? 'video/*',
      sizeBytes: sizeBytes,
      durationMs: durationMs,
      width: width,
      height: height,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
      importedAtUtc: DateTime.tryParse(
            json['importedAtUtc'] as String? ?? '',
          )?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
        'uri': uri,
        'displayName': displayName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'durationMs': durationMs,
        'width': width,
        'height': height,
        'rotationDegrees': rotationDegrees,
        'importedAtUtc': importedAtUtc.toUtc().toIso8601String(),
      };

  bool hasSameMediaInfo(VideoAssetMetadata other) =>
      uri == other.uri &&
      sizeBytes == other.sizeBytes &&
      durationMs == other.durationMs &&
      width == other.width &&
      height == other.height &&
      rotationDegrees == other.rotationDegrees;
}

class ProjectJob {
  const ProjectJob({
    required this.id,
    required this.status,
    required this.stage,
    required this.progress,
    required this.cancelRequested,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final ProjectJobStatus status;
  final String stage;
  final double progress;
  final bool cancelRequested;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  bool get canCancel =>
      status == ProjectJobStatus.prepared || status == ProjectJobStatus.running;

  ProjectJob copyWith({
    ProjectJobStatus? status,
    String? stage,
    double? progress,
    bool? cancelRequested,
    DateTime? updatedAtUtc,
  }) =>
      ProjectJob(
        id: id,
        status: status ?? this.status,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        cancelRequested: cancelRequested ?? this.cancelRequested,
        createdAtUtc: createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'status': status.name,
        'stage': stage,
        'progress': progress,
        'cancelRequested': cancelRequested,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
      };

  factory ProjectJob.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? 'prepared';
    final status = ProjectJobStatus.values.where((item) => item.name == statusName);
    if (status.isEmpty) {
      throw FormatException('Unknown job status: $statusName');
    }
    final progress = (json['progress'] as num?)?.toDouble() ?? 0;
    if (progress < 0 || progress > 1) {
      throw const FormatException('Job progress must be between 0 and 1.');
    }
    final now = DateTime.now().toUtc();
    return ProjectJob(
      id: json['id'] as String? ?? '',
      status: status.first,
      stage: json['stage'] as String? ?? 'prepared',
      progress: progress,
      cancelRequested: json['cancelRequested'] as bool? ?? false,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '')?.toUtc() ??
              now,
      updatedAtUtc:
          DateTime.tryParse(json['updatedAtUtc'] as String? ?? '')?.toUtc() ??
              now,
    );
  }
}

class CutawanProject {
  const CutawanProject({
    required this.schemaVersion,
    required this.id,
    required this.title,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.source,
    required this.preferences,
    required this.job,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String title;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final VideoAssetMetadata source;
  final ClipPreferences preferences;
  final ProjectJob job;

  factory CutawanProject.create({
    required VideoAssetMetadata source,
    required ClipPreferences preferences,
    DateTime? now,
  }) {
    final created = (now ?? DateTime.now()).toUtc();
    final entropy = Random.secure().nextInt(1 << 32).toRadixString(16);
    final id = 'cut_${created.microsecondsSinceEpoch}_$entropy';
    final title = source.displayName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return CutawanProject(
      schemaVersion: currentSchemaVersion,
      id: id,
      title: title.isEmpty ? source.displayName : title,
      createdAtUtc: created,
      updatedAtUtc: created,
      source: source,
      preferences: preferences,
      job: ProjectJob(
        id: 'job_$id',
        status: ProjectJobStatus.prepared,
        stage: 'source_imported',
        progress: 0,
        cancelRequested: false,
        createdAtUtc: created,
        updatedAtUtc: created,
      ),
    );
  }

  CutawanProject copyWith({
    String? title,
    DateTime? updatedAtUtc,
    VideoAssetMetadata? source,
    ClipPreferences? preferences,
    ProjectJob? job,
  }) =>
      CutawanProject(
        schemaVersion: schemaVersion,
        id: id,
        title: title ?? this.title,
        createdAtUtc: createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
        source: source ?? this.source,
        preferences: preferences ?? this.preferences,
        job: job ?? this.job,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'title': title,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
        'source': source.toJson(),
        'preferences': preferences.toJson(),
        'job': job.toJson(),
      };

  factory CutawanProject.fromJson(Map<String, dynamic> json) {
    final migrated = ProjectContract.migrate(json);
    if (migrated['schemaVersion'] != currentSchemaVersion) {
      throw FormatException(
        'Unsupported project schema version: ${migrated['schemaVersion']}',
      );
    }
    final id = migrated['id'] as String?;
    if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{3,160}$').hasMatch(id)) {
      throw const FormatException('Project ID is invalid.');
    }
    final sourceJson = migrated['source'];
    final preferencesJson = migrated['preferences'];
    final jobJson = migrated['job'];
    if (sourceJson is! Map<String, dynamic> ||
        preferencesJson is! Map<String, dynamic> ||
        jobJson is! Map<String, dynamic>) {
      throw const FormatException('Project payload is incomplete.');
    }
    final createdAt = DateTime.tryParse(
      migrated['createdAtUtc'] as String? ?? '',
    );
    final updatedAt = DateTime.tryParse(
      migrated['updatedAtUtc'] as String? ?? '',
    );
    final title = migrated['title'] as String?;
    if (createdAt == null ||
        updatedAt == null ||
        title == null ||
        title.trim().isEmpty) {
      throw const FormatException('Project identity or timestamps are invalid.');
    }
    final project = CutawanProject(
      schemaVersion: currentSchemaVersion,
      id: id,
      title: title,
      createdAtUtc: createdAt.toUtc(),
      updatedAtUtc: updatedAt.toUtc(),
      source: VideoAssetMetadata.fromJson(sourceJson),
      preferences: ClipPreferences.fromJson(preferencesJson),
      job: ProjectJob.fromJson(jobJson),
    );
    if (project.job.id.isEmpty) {
      throw const FormatException('Project job ID is missing.');
    }
    return project;
  }
}

class ProjectContract {
  const ProjectContract._();

  static Map<String, dynamic> migrate(Map<String, dynamic> input) {
    final version = (input['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version > CutawanProject.currentSchemaVersion) {
      throw FormatException('Project schema $version is newer than this app.');
    }
    if (version == CutawanProject.currentSchemaVersion) {
      return Map<String, dynamic>.from(input);
    }
    if (version == 0) {
      final migrated = Map<String, dynamic>.from(input);
      final projectId = migrated['id'] as String? ?? '';
      final createdAt =
          migrated['createdAtUtc'] as String? ?? DateTime.now().toUtc().toIso8601String();
      final updatedAt = migrated['updatedAtUtc'] as String? ?? createdAt;
      migrated['schemaVersion'] = 1;
      migrated.putIfAbsent('job', () => {
            'id': 'job_$projectId',
            'status': 'prepared',
            'stage': 'migrated',
            'progress': 0,
            'cancelRequested': false,
            'createdAtUtc': createdAt,
            'updatedAtUtc': updatedAt,
          });
      return migrated;
    }
    throw FormatException('No migration is available for project schema $version.');
  }
}
