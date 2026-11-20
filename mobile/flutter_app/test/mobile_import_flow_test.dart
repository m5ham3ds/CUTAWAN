import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/services.dart';

class _MemoryProjectRepository extends LocalProjectRepository {
  final Map<String, CutawanProject> _items = {};

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

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
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

      await tester.tap(find.text('اختيار فيديو'));
      await pumpUi(tester);

      expect(methods, contains('pickVideo'));
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
      await tester.pumpWidget(CutawanApp(repository: repository));
      await pumpUi(tester);
      await tester.tap(find.text('المهام'));
      await pumpUi(tester);

      expect(find.text('interview'), findsOneWidget);
      await tester.tap(find.text('إلغاء السجل'));
      await pumpUi(tester);
      expect(find.text('أُلغي سجل المهمة'), findsOneWidget);

      await tester.tap(find.text('المراجعة'));
      await pumpUi(tester);
      await tester.tap(find.text('إعادة فحص الوصول والبيانات'));
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
}
