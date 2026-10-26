import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../data/models/receipt.dart';

/// 删除收据确认弹窗（miuix 风格）。返回 true = 用户确认删除。
Future<bool> confirmDeleteReceipt(BuildContext context, Receipt receipt) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) {
      return MiuixOverlayDialog(
        show: true,
        renderInRootScaffold: false,
        title: '删除收据',
        summary: '${receipt.no}\n删除后可随时按同账期重新生成',
        onDismissRequest: () => Navigator.of(ctx).pop(false),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _DialogBtn(
                  '取消',
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DialogBtn(
                  '删除',
                  danger: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).then((bool? v) => v ?? false);
}

class _DialogBtn extends StatelessWidget {
  const _DialogBtn(this.label, {this.danger = false, required this.onTap});

  final String label;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final Color color = danger ? c.error : c.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: MiuixText(label,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: color),
      ),
    );
  }
}
