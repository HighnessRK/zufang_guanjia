import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/llm_models_service.dart';

void main() {
  test('模型清单去重排序，携带认证且不上传业务数据', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/v1/models');
      expect(request.method, 'GET');
      expect(request.headers.value('Authorization'), 'Bearer test-key');
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"data":[{"id":"z"},{"id":"a"},{"id":"a"},{}]}');
      await request.response.close();
    });
    expect(await LlmModelsService.fetch('http://127.0.0.1:${server.port}/v1/', 'test-key'),
        <String>['a', 'z']);
  });
  test('拒绝无效地址', () async {
    await expectLater(LlmModelsService.fetch('file:///secret', ''), throwsFormatException);
  });
}
