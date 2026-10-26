import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/notice_item.dart';
import '../../services/data_bus.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_engine.dart';
import '../notification/notification_center_page.dart';
import '../receipt/receipt_list_page.dart';
import '../rooms/room_edit_page.dart';
import '../shell/app_shell.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';

/// 首页：液态玻璃风格 —— 极光背景 + 毛玻璃卡片。
///   收款进度主卡 + 统计小卡 + 到期提醒 + 收支明细 + 快捷入口。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 顶栏折叠行为：上滑时大标题平滑收起，避让右上角操作按钮
  final MiuixExitUntilCollapsedScrollBehavior _appBarBehavior =
      miuixScrollBehavior();

  /// 首页统计
  HomeStat? _stat;

  /// 待办提醒
  List<NoticeItem> _notices = <NoticeItem>[];

  bool _loading = true;

  /// 外壳当前 Tab 索引；切回首页 Tab 时刷新数据
  ValueListenable<int>? _tabIndex;

  @override
  void initState() {
    super.initState();
    _load();
    // MCP / 其它入口改动数据后立刻刷新（详见 [DataBus]）
    DataBus.instance.addListener(_onDataBus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueListenable<int> index = AppShellScope.of(context).selectedIndex;
    if (!identical(_tabIndex, index)) {
      _tabIndex?.removeListener(_onTabChanged);
      _tabIndex = index;
      _tabIndex!.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataBus);
    _tabIndex?.removeListener(_onTabChanged);
    super.dispose();
  }

  /// 从其它 Tab 切回首页时重新拉取统计与提醒
  /// （原先由 push 返回后的 `.then((_) => _load())` 承担）
  void _onTabChanged() {
    if (_tabIndex?.value == 0 && mounted) _load();
  }

  /// MCP 写操作 / 跨页改动 → 首页统计与提醒立即重算
  void _onDataBus() {
    if (mounted) _load();
  }

  /// 拉取数据：统计 + 提醒，并同步刷新三端通知
  ///
  /// 【v1.1.2 优化】首次进入才转圈；切回本 Tab / 数据总线通知时**静默**刷新。
  /// 旧实现每次都先 `setState(_loading = true)` 把整页换成转圈动画，切 Tab
  /// 时既白闪一下又白白重建整页（用户报的「切换界面偶现卡顿」来源之一）。
  int _loadId = 0;

  Future<void> _load({bool showLoading = false}) async {
    final int id = ++_loadId;
    if (showLoading && mounted) setState(() => _loading = true);
    final HomeStat stat = await ReminderEngine.computeHomeStat();
    await NotificationService.instance.refresh();
    if (!mounted || id != _loadId) return;
    setState(() {
      _stat = stat;
      _notices = NotificationService.instance.notices.value;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return AuroraScaffold(
      topBar: MiuixTopAppBar(
        scrollBehavior: _appBarBehavior,
        color: Colors.transparent,
        title: AppConstants.appName,
        subtitle: DateUtil.format(DateTime.now()),
        actions: <Widget>[
          // 通知中心入口（带未读角标）
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (BuildContext context, int unread, Widget? child) {
              return MiuixIconButton(
                onPressed: _openNotificationCenter,
                child: MiuixBadgedBox(
                  badge: unread > 0
                      ? MiuixBadge(
                          child: MiuixText(unread > 99 ? '99+' : '$unread'),
                        )
                      : const SizedBox.shrink(),
                  child: MiuixIcon(
                    icon: Icons.notifications_none_rounded,
                    size: 24,
                    tint: c.onSurface,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        if (_loading) {
          return Padding(
            padding: padding,
            child: const Center(child: MiuixCircularProgressIndicator()),
          );
        }
        // 极光背景已由 AuroraScaffold 铺满整页（含顶栏区），此处直接放内容
        // MiuixScrollBehaviorListener：把列表滚动桥接给顶栏（大标题折叠）
        return MiuixScrollBehaviorListener(
          behavior: _appBarBehavior,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                padding.top + 8,
                20,
                kGlassNavClearance + padding.bottom,
              ),
              children: <Widget>[
                _buildHeroCard(c),
                const SizedBox(height: 12),
                _buildStatRow(c),
                const SizedBox(height: 4),
                const SectionTitle('待办提醒'),
                _buildRemindCard(c),
                const SizedBox(height: 8),
                _buildMonthCard(c),
                const SectionTitle('快捷入口'),
                const SizedBox(height: 2),
                _buildQuickEntries(c),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部玻璃主卡：本期收款进度（大数字 + 渐变进度条 + 收尾状态）
  Widget _buildHeroCard(MiuixColors c) {
    final HomeStat s = _stat!;
    final int due = s.monthDue;
    final int paid = s.monthPaid;
    final int pct = due > 0 ? (paid * 100 / due).round().clamp(0, 100) : 0;
    final int debt = s.monthDebt;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const GradientIconBox(
                icon: Icons.account_balance_wallet_rounded,
                colors: <Color>[Color(0xFF3482FF), Color(0xFF7B5CFF)],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MiuixText(
                      '本期收款进度',
                      fontSize: 12,
                      color: c.onSurfaceVariantSummary,
                    ),
                    const SizedBox(height: 2),
                    MiuixText(
                      '账期 ${s.period}',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.onSurfaceContainer,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: GradientButton.kGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF7B5CFF).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: MiuixText(
                  due > 0 ? '$pct%' : '—',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              MiuixText(
                '¥$paid',
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: c.onSurfaceContainer,
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: MiuixText(
                  '/ 应收 ¥$due',
                  fontSize: 14,
                  color: c.onSurfaceVariantSummary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 蓝 → 紫 → 粉 渐变进度条
          SizedBox(
            height: 12,
            width: double.infinity,
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: c.onSurfaceVariantSummary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: GradientButton.kGradient,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color:
                              const Color(0xFF3482FF).withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              MiuixText(
                debt > 0 ? '未收 ¥$debt' : '本期已全部收齐',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: debt > 0 ? c.error : const Color(0xFF34C759),
              ),
              const Spacer(),
              MiuixText(
                '共 ${s.totalRooms} 间 · 在租 ${s.occupiedRooms} 间',
                fontSize: 12,
                color: c.onSurfaceVariantSummary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 统计小卡（玻璃）：房间总数 / 在租空置
  Widget _buildStatRow(MiuixColors c) {
    final HomeStat s = _stat!;
    return Row(
      children: <Widget>[
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 20,
            onPressed: _openRooms,
            child: Row(
              children: <Widget>[
                const GradientIconBox(
                  icon: Icons.meeting_room_rounded,
                  colors: <Color>[Color(0xFF3482FF), Color(0xFF5AC8FA)],
                  size: 38,
                  radius: 12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MiuixText(
                        '${s.totalRooms}',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.onSurfaceContainer,
                      ),
                      MiuixText(
                        '房间总数',
                        fontSize: 11,
                        color: c.onSurfaceVariantSummary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 20,
            onPressed: _openRooms,
            child: Row(
              children: <Widget>[
                const GradientIconBox(
                  icon: Icons.person_rounded,
                  colors: <Color>[Color(0xFF34C759), Color(0xFF9BE7A6)],
                  size: 38,
                  radius: 12,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MiuixText(
                        '${s.occupiedRooms} / ${s.emptyRooms}',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.onSurfaceContainer,
                      ),
                      MiuixText(
                        '在租 / 空置',
                        fontSize: 11,
                        color: c.onSurfaceVariantSummary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 待办提醒玻璃卡片
  Widget _buildRemindCard(MiuixColors c) {
    final List<NoticeItem> top = _notices.take(3).toList();
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      borderRadius: 22,
      child: Column(
        children: <Widget>[
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 34, 22, 34),
              child: EmptyView(
                '暂无待办提醒，一切正常',
                icon: Icons.verified_rounded,
                hint: '房租水电未缴、租期临近到期时会自动出现在这里',
              ),
            )
          else
            for (int i = 0; i < top.length; i++) ...<Widget>[
              _buildNoticeRow(top[i], c),
              if (i != top.length - 1) const MiuixHorizontalDivider(),
            ],
          // 收款入口：首页待办卡常驻，房租 / 水费 / 电费一处收齐
          const MiuixHorizontalDivider(),
          MiuixBasicComponent(
            startAction: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    c.primary,
                    Color.lerp(c.primary, Colors.white, 0.45)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            title: '收款',
            summary: '房租 / 水费 / 电费 一处收齐',
            endActions: <Widget>[
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: c.onSurfaceVariantSummary,
              ),
            ],
            onClick: _openCollectPanel,
          ),
          if (_notices.isNotEmpty) ...<Widget>[
            const MiuixHorizontalDivider(),
            MiuixBasicComponent(
              title: '查看全部 ${_notices.length} 条提醒',
              onClick: _openNotificationCenter,
            ),
          ],
        ],
      ),
    );
  }

  /// 单条提醒
  Widget _buildNoticeRow(NoticeItem item, MiuixColors c) {
    final bool danger = item.level == 'danger';
    final Color color = danger ? c.error : const Color(0xFFFF9500);
    return MiuixBasicComponent(
      onClick: _openNotificationCenter,
      startAction: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[color, Color.lerp(color, Colors.white, 0.45)!],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          item.type == 'rent'
              ? Icons.payments_rounded
              : item.type == 'expire'
                  ? Icons.event_busy_rounded
                  : Icons.bolt_rounded,
          size: 18,
          color: Colors.white,
        ),
      ),
      title: item.title,
      summary: item.body,
      endActions: <Widget>[
        StatusTag(item.typeText, color: color),
      ],
    );
  }

  /// 收支明细玻璃卡片
  Widget _buildMonthCard(MiuixColors c) {
    final HomeStat s = _stat!;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const GradientIconBox(
                icon: Icons.donut_small_rounded,
                colors: <Color>[Color(0xFFFF6B9D), Color(0xFFAF52DE)],
                size: 34,
                radius: 11,
              ),
              const SizedBox(width: 10),
              MiuixText(
                '收支明细',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.onSurfaceContainer,
              ),
              const Spacer(),
              StatusTag('账期 ${s.period}', color: c.primary),
            ],
          ),
          const SizedBox(height: 12),
          CalcLine('房租应收', '¥${s.rentDue}'),
          CalcLine('房租实收', '¥${s.rentPaid}'),
          CalcLine('房租未收', '¥${s.rentDebt}'),
          const SizedBox(height: 6),
          const MiuixHorizontalDivider(),
          const SizedBox(height: 6),
          CalcLine('水电费合计', '¥${s.utilityDue}'),
          CalcLine('水电费未收', '¥${s.utilityUnpaid}'),
          const SizedBox(height: 10),
          CalcLine('当前欠费合计', '¥${s.monthDebt}', emphasis: true),
        ],
      ),
    );
  }

  /// 快捷入口（玻璃渐变图标）。
  /// 【v1.1.3】新增「电子收据」后共 6 项：一行 5 项在 400dp 逻辑屏上
  /// 每格仅剩 ~66dp，4 字标签会挤压，改为两行 3+3 等宽平铺。
  Widget _buildQuickEntries(MiuixColors c) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            QuickEntry(
              icon: Icons.add_home_rounded,
              label: '新增房间',
              color: c.primary,
              onTap: _openAddRoom,
            ),
            const SizedBox(width: 8),
            QuickEntry(
              icon: Icons.speed_rounded,
              label: '水电抄表',
              color: const Color(0xFF34C759),
              onTap: _openMeter,
            ),
            const SizedBox(width: 8),
            QuickEntry(
              icon: Icons.receipt_long_rounded,
              label: '房间管理',
              color: const Color(0xFFAF52DE),
              onTap: _openRooms,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            // 收款：与底部导航同序（抄表之后、设置之前）
            QuickEntry(
              icon: Icons.account_balance_wallet_rounded,
              label: '收款',
              color: const Color(0xFFFF9500),
              onTap: _openCollectPanel,
            ),
            const SizedBox(width: 8),
            QuickEntry(
              icon: Icons.request_quote_rounded,
              label: '电子收据',
              color: const Color(0xFF00BFB3),
              onTap: _openReceipt,
            ),
            const SizedBox(width: 8),
            QuickEntry(
              icon: Icons.tune_rounded,
              label: '设置',
              color: const Color(0xFF8E8E93),
              onTap: _openSettings,
            ),
          ],
        ),
      ],
    );
  }

  //========================= 跳转 ============================

  void _openNotificationCenter() {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(
              builder: (BuildContext _) => const NotificationCenterPage()),
        )
        .then((_) => _load());
  }

  /// 对应底部导航 Tab 的快捷入口改为直接切换 Tab，
  /// 不再把 Tab 根页面 push 进首页栈（否则点「首页」回不去）。
  void _openRooms() => AppShellScope.of(context).switchTab(1);

  void _openMeter() => AppShellScope.of(context).switchTab(2);

  /// 收款面板已是底部 Tab（3）：直接切过去，不再 push 二级页
  void _openCollectPanel() => AppShellScope.of(context).switchTab(3);

  void _openSettings() => AppShellScope.of(context).switchTab(4);

  /// 电子收据（v1.1.3）：生成 / 管理水、电收据图片
  void _openReceipt() {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(
              builder: (BuildContext _) => const ReceiptListPage()),
        )
        .then((_) => _load());
  }

  void _openAddRoom() {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(
              builder: (BuildContext _) => const RoomEditPage()),
        )
        .then((_) => _load());
  }
}
