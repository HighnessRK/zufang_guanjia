import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/ocr/soc_info.dart';

void main() {
  test('芯片展示完整商品名并区分硬件NPU和当前后端', () {
    for (final entry in {
      'SM8650': '骁龙 8 Gen 3',
      'SM8850-AC': '骁龙 8 Elite Gen 5',
      'MT6993': '天玑 9500'
    }.entries) {
      final soc =
          SocInfo.parse({'socModel': entry.key, 'board': 'internal-code'});
      expect(soc.description, entry.value);
      expect(soc.npu, contains('硬件支持'));
      expect(soc.hint, contains('CPU'));
    }
    expect(
        SocInfo.parse({'socModel': 'unknown', 'board': 'kalama'}).description,
        '芯片信息未识别');
  });
}
