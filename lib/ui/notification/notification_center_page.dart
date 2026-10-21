import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../data/models/notice_item.dart';
import '../../services/notification_service.dart';
import '../widgets/app_widgets.dart';

/// APP 内置通知中心：汇总房租到期、水电费未缴费、租期即将到期提醒。
class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  List<NoticeItem> _list = <NoticeItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await NotificationService.instance.refresh();
    if (!mounted) return;
    setState(() {
      _list = NotificationService.instance.notices.value;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '通知中心',
        subtitle: '${_list.length} 条提醒',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
        actions: <Widget>[
          MiuixIconButton(
            onPressed: _markAllRead,
            child: const MiuixIcon(icon: Icons.done_all_rounded),
          ),
          const SizedBox(width: 8),
        ],
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
              if (_list.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 90),
                  child: EmptyView('暂无提醒，房子一切正常 🎉',
                      icon: Icons.notifications_none_rounded),
                )
              else
                for (final NoticeItem item in _list) ...<Widget>[
                  _buildItem(item, c),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }

  /// 单条通知卡片
  Widget _buildItem(NoticeItem item, MiuixColors c) {
    final bool read = AppConfig.instance.isNoticeRead(item.id);
    final bool danger = item.level == 'danger';
    final Color color = danger ? c.error : const Color(0xFFFF9500);

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      onPressed: () => _markRead(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.type == 'rent'
                  ? Icons.payments_rounded
                  : item.type == 'expire'
                      ? Icons.event_busy_rounded
                      : Icons.bolt_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: MiuixText(
                        item.title,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.onSurface,
                      ),
                    ),
                    if (!read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                MiuixText(
                  item.body,
                  fontSize: 13,
                  color: c.onSurfaceVariantSummary,
                ),
                const SizedBox(height: 8),
                StatusTag(item.typeText, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markRead(NoticeItem item) async {
    await NotificationService.instance.markRead(item);
    if (mounted) setState(() {});
  }

  Future<void> _markAllRead() async {
    await NotificationService.instance.markAllRead();
    if (!mounted) return;
    setState(() {});
    AppSnackbar.show('全部标记为已读');
  }
}
