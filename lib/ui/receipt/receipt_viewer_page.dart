import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../data/models/receipt.dart';
import '../../data/repository/receipt_repository.dart';
import '../../services/native_bridge.dart';
import '../../services/receipt_exporter.dart';
import '../widgets/app_widgets.dart';
import 'receipt_card.dart';
import 'receipt_delete_dialog.dart';

/// 收据预览页（v1.1.3）：白纸质收据大图 + 保存相册 / 转发微信 / 删除。
///
/// 预览与导出共用 [ReceiptCard]，所见即所得；导出像素比 3.0 → 约 940px 宽。
class ReceiptViewerPage extends StatefulWidget {
  const ReceiptViewerPage({super.key, required this.receipt});

  final Receipt receipt;

  @override
  State<ReceiptViewerPage> createState() => _ReceiptViewerPageState();
}

class _ReceiptViewerPageState extends State<ReceiptViewerPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      AppSnackbar.show('操作失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 保存到系统相册（Pictures/租房管家，Android 10+ 免权限）
  Future<void> _save() => _guard(() async {
        final String path = await ReceiptExporter.exportPng(_boundaryKey);
        final bool ok = await NativeBridge.saveImageToGallery(path);
        if (!mounted) return;
        AppSnackbar.show(ok ? '已保存到相册（Pictures/租房管家）' : '保存失败，请重试');
      });

  /// 转发微信：先直启微信分享页，未安装则回落系统分享面板
  Future<void> _share() => _guard(() async {
        final String path = await ReceiptExporter.exportPng(_boundaryKey);
        await NativeBridge.shareImage(path, toWeChat: true);
      });

  Future<void> _delete() async {
    final bool ok = await confirmDeleteReceipt(context, widget.receipt);
    if (!ok || !mounted) return;
    final int? id = widget.receipt.id;
    if (id != null) {
      await ReceiptRepository.instance.delete(id);
    }
    if (mounted) Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final Receipt r = widget.receipt;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '收据预览',
        subtitle: '${r.roomNo} · ${r.period}',
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
            // ===== 收据本体（预览 = 导出）=====
            Center(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: ReceiptCard(receipt: r),
              ),
            ),
            const SizedBox(height: 22),

            // ===== 行动区 =====
            Row(
              children: <Widget>[
                Expanded(
                  child: GradientButton(
                    label: _busy ? '处理中…' : '保存到相册',
                    icon: Icons.download_rounded,
                    enabled: !_busy,
                    onPressed: _save,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientButton(
                    label: _busy ? '处理中…' : '转发微信',
                    icon: Icons.share_rounded,
                    enabled: !_busy,
                    onPressed: _share,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MiuixText(
              '未安装微信时将唤起系统分享面板，可选 QQ、文件、蓝牙等',
              fontSize: 11,
              color: c.onSurfaceVariantSummary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _dangerButton(c),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _dangerButton(MiuixColors c) {
    return GestureDetector(
      onTap: _busy ? null : _delete,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: _busy ? 0.6 : 1,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: c.error.withValues(alpha: 0.30)),
          ),
          child: MiuixText('删除收据',
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: c.error),
        ),
      ),
    );
  }
}
