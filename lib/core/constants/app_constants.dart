/// 全局常量定义：应用信息、表名、字段名、通知渠道等。
/// 集中管理，避免硬编码散落各处造成冗余。
class AppConstants {
  AppConstants._();

  //========================= 应用信息 =========================
  static const String appName = '租房管家';
  static const String appVersion = '1.1.1';
  static const String appBuild = '9';

  /// ====== 应用内更新：Release 仓库（GitHub / Gitee 同名公开仓库）======
  static const String updateRepoName = 'zufang_guanjia';
  static const String updateRepoGitHubOwner = 'HighnessRK';
  static const String updateRepoGiteeOwner = 'HighnesssRK';
  static const String appDesc = '纯本地离线 · 个人房东房源租户管理';

  //========================= 数据库 ===========================
  /// SQLite 数据库文件名
  static const String dbName = 'rental.db';
  /// 数据库版本：v2 = people 主租户标记；v3 = people 身份证跟随租户（2026-10）
  static const int dbVersion = 4;

  /// 房间信息表
  static const String tableRooms = 'rooms';

  /// 租户信息表
  static const String tablePeople = 'people';

  /// 缴费流水表（用于「缴费统计 / 历史账单 / 欠费累计」）
  static const String tablePayments = 'payments';

  //========================= 配置文件 =========================
  /// 本地配置文件名（纯文本）
  static const String configFileName = 'info.gwt';

  //========================= MCP Server =======================
  /// MCP Server 固定监听端口（Streamable HTTP：POST /mcp）
  ///
  /// 固定端口的好处是「复制出来的配置永不变化」——AI 客户端只要导入一次
  /// 配置就能一直连（LAN 地址可能随路由器分配变化，端口不会）。
  static const int mcpPort = 8765;

  /// MCP 服务端名 / 版本（initialize 时返回给客户端）
  static const String mcpServerName = '租房管家';
  static const String mcpProtocolVersion = '2025-06-18';

  //========================= 通知 =============================
  /// 通知渠道：通用提醒
  static const String channelGeneral = 'general_notice';

  /// 通知渠道：房租/租期到期提醒
  static const String channelRent = 'rent_remind';

  /// 通知渠道：水电费提醒
  static const String channelUtility = 'utility_remind';

  /// 通知渠道：澎湃OS 焦点通知
  static const String channelFocus = 'focus_notice_v2';

  /// 通知渠道：Android 16 Live Update（收款进度芯片）
  static const String channelLive = 'live_notice_v1';

  /// 通知渠道：应用内更新下载进度
  static const String channelDownload = 'download_notice';

  /// 原生桥接 MethodChannel 名称
  static const String nativeChannel = 'com.zufang.guanjia/native';

  /// 本地通知 ID 基数（避免与系统其他通知冲突）
  static const int notifyIdRent = 1001;
  static const int notifyIdUtility = 1002;
  static const int notifyIdExpire = 1003;
  static const int notifyIdFocus = 1099;
  static const int notifyIdUpdate = 1200;

  /// 实验室 Beta：手动触发的超级岛（焦点通知）测试通知
  static const int notifyIdFocusTest = 1100;

  /// Live Update：本期收款进度（同一 ID 原地更新）
  static const int notifyIdLive = 1101;

  //========================= 费用类型 =========================
  /// 缴费类型：房租
  static const String payTypeRent = 'rent';

  /// 缴费类型：水电费（旧版月度合并流水，历史数据兼容用）
  static const String payTypeUtility = 'utility';

  /// 缴费类型：水费（周期结算流水，季付/月付/年付）
  static const String payTypeWater = 'water';

  /// 缴费类型：电费（周期结算流水，智能夏季月付/其余季付）
  static const String payTypeElec = 'elec';

  /// 水电两类周期流水（统计/查询时一起处理）
  static const List<String> payTypesUtilitySplit = <String>[
    payTypeWater,
    payTypeElec,
  ];
}
