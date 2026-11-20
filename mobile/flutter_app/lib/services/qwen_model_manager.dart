import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class QwenModelProgress {
  const QwenModelProgress(this.receivedBytes, this.totalBytes);

  final int receivedBytes;
  final int totalBytes;

  double get fraction => totalBytes <= 0
      ? 0
      : (receivedBytes / totalBytes).clamp(0.0, 1.0).toDouble();
}

class QwenModelManager {
  QwenModelManager({Directory? storageDirectory})
      : _storageDirectoryOverride = storageDirectory;

  static const modelId = 'qwen2.5-0.5b-instruct-q4_k_m';
  static const fileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const modelBytes = 491400032;
  static const sha256Hex =
      '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db';
  static const modelRevision =
      '6dd44a1fb35d11b5d1b28902876ce3cc9e882d0e';
  static const modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/'
      '$modelRevision/$fileName';
  static const license = 'Apache-2.0';
  static const minimumFreeBytes = modelBytes + 128 * 1024 * 1024;

  final Directory? _storageDirectoryOverride;

  Future<Directory> get directory async {
    final override = _storageDirectoryOverride;
    final root = override ??
        Directory('${(await getApplicationSupportDirectory()).path}'
            '${Platform.pathSeparator}cutawan_models');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<File?> findInstalled() async {
    final target = File('${(await directory).path}'
        '${Platform.pathSeparator}$fileName');
    if (!await target.exists()) return null;
    final length = await target.length();
    if (length != modelBytes) {
      throw FormatException(
        'Qwen GGUF file size mismatch: expected $modelBytes bytes, found $length.',
      );
    }
    final digest = await sha256.bind(target.openRead()).first;
    if (digest.toString().toLowerCase() != sha256Hex) {
      throw const FormatException('Qwen GGUF SHA-256 verification failed.');
    }
    return target;
  }

  Future<void> download({
    required void Function(QwenModelProgress progress) onProgress,
  }) async {
    final root = await directory;
    final target = File('${root.path}${Platform.pathSeparator}$fileName');
    final partial = File('${target.path}.part');
    final client = http.Client();
    try {
      if (await target.exists()) {
        try {
          final installed = await findInstalled();
          if (installed != null) {
            onProgress(const QwenModelProgress(modelBytes, modelBytes));
            return;
          }
        } on FormatException {
          // A corrupt managed file is safe to replace because it has not
          // passed the model integrity gate and is not loadable by the app.
          await target.delete();
        }
      }
      if (await partial.exists()) await partial.delete();

      var uri = Uri.parse(modelUrl);
      if (uri.scheme != 'https' || uri.host != 'huggingface.co') {
        throw const FormatException(
          'Model manifest URL must be pinned HTTPS Hugging Face.',
        );
      }
      http.StreamedResponse? response;
      for (var redirects = 0; redirects <= 5; redirects++) {
        final request = http.Request('GET', uri)..followRedirects = false;
        response = await client.send(request);
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers['location'];
          await response.stream.drain<void>();
          if (location == null || redirects == 5) {
            throw const HttpException('Model download redirect limit exceeded.');
          }
          final next = uri.resolve(location);
          if (next.scheme != 'https' || next.host.isEmpty) {
            throw const HttpException(
              'Model download attempted an insecure redirect.',
            );
          }
          uri = next;
          continue;
        }
        break;
      }

      if (response == null || response.statusCode != 200) {
        final code = response?.statusCode ?? 0;
        if (response != null) await response.stream.drain<void>();
        throw HttpException('Model download failed: HTTP $code');
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength != modelBytes) {
        await response.stream.drain<void>();
        throw FormatException(
          'Unexpected model length: expected $modelBytes bytes, got $declaredLength.',
        );
      }

      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (received > modelBytes) {
            throw const FormatException(
              'Model download exceeded the pinned file size.',
            );
          }
          sink.add(chunk);
          onProgress(QwenModelProgress(received, modelBytes));
        }
      } finally {
        await sink.close();
      }

      if (received != modelBytes || await partial.length() != modelBytes) {
        throw FormatException(
          'Incomplete model download: expected $modelBytes bytes, received $received.',
        );
      }
      final digest = await sha256.bind(partial.openRead()).first;
      if (digest.toString().toLowerCase() != sha256Hex) {
        throw const FormatException('Qwen GGUF SHA-256 verification failed.');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      onProgress(const QwenModelProgress(modelBytes, modelBytes));
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> deleteInstalled() async {
    final target = File('${(await directory).path}'
        '${Platform.pathSeparator}$fileName');
    if (await target.exists()) await target.delete();
    final partial = File('${target.path}.part');
    if (await partial.exists()) await partial.delete();
  }
}
