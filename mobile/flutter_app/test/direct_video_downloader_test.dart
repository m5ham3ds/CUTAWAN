import 'dart:convert';
import 'dart:io';

import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/direct_video_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Directory directory;
  late DirectVideoDownloader downloader;
  var availableBytes = 1024 * 1024 * 1024;
  final servedPaths = <String>[];
  final fixture = List<int>.generate(256 * 1024, (index) => index % 251);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-download-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      servedPaths.add(request.uri.path);
      if (request.uri.path == '/redirect') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/clip.mp4');
        await request.response.close();
        return;
      }
      if (request.uri.path == '/html') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html>not a video</html>');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.contentLength = fixture.length;
      request.response.add(fixture);
      await request.response.close();
    });

    downloader = DirectVideoDownloader(
      storageDirectory: directory,
      availableStorageBytes: () async => availableBytes,
      inspectLocalFile: (path) async {
        final file = File(path);
        return VideoAssetMetadata(
          uri: Uri.file(path).toString(),
          displayName: file.uri.pathSegments.last,
          mimeType: 'video/mp4',
          sizeBytes: await file.length(),
          durationMs: 10000,
          width: 1280,
          height: 720,
          rotationDegrees: 0,
          importedAtUtc: DateTime.now().toUtc(),
        );
      },
      allowPrivateHostsForTesting: true,
    );
  });

  tearDown(() async {
    await server.close(force: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  String url(String path) => 'http://127.0.0.1:${server.port}$path';

  test('direct video URL downloads, reports progress and returns inspected metadata',
      () async {
    final progress = <VideoDownloadProgress>[];
    final metadata = await downloader.download(
      url('/clip.mp4'),
      cancellation: DownloadCancellation(),
      onProgress: progress.add,
    );

    final savedFile = File.fromUri(Uri.parse(metadata.uri));
    expect(await savedFile.exists(), isTrue);
    expect(await savedFile.readAsBytes(), fixture);
    expect(metadata.mimeType, 'video/mp4');
    expect(metadata.width, 1280);
    expect(progress, isNotEmpty);
    expect(progress.last.receivedBytes, fixture.length);
    expect(progress.last.fraction, 1);
    expect(await downloader.storageUsageBytes(), fixture.length);
  });

  test('redirects are followed only after validating the next URL', () async {
    final metadata = await downloader.download(
      url('/redirect'),
      cancellation: DownloadCancellation(),
    );

    expect(metadata.durationMs, 10000);
    expect(servedPaths, containsAll(['/redirect', '/clip.mp4']));
  });

  test('platform links, private IPs and unsupported schemes are rejected', () {
    expect(
      DirectVideoDownloader.validateDirectVideoUri(
        Uri.parse('https://www.youtube.com/watch?v=example'),
      ),
      contains('رابط منصة'),
    );
    expect(
      DirectVideoDownloader.validateDirectVideoUri(
        Uri.parse('http://127.0.0.1/movie.mp4'),
      ),
      contains('خاص أو محلي'),
    );
    expect(
      DirectVideoDownloader.validateDirectVideoUri(
        Uri.parse('file:///sdcard/movie.mp4'),
      ),
      contains('HTTP أو HTTPS'),
    );
  });

  test('non-video responses are rejected without leaving partial files', () async {
    await expectLater(
      downloader.download(
        url('/html'),
        cancellation: DownloadCancellation(),
      ),
      throwsA(isA<FormatException>()),
    );

    expect(directory.listSync(), isEmpty);
  });

  test('insufficient storage is rejected before contacting the server', () async {
    availableBytes = DirectVideoDownloader.storageReserveBytes + 1024;

    await expectLater(
      downloader.download(
        url('/clip.mp4'),
        cancellation: DownloadCancellation(),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(servedPaths, isEmpty);
  });

  test('cancelled download does not start or create temporary files', () async {
    final cancellation = DownloadCancellation()..cancel();

    await expectLater(
      downloader.download(
        url('/clip.mp4'),
        cancellation: cancellation,
      ),
      throwsA(isA<VideoDownloadCancelled>()),
    );

    expect(directory.listSync(), isEmpty);
    expect(servedPaths, isEmpty);
  });

  test('downloaded media can be removed from managed storage', () async {
    final metadata = await downloader.download(
      url('/clip.mp4'),
      cancellation: DownloadCancellation(),
    );

    await downloader.deleteDownloadedVideo(metadata.uri);

    expect(await File.fromUri(Uri.parse(metadata.uri)).exists(), isFalse);
    expect(await downloader.storageUsageBytes(), 0);
  });

  test('file names are not taken from query strings or unsafe path content',
      () async {
    final metadata = await downloader.download(
      url('/clip.mp4?name=../../unsafe'),
      cancellation: DownloadCancellation(),
    );

    final path = Uri.parse(metadata.uri).path;
    expect(path, contains('clip.mp4'));
    expect(path, isNot(contains('../')));
  });
}
