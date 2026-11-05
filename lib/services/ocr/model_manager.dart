import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

Future<String> _modelHash(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString().toLowerCase();

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
  bool initialized = false;
  ModelStatus status = ModelStatus.missing;
  // Whole download: includes every model/projector segment, including resumed bytes.
  int received = 0, total = 0;
  final Map<String, int> _downloaded = {};
  final Map<String, int> _expected = {};
  String currentFile = '';
  final Stopwatch _updates = Stopwatch()..start();
  int _lastUpdate = 0;
  void _notifyProgress() {
    if (_updates.elapsedMilliseconds - _lastUpdate < 120) return;
    _lastUpdate = _updates.elapsedMilliseconds;
    notifyListeners();
  }

  String _key(ModelAsset a, int index) => '${a.name}/$index';

  void _progress(ModelAsset a, int index, int bytes, {int? size}) {
    final key = _key(a, index);
    _downloaded[key] = bytes;
    if (size != null && size > 0) _expected[key] = size;
    received = _downloaded.values.fold(0, (sum, n) => sum + n);
    final count = assets.fold(0, (sum, a) => sum + a.sources.length);
    total = _expected.length == count
        ? _expected.values.fold(0, (sum, n) => sum + n)
        : 0;
  }

  /// v1.2.3 downloaded the projector as one file. Split an existing partial
  /// into the new mirror segments without losing downloaded bytes. A partial
  /// assembly is also a prefix of the same immutable file and is safe to split.
  Future<void> _migratePartial(ModelAsset a) async {
    if (a.parts == 0 || !await partial(a).exists() || a.byteSize == null) {
      return;
    }
    final old = partial(a);
    final length = await old.length();
    for (var i = 0, offset = 0; i < a.parts && offset < length; i++) {
      final size = a.sourceSize(i)!;
      final end = (offset + size).clamp(0, length);
      final segment = File('${root.path}/${a.name}.segment-$i');
      if (!await segment.exists() || await segment.length() < end - offset) {
        final sink = segment.openWrite();
        try {
          await sink.addStream(old.openRead(offset, end));
        } finally {
          await sink.close();
        }
      }
      offset += size;
    }
    await old.delete();
  }

  Future<void> _readProgress() async {
    _downloaded.clear();
    _expected.clear();
    received = total = 0;
    for (final a in assets) {
      final complete = await file(a).exists();
      for (var i = 0; i < a.sources.length; i++) {
        final size = a.sourceSize(i);
        final f = a.parts == 0
            ? partial(a)
            : File('${root.path}/${a.name}.segment-$i');
        final bytes = complete
            ? (size ?? await file(a).length())
            : await f.exists()
                ? await f.length()
                : 0;
        _progress(a, i, bytes, size: size ?? (complete ? bytes : null));
      }
    }
  }

  String error = '';
  bool get configured => assets.every((a) => a.configured);
  bool get ready => status == ModelStatus.ready;
  bool get busy => _running != null;
  File file(ModelAsset a) => File('${root.path}/${a.name}');
  File partial(ModelAsset a) => File('${root.path}/${a.name}.part');

  Future<void> init() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    status = ModelStatus.verifying;
    notifyListeners();
    try {
      await _init();
      initialized = true;
      notifyListeners();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _init() async {
    root = directory ??
        Directory(
            '${(await getApplicationSupportDirectory()).path}/models/xiaomi-ocr-0');
    await root.create(recursive: true);
    if (!configured) return;
    bool all = true, any = false, corrupt = false;
    for (final a in assets) {
      await _migratePartial(a);
      if (await file(a).exists()) {
        if (!await _valid(file(a), a)) {
          await file(a).delete();
          corrupt = true;
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
    status = corrupt ? ModelStatus.corrupt : ModelStatus.missing;
    if (all) {
      status = ModelStatus.ready;
    } else if (status != ModelStatus.corrupt && any) {
      status = ModelStatus.paused;
    }
    await _readProgress();
    notifyListeners();
  }

  Future<bool> _valid(File f, ModelAsset a) async =>
      await compute(_modelHash, f.path) == a.sha256.toLowerCase();

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
    await _readProgress();
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
          currentFile = '${a.name.startsWith('mmproj') ? '视觉投影器' : '主模型'}'
              '${a.parts == 0 ? '' : ' · 分片 ${index + 1}/${a.parts}'}';
          final expectedSize = a.sourceSize(index);
          if (expectedSize != null && offset == expectedSize) continue;
          if (expectedSize != null && offset > expectedSize) {
            await part.delete();
            offset = 0;
            _progress(a, index, 0);
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
          var partReceived = offset;
          final partTotal =
              response.contentLength < 0 ? 0 : offset + response.contentLength;
          _progress(a, index, partReceived, size: partTotal);
          status = ModelStatus.downloading;
          await _persist();
          final sink = part.openWrite(
              mode: offset == 0 ? FileMode.write : FileMode.append);
          try {
            await for (final chunk
                in response.timeout(const Duration(seconds: 60))) {
              if (_stop) break;
              sink.add(chunk);
              partReceived += chunk.length;
              _progress(a, index, partReceived);
              _notifyProgress();
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
          if (_stop) break;
          if ((expectedSize != null && await part.length() != expectedSize) ||
              (partTotal > 0 && partReceived != partTotal)) {
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
          for (var i = 0; i < a.sources.length; i++) {
            _progress(a, i, 0);
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
      final offset = await part.exists() ? await part.length() : 0;
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
        // Gitee may ignore Range. Keep the saved prefix and discard those bytes
        // from a full response, so resuming never duplicates bytes or resets
        // the displayed overall progress. Final full-file SHA stays mandatory.
        var discard = response.statusCode == 200 ? offset : 0;
        final limit = response.statusCode == 200 ? size : end + 1;
        var partReceived = offset;
        _progress(asset, index, partReceived, size: size);
        status = ModelStatus.downloading;
        await _persist();
        final sink = part.openWrite(
            mode: offset == 0 ? FileMode.write : FileMode.append);
        try {
          await for (final incoming
              in response.timeout(const Duration(seconds: 30))) {
            if (_stop) break;
            var chunk = incoming;
            if (discard >= chunk.length) {
              discard -= chunk.length;
              continue;
            }
            if (discard > 0) {
              chunk = chunk.sublist(discard);
              discard = 0;
            }
            if (partReceived + chunk.length > limit) {
              throw const HttpException('下载响应超出请求范围');
            }
            sink.add(chunk);
            partReceived += chunk.length;
            _progress(asset, index, partReceived);
            _notifyProgress();
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        if (_stop) return;
        if (partReceived != limit) throw const HttpException('下载响应不完整');
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
    await _readProgress();
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
        await _readProgress();
        await _persist();
      });
}
