import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

enum ModelStatus { missing, downloading, paused, verifying, ready, corrupt }

/// Only user-triggered downloads. Partial files survive process termination;
/// downloaded models are never trusted without rechecking both hashes at startup.
class ModelManager extends ChangeNotifier {
  ModelManager(
      {this.directory, this.assets = ModelCatalog.assets, this.clientFactory});
  static final instance = ModelManager();
  final Directory? directory;
  final List<ModelAsset> assets;
  final HttpClient Function()? clientFactory;
  late Directory root;
  Future<void>? _initializing;
  Future<void>? _running;
  Future<void> _maintenance = Future<void>.value();
  HttpClient? _client;
  bool _stop = false;
  ModelStatus status = ModelStatus.missing;
  int received = 0, total = 0;
  String error = '';
  bool get configured => assets.every((a) => a.configured);
  bool get ready => status == ModelStatus.ready;
  bool get busy => _running != null;
  File file(ModelAsset a) => File('${root.path}/${a.name}');
  File partial(ModelAsset a) => File('${root.path}/${a.name}.part');

  Future<void> init() => _initializing ??= _init();
  Future<void> _init() async {
    root = directory ??
        Directory(
            '${(await getApplicationSupportDirectory()).path}/models/xiaomi-ocr-0');
    await root.create(recursive: true);
    if (!configured) return;
    bool all = true, any = false;
    for (final a in assets) {
      if (await file(a).exists()) {
        if (!await _valid(file(a), a)) {
          await file(a).delete();
          status = ModelStatus.corrupt;
          error = '模型校验失败，请重新下载';
          all = false;
        }
      } else {
        all = false;
      }
      any = any || await partial(a).exists();
      for (var i = 0; i < a.parts; i++) {
        any = any || await File('${root.path}/${a.name}.segment-$i').exists();
      }
    }
    if (all) {
      status = ModelStatus.ready;
    } else if (status != ModelStatus.corrupt && any) {
      status = ModelStatus.paused;
    }
    notifyListeners();
  }

  Future<bool> _valid(File f, ModelAsset a) async =>
      (await sha256.bind(f.openRead()).first).toString().toLowerCase() ==
      a.sha256.toLowerCase();

  Future<void> _persist() async {
    await File('${root.path}/state.json').writeAsString(
        jsonEncode({
          'status': status.name,
          'received': received,
          'total': total,
        }),
        flush: true);
    notifyListeners();
  }

  Future<void> download() async {
    await init();
    await _maintenance;
    if (_running != null) return _running;
    if (!configured) throw StateError('缺少可信下载地址或完整 SHA-256');
    _stop = false;
    _running = _download();
    try {
      await _running;
    } finally {
      _running = null;
      notifyListeners();
    }
  }

