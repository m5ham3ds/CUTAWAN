import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/material.dart';
import 'package:cutawan_mobile/app.dart';

void configureCaptionStudioViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('mobile shell shows the four AutoClip-inspired destinations', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(find.text('إدخال'), findsOneWidget);
    expect(find.text('المهام'), findsOneWidget);
    expect(find.text('المراجعة'), findsOneWidget);
    expect(find.text('الاستوديو'), findsOneWidget);
    expect(find.textContaining('فيديو طويل يدخل'), findsOneWidget);
  });

  testWidgets('caption studio keeps visual presets separate from animation choices', (tester) async {
    configureCaptionStudioViewport(tester);
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('الاستوديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('اصنع أسلوبك الخاص'), findsOneWidget);
    expect(find.text('Beast'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Word Pop'), findsOneWidget);
    await tester.tap(find.text('Word Pop'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Karaoke Fill'), findsOneWidget);
  });

  testWidgets('caption studio preview is animated and persists edits in the latest project', (tester) async {
    configureCaptionStudioViewport(tester);
    final directory = await Directory.systemTemp.createTemp('cutawan-caption-widget-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final repository = LocalProjectRepository(rootDirectory: directory);
    final now = DateTime.utc(2026, 11, 20);
    final project = CutawanProject.create(
      source: VideoAssetMetadata(
        uri: 'content://media/external/video/media/99',
        displayName: 'caption.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 2000,
        durationMs: 30000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      ),
      preferences: const ClipPreferences(),
      now: now,
    );
    await repository.save(project);
    await tester.pumpWidget(CutawanApp(repository: repository));
    await tester.tap(find.text('الاستوديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('معاينة عربية / RTL'), findsOneWidget);
    final arabicPreview = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains('هذه لحظة'));
    expect(arabicPreview.textDirection, TextDirection.rtl);
    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('English'), findsOneWidget);
    final englishPreview = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains('This is the moment'));
    expect(englishPreview.textDirection, TextDirection.ltr);
    expect(find.text('Karaoke'), findsOneWidget);
    await tester.tap(find.text('Karaoke'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('حفظ إعدادات الاستوديو في المشروع'), findsOneWidget);
    await tester.tap(find.text('حفظ إعدادات الاستوديو في المشروع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final saved = await repository.load(project.id);
    expect(saved, isNotNull);
    expect(saved!.preferences.captionStyleId, 'karaoke');
    expect(saved.preferences.captionFontFamily, isNotEmpty);
    expect(saved.preferences.captionFontScale, greaterThan(0));
    expect(saved.preferences.captionPositionY, inInclusiveRange(0.1, 0.9));
  });

  testWidgets('jobs and review pages explain that processing is not connected yet', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('المهام'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مهام بعد'), findsOneWidget);

    await tester.tap(find.text('المراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مقاطع للمراجعة'), findsOneWidget);
  });
}
