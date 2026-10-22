import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/notification_service.dart';
import '../../services/update_service.dart';
import 'app_widgets.dart';

/// 发现新版本弹窗（对标大狗记）：深浅色自适应，更新内容解析为彩色标签，
///「立即更新」带下载进度（弹窗不消失、通知栏同步），完成后出现「安装」按钮。
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
  /// 0 = 未开始下载；1~100 = 下载中百分比；-1 = 下载完成待安装
  int _state = 0;
  bool _failed = false;
  File? _file;

  Future<void> _start() async {
    final String url = widget.info.apkUrl ?? '';
    if (url.isEmpty) {
      final String page = widget.info.pageUrl;
      if (page.isNotEmpty) await launchUrl(Uri.parse(page));
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _state = 1;
      _failed = false;
    });
    await NotificationService.showUpdateProgress(widget.info.version, 0);
    try {
      final File file = await UpdateService.downloadApk(
        url,
        (double p) {
          final int pct = (p * 100).clamp(0, 100).round();
          if (mounted) setState(() => _state = pct == 0 ? 1 : pct);
          NotificationService.showUpdateProgress(widget.info.version, pct);
        },
      );
      if (!mounted) return;
      setState(() {
        _file = file;
        _state = -1;
      });
      await NotificationService.showUpdateDone(widget.info.version);
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = 0;
          _failed = true;
        });
      }
      await NotificationService.cancelUpdateNotification();
    }
  }

  Future<void> _install() async {
    final File? f = _file;
    if (f == null) return;
    await Navigator.of(context).maybePop();
    await UpdateService.installApk(f.path);
  }

  /// 次级描边按钮（「稍后再说 / 取消」）：与右侧主按钮同高 52、同圆角 16，
  /// 透明底 + outline 描边，形成「实心主按钮 + 描边次按钮」的成对观感。
  Widget _outlineBtn(MiuixColors c, String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: c.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size.fromHeight(52),
        padding: EdgeInsets.zero,
      ),
      child: MiuixText(label, fontSize: 15, color: c.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final UpdateInfo info = widget.info;
    final String sizeText = info.apkSize != null && info.apkSize! > 0
        ? '大小：${(info.apkSize! / 1024 / 1024).toStringAsFixed(1)} MB'
        : '';
    final List<UpdateNoteEntry> notes = UpdateService.parseUpdateNotes(info.notes);
    final String dateText =
        info.date.isNotEmpty ? (sizeText.isEmpty ? '' : '  ·  ') + info.date : '';

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ====== 标题行：发现新版本 vX.Y.Z ======
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: MiuixText('发现新版本',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: c.onSurface),
                ),
                MiuixText('V${info.version}',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.primary),
              ],
            ),
            if (sizeText.isNotEmpty || info.date.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              MiuixText('$sizeText$dateText',
                  fontSize: 13, color: c.onSurfaceVariantSummary),
            ],
            const SizedBox(height: 18),
            // ====== 更新内容 ======
            MiuixText('更新内容',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.onSurface),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: notes.isEmpty
                    ? MiuixText(
                        info.notes.isEmpty ? '暂无更新说明' : info.notes,
                        fontSize: 14,
                        height: 1.55,
                        color: c.onSurfaceVariantSummary,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: notes
                            .map((UpdateNoteEntry e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (e.type.isNotEmpty) ...<Widget>[
                                        _NoteTag(type: e.type),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: MiuixText(e.text,
                                            fontSize: 14,
                                            height: 1.5,
                                            color: c.onSurfaceVariantSummary),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // ====== 底部：按钮 / 进度 ======
            if (_state > 0) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _state / 100,
                  minHeight: 6,
                  backgroundColor: c.onSurfaceVariantSummary.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _outlineBtn(c, '取消', () async {
                      final NavigatorState nav = Navigator.of(context);
                      await NotificationService.cancelUpdateNotification();
                      if (mounted) nav.maybePop();
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: '正在下载 $_state%',
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ] else if (_state == -1) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _outlineBtn(
                        c, '稍后再说', () => Navigator.of(context).maybePop()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: '安装',
                      onPressed: _install,
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              if (_failed) ...<Widget>[
                MiuixText('下载失败，请检查网络后重试',
                    fontSize: 13, color: c.error),
                const SizedBox(height: 12),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: _outlineBtn(
                        c, '稍后再说', () => Navigator.of(context).maybePop()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: _failed ? '重试' : '立即更新',
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

/// 更新内容条目彩色标签（与「更新日志」一致）
class _NoteTag extends StatelessWidget {
  const _NoteTag({required this.type});

  final String type;

  int get _color {
    switch (type) {
      case '修复':
        return 0xFFFF9500;
      case '优化':
        return 0xFF3478F6;
    }
    return 0xFF34C759;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Color(_color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: MiuixText(type,
          fontSize: 11, fontWeight: FontWeight.w600, color: color),
    );
  }
}
