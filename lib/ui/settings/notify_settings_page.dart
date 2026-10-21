import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../services/native_bridge.dart';
import '../../services/notification_service.dart';
import '../notification/notification_center_page.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';
import 'settings_edit.dart';

/// 设置 · 通知与提醒：提前天数 / 系统通知 / 澎湃OS 焦点通知 / 通知中心。
///
/// 说明：常驻前台服务已按「公平运行」原则移除——提醒在每次打开 /
/// 切回 App 时重算并推送，不再有「运行中」常驻通知。
class NotifySettingsPage extends StatefulWidget {
  const NotifySettingsPage({super.key});

  @override
  State<NotifySettingsPage> createState() => _NotifySettingsPageState();
}

class _NotifySettingsPageState extends State<NotifySettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '通知与提醒',
        subtitle: '房租 · 到期 · 水电费',
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
            const SectionTitle('提醒时机'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixArrowPreference(
                    title: '缴费提醒提前天数',
                    summary: '提前 ${cfg.remindDays} 天提醒未缴房租 / 水电费',
                    onClick: () => editIntDialog(
                        context, '缴费提醒提前天数', '天', cfg.remindDays,
                        (int v) async {
                      await cfg.update(remindDays: v);
                      await NotificationService.instance.refresh();
                      _refresh();
                    }),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '租期到期提醒提前天数',
                    summary: '提前 ${cfg.expireRemindDays} 天提醒租期到期',
                    onClick: () => editIntDialog(
                        context, '租期到期提醒提前天数', '天', cfg.expireRemindDays,
                        (int v) async {
                      await cfg.update(expireRemindDays: v);
                      await NotificationService.instance.refresh();
                      _refresh();
                    }),
                  ),
                ],
              ),
            ),
            const SectionTitle('通知渠道'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixSwitchPreference(
                    title: '系统通知提醒',
                    summary: 'Android 系统通知栏提醒',
                    value: cfg.notifyEnabled,
                    onChanged: (bool v) async {
                      await cfg.update(notifyEnabled: v);
                      if (v) {
                        await NotificationService.instance.init();
                        await NotificationService.instance.refresh();
                      } else {
                        await NativeBridge.cancelAll();
                      }
                      _refresh();
                    },
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixSwitchPreference(
                    title: '澎湃OS 焦点通知',
                    summary: 'HyperOS 状态栏醒目提醒（不支持时自动降级）',
                    value: cfg.focusEnabled,
                    onChanged: (bool v) async {
                      await cfg.update(focusEnabled: v);
                      await NotificationService.instance.refresh();
                      _refresh();
                    },
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '通知中心',
                    summary: '查看房租到期 / 水电未缴 / 租期提醒',
                    onClick: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                              builder: (BuildContext _) =>
                                  const NotificationCenterPage()),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MiuixText(
              '提醒在每次打开或切回 App 时自动重算并推送，无常驻后台服务、'
              '无「运行中」通知，公平占用系统资源。',
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        );
      },
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
