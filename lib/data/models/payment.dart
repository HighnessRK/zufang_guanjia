/// 缴费流水模型 —— 对应 SQLite `payments` 表。
///
/// 【为什么需要这张表】
/// rooms 表只能保存「当期快照」，历史账单会被下个月覆盖；
/// payments 表按「房间 + 费用类型 + 账期」归集，才能支撑
/// 「缴费统计 / 历史账单 / 欠费累计 / 月度年报表」等功能。
class Payment {
  Payment({
    this.id,
    this.roomNo = '',
    this.payType = '',
    this.period = '',
    this.due = 0,
    this.paid = 0,
    this.isSettled = false,
    this.payTime,
    this.remark = '',
  });

  /// 自增主键
  int? id;

  /// 房间号
  String roomNo;

  /// 费用类型：rent（房租）/ utility（水电费）
  String payType;

  /// 账期（yyyy-MM）
  String period;

  /// 应收金额（元）
  int due;

  /// 实收金额（元）
  int paid;

  /// 是否结清
  bool isSettled;

  /// 实际缴费时间（yyyy-MM-dd HH:mm）
  String? payTime;

  /// 备注
  String remark;

  /// 欠费金额
  int get debt => due - paid > 0 ? due - paid : 0;

  /// 费用类型中文名
  String get payTypeText => payType == 'rent' ? '房租' : '水电费';

  /// 从数据库 Map 构造
  factory Payment.fromMap(Map<String, Object?> m) => Payment(
        id: m['id'] as int?,
        roomNo: (m['room_no'] ?? '') as String,
        payType: (m['pay_type'] ?? '') as String,
        period: (m['period'] ?? '') as String,
        due: (m['due'] ?? 0) as int,
        paid: (m['paid'] ?? 0) as int,
        isSettled: ((m['is_settled'] ?? 0) as int) == 1,
        payTime: m['pay_time'] as String?,
        remark: (m['remark'] ?? '') as String,
      );

  /// 转为数据库 Map
  Map<String, Object?> toMap() => <String, Object?>{
        'room_no': roomNo,
        'pay_type': payType,
        'period': period,
        'due': due,
        'paid': paid,
        'is_settled': isSettled ? 1 : 0,
        'pay_time': payTime,
        'remark': remark,
      };
}
