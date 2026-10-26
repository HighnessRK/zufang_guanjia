import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/room_repository.dart';
import '../widgets/app_widgets.dart';
import 'settings_edit.dart';

/// 设置 · 计费参数：水电单价（抄表自动计费）+ 缴费周期
/// （房租年付 / 水季付 / 电智能夏季月付·其余季付，均可调）。
class BillingSettingsPage extends StatefulWidget {
  const BillingSettingsPage({super.key});

  @override
  State<BillingSettingsPage> createState() => _BillingSettingsPageState();
}

class _BillingSettingsPageState extends State<BillingSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '计费参数',
        subtitle: '水电单价 · 统一收缴日历',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
              20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
          children: <Widget>[
            const SectionTitle('水电单价'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixArrowPreference(
                    title: '水费单价',
                    summary: '${trimNumber(cfg.waterPrice)} 元/吨',
                    onClick: () => editNumberDialog(
                        context, '水费单价', '元/吨', cfg.waterPrice,
                        (double v) async {
                      await cfg.update(waterPrice: v);
                      _refresh();
                    }),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '电费单价',
                    summary: '${trimNumber(cfg.elecPrice)} 元/度',
                    onClick: () => editNumberDialog(
                        context, '电费单价', '元/度', cfg.elecPrice,
                        (double v) async {
                      await cfg.update(elecPrice: v);
                      _refresh();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MiuixText(
              '修改后立即生效：抄表页按新单价自动计算水电费，已生成的历史账单不受影响。',
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),
            const SizedBox(height: 20),
            const SectionTitle('缴费周期'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixArrowPreference(
                    title: '房租缴费周期',
                    summary: AppConfig.cycleLabel(cfg.rentCycle),
                    onClick: () async {
                      final int? v = await _pickOption<int>(
                        context,
                        '房租缴费周期',
                        cfg.rentCycle,
                        const <MapEntry<int, String>>[
                          MapEntry<int, String>(1, '月付'),
                          MapEntry<int, String>(3, '季付'),
                          MapEntry<int, String>(6, '半年付'),
                          MapEntry<int, String>(12, '年付'),
                        ],
                      );
                      if (v != null) {
                        await cfg.update(rentCycle: v);
                        _refresh();
                      }
                    },
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '收水间隔',
                    summary: AppConfig.cycleLabel(cfg.waterCycle),
                    onClick: () async {
                      final int? v = await _pickOption<int>(
                        context,
                        '收水间隔（时间间隔）',
                        cfg.waterCycle,
                        const <MapEntry<int, String>>[
                          MapEntry<int, String>(1, '月付'),
                          MapEntry<int, String>(3, '季付'),
                          MapEntry<int, String>(12, '年付'),
                        ],
                      );
                      if (v != null) {
                        await cfg.update(waterCycle: v);
                        _refresh();
                      }
                    },
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '收电间隔',
                    summary: cfg.elecCycleLabel,
                    onClick: () async {
                      final int? v = await _pickOption<int>(
                        context,
                        '收电间隔（时间间隔）',
                        cfg.elecCycle,
                        const <MapEntry<int, String>>[
                          MapEntry<int, String>(
                              0, '智能（夏季月付 · 其余季付）'),
                          MapEntry<int, String>(1, '月付'),
                          MapEntry<int, String>(3, '季付'),
                          MapEntry<int, String>(12, '年付'),
                        ],
                      );
                      if (v != null) {
                        await cfg.update(elecCycle: v);
                        _refresh();
                      }
                    },
                  ),
                  if (cfg.elecCycle == 0) ...<Widget>[
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '夏季月份范围',
                      summary: '${cfg.summerStart} 月 — ${cfg.summerEnd} 月',
                      onClick: () => _pickSummer(context),
                    ),
                  ],
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '收水日期',
                    summary: cfg.waterCollectDate,
                    onClick: () => _pickCollectDate('water'),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '收电日期',
                    // 【v1.1.3】默认跟随收水日期：只读展示跟随结果；打开
                    // 下方独立开关后恢复单独选择
                    summary: cfg.elecDateIndependent
                        ? cfg.elecCollectDate
                        : '跟随收水日期（${cfg.waterCollectDate}）',
                    onClick: cfg.elecDateIndependent
                        ? () => _pickCollectDate('elec')
                        : () => AppSnackbar.show(
                            '已跟随收水日期；打开下方「收电日期独立设置」可单独选'),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixBasicComponent(
                    title: '收电日期独立设置',
                    summary: cfg.elecDateIndependent
                        ? '已开启：收电日期单独选择，不随收水日期变化'
                        : '默认跟随：收电日期与收水日期保持一致',
                    onClick: () =>
                        _toggleElecIndependent(!cfg.elecDateIndependent),
                    endActions: <Widget>[
                      MiuixSwitch(
                        value: cfg.elecDateIndependent,
                        onChanged: _toggleElecIndependent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionTitle('房间'),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  MiuixBasicComponent(
                    title: '到期日期自动顺延一年',
                    summary: cfg.autoExpire
                        ? '改入住日期时，到期日期自动算成「入住 + 1 年」'
                        : '已关闭：到期日期完全手动填写',
                    onClick: () => cfg.update(autoExpire: !cfg.autoExpire),
                    endActions: <Widget>[
                      MiuixSwitch(
                        value: cfg.autoExpire,
                        onChanged: (bool v) => cfg.update(autoExpire: v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MiuixText(
              '房租应收 = 月租 × 周期月数（年付即一次收 12 个月）；'
              '水电费全楼层统一收：到达收水/收电日期后，'
              '所有房间的累计额同期一起应收，之后按间隔逐期推进。'
              '修改后立即按新日历重算，已生成的流水不受影响。',
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        );
      },
    );
  }

  /// 通用单选弹窗（选项 → 值）：委托给共享的 [showOptionPicker]，
  /// 与房间编辑页「房型」选择为同一套 HyperOS 列表样式。
  Future<T?> _pickOption<T>(
    BuildContext context,
    String title,
    T current,
    List<MapEntry<T, String>> options,
  ) {
    return showOptionPicker<T>(
      context,
      title: title,
      current: current,
      options: options,
    );
  }

  /// 夏季月份范围：先选起始月、再选结束月
  Future<void> _pickSummer(BuildContext context) async {
    final AppConfig cfg = AppConfig.instance;
    final int? s = await _pickOption<int>(
        context,
        '夏季起始月',
        cfg.summerStart,
        <MapEntry<int, String>>[
          for (int m = 1; m <= 12; m++) MapEntry<int, String>(m, '$m 月'),
        ]);
    if (s == null || !context.mounted) return;
    final int? e = await _pickOption<int>(
        context,
        '夏季结束月',
        cfg.summerEnd,
        <MapEntry<int, String>>[
          for (int m = 1; m <= 12; m++) MapEntry<int, String>(m, '$m 月'),
        ]);
    if (e == null) return;
    await cfg.update(summerStart: s, summerEnd: e);
    _refresh();
  }

  /// 选择全楼层统一收水 / 收电日期，改完立即按新日历重算应收
  Future<void> _pickCollectDate(String type) async {
    final AppConfig cfg = AppConfig.instance;
    final String cur =
        type == 'water' ? cfg.waterCollectDate : cfg.elecCollectDate;
    final DateTime? picked = await showDatePickDialog(
      context,
      title: type == 'water' ? '统一收水日期' : '统一收电日期',
      initialDate: DateUtil.parse(cur) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099, 12, 31),
    );
    if (picked == null || !mounted) return;
    final String text = DateUtil.format(picked);
    if (type == 'water') {
      await cfg.update(waterCollectDate: text);
    } else {
      await cfg.update(elecCollectDate: text);
    }
    // 立即按新日历重算全楼层应收（幂等，不影响已结清流水）
    final List<Room> rooms = await RoomRepository.instance.all();
    await PaymentRepository.instance.ensureCurrentPeriod(rooms);
    if (mounted) setState(() {});
  }

  /// 【v1.1.3】切换「收电日期独立设置」。关闭 = 电日回到水日，
  /// 立即按新日历重算全楼层应收（幂等，不影响已结清流水）。
  Future<void> _toggleElecIndependent(bool v) async {
    final AppConfig cfg = AppConfig.instance;
    await cfg.update(elecDateIndependent: v);
    final List<Room> rooms = await RoomRepository.instance.all();
    await PaymentRepository.instance.ensureCurrentPeriod(rooms);
    _refresh();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
