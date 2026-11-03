import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/ocr/local_ocr_engine.dart';

void main() {
  test('单窗读数只接受唯一整数，允许空格分组和单位', () {
    expect(parseMeterCropReading('12345'), 12345);
    expect(parseMeterCropReading('1 2 3 4 5'), 12345);
    expect(parseMeterCropReading('23456kWh'), 23456);
    expect(parseMeterCropReading('34567 度'), 34567);
    expect(parseMeterCropReading(' 45678\n'), 45678);
    expect(parseMeterCropReading('<think>red 8</think>56789'), 56789);
  });

  test('拒绝解释、多个数字、小数和越界值', () {
    expect(parseMeterCropReading('读数是 12345'), isNull);
    expect(parseMeterCropReading('12345\n23456'), isNull);
    expect(parseMeterCropReading('12345.8'), isNull);
    expect(parseMeterCropReading('1234567890'), isNull);
    expect(parseMeterCropReading('null'), isNull);
  });
}
