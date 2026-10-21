/// 日期工具类。
/// 为避免引入额外第三方依赖，这里手写最常用的格式化 / 解析 / 差值计算。
class DateUtil {
  DateUtil._();

  /// 格式化为 `yyyy-MM-dd`
  static String format(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 格式化为 `yyyy-MM-dd HH:mm`
  static String formatDateTime(DateTime d) {
    return '${format(d)} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化为账期 `yyyy-MM`（用于缴费流水归集）
  static String period(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}';
  }

  /// 当前账期（yyyy-MM）
  static String get currentPeriod => period(DateTime.now());

  /// 解析 `yyyy-MM-dd`；解析失败返回 null
  static DateTime? parse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return DateTime.tryParse(text.trim());
  }

  /// 两个日期相差的天数（b - a），只比较「日」粒度
  static int diffDays(DateTime a, DateTime b) {
    final DateTime da = DateTime(a.year, a.month, a.day);
    final DateTime db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// 两个账期（yyyy-MM）相差的月数（to - from）。
  /// 例：monthsBetween('2026-01','2026-04') = 3；早于 to 返回正值。
  /// 用于缴费周期引擎判断「距上次结算过了几个月」。
  static int monthsBetween(String fromPeriod, String toPeriod) {
    final DateTime? a = _parsePeriod(fromPeriod);
    final DateTime? b = _parsePeriod(toPeriod);
    if (a == null || b == null) return 0;
    return (b.year - a.year) * 12 + (b.month - a.month);
  }

  /// 解析账期 `yyyy-MM`
  static DateTime? _parsePeriod(String text) {
    final String t = text.trim();
    final List<String> parts = t.split('-');
    if (parts.length != 2) return null;
    final int? y = int.tryParse(parts[0]);
    final int? m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return null;
    return DateTime(y, m);
  }

  /// 距离今天还有多少天；已过期返回负数；日期为空返回 null
  static int? daysFromNow(String? dateText) {
    final DateTime? target = parse(dateText);
    if (target == null) return null;
    return diffDays(DateTime.now(), target);
  }

  /// 中文友好描述，例如「还有 12 天」「已过期 3 天」
  static String humanDays(int days) {
    if (days > 0) return '还有 $days 天';
    if (days == 0) return '就是今天';
    return '已过期 ${-days} 天';
  }

  /// 加月数（月末自动收敛：1-31 加 1 个月 → 2 月最后一天）。
  /// 用于全楼层统一收缴日历沿锚点逐期推进。
  static DateTime addMonths(DateTime d, int months) {
    final int total = d.year * 12 + (d.month - 1) + months;
    final int y = total ~/ 12;
    final int m = total % 12 + 1;
    final int last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > last ? last : d.day);
  }

  /// 当月第一天
  static DateTime firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  /// 当月最后一天
  static DateTime lastDayOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 0);
}
