import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/reframe_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:cutawan_mobile/screens/home_shell/review_page.dart';

class _ReviewMemoryRepository extends LocalProjectRepository {
  final Map<String, CutawanProject> _projects = {};
  final Map<String, List<Map<String, dynamic>>> _exports = {};

  void seed(CutawanProject project) {
    _projects[project.id] = project;
  }

  void seedExport(String projectId, Map<String, dynamic> export) {
    _exports[projectId] = [Map<String, dynamic>.from(export)];
  }

  @override
  Future<List<CutawanProject>> listProjects() async {
    final values = _projects.values.toList()
      ..sort((a, b) => b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return values;
  }

  @override
  Future<CutawanProject?> load(String projectId) async => _projects[projectId];

  @override
  Future<void> save(CutawanProject project) async {
    _projects[project.id] = project;
  }

  @override
  Future<CutawanTranscript?> loadTranscript(String projectId) async => null;

  @override
  Future<CandidateSet?> loadCandidates(String projectId) async => null;

  @override
  Future<ReframePlan?> loadReframePlan(String projectId) async => null;

  @override
  Future<List<Map<String, dynamic>>> loadExportRecords(String projectId) async =>
      List<Map<String, dynamic>>.from(_exports[projectId] ?? const []);

  @override
  Future<void> deleteExportRecord(String projectId, String clipId) async {
    _exports[projectId]?.removeWhere((record) => record['clipId'] == clipId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'validated export gallery opens, shares and deletes only the selected CUTAWAN video',
    (tester) async {
      const channel = MethodChannel('com.cutawan.mobile/media');
      final nativeCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call);
        return true;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _ReviewMemoryRepository();
      final project = CutawanProject.create(
        source: VideoAssetMetadata(
          uri: 'content://media/external/video/media/71',
          displayName: 'review-workflow.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 18000000,
          durationMs: 94000,
          width: 1920,
          height: 1080,
          rotationDegrees: 0,
          importedAtUtc: DateTime.utc(2026, 11, 21),
        ),
        preferences: const ClipPreferences(),
        now: DateTime.utc(2026, 11, 21),
      );
      repository.seed(project);
      repository.seedExport(project.id, {
        'clipId': 'clip_gallery_1',
        'outputUri': 'content://media/external/video/media/9001',
        'displayName': 'CUTAWAN_clip_gallery_1.mp4',
        'sha256': List<String>.filled(64, 'a').join(),
        'sizeBytes': 8192,
        'durationMs': 15000,
        'width': 1080,
        'height': 1920,
        'validated': true,
        'fullyDecodeValidated': true,
        'createdAtUtc': DateTime.utc(2026, 11, 22).toIso8601String(),
      });

      final projects = ValueNotifier<List<CutawanProject>>([project]);
      addTearDown(projects.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ReviewPage(
              projects: projects,
              repository: repository,
              onProjectsChanged: () async {},
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final openButton = find.byKey(const ValueKey('open-export-clip_gallery_1'));
      await tester.ensureVisible(openButton);
      await tester.pumpAndSettle();
      await tester.tap(openButton);
      await tester.pumpAndSettle();
      expect(nativeCalls.map((call) => call.method), contains('openExport'));

      final shareButton = find.byKey(const ValueKey('share-export-clip_gallery_1'));
      await tester.ensureVisible(shareButton);
      await tester.pumpAndSettle();
      await tester.tap(shareButton);
      await tester.pumpAndSettle();
      expect(nativeCalls.map((call) => call.method), contains('shareExport'));

      final deleteButton = find.byKey(const ValueKey('delete-export-clip_gallery_1'));
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('حذف الفيديو المصدّر؟'), findsOneWidget);
      await tester.tap(find.text('حذف الملف'));
      await tester.pumpAndSettle();

      expect(nativeCalls.map((call) => call.method), contains('deleteExport'));
      expect(repository._exports[project.id], isEmpty);
      expect(find.byKey(const ValueKey('export-card-clip_gallery_1')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review page presents the staged source-analysis-clips-export workflow on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _ReviewMemoryRepository();
      final project = CutawanProject.create(
        source: VideoAssetMetadata(
          uri: 'content://media/external/video/media/71',
          displayName: 'review-workflow.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 18000000,
          durationMs: 94000,
          width: 1920,
          height: 1080,
          rotationDegrees: 0,
          importedAtUtc: DateTime.utc(2026, 11, 21),
        ),
        preferences: const ClipPreferences(),
        now: DateTime.utc(2026, 11, 21),
      );
      repository.seed(project);

      await tester.pumpWidget(CutawanApp(
        repository: repository,
        storageUsageBytes: () async => 0,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      await tester.tap(find.text('المراجعة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('راجع النتائج قبل إخراجها'), findsOneWidget);
      expect(find.text('مسار المشروع'), findsOneWidget);
      expect(find.text('المصدر'), findsOneWidget);
      expect(find.text('التحليل'), findsOneWidget);
      expect(find.text('المقاطع'), findsOneWidget);
      expect(find.text('الإخراج'), findsOneWidget);
      expect(find.byKey(ValueKey('review-run-pipeline-${project.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('review-transcript-${project.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('review-framing-${project.id}')), findsOneWidget);
      expect(find.text('المقاطع المكتشفة'), findsOneWidget);
      expect(find.text('الفيديوهات المصدّرة'), findsOneWidget);

      await tester.ensureVisible(find.byKey(ValueKey('review-manual-tools-${project.id}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('review-manual-tools-${project.id}')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('إعادة التفريغ'), findsOneWidget);
      expect(find.text('إعادة تحليل التأطير'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review focuses the project opened from Dashboard before other saved projects',
    (tester) async {
      tester.view.physicalSize = const Size(320, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _ReviewMemoryRepository();
      final olderProject = CutawanProject.create(
        source: VideoAssetMetadata(
          uri: 'content://media/external/video/media/72',
          displayName: 'older-project.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 9000000,
          durationMs: 70000,
          width: 1280,
          height: 720,
          rotationDegrees: 0,
          importedAtUtc: DateTime.utc(2026, 11, 20),
        ),
        preferences: const ClipPreferences(),
        now: DateTime.utc(2026, 11, 20),
      );
      final requestedProject = CutawanProject.create(
        source: VideoAssetMetadata(
          uri: 'content://media/external/video/media/73',
          displayName: 'requested-project.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 11000000,
          durationMs: 83000,
          width: 1920,
          height: 1080,
          rotationDegrees: 0,
          importedAtUtc: DateTime.utc(2026, 11, 21),
        ),
        preferences: const ClipPreferences(),
        now: DateTime.utc(2026, 11, 21),
      );
      repository.seed(olderProject);
      repository.seed(requestedProject);
      final projects = ValueNotifier<List<CutawanProject>>([
        olderProject,
        requestedProject,
      ]);
      addTearDown(projects.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: ReviewPage(
                projects: projects,
                repository: repository,
                onProjectsChanged: () async {},
                initialProjectId: requestedProject.id,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('المشروع المحدد من الرئيسية'),
        findsOneWidget,
      );
      final requestedCard = find.byKey(
        ValueKey('review-project-${requestedProject.id}'),
      );
      final olderCard = find.byKey(
        ValueKey('review-project-${olderProject.id}'),
      );
      expect(
        tester.getRect(requestedCard).top,
        lessThan(tester.getRect(olderCard).top),
      );
      expect(
        find.byKey(
          ValueKey('review-run-pipeline-${requestedProject.id}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );


}
