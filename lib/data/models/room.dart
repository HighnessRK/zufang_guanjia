/// 房间信息模型 —— 严格对应 SQLite `rooms` 表字段。
class Room {
  Room({
    this.roomNo = '',
    this.rent = 0,
    this.paid = 0,
    this.roomType = '',
    this.tenant = '',
    this.idCard = '',
    this.checkIn,
    this.expire,
    this.elecPrev = 0,
    this.elecCurr = 0,
    this.waterPrev = 0,
    this.waterCurr = 0,
    this.waterFee = 0,
    this.elecFee = 0,
    this.utilityFee = 0,
    this.utilityPaid = false,
    this.cardCount = 0,
    this.keyCount = 0,
    this.deposit = 0,
    this.ac = 0,
    this.heater = 0,
    this.fridge = 0,
    this.washer = 0,
  });

  /// 房间号（文本，主键）
  String roomNo;

  /// 租金（整数，元/月）
  int rent;

  /// 实付（整数，本月实际收到的房租）
  int paid;

  /// 房型（文本，如「一室一厅」）
  String roomType;

  /// 承租人（文本）
  String tenant;

  /// 身份证（文本）
  String idCard;

  /// 入住日期（yyyy-MM-dd）
  String? checkIn;

  /// 到期日期（yyyy-MM-dd）
  String? expire;

  /// 上期电表（整数，度）
  int elecPrev;

  /// 本期电表（整数，度）
  int elecCurr;

  /// 上期水表（整数，吨）
  int waterPrev;

  /// 本期水表（整数，吨）
  int waterCurr;

  /// 水费（整数，元）
  int waterFee;

  /// 电费（整数，元）
  int elecFee;

  /// 水电费合计（整数，元）
  int utilityFee;

  /// 水电收缴（布尔型：true 已收 / false 未收）
  bool utilityPaid;

  /// 小豆豆（整数）—— 一楼大门磁卡数量
  int cardCount;

  /// 钥匙（整数，把数）
  int keyCount;

  /// 押金（整数，元）
  int deposit;

  /// 空调（整数，台数）
  int ac;

  /// 热水器（整数，台数）
  int heater;

  /// 冰箱（整数，台数）
  int fridge;

  /// 洗衣机（整数，台数）
  int washer;

  /// 从数据库 Map 构造
  factory Room.fromMap(Map<String, Object?> m) => Room(
        roomNo: (m['room_no'] ?? '') as String,
        rent: (m['rent'] ?? 0) as int,
        paid: (m['paid'] ?? 0) as int,
        roomType: (m['room_type'] ?? '') as String,
        tenant: (m['tenant'] ?? '') as String,
        idCard: (m['id_card'] ?? '') as String,
        checkIn: m['check_in'] as String?,
        expire: m['expire'] as String?,
        elecPrev: (m['elec_prev'] ?? 0) as int,
        elecCurr: (m['elec_curr'] ?? 0) as int,
        waterPrev: (m['water_prev'] ?? 0) as int,
        waterCurr: (m['water_curr'] ?? 0) as int,
        waterFee: (m['water_fee'] ?? 0) as int,
        elecFee: (m['elec_fee'] ?? 0) as int,
        utilityFee: (m['utility_fee'] ?? 0) as int,
        utilityPaid: ((m['utility_paid'] ?? 0) as int) == 1,
        cardCount: (m['card_count'] ?? 0) as int,
        keyCount: (m['key_count'] ?? 0) as int,
        deposit: (m['deposit'] ?? 0) as int,
        ac: (m['ac'] ?? 0) as int,
        heater: (m['heater'] ?? 0) as int,
        fridge: (m['fridge'] ?? 0) as int,
        washer: (m['washer'] ?? 0) as int,
      );

  /// 转为数据库 Map
  Map<String, Object?> toMap() => <String, Object?>{
        'room_no': roomNo,
        'rent': rent,
        'paid': paid,
        'room_type': roomType,
        'tenant': tenant,
        'id_card': idCard,
        'check_in': checkIn,
        'expire': expire,
        'elec_prev': elecPrev,
        'elec_curr': elecCurr,
        'water_prev': waterPrev,
        'water_curr': waterCurr,
        'water_fee': waterFee,
        'elec_fee': elecFee,
        'utility_fee': utilityFee,
        'utility_paid': utilityPaid ? 1 : 0,
        'card_count': cardCount,
        'key_count': keyCount,
        'deposit': deposit,
        'ac': ac,
        'heater': heater,
        'fridge': fridge,
        'washer': washer,
      };

  /// 是否已入住（有承租人）
  bool get isOccupied => tenant.trim().isNotEmpty;

  /// 房租是否已缴清
  bool get isRentPaid => paid >= rent;

  /// 楼层推导：房号去掉最后两位（101→1、1203→12）；不足三位归「—」。
  /// 抄表页 / 房间管理页共用的分组口径。
  static String floorOf(String roomNo) {
    final String t = roomNo.trim();
    if (t.length <= 2) return '—';
    return t.substring(0, t.length - 2);
  }

  /// 楼层展示名：'—'（房号无数字的房间）显示为「其他房间」
  static String floorName(String floor) =>
      floor == '—' ? '其他房间' : '$floor 层';

  /// 配套家电汇总文案
  String get applianceText {
    final List<String> parts = <String>[];
    if (ac > 0) parts.add('空调×$ac');
    if (heater > 0) parts.add('热水器×$heater');
    if (fridge > 0) parts.add('冰箱×$fridge');
    if (washer > 0) parts.add('洗衣机×$washer');
    return parts.isEmpty ? '无' : parts.join(' ');
  }

  /// 复制一份（编辑页使用，避免直接改动原对象）
  Room copy() => Room.fromMap(toMap());
}
