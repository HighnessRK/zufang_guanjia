/// APP 内置通知中心的消息条目（由提醒引擎实时计算，不额外建表）。
class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.level,
    required this.roomNo,
  });

  /// 消息唯一 ID（用于「已读」标记，写入 info.gwt）
  final String id;

  /// 类型：rent / expire / utility
  final String type;

  /// 标题
  final String title;

  /// 正文
  final String body;

  /// 级别：warn（提醒）/ danger（紧急）
  final String level;

  /// 关联房间号
  final String roomNo;

  /// 类型中文名
  String get typeText {
    switch (type) {
      case 'rent':
        return '房租提醒';
      case 'expire':
        return '租期提醒';
      case 'utility':
        return '水电提醒';
      default:
        return '系统消息';
    }
  }
}
