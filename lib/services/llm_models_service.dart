import 'dart:convert';
import 'dart:io';

/// 获取 OpenAI 兼容接口的模型清单，不发送照片或业务数据。
class LlmModelsService {
  LlmModelsService._();

  static Future<List<String>> fetch(String base, String key) async {
    final Uri? uri = Uri.tryParse('${base.trim().replaceAll(RegExp(r'/+$'), '')}/models');
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('请填写有效的 HTTP / HTTPS API 地址');
    }
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final HttpClientRequest request = await client.getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      if (key.trim().isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${key.trim()}');
      }
      final HttpClientResponse response = await request.close()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw HttpException('获取模型失败（HTTP ${response.statusCode}），请检查地址和密钥');
      }
      final String text = await response.transform(utf8.decoder).join()
          .timeout(const Duration(seconds: 15));
      final dynamic json = jsonDecode(text);
      final dynamic data = json is Map ? json['data'] : null;
      if (data is! List) throw const FormatException('接口未返回兼容的模型列表');
      return data.whereType<Map>().map((Map m) => m['id'])
          .whereType<String>().where((String s) => s.isNotEmpty).toSet().toList()..sort();
    } finally {
      client.close(force: true);
    }
  }
}
