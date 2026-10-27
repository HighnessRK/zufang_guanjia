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
    this.kind = 'utility',
    this.sequence = 1,
    this.periodStart = '',
    this.periodEnd = '',
    this.no = '',
    this.tenant = '',
    this.waterFee = 0,
    this.elecFee = 0,
    this.total = 0,
    this.waterUse,
    this.elecUse,
    this.waterPrice,
    this.elecPrice,
    this.waterPrev,
    this.waterCurr,
    this.elecPrev,
    this.elecCurr,
    this.note = '',
    this.watermark = '',
    required this.createdAt,
  });

  /// 自增主键
  int? id;

  /// 房间号
  final String roomNo;

  /// 账期 yyyy-MM
  final String period;

  /// utility = 水电，rent = 房租。
  final String kind;
  final int sequence;
  final String periodStart;
  final String periodEnd;

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

  /// 上期水表读数快照（吨）；v1.1.4 起带，历史快照为空
  final int? waterPrev;

  /// 本期水表读数快照（吨）
  final int? waterCurr;

  /// 上期电表读数快照（度）
  final int? elecPrev;

  /// 本期电表读数快照（度）
  final int? elecCurr;

  /// 备注
  final String note;
  final String watermark;

  /// 生成时间 yyyy-MM-dd HH:mm
  final String createdAt;

  /// 收据标题（列表与图片用）：如「2026-10 · 水电费收据」
  String get kindText => switch (kind) {
    'rent' => '房租', 'water' => '水费', 'elec' => '电费', _ => '水电费',
  };
  String get title => '$period · $kindText收据';

  String get periodText => periodStart.isNotEmpty && periodEnd.isNotEmpty
      ? '$periodStart — $periodEnd' : period;

  factory Receipt.fromMap(Map<String, Object?> m) => Receipt(
        id: m['id'] as int?,
        roomNo: m['room_no'] as String,
        period: m['period'] as String,
        kind: (m['kind'] as String?) ?? 'utility',
        sequence: (m['sequence'] as int?) ?? 1,
        periodStart: (m['period_start'] as String?) ?? '',
        periodEnd: (m['period_end'] as String?) ?? '',
        no: (m['no'] as String?) ?? '',
        tenant: (m['tenant'] as String?) ?? '',
        waterFee: (m['water_fee'] as int?) ?? 0,
        elecFee: (m['elec_fee'] as int?) ?? 0,
        total: (m['total'] as int?) ?? 0,
        waterUse: m['water_use'] as int?,
        elecUse: m['elec_use'] as int?,
        waterPrice: (m['water_price'] as num?)?.toDouble(),
        elecPrice: (m['elec_price'] as num?)?.toDouble(),
        waterPrev: m['water_prev'] as int?,
        waterCurr: m['water_curr'] as int?,
        elecPrev: m['elec_prev'] as int?,
        elecCurr: m['elec_curr'] as int?,
        note: (m['note'] as String?) ?? '',
        watermark: (m['watermark'] as String?) ?? '',
        createdAt: m['created_at'] as String,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'room_no': roomNo,
        'period': period,
        'kind': kind,
        'sequence': sequence,
        'period_start': periodStart,
        'period_end': periodEnd,
        'no': no,
        'tenant': tenant,
        'water_fee': waterFee,
        'elec_fee': elecFee,
        'total': total,
        'water_use': waterUse,
        'elec_use': elecUse,
        'water_price': waterPrice,
        'elec_price': elecPrice,
        'water_prev': waterPrev,
        'water_curr': waterCurr,
        'elec_prev': elecPrev,
        'elec_curr': elecCurr,
        'note': note,
        'watermark': watermark,
        'created_at': createdAt,
      };

  /// 表名（给仓储引用，避免再 import 常量包）
  static String get table => AppConstants.tableReceipts;
}
