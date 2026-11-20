import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/project_contract.dart';

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
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<void> save(CutawanProject project) async {
    _validateId(project.id);
    if (project.schemaVersion != CutawanProject.currentSchemaVersion) {
      throw StateError('Cannot persist an unsupported project schema.');
    }
    final validationError = project.preferences.validate();
    if (validationError != null) throw FormatException(validationError);
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
    if (!await file.exists()) return null;
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
      if (entity is! File || !entity.path.endsWith('.json')) continue;
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
    if (project == null) throw StateError('Project not found: $projectId');
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
    if (project == null) throw StateError('Project not found: $projectId');
    final updated = project.copyWith(
      source: source,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    await save(updated);
    return updated;
  }

  Future<void> delete(String projectId) async {
    _validateId(projectId);
    final directory = await _projectsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$projectId.json',
    );
    if (await file.exists()) await file.delete();
  }

  void _validateId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{3,160}$').hasMatch(id)) {
      throw const FormatException('Project ID is invalid.');
    }
  }
}
