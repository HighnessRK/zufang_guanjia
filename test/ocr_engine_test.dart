import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/services/llm_service.dart';
import 'package:zufang_guanjia/services/ocr/model_catalog.dart';
import 'package:zufang_guanjia/services/ocr/model_manager.dart';
import 'package:zufang_guanjia/services/ocr/ocr_engine.dart';
import 'package:zufang_guanjia/services/ocr/ocr_engine_resolver.dart';
import 'package:zufang_guanjia/services/ocr/soc_info.dart';

class FakeLocal implements OcrEngine {
  int calls = 0;
  bool fail = false;
  @override
  Future<OcrResult> recognize(File image, {String? prompt}) async {
    calls++;
    if (fail) throw StateError('test failure');
    return const OcrResult('1234', 'local');
  }

  @override
  Future<void> dispose() async {}
}

class LoopbackClient implements HttpClient {
  LoopbackClient(this.port);
  final int port;
  final HttpClient delegate = HttpClient();
  @override
  Future<HttpClientRequest> getUrl(Uri url) => delegate
      .getUrl(url.replace(scheme: 'http', host: '127.0.0.1', port: port));
  @override
  set connectionTimeout(Duration? value) => delegate.connectionTimeout = value;
  @override
  void close({bool force = false}) => delegate.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SizedTestAsset extends ModelAsset {
  const SizedTestAsset(String hash, this.size)
      : super('main', 'https://example.com/main', hash);
  final int size;
  @override
  int? sourceSize(int index) => size;
}

void main() {
  test('默认国内源元数据覆盖两个模型的完整字节数', () {
    expect(
        ModelCatalog.assets.every((a) => Uri.parse(a.url).host == 'gitee.com'),
        isTrue);
    expect(ModelCatalog.assets.fold<int>(0, (sum, a) => sum + a.byteSize!),
        1040937440);
    for (final a in ModelCatalog.assets) {
      expect(
          List.generate(a.parts, a.sourceSize)
              .fold<int>(0, (sum, n) => sum + n!),
          a.byteSize);
    }
  });
  test('整体进度累计已下载分片和已完成模型，暂停重启不归零', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-overall-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });
    final main = ModelAsset('main', 'https://example.com/main-',
        sha256.convert([1, 2, 3, 4]).toString(),
        parts: 2, byteSize: 4, partBytes: 2);
    final projector = ModelAsset('projector', 'https://example.com/projector-',
        sha256.convert([5, 6, 7, 8]).toString(),
        parts: 2, byteSize: 4, partBytes: 2);
    await File('${dir.path}/main').writeAsBytes([1, 2, 3, 4]);
    await File('${dir.path}/projector.segment-0').writeAsBytes([5, 6]);
    await File('${dir.path}/projector.segment-1').writeAsBytes([7]);
    final models = ModelManager(
        directory: dir,
        assets: [main, projector],
        clientFactory: () => LoopbackClient(server.port));
    await models.init();
    expect(models.status, ModelStatus.paused);
    expect(models.received, 7);
    expect(models.total, 8);
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.uri.path, '/projector-01');
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=1-1');
      request.response.statusCode = 206;
      request.response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes 1-1/2');
      request.response.add([8]);
      await request.response.close();
    });
    final seen = <int>[];
    models.addListener(() {
      expect(models.total, 8);
      seen.add(models.received);
    });
    await models.download();
    expect(models.error, isEmpty);
    expect(models.ready, isTrue);
    expect(requests, 1);
    expect(seen.every((v) => v >= 7 && v <= 8), isTrue);
    expect(models.received, 8);
    final restarted = ModelManager(directory: dir, assets: [main, projector]);
    await restarted.init();
    expect(restarted.ready, isTrue);
    expect(restarted.received, 8);
    expect(restarted.total, 8);
  });
  test('旧版完整文件断点迁移到国内分片，保留前缀并从断点续传', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-migrate-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });
    final asset = ModelAsset('projector', 'https://example.com/part-',
        sha256.convert([1, 2, 3, 4, 5, 6]).toString(),
        parts: 3, byteSize: 6, partBytes: 2);
    await File('${dir.path}/projector.part').writeAsBytes([1, 2, 3]);
    final models = ModelManager(
        directory: dir,
        assets: [asset],
        clientFactory: () => LoopbackClient(server.port));
    await models.init();
    expect(models.received, 3);
    expect(models.total, 6);
    expect(await File('${dir.path}/projector.segment-0').readAsBytes(), [1, 2]);
    expect(await File('${dir.path}/projector.segment-1').readAsBytes(), [3]);
    server.listen((request) async {
      final second = request.uri.path.endsWith('01');
      final start = second ? 1 : 0;
      request.response.statusCode = 206;
      request.response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes $start-1/2');
      request.response.add(second ? [4] : [5, 6]);
      await request.response.close();
    });
    await models.download();
    expect(models.ready, isTrue);
    expect(models.received, 6);
    expect(await models.file(asset).readAsBytes(), [1, 2, 3, 4, 5, 6]);
  });
  test('vendored mtmd 两条路径均设置 UTF-8 字节长度', () {
    final source = File(
            'packages/llama_cpp_dart/lib/src/multimodal/multimodal_context.dart')
        .readAsStringSync();
    expect(
        RegExp(r'\.\.text_len = utf8\.encode\(prompt\)\.length')
            .allMatches(source)
            .length,
        2);
  });
  test('已知大小模型按有界 Range 下载并从已有文件恢复', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-bounded-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });
    final data = List<int>.generate(2200000, (i) => i % 251);
    final asset = SizedTestAsset(sha256.convert(data).toString(), data.length);
    await File('${dir.path}/main.part').writeAsBytes(data.sublist(0, 123));
    var requests = 0;
    server.listen((request) async {
      final range = RegExp(r'^bytes=(\d+)-(\d+)$')
          .firstMatch(request.headers.value(HttpHeaders.rangeHeader)!)!;
      final start = int.parse(range[1]!);
      final end = int.parse(range[2]!);
      expect(end - start + 1, lessThanOrEqualTo(1024 * 1024));
      if (requests++ == 0) expect(start, 123);
      request.response.statusCode = 206;
      request.response.headers.set(
          HttpHeaders.contentRangeHeader, 'bytes $start-$end/${data.length}');
      request.response.add(data.sublist(start, end + 1));
      await request.response.close();
    });
    final models = ModelManager(
        directory: dir,
        assets: [asset],
        clientFactory: () => LoopbackClient(server.port));
    await models.download();
    expect(models.error, isEmpty);
    expect(models.ready, true);
    expect(requests, 3);
    expect(await models.file(asset).readAsBytes(), data);
  });
  test('国内源忽略 Range 时跳过已保存前缀，不重复写入或回退总进度', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-full-response-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });
    final asset = ModelAsset('main', 'https://example.com/main',
        sha256.convert([1, 2, 3, 4]).toString(),
        byteSize: 4);
    await File('${dir.path}/main.part').writeAsBytes([1, 2]);
    server.listen((request) async {
      expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=2-3');
      request.response.add([1]);
      await request.response.flush();
      request.response.add([2, 3, 4]);
      await request.response.close();
    });
    final models = ModelManager(
        directory: dir,
        assets: [asset],
        clientFactory: () => LoopbackClient(server.port));
    await models.init();
    models.addListener(() => expect(models.received, inInclusiveRange(2, 4)));
    await models.download();
    expect(models.error, isEmpty);
    expect(models.ready, isTrue);
    expect(await models.file(asset).readAsBytes(), [1, 2, 3, 4]);
    expect(models.received, 4);
  });
  test('分片损坏后清理所有分片，重试可重新下载；并发删除安全', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-segments-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });
    final asset = ModelAsset('main', 'https://example.com/part-',
        sha256.convert([1, 2, 3, 4]).toString(),
        parts: 2);
    final models = ModelManager(
        directory: dir,
        assets: [asset],
        clientFactory: () => LoopbackClient(server.port));
    bool corrupt = true;
    server.listen((request) async {
      request.response.add(corrupt
          ? [9, 9]
          : request.uri.path.endsWith('00')
              ? [1, 2]
              : [3, 4]);
      await request.response.close();
    });
    await models.download();
    expect(models.ready, false);
    expect(await File('${dir.path}/main.segment-0').exists(), false);
    corrupt = false;
    await models.download();
    expect(models.ready, true);
    expect(await models.file(asset).readAsBytes(), [1, 2, 3, 4]);
    await Future.wait([models.delete(), models.cancel(), models.delete()]);
    expect(models.ready, false);
    expect(await models.file(asset).exists(), false);
  });
  for (final behavior in ['range', 'ignore', 'bad-range', '416', 'bad-hash']) {
    test('下载断点 HTTP 边界：$behavior', () async {
      final dir = await Directory.systemTemp.createTemp('ocr-http-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        await dir.delete(recursive: true);
      });
      const data = [1, 2, 3, 4];
      final asset = ModelAsset(
          'main', 'https://example.com/main', sha256.convert(data).toString());
      final models = ModelManager(
          directory: dir,
          assets: [asset],
          clientFactory: () => LoopbackClient(server.port));
      await File('${dir.path}/main.part').writeAsBytes([1, 2]);
      server.listen((request) async {
        expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=2-');
        if (behavior == '416') {
          request.response.statusCode = 416;
        } else if (behavior == 'ignore' || behavior == 'bad-hash') {
          request.response.add(behavior == 'ignore' ? data : [9, 9, 9, 9]);
        } else {
          request.response.statusCode = 206;
          request.response.headers.set(HttpHeaders.contentRangeHeader,
              behavior == 'range' ? 'bytes 2-3/4' : 'bytes 1-3/4');
          request.response.add([3, 4]);
        }
        await request.response.close();
      });
      await models.download();
      if (behavior == 'range' || behavior == 'ignore') {
        expect(models.ready, true);
        expect(await models.file(asset).readAsBytes(), data);
      } else {
        expect(models.ready, false);
        expect(models.error, isNotEmpty);
        expect(await models.file(asset).exists(), false);
        if (behavior != 'bad-range') {
          expect(await models.partial(asset).exists(), false);
        }
      }
    });
  }
  test('缺失可信元数据不会允许下载', () {
    expect(const ModelAsset('x', '', '').configured, false);
    expect(const ModelAsset('x', 'https://example.com/x', 'abc').configured,
        false);
  });
  test('真实 SoC 字段与未知型号保守判断', () {
    expect(SocInfo.parse({'socModel': 'SM8550'}).level, 2);
    expect(SocInfo.parse({'hardware': 'SM8475'}).level, 1);
    expect(SocInfo.parse({'board': 'SM8350'}).level, 0);
    expect(SocInfo.parse({'model': 'Xiaomi 14'}).level, 0);
    expect(SocInfo.parse({}).level, 0);
  });
  test('整层读数保持 null 的位置，不从解释中猜单表数字', () {
    expect(LlmService.parseFloorReadings('[123,null,456]'), [123, -1, 456]);
    expect(LlmService.parseFloorReadings('[123,null,456]', expectedCount: 3),
        [123, -1, 456]);
    for (final invalid in [
      '[123]',
      '[123,456,789,999]',
      '[123,{"kWh":"0.00"},456]',
      '[123,"bad",456]',
      '示例 [123,null,456]',
      '[123,null,456] [789]',
      '[123,-2,456]'
    ]) {
      expect(() => LlmService.parseFloorReadings(invalid, expectedCount: 3),
          throwsFormatException);
    }
    expect(LlmService.parseReading('<think>可能为123</think>\n24737'), 24737);
    expect(LlmService.parseFloorReadings('<think>[999]</think>[123,null,456]'),
        [123, -1, 456]);
    expect(() => LlmService.parseReading('表号123 读数456'), throwsFormatException);
  });
  test('重启校验两个文件，损坏删除，不信任状态文件', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-test-');
    addTearDown(() => dir.delete(recursive: true));
    final digest = sha256.convert([1, 2, 3]).toString();
    final assets = [
      ModelAsset('main', 'https://example.com/main', digest),
      ModelAsset('proj', 'https://example.com/proj', digest)
    ];
    await File('${dir.path}/main').writeAsBytes([1, 2, 3]);
    await File('${dir.path}/proj').writeAsBytes([9]);
    final models = ModelManager(directory: dir, assets: assets);
    await models.init();
    expect(models.status, ModelStatus.corrupt);
    expect(await File('${dir.path}/proj').exists(), false);
  });
  test('完整模型重启为可用，取消不删除已完成模型，删除清理两文件', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-test-');
    addTearDown(() => dir.delete(recursive: true));
    final digest = sha256.convert([1, 2, 3]).toString();
    final assets = [
      ModelAsset('main', 'https://example.com/main', digest),
      ModelAsset('proj', 'https://example.com/proj', digest),
    ];
    for (final a in assets) {
      await File('${dir.path}/${a.name}').writeAsBytes([1, 2, 3]);
    }
    final models = ModelManager(directory: dir, assets: assets);
    final states = <ModelStatus>[];
    models.addListener(() => states.add(models.status));
    final initializing = models.init();
    expect(models.status, ModelStatus.verifying);
    await initializing;
    expect(models.ready, true);
    expect(models.initialized, isTrue);
    expect(states, isNot(contains(ModelStatus.missing)));
    final restarted = ModelManager(directory: dir, assets: assets);
    await restarted.init();
    expect(restarted.ready, isTrue);
    await models.cancel();
    expect(models.ready, true);
    await models.delete();
    expect(models.status, ModelStatus.missing);
    for (final a in assets) {
      expect(await models.file(a).exists(), false);
    }
  });
  test('仅云端不调用本地，自动失败回退，本地失败不上传', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-test-');
    addTearDown(() => dir.delete(recursive: true));
    final models = ModelManager(directory: dir);
    await models.init();
    models.status = ModelStatus.ready;
    final local = FakeLocal();
    final resolver = OcrEngineResolver(models: models, local: local);
    int cloudCalls = 0;
    final cloud = CloudOcrEngine((_, __) async {
      cloudCalls++;
      return '12';
    });
    final old = AppConfig.instance.ocrMode;
    addTearDown(() => AppConfig.instance.ocrMode = old);
    AppConfig.instance.ocrMode = 'cloud';
    await resolver.recognize(File('unused'), cloud: cloud);
    expect(local.calls, 0);
    AppConfig.instance.ocrMode = 'auto';
    local.fail = true;
    await resolver.recognize(File('unused'), cloud: cloud);
    expect(cloudCalls, 2);
    expect(resolver.warning, contains('回退'));
    final strict =
        OcrEngineResolver(models: models, local: FakeLocal()..fail = true);
    AppConfig.instance.ocrMode = 'local';
    await expectLater(
        strict.recognize(File('unused'), cloud: cloud), throwsStateError);
    expect(cloudCalls, 2);
    models.status = ModelStatus.missing;
    await expectLater(
        strict.recognize(File('unused'), cloud: cloud), throwsStateError);
    expect(cloudCalls, 2, reason: '本地模式模型丢失也不能上传照片');
  });
}
