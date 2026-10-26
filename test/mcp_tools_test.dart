import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/mcp_tools.dart';

void main() {
  test('能力清单与工具注册表保持一致且工具名唯一', () {
    final names = McpTools.all.map((t) => t.name).toList();
    expect(names.toSet().length, names.length);
    for (final cap in McpTools.capabilities) {
      for (final name in cap.tools) {
        expect(McpTools.lookup(name), isNotNull, reason: name);
      }
    }
    expect(McpTools.lookup('get_fee_report'), isNotNull);
    expect(McpTools.lookup('generate_receipt'), isNotNull);
  });
  test('删除收据未确认时不得执行', () async {
    await expectLater(McpTools.lookup('delete_receipt')!.handler(
        <String, dynamic>{'id': 1, 'confirmed': false}), throwsArgumentError);
  });
  test('报表拒绝非法及倒序账期', () async {
    for (final args in <Map<String, dynamic>>[
      <String, dynamic>{'from': '2026-13', 'to': '2026-01'},
      <String, dynamic>{'from': '2026-12', 'to': '2026-01'},
    ]) {
      await expectLater(McpTools.lookup('get_fee_report')!.handler(args), throwsArgumentError);
    }
  });
}
