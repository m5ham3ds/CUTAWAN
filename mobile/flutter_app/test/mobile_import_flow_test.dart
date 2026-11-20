import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/services.dart';

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

  late Directory directory;
  late LocalProjectRepository repository;
  final methods = <String>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-mobile-flow-');
    repository = LocalProjectRepository(rootDirectory: directory);
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
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets(
    'import saves project, reopen restores it, cancel persists and media can be re-inspected',
    (tester) async {
      await tester.pumpWidget(CutawanApp(repository: repository));
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
