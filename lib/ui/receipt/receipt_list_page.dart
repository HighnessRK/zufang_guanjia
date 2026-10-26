import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/utils/date_util.dart';
import '../../data/models/receipt.dart';
import '../../data/models/room.dart';
import '../../data/repository/receipt_repository.dart';
import '../../data/repository/room_repository.dart';
import '../../services/receipt_service.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';
import 'receipt_delete_dialog.dart';
import 'receipt_viewer_page.dart';

/// 电子收据页（v1.1.3）：生成水、电收据图片 + 历史收据管理。
///
/// 生成流程：选房间 → 选账期 → 落库快照 → 进入预览（保存相册 / 转发微信）。
/// 入口：首页快捷入口、收款页「更多工具」。
class ReceiptListPage extends StatefulWidget {
  const ReceiptListPage({super.key});

  @override
  State<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends State<ReceiptListPage> {
  List<Receipt> _list = <Receipt>[];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Receipt> list = await ReceiptRepository.instance.all();
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  /// 生成收据：选房间 → 选账期 → 生成（同房同期覆盖）→ 预览
  Future<void> _generate() async {
    if (_generating) return;
    final List<Room> rooms = await RoomRepository.instance.all();
    if (rooms.isEmpty) {
      AppSnackbar.show('先添加房间，再生成收据');
      return;
    }
    if (!mounted) return;

    // 1) 选房间
    final String? roomNo = await showOptionPicker<String>(
      context,
      title: '选择房间',
      current: rooms.first.roomNo,
      options: <MapEntry<String, String>>[
        for (final Room r in rooms)
          MapEntry<String, String>(
            r.roomNo,
            r.tenant.isEmpty ? r.roomNo : '${r.roomNo} · ${r.tenant}',
          ),
      ],
    );
    if (roomNo == null || !mounted) return;

    // 2) 选账期（该房间有水电流水的账期 + 当前账期）
    final List<String> periods = await ReceiptService.periodsOf(roomNo);
    if (!mounted) return;
    final String cur = DateUtil.currentPeriod;
    final String? period = await showOptionPicker<String>(
      context,
      title: '选择账期',
      current: periods.first,
      options: <MapEntry<String, String>>[
        for (final String p in periods)
          MapEntry<String, String>(p, p == cur ? '$p（本账期）' : p),
      ],
    );
    if (period == null || !mounted) return;

    // 3) 生成并预览
    setState(() => _generating = true);
    try {
      final Receipt receipt = await ReceiptService.generate(roomNo, period);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(AppPageRoute<void>(
        builder: (BuildContext _) => ReceiptViewerPage(receipt: receipt),
      ));
      await _load();
    } on StateError catch (e) {
      if (mounted) AppSnackbar.show(e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _open(Receipt r) async {
    await Navigator.of(context).push(AppPageRoute<void>(
      builder: (BuildContext _) => ReceiptViewerPage(receipt: r),
    ));
    // 预览页里可能删了收据，回来刷新
    await _load();
  }

  Future<void> _delete(Receipt r) async {
    final bool ok = await confirmDeleteReceipt(context, r);
    if (!ok || !mounted) return;
    final int? id = r.id;
    if (id != null) {
      await ReceiptRepository.instance.delete(id);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '电子收据',
        subtitle: _loading ? '加载中…' : '${_list.length} 张 · 可保存 / 转发',
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
              GradientButton(
                label: _generating ? '生成中…' : '生成收据',
                icon: Icons.add_rounded,
                enabled: !_generating,
                onPressed: _generate,
              ),
              const SizedBox(height: 14),
              if (_list.isEmpty)
                const EmptyView(
                  '还没有收据',
                  icon: Icons.receipt_long_rounded,
                  hint: '点上方「生成收据」，选房间与账期即可生成水电费收据图片，'
                      '可保存相册、转发微信',
                )
              else
                for (int i = 0; i < _list.length; i++) ...<Widget>[
                  _receiptCard(c, _list[i]),
                  if (i != _list.length - 1) const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _receiptCard(MiuixColors c, Receipt r) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 20,
      onPressed: () => _open(r),
      child: Row(
        children: <Widget>[
          const GradientIconBox(
            icon: Icons.receipt_long_rounded,
            colors: <Color>[Color(0xFF3482FF), Color(0xFF7B5CFF)],
            size: 40,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MiuixText(r.title,
                    fontSize: 14.5, fontWeight: FontWeight.w600),
                const SizedBox(height: 3),
                MiuixText(
                  r.tenant.isEmpty ? r.no : '${r.no} · 租户 ${r.tenant}',
                  fontSize: 11.5,
                  color: c.onSurfaceVariantSummary,
                ),
                const SizedBox(height: 2),
                MiuixText('生成于 ${r.createdAt}',
                    fontSize: 11, color: c.onSurfaceVariantSummary),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              MiuixText('¥${r.total}',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.primary),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _delete(r),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: c.error.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
