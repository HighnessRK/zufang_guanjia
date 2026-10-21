import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import 'app_widgets.dart';

/// 发现新版本弹窗（对标大狗记）：版本号 + 体积 + 更新说明预览，
///「立即更新」带下载进度，完成后调起系统安装器。
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  /// null = 未开始；0.0~1.0 = 下载中
  double? _progress;
  bool _failed = false;

  Future<void> _start() async {
    final String url = widget.info.apkUrl ?? '';
    if (url.isEmpty) {
      // 个别源附件无法匿名直链下载 → 打开 Release 页面手动下载
      final String page = widget.info.pageUrl;
      if (page.isNotEmpty) await launchUrl(Uri.parse(page));
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _progress = 0.0;
      _failed = false;
    });
    try {
      final File file = await UpdateService.downloadApk(
        url,
        (double p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
      await UpdateService.installApk(file.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _progress = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final UpdateInfo info = widget.info;
    final String sizeText = info.apkSize != null && info.apkSize! > 0
        ? ' · 约 ${(info.apkSize! / 1024 / 1024).toStringAsFixed(1)} MB'
        : '';

    return Dialog(
      backgroundColor: c.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.system_update_alt_rounded,
                    color: c.primary, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: MiuixText('发现新版本',
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            MiuixText('v${info.version}$sizeText',
                fontSize: 13, color: c.onSurfaceVariantSummary),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: MiuixText(
                  info.notes.isEmpty ? '详情见「关于 → 更新日志」' : info.notes,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_progress != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: _progress, minHeight: 6),
              ),
              const SizedBox(height: 10),
              Center(
                child: MiuixText(
                  '正在下载… ${(_progress! * 100).toStringAsFixed(0)}%',
                  fontSize: 12.5,
                  color: c.onSurfaceVariantSummary,
                ),
              ),
            ] else ...<Widget>[
              if (_failed) ...<Widget>[
                MiuixText('下载失败，请检查网络后重试',
                    fontSize: 12.5, color: c.error),
                const SizedBox(height: 10),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const MiuixText('稍后再说', fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: '立即更新',
                      onPressed: _start,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
