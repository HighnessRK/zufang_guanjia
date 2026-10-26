import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../data/models/receipt.dart';
import '../../core/utils/money_caps.dart';

/// 电子收据渲染卡（v1.1.3）：白色纸质样式，所见即所得 —— 预览与导出
/// PNG 用的是同一个 widget，导出像素比 3.0 → 约 960px 宽，微信转发清晰。
///
/// 支持旧版「水电费」合并口径：waterFee/elecFee 均为 0 而 total > 0 时
/// 只展示一行「水电费」。
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.receipt,
    this.width = 312,
  });

  final Receipt receipt;

  /// 卡片宽度（逻辑像素）
  final double width;

  static const Color _ink = Color(0xFF1D1D1F);
  static const Color _sub = Color(0xFF86868B);
  static const Color _hair = Color(0xFFE8E8ED);
  static const Color _accent = Color(0xFF2A6FF3);

  @override
  Widget build(BuildContext context) {
    final Receipt r = receipt;
    // 旧版合并口径：只有总额
    final bool merged = r.waterFee <= 0 && r.elecFee <= 0 && r.total > 0;
    final bool showWater = !merged && (r.waterFee > 0 || (r.waterUse ?? 0) > 0);
    final bool showElec = !merged && (r.elecFee > 0 || (r.elecUse ?? 0) > 0);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ===== 标题区 =====
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF3482FF), Color(0xFF7B5CFF)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 17, color: Colors.white),
              ),
              const SizedBox(width: 9),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MiuixText('水电费收据',
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: _ink),
                  MiuixText('电子收据',
                      fontSize: 10, color: _sub),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _divider(),
          const SizedBox(height: 10),

          // ===== 抬头信息 =====
          _kv('收据编号', r.no),
          _kv('房    号', r.roomNo),
          if (r.tenant.isNotEmpty) _kv('租    户', r.tenant),
          _kv('账    期', r.period),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // ===== 费用明细 =====
          // 乘式仅在用量 > 0 时展示：欠费/固定金额等场景用量可能为 0，
          // 显示「0 吨 × 6 元/吨」会与右侧金额自相矛盾，此时只显示金额。
          if (merged) ...<Widget>[
            _line('水电费', '', right: _money(r.total)),
          ] else ...<Widget>[
            if (showWater) _meterDetail('水费', '吨', r.waterPrev,
                r.waterCurr, r.waterUse, r.waterPrice, r.waterFee),
            if (showElec) _meterDetail('电费', '度', r.elecPrev,
                r.elecCurr, r.elecUse, r.elecPrice, r.elecFee),
          ],
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // ===== 合计 =====
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              const MiuixText('合计金额',
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
              const Spacer(),
              MiuixText(_money(r.total),
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _accent),
            ],
          ),
          const SizedBox(height: 8),
          _kv('金额大写', MoneyCaps.from(r.total)),
          const SizedBox(height: 12),
          _divider(),
          const SizedBox(height: 8),

          // ===== 页脚 =====
          _kv('生成时间', r.createdAt, small: true),
          if (r.note.isNotEmpty) _kv('备    注', r.note, small: true),
          const SizedBox(height: 8),
          const Center(
            child: MiuixText('仅作水电费收缴凭证',
                fontSize: 9.5, color: _sub),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: _hair);

  Widget _meterDetail(String label, String unit, int? prev, int? curr,
      int? use, double? price, int fee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _line(label, '', right: _money(fee)),
        _kv('上期读数', prev == null ? '未留存' : '$prev $unit', small: true),
        _kv('本期读数', curr == null ? '未留存' : '$curr $unit', small: true),
        _kv('本期用量', use == null ? '未留存' : '$use $unit', small: true),
        _kv('单    价', price == null ? '未留存' : '${_num(price)} 元/$unit',
            small: true),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _kv(String k, String v, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 62,
            child: MiuixText(k,
                fontSize: small ? 10.5 : 11.5,
                fontWeight: FontWeight.w500,
                color: _sub),
          ),
          Expanded(
            child: MiuixText(v,
                fontSize: small ? 11 : 12.5,
                fontWeight: FontWeight.w600,
                color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String sub, {String? right}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          MiuixText(label,
              fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
          const SizedBox(width: 8),
          if (sub.isNotEmpty)
            Expanded(
              child: MiuixText(sub, fontSize: 10.5, color: _sub),
            )
          else
            const Spacer(),
          MiuixText(right ?? '',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink),
        ],
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

  /// 单价：整数不带小数，小数保留两位内
  static String _num(double v) {
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2);
  }
}
