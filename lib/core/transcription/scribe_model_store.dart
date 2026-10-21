import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/app_log.dart';

/// A model file to download: where from, and what it must be.
class ModelFileSpec {
  final String fileName;
  final String url;
  final int sizeBytes;
  final String sha256;

  const ModelFileSpec({required this.fileName, required this.url, required this.sizeBytes, required this.sha256});
}

/// The offline Amharic model: Addis Scribe Streaming, quantized for phones.
class ScribeModel {
  ScribeModel._();

  static const spec = ModelFileSpec(fileName: fileName, url: url, sizeBytes: sizeBytes, sha256: sha256);

  static const fileName = 'addis-scribe-rnnt-q5_k.gguf';

  /// Pinned to a commit of the official repo, so the file can't change under us.
  static const revision = '1acb8b93c58155709c5831523432a1cb2a0e0ac6';
  static const url = 'https://huggingface.co/addisai/addis-scribe-streaming/resolve/$revision/mobile/$fileName';
  static const sizeBytes = 499136448;

  /// From the export report published with the file (q5-export-report.json).
  static const sha256 = '31aceccf293eeadf0814bb1355cf3ce270959856900759e9c49f4201aa3a38f3';

  static const attribution =
      'Addis Scribe Streaming © Addis AI, built on NVIDIA Nemotron 3.5 ASR Streaming 0.6B, '
      'used under the OpenMDW-1.1 licence (openmdw.ai/license/1-1). '
      'Runs with NVIDIA NeMo-Speech.cpp (Apache-2.0).';

  static const repositoryUrl = 'https://huggingface.co/addisai/addis-scribe-streaming';
}

enum ScribeModelStatus { notDownloaded, downloading, verifying, ready, failed }

