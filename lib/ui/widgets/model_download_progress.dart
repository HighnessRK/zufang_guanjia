import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'app_palette.dart';

/// Overall bytes for the model and projector; transport segments stay secondary.
class ModelDownloadProgress extends StatelessWidget {
  const ModelDownloadProgress(
      {super.key,
      required this.received,
      required this.total,
      this.detail = '',
      this.verifying = false,
      this.label = '总下载进度'});
  final int received, total;
  final String detail, label;
  final bool verifying;

  static String formatBytes(int bytes) => bytes >= 1000000000
      ? '${(bytes / 1000000000).toStringAsFixed(2)} GB'
      : '${(bytes / 1000000).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final c = MiuixTheme.of(context).colors;
    final palette = AppPalette.of(context);
    final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    final percent =
        total > 0 ? '${(progress * 100).toStringAsFixed(1)}%' : '准备中';
    return Semantics(
        label: '模型总下载进度',
        value: percent,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: MiuixText(verifying ? '正在校验文件' : label,
                    fontSize: 12, color: c.onSurfaceVariantSummary)),
            MiuixText(percent,
                fontSize: 15, fontWeight: FontWeight.w700, color: c.primary),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                  height: 10,
                  child: ColoredBox(
                      color: c.primary.withValues(alpha: 0.10),
                      child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: Duration(
                              milliseconds:
                                  MediaQuery.disableAnimationsOf(context)
                                      ? 0
                                      : 180),
                          curve: Curves.easeOut,
                          builder: (_, value, __) => Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                  widthFactor: value,
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          gradient: palette.gradient),
                                      child: const SizedBox.expand()))))))),
          const SizedBox(height: 10),
          MiuixText(
              '${formatBytes(received)} / ${total > 0 ? formatBytes(total) : '大小待获取'}',
              fontSize: 12,
              color: c.onSurfaceVariantSummary),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            MiuixText(detail, fontSize: 11, color: c.onSurfaceVariantSummary)
          ],
        ]));
  }
}