  Future<void> _download() async {
    error = '';
    _client = (clientFactory?.call() ?? HttpClient())
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      for (final a in assets) {
        if (_stop) break;
        if (await file(a).exists() && await _valid(file(a), a)) continue;
        for (var index = 0; index < a.sources.length; index++) {
          if (_stop) break;
          final part = a.parts == 0
              ? partial(a)
              : File('${root.path}/${a.name}.segment-$index');
          var offset = await part.exists() ? await part.length() : 0;
          final expectedSize = a.sourceSize(index);
          if (expectedSize != null && offset == expectedSize) continue;
          if (expectedSize != null && offset > expectedSize) {
            await part.delete();
            offset = 0;
          }
          if (expectedSize != null) {
            await _downloadRanges(a, index, part, expectedSize);
            continue;
          }
          // GitHub web downloads can be blocked while API asset redirects work.
          // Use the official API endpoint when available, no third-party proxy.
          final api = a.apiSource(index);
          final request =
              await _client!.getUrl(Uri.parse(api ?? a.sources[index]));
          if (api != null) {
            request.headers.set('Accept', 'application/octet-stream');
          }
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          if (offset > 0) {
            request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
          }
          final response =
              await request.close().timeout(const Duration(seconds: 60));
          if (response.statusCode != 200 && response.statusCode != 206) {
            if (response.statusCode == 416 && await part.exists()) {
              await part.delete();
            }
            throw HttpException('下载返回 ${response.statusCode}');
          }
          if (response.statusCode == 206 &&
              !(response.headers.value(HttpHeaders.contentRangeHeader) ?? '')
                  .startsWith('bytes $offset-')) {
            throw const HttpException('服务器断点范围不匹配');
          }
          if (response.statusCode == 200) offset = 0;
          received = offset;
          total =
              response.contentLength < 0 ? 0 : offset + response.contentLength;
          status = ModelStatus.downloading;
          await _persist();
          final sink = part.openWrite(
              mode: offset == 0 ? FileMode.write : FileMode.append);
          try {
            await for (final chunk
                in response.timeout(const Duration(seconds: 60))) {
              if (_stop) break;
              sink.add(chunk);
              received += chunk.length;
              notifyListeners();
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
          if (_stop) break;
          if ((expectedSize != null && await part.length() != expectedSize) ||
              (total > 0 && received != total)) {
            throw const HttpException('下载不完整，请恢复下载');
          }
        }
        if (_stop) break;
        final part = partial(a);
        if (a.parts > 0) {
          final assembled = part.openWrite();
          try {
            for (var i = 0; i < a.parts; i++) {
              await assembled.addStream(
                  File('${root.path}/${a.name}.segment-$i').openRead());
            }
          } finally {
            await assembled.close();
          }
        }
        status = ModelStatus.verifying;
        await _persist();
        if (!await _valid(part, a)) {
          await part.delete();
          for (var i = 0; i < a.parts; i++) {
            final segment = File('${root.path}/${a.name}.segment-$i');
            if (await segment.exists()) await segment.delete();
          }
          throw const FormatException('SHA-256 校验失败，已删除损坏文件');
        }
        if (_stop) break;
        await part.rename(file(a).path);
        for (var i = 0; i < a.parts; i++) {
          final segment = File('${root.path}/${a.name}.segment-$i');
          if (await segment.exists()) await segment.delete();
        }
      }
      status = _stop ? ModelStatus.paused : ModelStatus.ready;
    } catch (e) {
      status = _stop ? ModelStatus.paused : ModelStatus.corrupt;
      if (!_stop) error = '$e';
    } finally {
      _client?.close(force: true);
      _client = null;
      await _persist();
    }
  }

  Future<void> pause() async {
    _stop = true;
    _client?.close(force: true);
    await _running;
  }

  /// Bounded requests avoid stalled multi-minute GitHub asset responses.
  /// Every retry resumes only the bytes flushed to disk; final SHA remains
  /// mandatory before a model can be loaded.
  Future<void> _downloadRanges(
      ModelAsset asset, int index, File part, int size) async {
    var failures = 0;
    while (!_stop) {
      var offset = await part.exists() ? await part.length() : 0;
      if (offset == size) return;
      final end = (offset + 1024 * 1024).clamp(0, size) - 1;
      try {
        final api = asset.apiSource(index);
        final request = await _client!
            .getUrl(Uri.parse(api ?? asset.sources[index]))
            .timeout(const Duration(seconds: 30));
        if (api != null) {
          request.headers.set('Accept', 'application/octet-stream');
        }
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-$end');
        final response =
            await request.close().timeout(const Duration(seconds: 30));
        if (response.statusCode != 206 && response.statusCode != 200) {
          throw HttpException('下载返回 ${response.statusCode}');
        }
        if (response.statusCode == 206 &&
            response.headers.value(HttpHeaders.contentRangeHeader) !=
                'bytes $offset-$end/$size') {
          throw const HttpException('服务器断点范围不匹配');
        }
        // Servers ignoring Range may send the whole asset. Never append that
        // response to a partial file or mistake a JSON API response for GGUF.
        if (response.statusCode == 200) offset = 0;
        final limit = response.statusCode == 200 ? size : end + 1;
        received = offset;
        total = size;
        status = ModelStatus.downloading;
        await _persist();
        final sink = part.openWrite(
            mode: offset == 0 ? FileMode.write : FileMode.append);
        try {
          await for (final chunk
              in response.timeout(const Duration(seconds: 30))) {
            if (_stop) break;
            if (received + chunk.length > limit) {
              throw const HttpException('下载响应超出请求范围');
            }
            sink.add(chunk);
            received += chunk.length;
            notifyListeners();
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (_stop) return;
        if (received != limit) throw const HttpException('下载响应不完整');
        failures = 0;
      } catch (_) {
        if (_stop) return;
        if (++failures >= 4) rethrow;
        await Future<void>.delayed(Duration(seconds: failures));
      }
    }
  }

  Future<void> _maintain(Future<void> Function() action) {
    final result = _maintenance.then((_) => action());
    _maintenance =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> cancel() => _maintain(_cancel);

  Future<void> _cancel() async {
    await pause();
    await init();
    for (final a in assets) {
      if (await partial(a).exists()) await partial(a).delete();
      for (var i = 0; i < a.parts; i++) {
        final segment = File('${root.path}/${a.name}.segment-$i');
        if (await segment.exists()) await segment.delete();
      }
    }
    status = configured &&
            await Future.wait(assets.map((a) => file(a).exists()))
                .then((values) => values.every((v) => v))
        ? ModelStatus.ready
        : ModelStatus.missing;
    received = total = 0;
    await _persist();
  }

  /// Call only after disposing the inference engine (Windows also locks files).
  Future<void> delete() => _maintain(() async {
        await _cancel();
        for (final a in assets) {
          if (await file(a).exists()) await file(a).delete();
        }
        error = '';
        status = ModelStatus.missing;
        await _persist();
      });
}
