import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_broker/core/transcription/scribe_model_store.dart';

void main() {
  late Directory tmp;
  final body = utf8.encode('fictional model bytes ' * 50); // 1100 bytes
  final spec = ModelFileSpec(
    fileName: 'model.gguf',
    url: 'https://models.example/model.gguf',
    sizeBytes: body.length,
    sha256: sha256.convert(body).toString(),
  );

  setUp(() async => tmp = await Directory.systemTemp.createTemp('scribe_model_test'));
  tearDown(() async => tmp.delete(recursive: true));

  /// Redirects the first request to a CDN URL, then serves [body] honouring Range
  /// (unless [ignoreRange]). Records the Range headers it saw.
  MockClient cdn(List<String?> ranges, {bool ignoreRange = false, List<int>? serve}) {
    final data = serve ?? body;
    return MockClient.streaming((request, _) async {
      if (request.url.host == 'models.example') {
        return http.StreamedResponse(const Stream.empty(), 302, headers: {'location': 'https://cdn.example/blob'});
      }
      final range = request.headers['Range'];
      ranges.add(range);
      if (range != null && !ignoreRange) {
        final from = int.parse(range.substring('bytes='.length, range.length - 1));
        return http.StreamedResponse(Stream.value(data.sublist(from)), 206);
      }
      // Two chunks, like a real network read.
      final half = data.length ~/ 2;
      return http.StreamedResponse(Stream.fromIterable([data.sublist(0, half), data.sublist(half)]), 200);
    });
  }

  ScribeModelStore store(http.Client client) =>
      ScribeModelStore(spec: spec, clientFactory: () => client, baseDirectory: () async => tmp);

  test('downloads through the redirect, verifies and becomes ready', () async {
    final ranges = <String?>[];
    final s = store(cdn(ranges));
    await s.download();

    expect(s.status, ScribeModelStatus.ready);
    expect(await (await s.modelFile()).readAsBytes(), body);
    expect(File('${(await s.modelFile()).path}.part').existsSync(), isFalse);
    expect(ranges, [null]);
  });

  test('resumes a partial download with a Range request', () async {
    final s0 = store(cdn([]));
    final part = File('${(await s0.modelFile()).path}.part');
    await part.writeAsBytes(body.sublist(0, 400));

    final ranges = <String?>[];
    final s = store(cdn(ranges));
    await s.refresh();
    expect(s.receivedBytes, 400);
    await s.download();

    expect(ranges, ['bytes=400-']);
    expect(s.status, ScribeModelStatus.ready);
    expect(await (await s.modelFile()).readAsBytes(), body);
  });

  test('starts over when the server ignores the range', () async {
    final s0 = store(cdn([]));
    await File('${(await s0.modelFile()).path}.part').writeAsBytes(body.sublist(0, 400));

    final s = store(cdn([], ignoreRange: true));
    await s.download();

    expect(s.status, ScribeModelStatus.ready);
    expect(await (await s.modelFile()).readAsBytes(), body);
  });

  test('a damaged file fails the checksum and is removed', () async {
    final damaged = List<int>.from(body)..[10] ^= 0xff;
    final s = store(cdn([], serve: damaged));
    await s.download();

    expect(s.status, ScribeModelStatus.failed);
    expect(s.error, contains('checksum'));
    expect((await s.modelFile()).existsSync(), isFalse);
    expect(File('${(await s.modelFile()).path}.part').existsSync(), isFalse);
  });

  test('HTTP errors are reported', () async {
    final s = store(MockClient((_) async => http.Response('nope', 404)));
    await s.download();

    expect(s.status, ScribeModelStatus.failed);
    expect(s.error, contains('404'));
  });

  test('cancel keeps the received part for resuming', () async {
    final chunks = StreamController<List<int>>();
    final s = store(
      MockClient.streaming((request, _) async => http.StreamedResponse(chunks.stream, 200)),
    );
    final done = s.download();
    chunks.add(body.sublist(0, 300));
    for (var i = 0; i < 200 && s.receivedBytes < 300; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    s.cancel();
    chunks.add(body.sublist(300, 600));
    await chunks.close();
    await done;

    expect(s.status, ScribeModelStatus.notDownloaded);
    final part = File('${(await s.modelFile()).path}.part');
    expect(part.existsSync(), isTrue);
    expect(await part.readAsBytes(), body.sublist(0, part.lengthSync()));
  });

  test('refresh finds an existing model and delete removes it', () async {
    final s = store(cdn([]));
    await (await s.modelFile()).writeAsBytes(body);
    await s.refresh();
    expect(s.isReady, isTrue);

    await s.delete();
    expect(s.status, ScribeModelStatus.notDownloaded);
    expect((await s.modelFile()).existsSync(), isFalse);
  });
}
