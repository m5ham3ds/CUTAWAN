import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/home_shell.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _JobsMemoryRepository extends LocalProjectRepository {
  final Map<String, CutawanProject> records = {};

  void seed(CutawanProject project) => records[project.id] = project;

  @override
  Future<CutawanProject> cancelJob(String projectId) async {
    final project = records[projectId];
    if (project == null) throw StateError('Project not found.');
    if (!project.job.canCancel) throw StateError('Job cannot be cancelled.');
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
    records[projectId] = updated;
    return updated;
  }

  @override
  Future<void> delete(String projectId) async {
    records.remove(projectId);
  }
}

CutawanProject _makeProject(
  String name, {
  ProjectJobStatus status = ProjectJobStatus.prepared,
  String stage = 'source_imported',
  double progress = 0,
}) {
  final now = DateTime.utc(2026, 11, 21, 12);
  final project = CutawanProject.create(
    source: VideoAssetMetadata(
      uri: 'content://media/external/video/${name.hashCode.abs()}',
      displayName: '$name.mp4',
      mimeType: 'video/mp4',
      sizeBytes: 12 * 1024 * 1024,
      durationMs: 90000,
      width: 1920,
      height: 1080,
      rotationDegrees: 0,
      importedAtUtc: now,
    ),
    preferences: const ClipPreferences(requestedClipCount: 4),
    now: now,
  );
  return project.copyWith(
    updatedAtUtc: now,
    job: project.job.copyWith(
      status: status,
      stage: stage,
      progress: progress,
      cancelRequested: status == ProjectJobStatus.cancelled,
      updatedAtUtc: now,
    ),
  );
}

Future<void> _pumpJobsPage(
  WidgetTester tester, {
  required ValueNotifier<List<CutawanProject>> projects,
  required _JobsMemoryRepository repository,
  required VoidCallback onOpenReview,
  required VoidCallback onOpenCreate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: JobsPage(
            projects: projects,
            repository: repository,
            onProjectsChanged: () async {
              projects.value = repository.records.values.toList(growable: false);
            },
            onOpenReview: onOpenReview,
            onOpenCreate: onOpenCreate,
            storageUsageBytes: () async => 2 * 1024 * 1024,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mediaChannel = MethodChannel('com.cutawan.mobile/media');
  final nativeMethods = <String>[];

  setUp(() {
    nativeMethods.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, (call) async {
      nativeMethods.add(call.method);
      if (call.method == 'cancelBackgroundRenderForProject') return true;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mediaChannel, null);
  });

  testWidgets('job filters and search isolate the requested project states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _JobsMemoryRepository();
    final ready = _makeProject('ready-project');
    final running = _makeProject(
      'running-project',
      status: ProjectJobStatus.running,
      stage: 'transcribing',
      progress: 0.43,
    );
    final completed = _makeProject(
      'completed-project',
      status: ProjectJobStatus.completed,
      stage: 'complete',
      progress: 1,
    );
    final failed = _makeProject(
      'failed-project',
      status: ProjectJobStatus.failed,
      stage: 'failed_transcribing',
      progress: 0.28,
    );
    final cancelled = _makeProject(
      'cancelled-project',
      status: ProjectJobStatus.cancelled,
      stage: 'cancelled_by_user',
      progress: 0.1,
    );
    for (final project in [ready, running, completed, failed, cancelled]) {
      repository.seed(project);
    }
    final projects = ValueNotifier<List<CutawanProject>>(
      repository.records.values.toList(growable: false),
    );
    addTearDown(projects.dispose);

    var reviewOpens = 0;
    var createOpens = 0;
    await _pumpJobsPage(
      tester,
      projects: projects,
      repository: repository,
      onOpenReview: () => reviewOpens++,
      onOpenCreate: () => createOpens++,
    );

    expect(find.byKey(ValueKey('job-card-${ready.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${running.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${completed.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${failed.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${cancelled.id}')), findsOneWidget);
    expect(find.text('تعذّر في تفريغ الكلام'), findsOneWidget);
    expect(find.text('اكتملت المعالجة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('jobs-filter-attention')));
    await tester.pump();
    expect(find.byKey(ValueKey('job-card-${failed.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${cancelled.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${ready.id}')), findsNothing);
    expect(find.byKey(ValueKey('job-card-${running.id}')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('jobs-search')),
      'cancelled-project',
    );
    await tester.pump();
    expect(find.byKey(ValueKey('job-card-${cancelled.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('job-card-${failed.id}')), findsNothing);
    expect(reviewOpens, 0);
    expect(createOpens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('running jobs can be stopped but cannot be deleted while active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _JobsMemoryRepository();
    final running = _makeProject(
      'active-job',
      status: ProjectJobStatus.running,
      stage: 'rendering_clip_7',
      progress: 0.62,
    );
    repository.seed(running);
    final projects = ValueNotifier<List<CutawanProject>>([running]);
    addTearDown(projects.dispose);
    var reviewOpens = 0;

    await _pumpJobsPage(
      tester,
      projects: projects,
      repository: repository,
      onOpenReview: () => reviewOpens++,
      onOpenCreate: () {},
    );

    final deleteButton = tester.widget<IconButton>(
      find.byKey(ValueKey('delete-project-${running.id}')),
    );
    expect(deleteButton.onPressed, isNull);
    expect(find.text('إيقاف المعالجة'), findsOneWidget);

    final cancelButton = find.byKey(ValueKey('cancel-job-${running.id}'));
    await tester.ensureVisible(cancelButton);
    await tester.pump();
    await tester.tap(cancelButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final restored = repository.records[running.id]!;
    expect(restored.job.status, ProjectJobStatus.cancelled);
    expect(restored.job.cancelRequested, isTrue);
    expect(nativeMethods, contains('cancelBackgroundRenderForProject'));
    expect(find.text('متوقف'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('open-review-${running.id}')));
    expect(reviewOpens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty Jobs state opens Create and 320dp layout has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _JobsMemoryRepository();
    final projects = ValueNotifier<List<CutawanProject>>([]);
    addTearDown(projects.dispose);
    var reviewOpens = 0;
    var createOpens = 0;

    await _pumpJobsPage(
      tester,
      projects: projects,
      repository: repository,
      onOpenReview: () => reviewOpens++,
      onOpenCreate: () => createOpens++,
    );

    await tester.drag(
      find.byKey(const ValueKey('jobs-workspace-list')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مهام بعد'), findsOneWidget);
    await tester.tap(find.text('إنشاء مشروع'));
    expect(createOpens, 1);
    expect(reviewOpens, 0);
    expect(tester.takeException(), isNull);
  });
}
