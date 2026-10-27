import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../utils/date_util.dart';

/// 全局配置（info.gwt）读写服务。
///
/// 【设计说明】
/// * info.gwt 是**纯文本**本地配置文件，格式为 `键=值`，一行一条，# 为注释；
/// * 项目根目录 / assets 里的 info.gwt 是**默认模板**，APP 首次启动时释放到
///   应用私有目录（files/info.gwt）；
/// * 之后 APP 启动读取、设置页修改后自动回写的就是私有目录那一份；
/// * 数据本体全程本地；仅「应用内更新」在开关开启时联网检查 Release。
class AppConfig extends ChangeNotifier {
  AppConfig._();

  /// 全局单例
  static final AppConfig instance = AppConfig._();

  //========================= 运行期字段 =======================

  /// 水费单价（元/吨），默认 6
  double waterPrice = 6.0;

  /// 电费单价（元/度），默认 1.2
  double elecPrice = 1.2;

  /// 房租缴费周期（月）：1 月付 / 3 季付 / 6 半年付 / 12 年付。
  /// 默认 12（年付：一次收「月租 × 12」，之后 12 个月内不再重复应收）。
  int rentCycle = 12;

  /// 水费收缴周期（月）：1 月付 / 3 季付 / 12 年付。
  /// 默认 3（季付：水表用量按周期累计，到期一次结清）。
  int waterCycle = 3;

  /// 电费收缴周期（月）：0 = 智能（夏季月付、其余季节季付）/ 1 / 3 / 12。
  /// 默认 0（智能）。
  int elecCycle = 0;

  /// 智能电费模式下的夏季起始月（1-12），默认 6
  int summerStart = 6;

  /// 智能电费模式下的夏季结束月（1-12），默认 9。
  /// 起始月 > 结束月表示跨年夏季（如 10 月 ~ 次年 4 月）。
  int summerEnd = 9;

  /// 统一收水日期（yyyy-MM-dd）：全楼层水费以此日为锚点，每 waterCycle
  /// 个月为一个统一收缴日，到期所有房间同期一起应收。
  /// 缺失时自动定为当月 1 日并立即写盘固定（不随月份漂移）。
  String waterCollectDate = '';

  /// 统一收电日期（yyyy-MM-dd）：同上，间隔按 [elecIntervalAt] 逐段判定
  /// （智能模式夏季月付、其余季付）。
  String elecCollectDate = '';

  /// 【v1.1.3】收电日期独立于收水日期。
  ///
  /// 默认 false = 跟随收水日期（改水日即同步电日，收电日期行只读展示）；
  /// 需要两日不一致时打开本开关，收电日期行恢复可点、单独选择。
  /// 老用户升级首次读到键缺失时，按既有两日是否相同推断，保持原行为不变。
  bool elecDateIndependent = false;

  /// 【v1.1.1】入住日期一改，到期日期自动顺延一年。
  /// 默认开启；关掉则到期日期完全手动维护。
  bool autoExpire = true;

  /// 指定月份是否处于夏季（智能电费模式用）
  bool isSummerMonth(int m) {
    if (summerStart <= summerEnd) {
      return m >= summerStart && m <= summerEnd;
    }
    // 跨年夏季：如 start=10, end=4 → 10~12 月与 1~4 月
    return m >= summerStart || m <= summerEnd;
  }

  /// 当月是否处于夏季
  bool isSummerNow() => isSummerMonth(DateTime.now().month);

  /// 电费当期实际收缴周期（月）：智能模式下夏季 1、其余 3；
  /// 固定周期模式返回配置值（兜底非法值）。
  int get elecCycleNow => elecIntervalAt(DateTime.now());

  /// 指定日期所处的电费收缴间隔（月）：智能模式按该日所处季节逐段判定
  /// （夏季月付、其余季付），固定周期模式直接返回配置值。
  /// 用于统一收缴日历沿锚点推进（夏季前后间隔可以不同）。
  int elecIntervalAt(DateTime d) {
    if (elecCycle == 0) return isSummerMonth(d.month) ? 1 : 3;
    return elecCycle == 1 || elecCycle == 3 || elecCycle == 12 ? elecCycle : 3;
  }

