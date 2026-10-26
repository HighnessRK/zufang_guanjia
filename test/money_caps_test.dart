import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/utils/money_caps.dart';

/// 人民币金额转中文大写 —— 收据 / 账单 / 打印凭据展示用。
void main() {
  test('整数元以「整」收尾', () {
    expect(MoneyCaps.from(1234), '人民币壹仟贰佰叁拾肆元整');
    expect(MoneyCaps.from(0), '人民币零元整');
    expect(MoneyCaps.from(5), '人民币伍元整');
  });

  test('中间连续零合并为一个「零」', () {
    expect(MoneyCaps.from(1005), '人民币壹仟零伍元整');
    expect(MoneyCaps.from(1050), '人民币壹仟零伍拾元整');
    expect(MoneyCaps.from(10005), '人民币壹万零伍元整');
    expect(MoneyCaps.from(1000005), '人民币壹佰万零伍元整');
  });

  test('跨节（万/亿）', () {
    expect(MoneyCaps.from(11000), '人民币壹万壹仟元整');
    expect(MoneyCaps.from(11005), '人民币壹万壹仟零伍元整');
    expect(MoneyCaps.from(100005000), '人民币壹亿零伍仟元整');
    expect(MoneyCaps.from(100010000), '人民币壹亿零壹万元整');
    expect(MoneyCaps.from(10001), '人民币壹万零壹元整');
    expect(MoneyCaps.from(123456789), '人民币壹亿贰仟叁佰肆拾伍万陆仟柒佰捌拾玖元整');
    expect(MoneyCaps.from(100000000), '人民币壹亿元整');
  });

  test('带角分', () {
    expect(MoneyCaps.from(100.50), '人民币壹佰元伍角');
    expect(MoneyCaps.from(100.05), '人民币壹佰元零伍分');
    expect(MoneyCaps.from(100.55), '人民币壹佰元伍角伍分');
    expect(MoneyCaps.from(0.50), '人民币伍角');
  });

  test('负数', () {
    expect(MoneyCaps.from(-1234), '负人民币壹仟贰佰叁拾肆元整');
    expect(MoneyCaps.from(-100.50), '负人民币壹佰元伍角');
  });

  test('withPrefix=false 去掉「人民币」前缀', () {
    expect(MoneyCaps.from(66, withPrefix: false), '陆拾陆元整');
    expect(MoneyCaps.from(0, withPrefix: false), '零元整');
  });
}
