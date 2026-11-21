import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/reframe_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';

class _ReviewMemoryRepository extends LocalProjectRepository {
  final Map<String, CutawanProject> _projects = {};

  void seed(CutawanProject project) {
    _projects[project.id] = project;
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
  Future<List<Map<String, dynamic>>> loadExportRecords(String projectId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