  /// 周期配置的中文摘要（设置页/编辑页展示用）
  static String cycleLabel(int months) {
    switch (months) {
      case 1:
        return '月付';
      case 3:
        return '季付';
      case 6:
        return '半年付';
      case 12:
        return '年付';
    }
    return '$months 个月';
  }

  /// 周期单位字（元/月、元/季…；房间编辑页租金标签随设置周期变化用）
  static String cycleUnit(int months) {
    switch (months) {
      case 1:
        return '月';
      case 3:
        return '季';
      case 6:
        return '半年';
      case 12:
        return '年';
    }
    return '$months 个月';
  }

  /// 电费周期摘要（含智能模式说明）
  String get elecCycleLabel => elecCycle == 0 ? '智能（夏季月付·其余季付）' : cycleLabel(elecCycle);

  /// 未缴费提醒提前天数（天），默认 7
  int remindDays = 7;

  /// 租期到期提醒提前天数（天），默认 30
  int expireRemindDays = 30;

  /// 是否开启系统通知
  bool notifyEnabled = true;

  /// 是否开启澎湃OS/HyperOS 焦点通知
  bool focusEnabled = true;

  /// 内置通知中心已读消息 ID（逗号分隔）
  String noticeReadIds = '';

  /// 高级材质：true = 液态玻璃（极光底 + 玻璃高光卡片），false = 高斯模糊
  /// （纯色底 + 毛玻璃卡片）
  bool premiumMaterial = true;

  /// 大模型 API 基地址（OpenAI 兼容，如 https://api.openai.com/v1，
  /// 本地推理可用 http://192.168.x.x:11434/v1）
  String llmBaseUrl = '';

  /// 大模型 API Key
  String llmApiKey = '';

  /// 对话模型名（预留）
  String llmModel = '';

  /// 视觉模型名（电表拍照识别用）
  String llmVisionModel = '';

  /// 收据自动水印文字；为空表示不显示水印。
  String receiptWatermark = '';

  String feishuAppToken = '';
  String feishuTableId = '';
  String feishuClientId = '';
  String feishuClientSecret = '';
  bool feishuEnabled = false;

  /// 应用内更新：下载源 'gitee'（默认，国内快）/ 'github'
  String updateSource = 'gitee';

  /// 应用内更新：启动时静默检查新版本
  bool autoCheckUpdate = true;

  /// 应用内更新：发现新版本时弹窗提醒（自动检查开启时生效）
  bool updateNotify = true;

  /// 上次自动提醒过的版本号（同一版本只自动提醒一次）
  String updatePromptedVersion = '';

  /// 预测式返回手势（边缘侧滑跟手返回）。默认关闭。
  /// 关闭时不认领边缘手势 → 走系统经典返回，无跟手动画。
  bool predictiveBack = false;

  /// MCP Server 开关：开启后在 8765 端口提供 Streamable HTTP 服务，
  /// AI 助手（Claude / ChatGPT / 任意 MCP 客户端）可通过局域网全流程
  /// 查询与修改本 APP 的房间、租户、收款、抄表与设置。默认开启。
  bool mcpEnabled = true;

  //========================= 路径 ============================

  /// info.gwt 实际读写路径
  File? _file;

  /// 本次 load 发现统一收缴日期缺失 / 非法（init 会一次性写盘固定）
  bool _collectDateDirty = false;

  /// 配置文件完整路径（供备份使用）
  String? get configPath => _file?.path;

  //========================= 初始化 ===========================

  /// 启动时调用：定位 / 释放 / 读取配置文件
  Future<void> init() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/${AppConstants.configFileName}');

