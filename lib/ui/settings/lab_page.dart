import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/constants/app_constants.dart';
import '../../services/native_bridge.dart';
import '../../services/reminder_engine.dart';
import '../widgets/app_widgets.dart';

/// 实验室 Beta（设置二级页）：
///   超级岛 / Live Update 手动触发测试 + 设备能力逐项诊断弹窗。
class LabPage extends StatefulWidget {
  const LabPage({super.key});

  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  /// 顶栏折叠行为：上滑时大标题平滑收起
  final MiuixExitUntilCollapsedScrollBehavior _appBarBehavior =
      miuixScrollBehavior();

  /// 设备信息（诊断展示用；加载失败不阻塞界面）
  Map<String, dynamic>? _sysInfo;

  /// 超级岛 / 焦点通知 / Live Update 状态（协议版本 / 岛支持 / 权限）
  Map<String, dynamic>? _focusStatus;

  @override
  void initState() {
    super.initState();
    _loadSysInfo();
    _loadFocusStatus();
  }

  Future<void> _loadSysInfo() async {
    try {
      final Map<String, dynamic> m = await NativeBridge.systemInfo();
      if (mounted) setState(() => _sysInfo = m);
    } catch (_) {
      // 设备信息获取失败不影响实验室页面其它功能
    }
  }

  Future<void> _loadFocusStatus() async {
    try {
      final Map<String, dynamic> m = await NativeBridge.focusStatus();
      if (mounted) setState(() => _focusStatus = m);
    } catch (_) {
      // 焦点状态获取失败时摘要保持"检测中"
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return AuroraScaffold(
      topBar: MiuixTopAppBar(
        scrollBehavior: _appBarBehavior,
        color: Colors.transparent,
        title: '实验室 Beta',
        subtitle: '通知能力测试 · 设备诊断',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        // MiuixScrollBehaviorListener：把列表滚动桥接给顶栏（大标题折叠）
        return MiuixScrollBehaviorListener(
          behavior: _appBarBehavior,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
            children: <Widget>[
              //==================== 手动测试 ====================
              const SectionTitle('手动测试'),
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    MiuixArrowPreference(
                      title: '手动触发小米超级岛通知',
                      summary: _focusSummary(),
                      onClick: _triggerFocusTest,
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '手动触发 Live Update',
                      summary: _liveSummary(),
                      onClick: _triggerLiveTest,
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '清除测试通知',
                      summary: '移除实验室 Beta 发出的测试通知',
                      onClick: _clearFocusTest,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              MiuixText(
                '以上为实验性通知能力：测试通知只发送到本机；结果弹窗会逐项列出'
                '设备真实能力、降级原因与下一步处理建议。',
                fontSize: 11,
                color: c.onSurfaceVariantSummary,
              ),
            ],
          ),
        );
      },
    );
  }

  /// ==================== 超级岛（焦点通知）====================

  /// 实验室 Beta 行的摘要：展示当前设备能否真正上超级岛、权限是否开启
  String _focusSummary() {
    final Map<String, dynamic>? sys = _sysInfo;
    final String ver = sys == null
        ? ''
        : '（Android ${sys['androidVersion'] ?? '?'} · API ${sys['sdkInt'] ?? '?'}）';
    final Map<String, dynamic>? f = _focusStatus;
    if (f == null) return '检测超级岛能力中…（点击可发送测试通知）';
    if (f['isXiaomi'] != true) {
      return '非小米设备，点击后降级为普通高优先级通知$ver';
    }
    final int protocol = (f['protocol'] as num?)?.toInt() ?? 0;
    if (protocol <= 0) return '系统不支持焦点通知，将按普通通知显示$ver';
    final bool perm = f['hasFocusPermission'] == true;
    final bool ready = f['ready'] == true;
    final String head;
    if (protocol >= 3) {
      head = ready ? 'OS3 超级岛就绪' : 'OS3 协议（上岛条件未满足）';
    } else if (protocol == 2) {
      head = 'OS2 焦点协议（超级岛通用模板）';
    } else {
      head = 'OS1 旧版焦点协议（仅状态栏胶囊）';
    }
    final String power = perm
        ? '焦点权限已开启'
        : '焦点权限未开启（下拉通知栏 → 更多设置 → 焦点通知）';
    return '$head · $power$ver';
  }

  /// 手动触发一条 HyperOS 超级岛（焦点通知），用于测试
  Future<void> _triggerFocusTest() async {
    try {
      // 先确保 Android 13+ 通知权限（未授权时系统会弹出授权框）
      await NativeBridge.requestNotifyPermission();
      // 取最新的焦点状态：用于发送前判断 + 发送后给出准确提示
      final Map<String, dynamic> f = await NativeBridge.focusStatus();
      if (mounted) setState(() => _focusStatus = f);

      final DateTime now = DateTime.now();
      final String ts = '${now.month}/${now.day} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      await NativeBridge.showNotification(
        id: AppConstants.notifyIdFocusTest,
        title: '超级岛测试通知',
        body: '实验室 Beta 手动触发 · $ts',
        channelId: AppConstants.channelFocus,
        focus: true,
      );
      if (!mounted) return;
      // 根据真实状态给出诊断弹窗，避免"以为上岛了其实降级了"
      _showFocusResultDialog(f);
    } catch (e) {
      if (mounted) AppSnackbar.show('发送失败：$e');
    }
  }

