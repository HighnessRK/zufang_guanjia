/// 租户信息模型 —— 严格对应 SQLite `people` 表字段
/// （id 为实现增删改查所需的自增主键，业务字段与需求完全一致）。
class Person {
  Person({
    this.id,
    this.roomNo = '',
    this.name = '',
    this.phone = '',
    this.idCard = '',
    this.isPrimary = false,
  });

  /// 自增主键
  int? id;

  /// 房间号（文本，关联 rooms.room_no）
  String roomNo;

  /// 姓名（文本）
  String name;

  /// 电话（文本）
  String phone;

  /// 身份证号（文本，选填）—— 跟随租户本人，不挂在房间上
  String idCard;

  /// 是否主租户（一个房间可有多位租户，主租户即 rooms.tenant 镜像，
  /// 列表 / 统计 / 提醒里的「承租人」均展示主租户）
  bool isPrimary;

  /// 从数据库 Map 构造
  factory Person.fromMap(Map<String, Object?> m) => Person(
        id: m['id'] as int?,
        roomNo: (m['room_no'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        idCard: (m['id_card'] ?? '') as String,
        isPrimary: ((m['is_primary'] ?? 0) as int) == 1,
      );

  /// 转为数据库 Map（不含 id，用于 insert）
  Map<String, Object?> toMap() => <String, Object?>{
        'room_no': roomNo,
        'name': name,
        'phone': phone,
        'id_card': idCard,
        'is_primary': isPrimary ? 1 : 0,
      };
}