    // 首次启动：把内置模板复制到私有目录
    if (!await file.exists()) {
      final String template =
          await rootBundle.loadString('assets/${AppConstants.configFileName}');
      await file.writeAsString(template, flush: true);
    }
    _file = file;
    await load();
    // 首次运行：缺省的统一收缴日期立即写盘固定（防止默认值逐月漂移，
    // 保证全楼层收缴锚点唯一且稳定）
    if (_collectDateDirty) await save();
  }

  //========================= 读取 =============================

  /// 读取 info.gwt 并解析到内存字段
  Future<void> load() async {
    final File? file = _file;
    if (file == null || !await file.exists()) return;

    final Map<String, String> map = <String, String>{};
    final List<String> lines =
        (await file.readAsString()).split(RegExp(r'\r?\n'));
    for (final String line in lines) {
      final String t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final int idx = t.indexOf('=');
      if (idx <= 0) continue;
      map[t.substring(0, idx).trim()] = t.substring(idx + 1).trim();
    }

    waterPrice = _toDouble(map['water_price'], 6.0);
    elecPrice = _toDouble(map['elec_price'], 1.2);
    rentCycle = _toInt(map['rent_cycle'], 12);
    waterCycle = _toInt(map['water_cycle'], 3);
    elecCycle = _toInt(map['elec_cycle'], 0);
    summerStart = _toInt(map['summer_start'], 6);
    summerEnd = _toInt(map['summer_end'], 9);
    // 统一收缴日期：缺失 / 非法时定为当月 1 日，init 会一次性写盘固定
    final DateTime today = DateTime.now();
    final DateTime? waterDay = DateUtil.parse(map['water_collect_date']);
    final DateTime? elecDay = DateUtil.parse(map['elec_collect_date']);
    waterCollectDate =
        DateUtil.format(waterDay ?? DateTime(today.year, today.month, 1));
    elecCollectDate =
        DateUtil.format(elecDay ?? DateTime(today.year, today.month, 1));
    _collectDateDirty = waterDay == null || elecDay == null;
    // 【v1.1.3】收电日期默认跟随收水日期。
    // 键缺失 = 首次升到 1.1.3：按既有两日是否相同推断（不同则保留独立，
    // 不悄悄改老用户的收电日）；键存在 = 以开关为准，关闭时强制同步。
    if (!map.containsKey('elec_date_independent')) {
      elecDateIndependent = waterCollectDate != elecCollectDate;
    } else {
      elecDateIndependent = map['elec_date_independent'] == '1';
    }
    if (!elecDateIndependent && elecCollectDate != waterCollectDate) {
      elecCollectDate = waterCollectDate;
      _collectDateDirty = true;
    }
    remindDays = _toInt(map['remind_days'], 7);
    expireRemindDays = _toInt(map['expire_remind_days'], 30);
    notifyEnabled = map['notify_enabled'] != '0';
    focusEnabled = map['focus_enabled'] != '0';
    noticeReadIds = map['notice_read_ids'] ?? '';
    premiumMaterial = map['premium_material'] != '0';
    llmBaseUrl = map['llm_base_url'] ?? '';
    llmApiKey = map['llm_api_key'] ?? '';
    llmModel = map['llm_model'] ?? '';
    llmVisionModel = map['llm_vision_model'] ?? '';
    receiptWatermark = map['receipt_watermark'] ?? '';
    feishuAppToken = map['feishu_app_token'] ?? '';
    feishuTableId = map['feishu_table_id'] ?? '';
    feishuClientId = map['feishu_client_id'] ?? '';
    feishuClientSecret = map['feishu_client_secret'] ?? '';
    feishuEnabled = map['feishu_enabled'] == '1';
    updateSource = map['update_source'] == 'github' ? 'github' : 'gitee';
    autoCheckUpdate = map['auto_check_update'] != '0';
    updateNotify = map['update_notify'] != '0';
    autoExpire = map['auto_expire'] != '0';
    updatePromptedVersion = map['update_prompted_version'] ?? '';
    predictiveBack = map['predictive_back'] == '1';
    mcpEnabled = map['mcp_enabled'] != '0';

    // 数据合法性兜底：单价与天数不允许为负
    if (waterPrice < 0) waterPrice = 6.0;
    if (elecPrice < 0) elecPrice = 1.2;
    if (remindDays < 0) remindDays = 7;
    if (expireRemindDays < 0) expireRemindDays = 30;

    // 周期白名单兜底（只能取标准档位）
    if (rentCycle != 1 && rentCycle != 3 && rentCycle != 6 && rentCycle != 12) {
      rentCycle = 12;
    }
    if (waterCycle != 1 && waterCycle != 3 && waterCycle != 12) {
      waterCycle = 3;
    }
    if (elecCycle != 0 && elecCycle != 1 && elecCycle != 3 && elecCycle != 12) {
      elecCycle = 0;
    }
    if (summerStart < 1 || summerStart > 12) summerStart = 6;
    if (summerEnd < 1 || summerEnd > 12) summerEnd = 9;

    notifyListeners();
  }

  //========================= 保存 =============================

  /// 把当前内存字段写回 info.gwt（自动保留文件头注释，便于人工查看）
  Future<void> save() async {
    final File? file = _file;
    if (file == null) return;

    final StringBuffer buf = StringBuffer()
      ..writeln('#===============================================================')
      ..writeln('# 租房管家 全局配置文件 info.gwt（由 APP 自动维护）')
      ..writeln('#===============================================================')
      ..writeln()
      ..writeln('#—— 计费参数 ———')
      ..writeln('water_price=${_trimNum(waterPrice)}')
      ..writeln('elec_price=${_trimNum(elecPrice)}')
      ..writeln()
      ..writeln('#—— 缴费周期（月）———')
      ..writeln('# 房租：1 月付 / 3 季付 / 6 半年付 / 12 年付')
      ..writeln('rent_cycle=$rentCycle')
      ..writeln('# 水费：1 月付 / 3 季付 / 12 年付')
      ..writeln('water_cycle=$waterCycle')
      ..writeln('# 电费：0 智能（夏季月付其余季付）/ 1 / 3 / 12')
      ..writeln('elec_cycle=$elecCycle')
      ..writeln('# 智能电费的夏季月份范围（起止 1-12，起 > 止 表示跨年）')
      ..writeln('summer_start=$summerStart')
      ..writeln('summer_end=$summerEnd')
      ..writeln('# 全楼层统一收缴日（yyyy-MM-dd）：水/电各自以此为锚点，')
      ..writeln('# 按上面的周期间隔逐期推进，到期所有房间同期一起应收')
      ..writeln('water_collect_date=$waterCollectDate')
      ..writeln('elec_collect_date=$elecCollectDate')
      ..writeln('# 收电日期独立于收水 1=独立 0=跟随收水（v1.1.3 默认跟随）')
      ..writeln('elec_date_independent=${elecDateIndependent ? 1 : 0}')
      ..writeln()
      ..writeln('#—— 通知提醒 ———')
      ..writeln('remind_days=$remindDays')
      ..writeln('expire_remind_days=$expireRemindDays')
      ..writeln('notify_enabled=${notifyEnabled ? 1 : 0}')
      ..writeln('focus_enabled=${focusEnabled ? 1 : 0}')
      ..writeln()
      ..writeln('#—— 外观材质 ———')
      ..writeln('# 高级材质 1=液态玻璃 0=高斯模糊')
      ..writeln('premium_material=${premiumMaterial ? 1 : 0}')
      ..writeln()
      ..writeln('#—— 大模型 API（本地填写，不上传）———')
      ..writeln('llm_base_url=$llmBaseUrl')
      ..writeln('llm_api_key=$llmApiKey')
      ..writeln('llm_model=$llmModel')
      ..writeln('llm_vision_model=$llmVisionModel')
      ..writeln('receipt_watermark=$receiptWatermark')
      ..writeln('feishu_app_token=$feishuAppToken')
      ..writeln('feishu_table_id=$feishuTableId')
      ..writeln('feishu_client_id=$feishuClientId')
      ..writeln('feishu_client_secret=$feishuClientSecret')
      ..writeln('feishu_enabled=${feishuEnabled ? 1 : 0}')
      ..writeln()
      ..writeln('#—— 应用更新 ———')
      ..writeln('# 下载源 gitee / github')
      ..writeln('update_source=$updateSource')
      ..writeln('auto_check_update=${autoCheckUpdate ? 1 : 0}')
      ..writeln('update_notify=${updateNotify ? 1 : 0}')
      ..writeln('auto_expire=${autoExpire ? 1 : 0}')
      ..writeln('update_prompted_version=$updatePromptedVersion')
      ..writeln('predictive_back=${predictiveBack ? 1 : 0}')
      ..writeln()
      ..writeln('#—— MCP Server（AI 助手接入）———')
      ..writeln('# 1=开启 0=关闭；开启后局域网内 AI 可全流程读写本 APP 数据')
      ..writeln('mcp_enabled=${mcpEnabled ? 1 : 0}')
      ..writeln()
      ..writeln('#—— 运行期数据 ———')
      ..writeln('notice_read_ids=$noticeReadIds');

    await file.writeAsString(buf.toString(), flush: true);
    notifyListeners();
  }

  /// 一次性批量更新（设置页使用）：修改后立即写盘生效
  Future<void> update({
    double? waterPrice,
    double? elecPrice,
    int? rentCycle,
    int? waterCycle,
    int? elecCycle,
    int? summerStart,
    int? summerEnd,
    String? waterCollectDate,
    String? elecCollectDate,
    bool? elecDateIndependent,
    int? remindDays,
    int? expireRemindDays,
    bool? notifyEnabled,
    bool? focusEnabled,
    String? noticeReadIds,
    bool? premiumMaterial,
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
    String? llmVisionModel,
    String? receiptWatermark,
    String? updateSource,
    bool? autoCheckUpdate,
    bool? updateNotify,
    bool? autoExpire,
    String? updatePromptedVersion,
    bool? predictiveBack,
    bool? mcpEnabled,
  }) async {
    this.waterPrice = waterPrice ?? this.waterPrice;
    this.elecPrice = elecPrice ?? this.elecPrice;
    this.rentCycle = rentCycle ?? this.rentCycle;
    this.waterCycle = waterCycle ?? this.waterCycle;
    this.elecCycle = elecCycle ?? this.elecCycle;
    this.summerStart = summerStart ?? this.summerStart;
    this.summerEnd = summerEnd ?? this.summerEnd;
    this.waterCollectDate = waterCollectDate ?? this.waterCollectDate;
    this.elecCollectDate = elecCollectDate ?? this.elecCollectDate;
    this.elecDateIndependent =
        elecDateIndependent ?? this.elecDateIndependent;
    // 【v1.1.3】跟随模式下电日始终等于水日：任一处改动后兜底同步
    if (!this.elecDateIndependent) {
      this.elecCollectDate = this.waterCollectDate;
    }
    this.remindDays = remindDays ?? this.remindDays;
    this.expireRemindDays = expireRemindDays ?? this.expireRemindDays;
    this.notifyEnabled = notifyEnabled ?? this.notifyEnabled;
    this.focusEnabled = focusEnabled ?? this.focusEnabled;
    this.noticeReadIds = noticeReadIds ?? this.noticeReadIds;
    this.premiumMaterial = premiumMaterial ?? this.premiumMaterial;
    this.llmBaseUrl = llmBaseUrl ?? this.llmBaseUrl;
    this.llmApiKey = llmApiKey ?? this.llmApiKey;
    this.llmModel = llmModel ?? this.llmModel;
    this.llmVisionModel = llmVisionModel ?? this.llmVisionModel;
    this.receiptWatermark = receiptWatermark ?? this.receiptWatermark;
    this.updateSource = updateSource ?? this.updateSource;
    this.autoCheckUpdate = autoCheckUpdate ?? this.autoCheckUpdate;
    this.updateNotify = updateNotify ?? this.updateNotify;
    this.autoExpire = autoExpire ?? this.autoExpire;
    this.updatePromptedVersion =
        updatePromptedVersion ?? this.updatePromptedVersion;
    this.predictiveBack = predictiveBack ?? this.predictiveBack;
    this.mcpEnabled = mcpEnabled ?? this.mcpEnabled;
    await save();
  }

  //========================= 通知已读 =========================

  /// 把一条内置通知标记为已读
  Future<void> markNoticeRead(String id) async {
    final Set<String> ids = noticeReadIds.isEmpty
        ? <String>{}
        : noticeReadIds.split(',').where((String e) => e.isNotEmpty).toSet();
    if (ids.add(id)) {
      noticeReadIds = ids.join(',');
      await save();
    }
  }

  /// 全部标记为已读
  Future<void> markAllNoticeRead(List<String> ids) async {
    noticeReadIds = ids.join(',');
    await save();
  }

  /// 判断某条通知是否已读
  bool isNoticeRead(String id) {
    if (noticeReadIds.isEmpty) return false;
    return noticeReadIds.split(',').contains(id);
  }

  //========================= 私有工具 =========================

  static double _toDouble(String? v, double def) =>
      v == null ? def : (double.tryParse(v) ?? def);

  static int _toInt(String? v, int def) =>
      v == null ? def : (int.tryParse(v) ?? def);

  /// 数值去掉多余的 .0
  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
