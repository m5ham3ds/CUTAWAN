import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import 'package:cutawan_mobile/screens/home_shell/models_page.dart';
import 'package:cutawan_mobile/services/ai_model_gateway.dart';
import 'package:cutawan_mobile/services/qwen_model_manager.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

class _MemoryCredentialStorage implements AiSecretStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'model center stays usable at compact, regular and wide sizes with enlarged text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cases = <({
        Size size,
        TextDirection direction,
        ThemeData theme,
        double scale,
      })>[
        (
          size: const Size(320, 780),
          direction: TextDirection.rtl,
          theme: CutawanTheme.light(),
          scale: 2,
        ),
        (
          size: const Size(390, 844),
          direction: TextDirection.ltr,
          theme: CutawanTheme.dark(),
          scale: 1.5,
        ),
        (
          size: const Size(720, 900),
          direction: TextDirection.rtl,
          theme: CutawanTheme.dark(),
          scale: 1,
        ),
      ];

      for (final item in cases) {
        tester.view.physicalSize = item.size;
        tester.view.devicePixelRatio = 1;
        final directory = await Directory.systemTemp.createTemp(
          'cutawan-models-widget-',
        );
        final credentials = AiCredentialStore(
          storage: _MemoryCredentialStorage(),
        );
        final whisper = WhisperModelManager(storageDirectory: directory);
        final qwen = QwenModelManager(storageDirectory: directory);

        await tester.pumpWidget(
          MaterialApp(
            theme: item.theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: item.size,
                textScaler: TextScaler.linear(item.scale),
              ),
              child: Directionality(
                textDirection: item.direction,
                child: ModelsPage(
                  whisperManager: whisper,
                  qwenManager: qwen,
                  credentials: credentials,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('مركز النماذج'), findsOneWidget);
        expect(find.text('النماذج المحلية'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('اختيار محرك الذكاء الاصطناعي'),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('اختيار محرك الذكاء الاصطناعي'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await directory.delete(recursive: true);
      }
    },
  );
}
