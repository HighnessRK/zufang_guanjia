import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/room_repository.dart';
import '../../services/data_bus.dart';
import '../shell/app_shell.dart';
import '../widgets/app_widgets.dart';

/// 底部导航「收款」Tab 根页面：把散落在各房间详情/编辑页里的收款动作
/// 集中到一页。
///
/// 顶部卡片汇总「房租欠款 / 水费待收 / 电费待收」三项，下方逐房间列出
/// 待收项，每项直接点「收款」即可入账，不必再一间间点进详情页。
/// 收款动作复用与编辑页完全相同的账期引擎（房租 / 水 / 电）。
class CollectPanelPage extends StatefulWidget {
  const CollectPanelPage({super.key});

  @override
  State<CollectPanelPage> createState() => _CollectPanelPageState();
}

class _CollectPanelPageState extends State<CollectPanelPage> {
  final MiuixExitUntilCollapsedScrollBehavior _appBarBehavior =
      miuixScrollBehavior();

  List<Room> _all = <Room>[];
  bool _loading = true;

  /// 房租欠款：roomNo → 未收合计（未结清 rent 流水 due−paid）
  Map<String, int> _rentOwed = <String, int>{};

  /// 水费 / 电费待收：roomNo → 未结清水电流水 due−paid
  Map<String, int> _utilOwed = <String, int>{};

  /// 每房水费 / 电费周期累计额（结算整额入账用）
  Map<String, int> _waterAccrued = <String, int>{};
  Map<String, int> _elecAccrued = <String, int>{};

  /// 正在收款的项（"roomNo:payType"），禁用对应按钮防重复点击
  final Set<String> _busy = <String>{};

  /// 感知底部 Tab 切换（切回本 Tab 时重新拉取待收）
  ValueListenable<int>? _tabIndex;

  /// 本页在底部导航中的索引
  static const int _tab = 3;

  @override
  void initState() {
    super.initState();
    _load();
    // MCP / 其它入口改收款后立刻刷新（本页无输入框，可放心重建）
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

  /// 从其它 Tab 切回收款页时重新拉取（别处收款/编辑会改变欠款）
  void _onTabChanged() {
    if (_tabIndex?.value == _tab && mounted) _load();
  }

  /// MCP 写操作（收款 / 改房 / 改设置）→ 欠款立即重算
  void _onDataBus() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final List<Room> list = await RoomRepository.instance.all();
    final Map<String, int> rentOwed =
        await PaymentRepository.instance.unsettledRentByRoom();
    final Map<String, int> utilOwed =
        await PaymentRepository.instance.unsettledUtilityByRoom();
    if (!mounted) return;
    setState(() {
      _all = list;
      _rentOwed = rentOwed;
      _utilOwed = utilOwed;
      _waterAccrued = <String, int>{
        for (final Room r in list) r.roomNo: r.waterFee,
      };
      _elecAccrued = <String, int>{
        for (final Room r in list) r.roomNo: r.elecFee,
      };
      _loading = false;
    });
  }