  /// 超级岛测试结果诊断弹窗：展示设备真实能力 + 为什么没上岛 + 下一步
  void _showFocusResultDialog(Map<String, dynamic> f) {
    final bool xiaomi = f['isXiaomi'] == true;
    final int protocol = (f['protocol'] as num?)?.toInt() ?? 0;
    final bool island = f['supportIsland'] == true;
    final bool perm = f['hasFocusPermission'] == true;
    final bool gateOk = f['xmsfGate'] == true;
    final bool ready = f['ready'] == true;

    final String protocolText = !xiaomi
        ? '不适用（非小米设备）'
        : protocol >= 3
            ? 'OS$protocol（小米超级岛模板）'
            : protocol >= 1
                ? 'OS$protocol（焦点通知，非超级岛形态）'
                : '不支持（0）';
    final String islandText = !xiaomi ? '不适用' : (island ? '支持' : '不支持');
    final String gateText = !xiaomi
        ? '不适用'
        : (gateOk ? '可用' : '不可用（XMSF 或隐藏 API 缺失）');
    final String readyText =
        ready ? '就绪（按超级岛通道发送）' : '未就绪（降级为普通通知）';
    final String permText =
        !xiaomi ? '不适用' : (perm ? '已开启' : '未开启');

    String advice;
    if (!xiaomi) {
      advice = '非小米 / Redmi / POCO 设备无法上岛，通知已按普通通知显示。';
    } else if (protocol <= 0) {
      advice = '系统未提供焦点通知协议（可能为国际版系统或未更新澎湃OS），'
          '通知已按普通通知显示。';
    } else if (!ready) {
      if (protocol < 3) {
        advice = '当前为 OS$protocol 旧焦点协议，只能显示状态栏胶囊形态，'
            '超级岛需要澎湃OS 3（焦点协议 3）。通知已按当前协议发送。';
      } else if (!island) {
        advice = '系统岛能力未启用（persist.sys.feature.island=false），'
            '通知已按普通通知显示。';
      } else {
        advice = '设备缺少 XMSF 校验通道（小米推送框架不可见或隐藏 API 被禁用），'
            '无法完成超级岛校验，通知已按普通通知显示。';
      }
    } else {
      advice = '本地条件全部就绪，通知已按超级岛通道发送。观察屏幕顶部摄像头'
          '挖孔两侧的小岛胶囊（点击可展开）：\n'
          '· 若出现了岛 → 上岛成功；\n'
          '· 若没出现 → 被系统「焦点通知作用域鉴权」拦截（SystemUI AuthManager'
          ' 按包名返回 scope mismatch；开源参考项目在同一台设备上同样被拒）'
          '。该授权只能在小米平台侧开通：发邮件至 '
          'mipush-permission@xiaomi.com 申请「焦点通知使用权限」，'
          '平台配置权限后即可上岛（详见 dev.mi.com 超级岛 FAQ）。';
    }

    showAppDialog(
      context,
      title: '超级岛测试结果',
      cancelText: '关闭',
      confirmText: '再次发送',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _diagLine('小米设备', xiaomi ? '是' : '否'),
          _diagLine('焦点协议版本', protocolText),
          _diagLine('系统岛能力', islandText),
          _diagLine('XMSF 校验门', gateText),
          _diagLine('焦点通知权限', permText),
          _diagLine('超级岛就绪', readyText),
          const SizedBox(height: 10),
          MiuixText(advice, fontSize: 12),
        ],
      ),
    ).then((bool? again) {
      if (again == true && mounted) _triggerFocusTest();
    });
  }

  Widget _diagLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: MiuixText(label, fontSize: 12),
          ),
          Expanded(child: MiuixText(value, fontSize: 12)),
        ],
      ),
    );
  }

  //==================== Live Update（Android 16）=====================

  /// Live Update 行摘要：能否真正晋升为状态栏芯片，一句话讲清
  String _liveSummary() {
    final Map<String, dynamic>? sys = _sysInfo;
    final String ver = sys == null
        ? ''
        : '（Android ${sys['androidVersion'] ?? '?'} · API ${sys['sdkInt'] ?? '?'}）';
    final Map<String, dynamic>? f = _focusStatus;
    if (f == null) return '检测 Live Update 能力中…（点击可发送测试进度）';
    if (f['liveApi36'] != true) {
      return 'Android 16 以下，降级为普通进度通知$ver';
    }
    if (f['liveQpr1'] != true) {
      return 'Android 16.0（无 QPR1）：原地更新，不晋升芯片$ver';
    }
    if (f['livePromotable'] != true) return '通知不满足晋升条件$ver';
    if (f['liveCanPost'] != true) {
      return 'Live Update 总开关未开（下拉通知栏设置里开启）$ver';
    }
    return 'Live Update 就绪 · 点击发送收款进度芯片$ver';
  }

  /// 手动触发一条 Live Update（本期收款进度），用于测试
  Future<void> _triggerLiveTest() async {
    try {
      await NativeBridge.requestNotifyPermission();
      final Map<String, dynamic> f = await NativeBridge.focusStatus();
      if (mounted) setState(() => _focusStatus = f);

      // 用真实收款数据；本月无应收时用演示数据，保证总能看到进度条
      final HomeStat stat = await ReminderEngine.computeHomeStat();
      int due = stat.monthDue;
      int paid = stat.monthPaid;
      if (due <= 0 || paid > due) {
        if (due <= 0) {
          due = 8000;
          paid = 5200;
        } else {
          paid = due;
        }
      }
      int pct = (paid * 100 / due).round();
      if (pct > 100) pct = 100;
      if (pct < 0) pct = 0;
      final int remain = due > paid ? due - paid : 0;

      await NativeBridge.showNotification(
        id: AppConstants.notifyIdLive,
        channelId: AppConstants.channelLive,
        title: '本期收款进度',
        body: '已收 ¥$paid · 应收 ¥$due'
            '${remain > 0 ? ' · 欠 ¥$remain' : ' · 已结清'}',
        live: true,
        progress: pct,
        progressMax: 100,
        criticalText: '$pct%',
        restart: true, // start：清除"已划掉"记录
      );
      if (!mounted) return;
      _showLiveResultDialog(f);
    } catch (e) {
      if (mounted) AppSnackbar.show('发送失败：$e');
    }
  }

  /// Live Update 测试诊断弹窗：三道闸门逐项给出 + 下一步指引
  void _showLiveResultDialog(Map<String, dynamic> f) {
    final bool api36 = f['liveApi36'] == true;
    final bool qpr1 = f['liveQpr1'] == true;
    final bool promotable = f['livePromotable'] == true;
    final bool canPost = f['liveCanPost'] == true;

    String advice;
    if (!api36) {
      advice = '当前系统低于 Android 16，Live Update API 不存在。'
          '通知已按普通常驻进度通知发送：下拉通知栏可见进度条，'
          '但不会晋升到状态栏芯片。';
    } else if (!qpr1) {
      advice = '系统是 Android 16.0（未含 QPR1）：进度通知已原地更新显示在'
          '通知栏顶部，但状态栏芯片 / 晋升位需要 Android 16 QPR1（36.1）'
          '及以上，等系统更新后自动生效，无需改代码。';
    } else if (!promotable) {
      advice = '通知本身不满足晋升条件（需常驻 + 有标题 + 进度样式、'
          '渠道非最低重要度）。已发送，但不会晋升为 Live Update。';
    } else if (!canPost) {
      advice = '设备与通知都合格，但本应用的 Live Update 总开关没开：'
          '下拉通知栏 → 右上角设置 → 应用通知 → 找到「租房管家」→ '
          '开启「Live Update」（或称"晋升通知"），然后重新点此测试。';
    } else {
      advice = '条件全部满足，Live Update 已发送。可以观察：\n'
          '· 状态栏的小芯片（如 "65%"）；\n'
          '· 下拉通知栏置顶的进度条（高于普通通知）；\n'
          '· 锁屏上的醒目进度。\n'
          '点「取消关注」或划掉后，定时刷新不会复活它（系统要求）；'
          '重新打开一次应用即恢复。';
    }

    showAppDialog(
      context,
      title: 'Live Update 测试结果',
      cancelText: '关闭',
      confirmText: '再次发送',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _diagLine('Android 16（API36）', api36 ? '是' : '否'),
          _diagLine('QPR1 晋升位', qpr1 ? '支持' : '不支持（16.0）'),
          _diagLine('通知可晋升', promotable ? '是' : '否'),
          _diagLine('用户总开关', canPost ? '已开启' : '未开启'),
          const SizedBox(height: 10),
          MiuixText(advice, fontSize: 12),
        ],
      ),
    ).then((bool? again) {
      if (again == true && mounted) _triggerLiveTest();
    });
  }

  /// 清除实验室 Beta 发出的测试通知
  Future<void> _clearFocusTest() async {
    try {
      await NativeBridge.cancelNotification(AppConstants.notifyIdFocusTest);
      await NativeBridge.cancelNotification(AppConstants.notifyIdLive);
      if (mounted) AppSnackbar.show('测试通知已清除');
    } catch (e) {
      if (mounted) AppSnackbar.show('清除失败：$e');
    }
  }
}
