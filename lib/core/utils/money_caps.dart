/// 人民币金额 → 中文大写（收据 / 账单 / 打印凭据用）。
///
/// 覆盖「元」与「角 / 分」两级小数，末尾无小数时以「整」收尾；
/// 零位按国标处理：中间连续零合并为一个「零」，末尾零不显示。
/// 例：
///   1234   → 人民币壹仟贰佰叁拾肆元整
///   10001  → 人民币壹万零壹元整
///   1005   → 人民币壹仟零伍元整
///   100.50 → 人民币壹佰元伍角
///   0      → 人民币零元整
class MoneyCaps {
  MoneyCaps._();

  static const List<String> _digit = <String>[
    '零', '壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖',
  ];

  static const List<String> _unit = <String>['', '拾', '佰', '仟'];

  /// 分段（4 位一节）单位：个 / 万 / 亿 / 万亿
  static const List<String> _section = <String>['', '万', '亿', '万亿'];

  /// 入口：任意数值（整数 / 浮点）→ 大写人民币字符串。
  ///
  /// [withPrefix] 为 true 时前面加「人民币」，默认 true。
  static String from(num value, {bool withPrefix = true}) {
    // 统一到「分」再整数化，避免二进制浮点误差
    final int cents = (value * 100).round();
    final String prefix = withPrefix ? '人民币' : '';

    if (cents == 0) return '$prefix零元整';

    final String sign = cents < 0 ? '负' : '';
    final int abs = cents.abs();
    final int yuan = abs ~/ 100;
    final int jiao = (abs ~/ 10) % 10;
    final int fen = abs % 10;

    final StringBuffer buf = StringBuffer();

    if (yuan == 0) {
      // 纯角分：不写「零元」，直接「伍角」「伍分」
      if (jiao > 0) buf.write('${_digit[jiao]}角');
      if (fen > 0) buf.write('${_digit[fen]}分');
    } else {
      buf.write(_sectionOf(yuan));
      buf.write('元');
      if (jiao == 0 && fen == 0) {
        buf.write('整');
      } else {
        if (jiao > 0) {
          buf.write('${_digit[jiao]}角');
        } else if (fen > 0) {
          // 有元有分但没角：中间补「零」
          buf.write('零');
        }
        if (fen > 0) {
          buf.write('${_digit[fen]}分');
        }
      }
    }

    return '$sign$prefix$buf';
  }

  /// 整数元 → 「X仟X佰X拾X」字符串（无「元」字尾）。
  ///
  /// 4 位一节从低位到高位处理；跨节补零规则：低位节没有顶到千位
  /// （如 10001 = 1 万 + 1 → 「壹万零壹」）或低位节本身内部有零
  /// （如 10005 → 「壹万零伍」）时，本节前补「零」；最高节不补零。
  static String _sectionOf(int n) {
    if (n == 0) return '零';

    final List<int> chunks = <int>[];
    int rest = n;
    while (rest > 0) {
      chunks.add(rest % 10000);
      rest ~/= 10000;
    }
    if (chunks.length > _section.length) {
      throw RangeError('金额超出支持范围');
    }
    final StringBuffer out = StringBuffer();
    bool gap = false;
    for (int i = chunks.length - 1; i >= 0; i--) {
      final int chunk = chunks[i];
      if (chunk == 0) {
        if (out.isNotEmpty) gap = true;
        continue;
      }
      if (out.isNotEmpty && (gap || chunk < 1000)) out.write('零');
      out.write('${_chunk(chunk)}${_section[i]}');
      gap = false;
    }
    return out.toString();
  }

  /// 单节（0 < n < 10000）→ 「X仟X佰X拾X」，含内部零合并
  static String _chunk(int n) {
    final StringBuffer buf = StringBuffer();
    bool pendingZero = false;
    int div = 1000;
    for (int i = 0; i < 4; i++) {
      final int d = (n ~/ div) % 10;
      div ~/= 10;
      if (d == 0) {
        if (buf.isNotEmpty) pendingZero = true;
        continue;
      }
      if (pendingZero) {
        buf.write('零');
        pendingZero = false;
      }
      buf.write('${_digit[d]}${_unit[3 - i]}');
    }
    return buf.toString();
  }
}
