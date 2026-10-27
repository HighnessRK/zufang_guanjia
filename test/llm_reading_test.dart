import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/llm_service.dart';

void main() {
  test('电表整数读数舍弃红色小数位，不从解释文字猜数字', () {
    expect(LlmService.parseReading('17157'), 17157);
    expect(LlmService.parseReading('17157.9'), 17157);
    expect(() => LlmService.parseReading('读数是17157，红色0.1'), throwsFormatException);
  });
}
