import '../../core/constants/app_constants.dart';

/// 电子收据（v1.1.3）：一次「某房间 · 某账期」水电费收据的**快照**。
///
/// 生成时把当时的金额、用量、单价、租户全部落库，之后即使改了单价、
/// 抄了新表、换了租户，历史收据的展示与图片也不变。房间删除会级联清掉
/// 其收据（外键 ON DELETE CASCADE）。
class Receipt {
  Receipt({
    this.id,
    required this.roomNo,
    required this.period,
    this.no = '',
    this.tenant = '',
    this.waterFee = 0,
    this.elecFee = 0,
    this.total = 0,
    this.waterUse,
    this.elecUse,
    this.waterPrice,
    this.elecPrice,
    this.note = '',
    required this.createdAt,
  });

  /// 自增主键
  int? id;

  /// 房间号
  final String roomNo;

  /// 账期 yyyy-MM
  final String period;

  /// 收据编号，如 SJ-202610-202
  final String no;

  /// 租户快照（生成时的主租户，可空）
  final String tenant;

  /// 水费（元）
  final int waterFee;

  /// 电费（元）
  final int elecFee;

  /// 合计（元）
  final int total;

  /// 水用量快照（吨）；旧账期无读数则为空
  final int? waterUse;

  /// 电用量快照（度）
  final int? elecUse;

  /// 水价快照（元/吨）
  final double? waterPrice;

  /// 电价快照（元/度）
  final double? elecPrice;

  /// 备注
  final String note;

  /// 生成时间 yyyy-MM-dd HH:mm
  final String createdAt;

  /// 收据标题（列表与图片用）：如「2026-10 · 水电费收据」
  String get title => '$period · 水电费收据';

  factory Receipt.fromMap(Map<String, Object?> m) => Receipt(
        id: m['id'] as int?,
        roomNo: m['room_no'] as String,
        period: m['period'] as String,
        no: (m['no'] as String?) ?? '',
        tenant: (m['tenant'] as String?) ?? '',
        waterFee: (m['water_fee'] as int?) ?? 0,
        elecFee: (m['elec_fee'] as int?) ?? 0,
        total: (m['total'] as int?) ?? 0,
        waterUse: m['water_use'] as int?,
        elecUse: m['elec_use'] as int?,
        waterPrice: (m['water_price'] as num?)?.toDouble(),
        elecPrice: (m['elec_price'] as num?)?.toDouble(),
        note: (m['note'] as String?) ?? '',
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'room_no': roomNo,
        'period': period,
        'no': no,
        'tenant': tenant,
        'water_fee': waterFee,
        'elec_fee': elecFee,
        'total': total,
        'water_use': waterUse,
        'elec_use': elecUse,
        'water_price': waterPrice,
        'elec_price': elecPrice,
        'note': note,
        'created_at': createdAt,
      };

  /// 表名（给仓储引用，避免再 import 常量包）
  static String get table => AppConstants.tableReceipts;
}
