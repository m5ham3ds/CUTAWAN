import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/services.dart';

class _MemoryProjectRepository extends LocalProjectRepository {
  final Map<String, CutawanProject> _items = {};

  void seedProject(CutawanProject project) {
    _items[project.id] = project;
  }

  List<CutawanProject> get storedProjects => _items.values.toList();

  @override
  Future<void> save(CutawanProject project) async {
    _items[project.id] = project;
  }

  @override
  Future<List<CutawanProject>> listProjects() async {
    final items = storedProjects
      ..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return items;
  }

  @override
  Future<CutawanProject?> load(String projectId) async => _items[projectId];

  @override
  Future<CutawanProject> cancelJob(String projectId) async {
    final project = _items[projectId];
    if (project == null) throw StateError('Project not found.');
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
    _items[projectId] = updated;
    return updated;
  }

  @override
  Future<CutawanProject> refreshSource(
    String projectId,
    VideoAssetMetadata source,
  ) async {
    final project = _items[projectId];
    if (project == null) throw StateError('Project not found.');
    final updated = project.copyWith(
      source: source,
      updatedAtUtc: DateTime.now().toUtc(),
    );
    _items[projectId] = updated;
    return updated;
  }

  @override
  Future<void> delete(String projectId) async {
    _items.remove(projectId);
  }
}

class _FailingSaveRepository extends _MemoryProjectRepository {
  @override
  Future<void> save(CutawanProject project) async {
    throw StateError('simulated disk write failure');
  }
}

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> openCreatePage(WidgetTester tester) async {
  await tester.tap(find.text('إنشاء'));
  await pumpUi(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mediaChannel = MethodChannel('com.cutawan.mobile/media');

  final metadata = <String, Object?>{
    'uri': 'content://media/external/video/media/42',
    'displayName': 'interview.mp4',
    'mimeType': 'video/mp4',
    'sizeBytes': 24000000,
    'durationMs': 125000,
    'width': 1920,
    'height': 1080,
    'rotationDegrees': 0,
    'importedAtUtc': '2026-11-20T01:00:00.000Z',
  };

  late _MemoryProjectRepository repository;
  final methods = <String>[];

  setUp(() async {
    repository = _MemoryProjectRepository();
    methods.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
      methods.add(call.method);
      if (call.method == 'pickVideo' || call.method == 'inspectVideo') {
        return metadata;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, null);
  });

  testWidgets(
    'import saves project, reopen restores it, cancel persists and media can be re-inspected',
    (tester) async {
      await tester.pumpWidget(
        CutawanApp(repository: repository, storageUsageBytes: () async => 0),
      );
      await pumpUi(tester);

      await openCreatePage(tester);
      await tester.tap(find.text('اختيار فيديو'));
      await pumpUi(tester);

      expect(methods, contains('pickVideo'));
      expect(await repository.listProjects(), isEmpty,
          reason: 'Choosing a source must not save a project before settings are confirmed.');
      await tester.ensureVisible(find.byKey(const ValueKey('create-step-continue')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-step-continue')));
      await pumpUi(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('create-project-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
      await pumpUi(tester);
      final savedProjects = await repository.listProjects();
      expect(
        savedProjects,
        hasLength(1),
        reason: 'The selected media must be persisted as a project before the UI switches to Jobs.',
      );
      expect(savedProjects.single.source.uri, metadata['uri']);

      await tester.tap(find.text('المهام'));
      await pumpUi(tester);
      expect(find.text('interview'), findsOneWidget);
      expect(
        find.text('المصدر محفوظ — جاهز للتحليل (لم يبدأ المحرك)'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpUi(tester);
      await tester.pumpWidget(
        CutawanApp(repository: repository, storageUsageBytes: () async => 0),
      );
      await pumpUi(tester);
      await tester.tap(find.text('المهام'));
      await pumpUi(tester);

      expect(find.text('interview'), findsOneWidget);
      final cancelButton = find.byKey(ValueKey('cancel-job-${savedProjects.single.id}'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pump();
      await tester.ensureVisible(cancelButton);
      await tester.pump();
      await tester.tap(cancelButton);
      await pumpUi(tester);
      final cancelledProject = await repository.load(savedProjects.single.id);
      expect(cancelledProject?.job.status, ProjectJobStatus.cancelled);

      await tester.tap(find.text('المراجعة'));
      await pumpUi(tester);
      final verifyButton =
          find.byKey(ValueKey('review-verify-${savedProjects.single.id}'));
      await tester.ensureVisible(verifyButton);
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(verifyButton).onPressed,
        isNotNull,
        reason: 'The source verification action must remain enabled for a cancelled, resumable project.',
      );
      await tester.tap(verifyButton);
      await pumpUi(tester);

      expect(methods, contains('inspectVideo'));
      final refreshedProject = await repository.load(savedProjects.single.id);
      expect(refreshedProject, isNotNull);
      expect(
        refreshedProject!.source.hasSameMediaInfo(savedProjects.single.source),
        isTrue,
      );
    },
  );

  testWidgets('failed import releases a new SAF grant only when no project references it', (tester) async {
    final failingRepository = _FailingSaveRepository();
    repository = failingRepository;
    await tester.pumpWidget(
      CutawanApp(
        repository: repository,
        storageUsageBytes: () async => 0,
      ),
    );
    await pumpUi(tester);

    await openCreatePage(tester);
    await tester.tap(find.text('اختيار فيديو'));
    await pumpUi(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('create-step-continue')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-step-continue')));
    await pumpUi(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('create-project-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
    await pumpUi(tester);
    await tester.tap(find.text('المهام'));
    await pumpUi(tester);

    expect(methods, contains('pickVideo'));
    expect(methods, contains('releasePersistedPermission'));
    expect(failingRepository.storedProjects, isEmpty);
  });

  testWidgets('failed duplicate import preserves a SAF grant used by an existing project', (tester) async {
    final failingRepository = _FailingSaveRepository();
    final existingProject = CutawanProject.create(
      source: VideoAssetMetadata.fromJson(Map<String, dynamic>.from(metadata)),
      preferences: const ClipPreferences(),
      now: DateTime.utc(2026, 11, 20),
    );
    failingRepository.seedProject(existingProject);
    repository = failingRepository;

    await tester.pumpWidget(
      CutawanApp(
        repository: repository,
        storageUsageBytes: () async => 0,
      ),
    );
    await pumpUi(tester);

    await openCreatePage(tester);
    await tester.tap(find.text('اختيار فيديو'));
    await pumpUi(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('create-step-continue')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-step-continue')));
    await pumpUi(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('create-project-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
    await pumpUi(tester);
    await tester.tap(find.text('المهام'));
    await pumpUi(tester);

    expect(methods, contains('pickVideo'));
    expect(methods, isNot(contains('releasePersistedPermission')));
    expect(failingRepository.storedProjects, hasLength(1));
  });

}
