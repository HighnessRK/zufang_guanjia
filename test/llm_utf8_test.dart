import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/services/llm_service.dart';

void main() {
  test('含中文提示的真实 HttpClient 请求使用 UTF-8 字节发送', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final cfg = AppConfig.instance;
    final old = [cfg.llmBaseUrl, cfg.llmApiKey, cfg.llmVisionModel];
    cfg.llmBaseUrl = 'http://127.0.0.1:${server.port}';
    cfg.llmApiKey = 'test';
    cfg.llmVisionModel = 'vision-test';
    final handled = server.first.then((req) async {
      final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      expect(req.headers.contentType!.charset, 'utf-8');
      expect(body['messages'][0]['content'][0]['text'], contains('整数'));
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({'choices': [{'message': {'content': '17157.9'}}]}));
      await req.response.close();
    });
    try {
      expect(await LlmService.recognizeElecMeter(Uint8List.fromList([1, 2, 3])), 17157);
      await handled;
    } finally {
      cfg.llmBaseUrl = old[0]; cfg.llmApiKey = old[1]; cfg.llmVisionModel = old[2];
      await server.close(force: true);
    }
  });
}
