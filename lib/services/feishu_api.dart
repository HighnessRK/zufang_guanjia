import 'dart:convert';
import 'dart:io';

/// OpenAPI client. Tokens stay in memory and are refreshed before expiry.
class FeishuApi {
  FeishuApi(this.clientId, this.secret);
  final String clientId;
  final String secret;
  String? _token;
  DateTime _expires = DateTime(2000);

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Object? body, bool retry = true}) async {
    if (_token == null || DateTime.now().isAfter(_expires)) {
      final auth = await _send('/auth/v3/tenant_access_token/internal',
          'POST', {'app_id': clientId, 'app_secret': secret}, null);
      _token = auth['tenant_access_token'] as String;
      _expires = DateTime.now().add(Duration(seconds: (auth['expire'] as int) - 120));
    }
    try {
      return await _send(path, method, body, _token);
    } on FeishuException catch (e) {
      if (retry && [99991663, 99991664, 99991668].contains(e.code)) {
        _token = null;
        return request(path, method: method, body: body, retry: false);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _send(
      String path, String method, Object? body, String? token) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.openUrl(method,
          Uri.parse('https://open.feishu.cn/open-apis$path'))
          .timeout(const Duration(seconds: 25));
      req.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      if (body != null) req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 40));
      final text = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 40));
      final obj = jsonDecode(text) as Map<String, dynamic>;
      final code = (obj['code'] as int?) ?? -1;
      if (res.statusCode != 200 || code != 0) {
        // Do not include response bodies: these may contain private values.
        throw FeishuException(code, '飞书请求失败（HTTP ${res.statusCode}，code $code），请检查应用权限与多维表格授权');
      }
      return obj;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final items = <Map<String, dynamic>>[];
    String? page;
    do {
      final suffix = page == null ? '' : '&page_token=${Uri.encodeQueryComponent(page)}';
      final res = await request('$path?page_size=100$suffix');
      final data = res['data'] as Map<String, dynamic>;
      items.addAll((data['items'] as List? ?? []).cast<Map<String, dynamic>>());
      page = data['has_more'] == true ? data['page_token'] as String? : null;
      if (data['has_more'] == true && page == null) throw StateError('飞书分页响应不完整');
    } while (page != null);
    return items;
  }
}

class FeishuException implements Exception {
  FeishuException(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => message;
}
