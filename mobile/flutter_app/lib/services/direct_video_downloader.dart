import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/project_contract.dart';

class DownloadCancellation {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void throwIfCancelled() {
    if (_isCancelled) throw const VideoDownloadCancelled();
  }

  void addListener(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}

class VideoDownloadCancelled implements Exception {
  const VideoDownloadCancelled();

  @override
  String toString() => 'Video download was cancelled.';
}

class VideoDownloadProgress {
  const VideoDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}

class DirectVideoDownloader {
  DirectVideoDownloader({
    Directory? storageDirectory,
    required Future<int> Function() availableStorageBytes,
    required Future<VideoAssetMetadata> Function(String path) inspectLocalFile,
    HttpClient Function()? httpClientFactory,
    this.allowPrivateHostsForTesting = false,
  })  : _storageDirectoryOverride = storageDirectory,
        _availableStorageBytes = availableStorageBytes,
        _inspectLocalFile = inspectLocalFile,
        _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const int storageReserveBytes = 64 * 1024 * 1024;
  static const int maximumDownloadBytes = 8 * 1024 * 1024 * 1024;
  static const int maximumRedirects = 5;

  final Directory? _storageDirectoryOverride;
  final Future<int> Function() _availableStorageBytes;
  final Future<VideoAssetMetadata> Function(String path) _inspectLocalFile;
  final HttpClient Function() _httpClientFactory;
  final bool allowPrivateHostsForTesting;