  /// 逐房间展开的待收项（房租 / 水费 / 电费，每项一个收款入口）
  List<_CollectItem> _items() {
    final List<_CollectItem> out = <_CollectItem>[];
    for (final Room r in _all) {
      final int rent = _rentOwed[r.roomNo] ?? 0;
      final int util = _utilOwed[r.roomNo] ?? 0;
      if (rent > 0) {
        out.add(_CollectItem(
          roomNo: r.roomNo,
          tenant: r.tenant,
          payType: AppConstants.payTypeRent,
          label: '房租欠款',
          amount: rent,
        ));
      }
      if (util > 0) {
        out.add(_CollectItem(
          roomNo: r.roomNo,
          tenant: r.tenant,
          payType: AppConstants.payTypeUtility,
          label: '水电待收',
          amount: util,
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final List<_CollectItem> items = _items();
    final int rentTotal = _rentOwed.values.fold(0, (int a, int b) => a + b);
    final int utilTotal = _utilOwed.values.fold(0, (int a, int b) => a + b);

    return AuroraScaffold(
      topBar: MiuixTopAppBar(
        scrollBehavior: _appBarBehavior,
        color: Colors.transparent,
        title: '收款',
        subtitle: '房租 · 水费 · 电费 一处收齐',
        actions: <Widget>[
          MiuixIconButton(
            onPressed: _load,
            child: const MiuixIcon(icon: Icons.refresh_rounded),
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
                _buildSummaryCard(rentTotal, utilTotal, c),
                const SizedBox(height: 16),
                const SectionTitle('待收明细'),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyView(
                      '全部收齐，暂无待收',
                      icon: Icons.verified_rounded,
                      hint: '房租欠款与到期水电费会自动汇总到这里',
                    ),
                  )
                else
                  for (int i = 0; i < items.length; i++) ...<Widget>[
                    _buildItemCard(items[i], c),
                    if (i != items.length - 1) const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部汇总卡：三项待收总额 + 一句话说明
  Widget _buildSummaryCard(int rentTotal, int utilTotal, MiuixColors c) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MiuixText('待收合计',
              fontSize: 13, color: c.onSurfaceVariantSummary),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _SumBlock('房租', rentTotal, c.error),
              const SizedBox(width: 12),
              _SumBlock('水电', utilTotal, const Color(0xFFFF9500)),
            ],
          ),
          const SizedBox(height: 12),
          MiuixText(
            '点任意一项右侧「收款」即入账，无需进入房间详情。',
            fontSize: 11,
            color: c.onSurfaceVariantSummary,
          ),
        ],
      ),
    );
  }

  /// 单条待收项卡片：房间 + 类型 + 金额 + 收款按钮
  Widget _buildItemCard(_CollectItem item, MiuixColors c) {
    final bool busy = _busy.contains(item.key);
    final bool isRent = item.payType == AppConstants.payTypeRent;
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isRent ? c.error : const Color(0xFFFF9500))
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRent ? Icons.home_work_rounded : Icons.bolt_rounded,
              size: 20,
              color: isRent ? c.error : const Color(0xFFFF9500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MiuixText(
                  '${item.roomNo} · ${item.label}',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                if (item.tenant.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  MiuixText(
                    item.tenant,
                    fontSize: 12,
                    color: c.onSurfaceVariantSummary,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          GradientButton(
            label: busy ? '收款中…' : '收款 ¥${item.amount}',
            compact: true,
            enabled: !busy,
            onPressed: () => _collect(item),
          ),
        ],
      ),
    );
  }

  /// 收款：确认弹窗 → 走账期引擎入账 → 刷新
  Future<void> _collect(_CollectItem item) async {
    final bool isRent = item.payType == AppConstants.payTypeRent;
    final String label = isRent ? '房租' : '水电费';
    final AppConfig cfg = AppConfig.instance;
    final bool? ok = await showAppDialog(
      context,
      title: '收$label · ${item.roomNo}',
      summary: isRent
          ? '本次收款 ¥${item.amount}（${AppConfig.cycleLabel(cfg.rentCycle)}口径）。'
              '\n收满本期应收将自动结清该笔房租流水。'
          : '本次收取水电费 ¥${item.amount}，收清后该房水电转入下一周期。',
      confirmText: '确认收款 ¥${item.amount}',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(item.key));
    try {
      if (isRent) {
        // 房租：本次收款额作为增量入账，收满本期欠额即自动结清
        await PaymentRepository.instance
            .collectRent(item.roomNo, item.amount);
      } else {
        // 水电：按房间当前水/电累计额分别整额结清
        // （各自累计清零 + 该表读数滚动进下一周期）
        final int w = _waterAccrued[item.roomNo] ?? 0;
        final int e = _elecAccrued[item.roomNo] ?? 0;
        if (w > 0) {
          await PaymentRepository.instance.settleUtility(
              item.roomNo, AppConstants.payTypeWater, w);
        }
        if (e > 0) {
          await PaymentRepository.instance.settleUtility(
              item.roomNo, AppConstants.payTypeElec, e);
        }
      }
      await _load();
      if (!mounted) return;
      AppSnackbar.show('已收$label ¥${item.amount}（${item.roomNo}）');
    } finally {
      if (mounted) setState(() => _busy.remove(item.key));
    }
  }
}

/// 待收项：某房间某类费用的一笔待收款
class _CollectItem {
  const _CollectItem({
    required this.roomNo,
    required this.tenant,
    required this.payType,
    required this.label,
    required this.amount,
  });

  final String roomNo;
  final String tenant;
  final String payType;
  final String label;
  final int amount;

  /// 唯一键，用于「收款中」状态标记
  String get key => '$roomNo:$payType';
}

/// 汇总卡里的一个金额块
class _SumBlock extends StatelessWidget {
  const _SumBlock(this.label, this.amount, this.color);

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            MiuixText(label,
                fontSize: 12, color: c.onSurfaceVariantSummary),
            const SizedBox(height: 4),
            MiuixText(
              '¥$amount',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: amount > 0 ? color : c.onSurfaceVariantSummary,
            ),
          ],
        ),
      ),
    );
  }
}
