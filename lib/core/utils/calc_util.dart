/// 水电费计算引擎（核心公式，全部集中在这里，方便核对与维护）。
///
/// 计算规则：
///   用电量 = 本期电表 - 上期电表（负数按 0 处理，防止误录倒转）
///   用水量 = 本期水表 - 上期水表
///   电费   = 用电量 × 电费单价
///   水费   = 用水量 × 水费单价
///   水电费合计 = 电费 + 水费
///
/// 金额采用「向上取整到元」的口径（房东收缴习惯），同时保留一位小数的
/// 精确值供界面展示，避免出现 0.1 + 0.2 之类的浮点误差。
class CalcUtil {
  CalcUtil._();

  /// 计算结果
  static CalcResult compute({
    required int elecPrev,
    required int elecCurr,
    required int waterPrev,
    required int waterCurr,
    required double elecPrice,
    required double waterPrice,
  }) {
    // 用量：本期 - 上期，最小为 0（防止误录导致负数账单）
    final int elecUse = elecCurr - elecPrev;
    final int waterUse = waterCurr - waterPrev;
    final int elecUseSafe = elecUse < 0 ? 0 : elecUse;
    final int waterUseSafe = waterUse < 0 ? 0 : waterUse;

    // 精确金额（元，保留两位小数）
    final double elecFeeExact = _round2(elecUseSafe * elecPrice);
    final double waterFeeExact = _round2(waterUseSafe * waterPrice);
    final double totalExact = _round2(elecFeeExact + waterFeeExact);

    // 实收口径金额（四舍五入到元，整数字段落库）
    final int elecFee = elecFeeExact.round();
    final int waterFee = waterFeeExact.round();
    final int total = elecFee + waterFee;

    return CalcResult(
      elecUse: elecUseSafe,
      waterUse: waterUseSafe,
      elecUseRaw: elecUse,
      waterUseRaw: waterUse,
      elecFee: elecFee,
      waterFee: waterFee,
      totalFee: total,
      elecFeeExact: elecFeeExact,
      waterFeeExact: waterFeeExact,
      totalExact: totalExact,
      hasNegative: elecUse < 0 || waterUse < 0,
    );
  }

  /// 保留两位小数，规避浮点误差
  static double _round2(double v) =>
      double.parse(v.toStringAsFixed(2));

  /// 判断本期读数是否合法：不得小于上期读数
  static bool isValidReading(int prev, int curr) => curr >= prev;
}

/// 水电费计算结果
class CalcResult {
  const CalcResult({
    required this.elecUse,
    required this.waterUse,
    required this.elecUseRaw,
    required this.waterUseRaw,
    required this.elecFee,
    required this.waterFee,
    required this.totalFee,
    required this.elecFeeExact,
    required this.waterFeeExact,
    required this.totalExact,
    required this.hasNegative,
  });

  /// 用电量（度）
  final int elecUse;

  /// 用水量（吨）
  final int waterUse;

  /// 原始用电量（可能为负，用于提示录入错误）
  final int elecUseRaw;

  /// 原始用水量（可能为负）
  final int waterUseRaw;

  /// 电费（元，整数落库）
  final int elecFee;

  /// 水费（元，整数落库）
  final int waterFee;

  /// 水电费合计（元，整数落库）
  final int totalFee;

  /// 电费精确值（元）
  final double elecFeeExact;

  /// 水费精确值（元）
  final double waterFeeExact;

  /// 合计精确值（元）
  final double totalExact;

  /// 是否出现「本期读数小于上期读数」的异常
  final bool hasNegative;
}
