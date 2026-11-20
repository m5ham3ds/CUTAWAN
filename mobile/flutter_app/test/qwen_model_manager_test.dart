import 'dart:io';

import 'package:cutawan_mobile/services/qwen_model_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

void main() {
  test('Qwen model manifest pins HTTPS revision, size, digest and license', () {
    final uri = Uri.parse(QwenModelManager.modelUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'huggingface.co');
    expect(uri.path, contains(QwenModelManager.modelRevision));
    expect(
      QwenModelManager.modelRevision,
      '6dd44a1fb35d11b5d1b28902876ce3cc9e882d0e',
    );
    expect(
      QwenModelManager.sha256Hex,
      '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
    );
    expect(QwenModelManager.modelBytes, 491400032);
    expect(QwenModelManager.license, 'Apache-2.0');
    expect(
      QwenModelManager.minimumFreeBytes,
      greaterThan(QwenModelManager.modelBytes),
    );
  });

  test('Qwen manager rejects an installed file with the wrong size', () async {
    final directory = await Directory.systemTemp.createTemp('cutawan-qwen-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final target = File(
      '${directory.path}${Platform.pathSeparator}${QwenModelManager.fileName}',
    );
    await target.writeAsBytes([1, 2, 3]);

    final manager = QwenModelManager(storageDirectory: directory);
    await expectLater(
      manager.findInstalled(),
      throwsA(isA<FormatException>()),
    );
  });

  test('Whisper catalog selects a pinned multilingual model, not English-only', () {
    final model = WhisperModelCatalog.base;
    expect(model.id, 'base');
    expect(
      model.languageScope,
      WhisperModelLanguageScope.multilingual,
    );
    expect(Uri.parse(model.url).scheme, 'https');
    expect(
      model.sha256,
      '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
    );
    expect(model.approximateBytes, 147951465);
  });
}
