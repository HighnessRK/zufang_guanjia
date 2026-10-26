import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/utils/date_util.dart';
import '../../data/repository/payment_repository.dart';
import '../../services/data_bus.dart';
import '../widgets/app_widgets.dart';

/// 【v1.1.3 · 租金报表】按起止日期汇总区间内房租、水费、电费的
/// 应收 / 实收 / 欠费。
///
/// 口径：起止日期映射到所在**账期（yyyy-MM）**，统计区间内所有账期流水；
/// 预设一键切「本月 / 近3月 / 近6月 / 近1年」，也可手动选起止日期。
/// 入口：收款页「更多工具」。
class FeeReportPage extends StatefulWidget {
  const FeeReportPage({super.key});

  @override
  State<FeeReportPage> createState() => _FeeReportPageState();
}

class _FeeReportPageState extends State<FeeReportPage> {
  static const Color _kGreen = Color(0xFF34C759);
  static const Color _kOrange = Color(0xFFFF9500);

  DateTime _from = _presetFrom(6);
  DateTime _to = DateTime.now();

  List<FeeTypeSum> _rows = <FeeTypeSum>[];
  bool _loading = true;

  /// 近 N 个月的起点（N=1 即本月）：N 个月前的 1 日
  static DateTime _presetFrom(int months) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month - (months - 1), 1);
  }

  @override
  void initState() {
    super.initState();
    _load();
    DataBus.instance.addListener(_onDataBus);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataBus);
    super.dispose();
  }

  /// MCP / 收款改动后回到本页立即重算
  void _onDataBus() {
    if (mounted) _load();
  }

  int _loadId = 0;

  Future<void> _load() async {
    final int id = ++_loadId;
    final List<FeeTypeSum> rows = await PaymentRepository.instance
        .sumByTypeRange(DateUtil.period(_from), DateUtil.period(_to));
    if (!mounted || id != _loadId) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  int get _totalDue => _rows.fold<int>(0, (int s, FeeTypeSum r) => s + r.due);

  int get _totalPaid => _rows.fold<int>(0, (int s, FeeTypeSum r) => s + r.paid);

  int get _totalDebt => _rows.fold<int>(0, (int s, FeeTypeSum r) => s + r.debt);

  int get _totalCount => _rows.fold<int>(0, (int s, FeeTypeSum r) => s + r.count);

  /// 预设是否正生效（from 精确到月、to 精确到日全部命中）
  bool _presetActive(int months) {
    final DateTime f = _presetFrom(months);
    final DateTime now = DateTime.now();
    return _from.year == f.year &&
        _from.month == f.month &&
        _to.year == now.year &&
        _to.month == now.month &&
        _to.day == now.day;
  }

  void _applyPreset(int months) {
    setState(() {
      _from = _presetFrom(months);
      _to = DateTime.now();
      _loading = true;
    });
    _load();
  }

  Future<void> _pick(bool isFrom) async {
    final DateTime? d = await showDatePickDialog(
      context,
      title: isFrom ? '开始日期' : '结束日期',
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099, 12, 31),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = d;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = d;
        if (_to.isBefore(_from)) _from = _to;
      }
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final String fromP = DateUtil.period(_from);
    final String toP = DateUtil.period(_to);
    final int months = DateUtil.monthsBetween(fromP, toP) + 1;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '租金报表',
        subtitle: '账期 $fromP ~ $toP',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
            children: <Widget>[
              _buildRangeCard(c),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: MiuixCircularProgressIndicator()),
                )
              else if (_rows.isEmpty) ...<Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: EmptyView(
                    '该区间暂无费用流水',
                    icon: Icons.receipt_long_rounded,
                    hint: '换个区间试试；房租与水电收缴后会自动生成流水',
                  ),
                ),
              ]
              else ...<Widget>[
                _buildSummary(c, months),
                const SizedBox(height: 12),
                const SectionTitle('分类明细'),
                _buildTable(c),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 统计区间：预设快捷 + 起止日期
  Widget _buildRangeCard(MiuixColors c) {
    const List<int> presets = <int>[1, 3, 6, 12];
    const List<String> labels = <String>['本月', '近3月', '近6月', '近1年'];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      borderRadius: 20,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < presets.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  _chip(
                    c,
                    labels[i],
                    active: _presetActive(presets[i]),
                    onTap: () => _applyPreset(presets[i]),
                  ),
                ],
              ],
            ),
          ),
          const MiuixHorizontalDivider(),
          MiuixArrowPreference(
            title: '开始日期',
            summary: DateUtil.format(_from),
            onClick: () => _pick(true),
          ),
          const MiuixHorizontalDivider(),
          MiuixArrowPreference(
            title: '结束日期',
            summary: DateUtil.format(_to),
            onClick: () => _pick(false),
          ),
        ],
      ),
    );
  }

  Widget _chip(MiuixColors c, String label,
      {required bool active, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? c.primary.withValues(alpha: 0.14)
                : c.surfaceContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active
                  ? c.primary.withValues(alpha: 0.45)
                  : c.outline.withValues(alpha: 0.5),
            ),
          ),
          child: MiuixText(
            label,
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? c.primary : c.onSurfaceSecondary,
          ),
        ),
      ),
    );
  }

  /// 区间汇总：应收 / 实收 / 欠费 三列 + 口径说明
  Widget _buildSummary(MiuixColors c, int months) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _sumCol(c, '应收', _money(_totalDue), c.onSurface),
              ),
              Expanded(
                child: _sumCol(c, '实收', _money(_totalPaid), _kGreen),
              ),
              Expanded(
                child: _sumCol(
                  c,
                  '欠费',
                  _money(_totalDebt),
                  _totalDebt > 0 ? _kOrange : c.onSurfaceVariantSummary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MiuixText(
            '共 $months 个账期 · $_totalCount 笔流水 · 按账期（月份）口径统计',
            fontSize: 11.5,
            color: c.onSurfaceVariantSummary,
          ),
        ],
      ),
    );
  }

  Widget _sumCol(MiuixColors c, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MiuixText(label, fontSize: 12, color: c.onSurfaceVariantSummary),
        const SizedBox(height: 4),
        MiuixText(value, fontSize: 19, fontWeight: FontWeight.w700,
            color: color),
      ],
    );
  }

  /// 分类明细表：类型 | 应收 | 实收 | 欠费 + 总计行
  Widget _buildTable(MiuixColors c) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: <Widget>[
          _tableRow(
            c,
            <String>['类型', '应收', '实收', '欠费'],
            header: true,
          ),
          const SizedBox(height: 4),
          for (int i = 0; i < _rows.length; i++) ...<Widget>[
            if (i > 0) const MiuixHorizontalDivider(),
            _tableRow(
              c,
              <String>[
                '',
                _money(_rows[i].due),
                _money(_rows[i].paid),
                _money(_rows[i].debt),
              ],
              type: _rows[i],
            ),
          ],
          const MiuixHorizontalDivider(),
          _tableRow(
            c,
            <String>['', _money(_totalDue), _money(_totalPaid),
              _money(_totalDebt)],
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _tableRow(
    MiuixColors c,
    List<String> cells, {
    bool header = false,
    bool bold = false,
    FeeTypeSum? type,
  }) {
    final TextStyle? head = header
        ? TextStyle(fontSize: 12, color: c.onSurfaceVariantSummary)
        : null;
    final Color debtColor = !header && !bold && _totalDebt > 0 && cells[3] != '¥0'
        ? _kOrange
        : (header || bold ? c.onSurface : c.onSurfaceSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: type == null
                ? (header
                    ? MiuixText(cells[0], style: head)
                    : bold
                        ? const MiuixText('合计',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)
                        : const SizedBox.shrink())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      MiuixText(type.label,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600),
                      MiuixText('${type.count} 笔 · ${type.rooms} 间',
                          fontSize: 11,
                          color: c.onSurfaceVariantSummary),
                    ],
                  ),
          ),
          Expanded(
            flex: 2,
            child: _num(cells[1],
                header: header,
                bold: bold,
                color: header ? c.onSurfaceVariantSummary : c.onSurfaceSecondary),
          ),
          Expanded(
            flex: 2,
            child: _num(cells[2],
                header: header,
                bold: bold,
                color: header
                    ? c.onSurfaceVariantSummary
                    : (bold ? _kGreen : c.onSurfaceSecondary)),
          ),
          Expanded(
            flex: 2,
            child: _num(cells[3], header: header, bold: bold, color: debtColor),
          ),
        ],
      ),
    );
  }

  Widget _num(String text,
      {required bool header, required bool bold, required Color color}) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: header ? 12 : (bold ? 14.5 : 13.5),
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: color,
      ),
    );
  }

  /// 千分位金额
  static String _money(int v) {
    final String s = v.abs().toString();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write(',');
      }
      buf.write(s[i]);
    }
    return v < 0 ? '-¥$buf' : '¥$buf';
  }
}