/// Downloads, verifies and deletes the model file, and remembers progress so
/// Settings and the note screen show the same state. The download continues
/// while the app is open and resumes where it stopped if interrupted.
class ScribeModelStore extends ChangeNotifier {
  ScribeModelStore({
    this.spec = ScribeModel.spec,
    http.Client Function()? clientFactory,
    Future<Directory> Function()? baseDirectory,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _baseDirectory = baseDirectory ?? getApplicationSupportDirectory;

  static final ScribeModelStore instance = ScribeModelStore();

  static const _tag = 'ScribeModel';

  final ModelFileSpec spec;
  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _baseDirectory;

  ScribeModelStatus _status = ScribeModelStatus.notDownloaded;
  int _receivedBytes = 0;
  String? _error;
  http.Client? _activeClient;
  bool _cancelRequested = false;

  ScribeModelStatus get status => _status;
  int get receivedBytes => _receivedBytes;
  double get progress => _receivedBytes / spec.sizeBytes;
  String? get error => _error;
  bool get isReady => _status == ScribeModelStatus.ready;
  bool get isBusy => _status == ScribeModelStatus.downloading || _status == ScribeModelStatus.verifying;

  Future<Directory> directory() async {
    final dir = Directory(p.join((await _baseDirectory()).path, 'scribe'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> modelFile() async => File(p.join((await directory()).path, spec.fileName));
  Future<File> _partFile() async => File('${(await modelFile()).path}.part');

  /// Reads the state from disk once (cheap: sizes only).
  Future<void> refresh() async {
    if (isBusy) return;
    final file = await modelFile();
    final part = await _partFile();
    if (file.existsSync() && file.lengthSync() == spec.sizeBytes) {
      _set(ScribeModelStatus.ready, received: spec.sizeBytes);
    } else {
      _set(ScribeModelStatus.notDownloaded, received: part.existsSync() ? part.lengthSync() : 0);
    }
  }

  /// Whether the model is on the phone, looking at the disk again unless a
  /// download is running (cheap: one file size).
  Future<bool> ensureChecked() async {
    if (!isReady && !isBusy) await refresh();
    return isReady;
  }

  /// Downloads (or resumes) the model, then checks its SHA-256.
  Future<void> download() async {
    if (isBusy || isReady) return;
    _cancelRequested = false;
    _error = null;
    final part = await _partFile();
    var have = part.existsSync() ? part.lengthSync() : 0;
    if (have > spec.sizeBytes) {
      await part.delete();
      have = 0;
    }
    _set(ScribeModelStatus.downloading, received: have);

    final client = _activeClient = _clientFactory();
    IOSink? sink;
    try {
      if (have < spec.sizeBytes) {
        final response = await _get(client, Uri.parse(spec.url), have);
        if (have > 0 && response.statusCode == 200) {
          // The server ignored the range: start over.
          have = 0;
          _set(ScribeModelStatus.downloading, received: 0);
        } else if (response.statusCode != 200 && response.statusCode != 206) {
          throw HttpException('Download failed (HTTP ${response.statusCode})');
        }
        sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
        var lastNotified = DateTime.now();
        await for (final chunk in response.stream) {
          if (_cancelRequested) break;
          sink.add(chunk);
          have += chunk.length;
          _receivedBytes = have;
          final now = DateTime.now();
          if (now.difference(lastNotified).inMilliseconds > 250) {
            lastNotified = now;
            notifyListeners();
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;
      }
      if (_cancelRequested) {
        _set(ScribeModelStatus.notDownloaded, received: have);
        return;
      }
      if (have != spec.sizeBytes) {
        throw HttpException('Download stopped early (${_mb(have)} of ${_mb(spec.sizeBytes)})');
      }

      _set(ScribeModelStatus.verifying, received: have);
      final digest = await _sha256(part);
      if (digest != spec.sha256) {
        await part.delete();
        throw const FileSystemException('The downloaded file is damaged (checksum mismatch); please try again');
      }
      await part.rename((await modelFile()).path);
      AppLog.i(_tag, 'model downloaded and verified');
      _set(ScribeModelStatus.ready, received: spec.sizeBytes);
    } catch (e) {
      await sink?.close();
      if (_cancelRequested) {
        _set(ScribeModelStatus.notDownloaded, received: _receivedBytes);
      } else {
        AppLog.w(_tag, 'download failed', e);
        _error = e is HttpException || e is FileSystemException
            ? _message(e)
            : 'Download failed. Check the connection and try again.';
        _set(ScribeModelStatus.failed, received: _receivedBytes);
      }
    } finally {
      client.close();
      _activeClient = null;
    }
  }

  /// Stops the download; what was received is kept for resuming.
  void cancel() {
    if (_status != ScribeModelStatus.downloading) return;
    _cancelRequested = true;
    _activeClient?.close();
  }

  /// Removes the model and any partial download.
  Future<void> delete() async {
    cancel();
    for (final f in [await modelFile(), await _partFile()]) {
      if (f.existsSync()) await f.delete();
    }
    _error = null;
    _set(ScribeModelStatus.notDownloaded, received: 0);
  }

  /// GET with a Range header, following redirects by hand: Hugging Face sends
  /// the file from a CDN, and the range has to survive the hop.
  Future<http.StreamedResponse> _get(http.Client client, Uri uri, int from) async {
    var target = uri;
    for (var hop = 0; hop < 6; hop++) {
      final request = http.Request('GET', target)..followRedirects = false;
      if (from > 0) request.headers['Range'] = 'bytes=$from-';
      final response = await client.send(request);
      if (response.isRedirect || (response.statusCode >= 300 && response.statusCode < 400)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null) throw const HttpException('Redirect without a location');
        target = target.resolve(location);
        continue;
      }
      return response;
    }
    throw const HttpException('Too many redirects');
  }

  static Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  void _set(ScribeModelStatus status, {required int received}) {
    _status = status;
    _receivedBytes = received;
    notifyListeners();
  }

  static String _mb(int bytes) => '${(bytes / 1e6).round()} MB';

  static String _message(Object e) => switch (e) {
    HttpException(:final message) => message,
    FileSystemException(:final message) => message,
    _ => '$e',
  };
}
