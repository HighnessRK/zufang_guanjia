import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/utils/date_util.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/room_repository.dart';
import '../../services/reminder_engine.dart';
import '../widgets/app_widgets.dart';

/// 缴费统计页：月度收支报表 / 欠费累计 / 结清率 / 房间欠费明细。
class StatPage extends StatefulWidget {
  const StatPage({super.key});

  @override
  State<StatPage> createState() => _StatPageState();
}

class _StatPageState extends State<StatPage> {
  List<StatSummary> _monthly = <StatSummary>[];
  List<Room> _rooms = <Room>[];

  /// 欠费明细口径（payments 周期流水）：
  /// 房租 = 未结清 rent 流水欠款合计；水电 = 未结清流水合计
  Map<String, int> _rentOwed = <String, int>{};
  Map<String, int> _utilOwed = <String, int>{};
  HomeStat? _home;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<StatSummary> monthly =
        await PaymentRepository.instance.monthlyReport(6);
    final List<Room> rooms = await RoomRepository.instance.all();
    final HomeStat home = await ReminderEngine.computeHomeStat();
    final Map<String, int> rentOwed =
        await PaymentRepository.instance.unsettledRentByRoom();
    final Map<String, int> utilOwed =
        await PaymentRepository.instance.unsettledUtilityByRoom();
    if (!mounted) return;
    setState(() {
      _monthly = monthly;
      _rooms = rooms;
      _home = home;
      _rentOwed = rentOwed;
      _utilOwed = utilOwed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '缴费统计',
        subtitle: '账期 ${DateUtil.currentPeriod}',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        if (_loading) {
          return Padding(
            padding: padding,
            child: const Center(child: MiuixCircularProgressIndicator()),
          );
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
            children: <Widget>[
              _buildOverview(c),
              const SizedBox(height: 12),
              _buildMonthly(c),
              const SizedBox(height: 12),
              _buildRoomDebt(c),
            ],
          ),
        );
      },
    );
  }

  /// 本期总览
  Widget _buildOverview(MiuixColors c) {
    final HomeStat h = _home!;
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MiuixText('本期总览', fontSize: 16, fontWeight: FontWeight.w700),
          const SizedBox(height: 10),
          CalcLine('应收合计', '¥${h.monthDue}'),
          CalcLine('实收合计', '¥${h.monthPaid}'),
          CalcLine('欠费合计', '¥${h.monthDebt}', emphasis: true),
          const SizedBox(height: 6),
          const MiuixHorizontalDivider(),
          const SizedBox(height: 6),
          CalcLine('房租未收', '¥${h.rentDebt}'),
          CalcLine('水电费未收', '¥${h.utilityUnpaid}'),
          CalcLine('即将到期房间', '${h.expireSoonRooms} 间'),
        ],
      ),
    );
  }

  /// 近 6 个月月度报表
  Widget _buildMonthly(MiuixColors c) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MiuixText('月度收支报表',
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          for (int i = 0; i < _monthly.length; i++) ...<Widget>[
            MiuixBasicComponent(
              title: _monthly[i].period,
              summary:
                  '应收 ¥${_monthly[i].due} · 实收 ¥${_monthly[i].paid} · 欠 ¥${_monthly[i].debt}',
              endActions: <Widget>[
                StatusTag(
                  _monthly[i].debt == 0 ? '已结清' : '有欠费',
                  color:
                      _monthly[i].debt == 0 ? const Color(0xFF34C759) : c.error,
                ),
              ],
            ),
            if (i != _monthly.length - 1) const MiuixHorizontalDivider(),
          ],
        ],
      ),
    );
  }

  /// 各房间欠费明细（payments 周期口径：存在未结清应收流水即欠费，
  /// 与总览 / 月报 / 待办提醒同源同口径）
  Widget _buildRoomDebt(MiuixColors c) {
    final List<Room> owing = _rooms
        .where((Room r) =>
            _rentOwed.containsKey(r.roomNo) || _utilOwed.containsKey(r.roomNo))
        .toList();

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MiuixText(
                '欠费房间明细（${owing.length} 间）',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (owing.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyView('没有欠费房间，全部结清 🎉', icon: Icons.verified_rounded),
            )
          else
            for (int i = 0; i < owing.length; i++) ...<Widget>[
              MiuixBasicComponent(
                title: owing[i].roomNo,
                summary: owing[i].isOccupied ? owing[i].tenant : '空置',
                endActions: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      if (_rentOwed.containsKey(owing[i].roomNo))
                        StatusTag(
                          '房租欠 ¥${_rentOwed[owing[i].roomNo]}',
                          color: c.error,
                        ),
                      if (_utilOwed.containsKey(owing[i].roomNo)) ...<Widget>[
                        if (_rentOwed.containsKey(owing[i].roomNo))
                          const SizedBox(height: 4),
                        StatusTag(
                          '水电欠 ¥${_utilOwed[owing[i].roomNo]}',
                          color: const Color(0xFFFF9500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (i != owing.length - 1) const MiuixHorizontalDivider(),
            ],
        ],
      ),
    );
  }
}