  Future<Directory> _directory() async {
    final root = _storageDirectoryOverride ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}'
          '${Platform.pathSeparator}sources',
        );
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  Future<void> cleanupInterruptedDownloads() async {
    final directory = await _directory();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.part')) {
        await entity.delete();
      }
    }
  }

  Future<int> storageUsageBytes() async {
    final directory = await _directory();
    var total = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && !entity.path.endsWith('.part')) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> deleteDownloadedVideo(String fileUri) async {
    final uri = Uri.tryParse(fileUri);
    if (uri == null || uri.scheme != 'file') {
      throw const FormatException('Only app-downloaded file sources can be deleted here.');
    }
    final directory = await _directory();
    final root = directory.resolveSymbolicLinksSync();
    final file = File.fromUri(uri);
    final resolved = await file.resolveSymbolicLinks();
    if (!resolved.startsWith('$root${Platform.pathSeparator}')) {
      throw const FormatException('The selected file is outside Cutawan media storage.');
    }
    if (await file.exists()) await file.delete();
  }

  static String? validateDirectVideoUri(
    Uri uri, {
    bool allowPrivateHostsForTesting = false,
  }) {
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'استخدم رابط HTTP أو HTTPS مباشرًا لملف فيديو.';
    }
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return 'الرابط لا يحتوي على مضيف صالح.';
    }
    final host = uri.host.toLowerCase();
    final blockedHosts = <String>[
      'localhost',
      'youtube.com',
      'youtu.be',
      'tiktok.com',
      'instagram.com',
      'facebook.com',
      'fb.watch',
      'x.com',
      'twitter.com',
    ];
    if (blockedHosts.any((blocked) => host == blocked || host.endsWith('.$blocked'))) {
      return 'هذا رابط منصة، وليس رابط ملف فيديو مباشرًا. لا يتجاوز Cutawan قيود المنصات أو DRM.';
    }
    if (!allowPrivateHostsForTesting) {
      if (host.endsWith('.local') || host.endsWith('.localhost')) {
        return 'لا يمكن تنزيل ملفات من نطاق محلي.';
      }
      final address = InternetAddress.tryParse(host);
      if (address != null && _isNonPublicAddress(address)) {
        return 'لا يمكن تنزيل ملف من عنوان شبكة خاص أو محلي.';
      }
    }
    return null;
  }

  static bool _isNonPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final a = bytes[0];
      final b = bytes[1];
      return a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a == 100 && b >= 64 && b <= 127) ||
          a >= 224;
    }
    if (address.type == InternetAddressType.IPv6) {
      final isUnspecified = bytes.every((byte) => byte == 0);
      final isLoopback = bytes.take(15).every((byte) => byte == 0) && bytes[15] == 1;
      final isUniqueLocal = (bytes[0] & 0xfe) == 0xfc;
      final isLinkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
      return isUnspecified || isLoopback || isUniqueLocal || isLinkLocal;
    }
    return true;
  }

  Future<VideoAssetMetadata> download(
    String rawUrl, {
    required DownloadCancellation cancellation,
    void Function(VideoDownloadProgress progress)? onProgress,
  }) async {
    cancellation.throwIfCancelled();
    final initialUri = Uri.tryParse(rawUrl.trim());
    if (initialUri == null) {
      throw const FormatException('رابط الفيديو غير صالح.');
    }
    var currentUri = initialUri;
    var redirectCount = 0;
    final initialError = validateDirectVideoUri(
      currentUri,
      allowPrivateHostsForTesting: allowPrivateHostsForTesting,
    );
    if (initialError != null) throw FormatException(initialError);

    final availableBytes = await _availableStorageBytes();
    if (availableBytes <= storageReserveBytes) {
      throw const FileSystemException('المساحة المتاحة لا تكفي لتنزيل الفيديو بأمان.');
    }

    final client = _httpClientFactory();
    client.connectionTimeout = const Duration(seconds: 20);
    client.idleTimeout = const Duration(seconds: 30);
    void abortRequest() => client.close(force: true);
    cancellation.addListener(abortRequest);

    final directory = await _directory();
    await cleanupInterruptedDownloads();
    client.autoUncompress = false;
    File? partialFile;
    File? completedFile;
    IOSink? sink;
    var downloadAccepted = false;
    var receivedBytes = 0;
    int? totalBytes;

    try {
      late HttpClientResponse response;
      while (true) {
        cancellation.throwIfCancelled();
        final request = await client.getUrl(currentUri);
        request.followRedirects = false;
        request.maxRedirects = 0;
        request.headers.set(HttpHeaders.acceptHeader, 'video/*,application/octet-stream;q=0.8');
        request.headers.set(HttpHeaders.userAgentHeader, 'CutawanMobile/0.2');
        response = await request.close();

        if (_isRedirect(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null || redirectCount >= maximumRedirects) {
            throw const HttpException('Too many redirects or missing redirect location.');
          }
          final nextUri = currentUri.resolve(location);
          if (currentUri.scheme == 'https' && nextUri.scheme != 'https') {
            throw const HttpException('Refusing an HTTPS-to-HTTP downgrade redirect.');
          }
          final redirectError = validateDirectVideoUri(
            nextUri,
            allowPrivateHostsForTesting: allowPrivateHostsForTesting,
          );
          if (redirectError != null) throw HttpException(redirectError);
          currentUri = nextUri;
          redirectCount++;
          continue;
        }
        break;
      }

      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Video server returned HTTP ${response.statusCode}.');
      }

      final contentType =
          response.headers.contentType?.mimeType.toLowerCase() ?? '';
      final extension = _extensionFromUri(currentUri);
      if (!contentType.startsWith('video/') &&
          !(contentType == 'application/octet-stream' && _isVideoExtension(extension))) {
        await response.drain<void>();
        throw const FormatException('The URL did not return a recognizable video file.');
      }

      totalBytes = response.contentLength >= 0 ? response.contentLength : null;
      if (totalBytes != null) {
        if (totalBytes > maximumDownloadBytes) {
          await response.drain<void>();
          throw const FileSystemException('The video exceeds the 8 GB mobile import limit.');
        }
        if (totalBytes + storageReserveBytes > availableBytes) {
          await response.drain<void>();
          throw const FileSystemException('Insufficient free storage for this video and safety reserve.');
        }
      }

      final fileExtension =
          _isVideoExtension(extension) ? extension : _extensionFromMime(contentType);
      final basename = _safeBasename(currentUri, fileExtension);
      final uniqueName =
          '${DateTime.now().microsecondsSinceEpoch}_$basename';
      final target = File(
        '${directory.path}${Platform.pathSeparator}$uniqueName',
      );
      partialFile = File('${target.path}.part');
      sink = partialFile.openWrite(mode: FileMode.writeOnly);
      onProgress?.call(
        VideoDownloadProgress(receivedBytes: 0, totalBytes: totalBytes),
      );

      await for (final chunk in response) {
        cancellation.throwIfCancelled();
        receivedBytes += chunk.length;
        if (receivedBytes > maximumDownloadBytes) {
          throw const FileSystemException('The video exceeds the 8 GB mobile import limit.');
        }
        if (receivedBytes + storageReserveBytes > availableBytes) {
          throw const FileSystemException('Free storage fell below the required safety reserve.');
        }
        sink.add(chunk);
        onProgress?.call(
          VideoDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      cancellation.throwIfCancelled();
      await sink.flush();
      await sink.close();
      sink = null;
      if (receivedBytes == 0) {
        throw const FormatException('The server returned an empty video file.');
      }
      if (totalBytes != null && receivedBytes != totalBytes) {
        throw const HttpException('Downloaded byte count does not match Content-Length.');
      }

      completedFile = await partialFile.rename(target.path);
      cancellation.throwIfCancelled();
      final metadata = await _inspectLocalFile(completedFile.path);
      if (metadata.sizeBytes > 0 && metadata.sizeBytes != receivedBytes) {
        throw const FormatException('Native media size does not match downloaded file size.');
      }
      downloadAccepted = true;
      return metadata;
    } on VideoDownloadCancelled {
      rethrow;
    } on SocketException catch (error) {
      if (cancellation.isCancelled) throw const VideoDownloadCancelled();
      throw HttpException('Network download failed: ${error.message}');
    } finally {
      cancellation.removeListener(abortRequest);
      client.close(force: true);
      if (sink != null) await sink.close();
      if (partialFile != null && await partialFile.exists()) {
        await partialFile.delete();
      }
      if (completedFile != null && !downloadAccepted &&
          await completedFile.exists()) {
        await completedFile.delete();
      }
    }
  }

  static bool _isRedirect(int status) =>
      status == HttpStatus.movedPermanently ||
      status == HttpStatus.found ||
      status == HttpStatus.seeOther ||
      status == HttpStatus.temporaryRedirect ||
      status == HttpStatus.permanentRedirect;

  static String _extensionFromUri(Uri uri) {
    final path = uri.path.toLowerCase();
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    final extension = path.substring(dot);
    return extension.length <= 8 ? extension : '';
  }

  static bool _isVideoExtension(String extension) => const {
        '.mp4',
        '.m4v',
        '.mov',
        '.mkv',
        '.webm',
        '.avi',
        '.3gp',
        '.ts',
      }.contains(extension);

  static String _extensionFromMime(String mime) => switch (mime) {
        'video/mp4' => '.mp4',
        'video/webm' => '.webm',
        'video/quicktime' => '.mov',
        'video/x-matroska' => '.mkv',
        'video/3gpp' => '.3gp',
        _ => '.mp4',
      };

  static String _safeBasename(Uri uri, String extension) {
    var name = uri.pathSegments.isEmpty ? 'video$extension' : uri.pathSegments.last;
    try {
      name = Uri.decodeComponent(name);
    } on FormatException {
      name = 'video$extension';
    }
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (!_isVideoExtension(_extensionFromUri(Uri(path: name)))) {
      name = 'video$extension';
    }
    return name;
  }
}
