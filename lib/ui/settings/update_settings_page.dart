import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../widgets/app_widgets.dart';

/// 更新设置（对标大狗记）：下载源（GitHub / Gitee）、自动检查更新、更新提醒。
class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '更新设置',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        return ListenableBuilder(
          listenable: cfg,
          builder: (BuildContext context, _) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  20, padding.top + 12, 20, kGlassNavClearance + padding.bottom),
              children: <Widget>[
                const SectionTitle('下载源'),
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  borderRadius: 20,
                  child: Column(
                    children: <Widget>[
                      MiuixBasicComponent(
                        title: 'GitHub',
                        summary: 'github.com · 国际节点',
                        onClick: () => _pickSource('github'),
                        endActions: <Widget>[
                          if (cfg.updateSource == 'github')
                            MiuixIcon(
                                icon: Icons.check_rounded, tint: c.primary),
                        ],
                      ),
                      const MiuixHorizontalDivider(),
                      MiuixBasicComponent(
                        title: 'Gitee',
                        summary: 'gitee.com · 国内节点（推荐）',
                        onClick: () => _pickSource('gitee'),
                        endActions: <Widget>[
                          if (cfg.updateSource == 'gitee')
                            MiuixIcon(
                                icon: Icons.check_rounded, tint: c.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                const SectionTitle('检查'),
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  borderRadius: 20,
                  child: Column(
                    children: <Widget>[
                      MiuixBasicComponent(
                        title: '自动检查更新',
                        summary: '每次启动及每天 09:00、21:00 检查',
                        onClick: () =>
                            cfg.update(autoCheckUpdate: !cfg.autoCheckUpdate),
                        endActions: <Widget>[
                          MiuixSwitch(
                            value: cfg.autoCheckUpdate,
                            onChanged: (bool v) =>
                                cfg.update(autoCheckUpdate: v),
                          ),
                        ],
                      ),
                      const MiuixHorizontalDivider(),
                      MiuixBasicComponent(
                        title: '更新提醒',
                        summary: cfg.autoCheckUpdate
                            ? '启动时弹窗，后台检查发现新版本时通知'
                            : '开启自动检查更新后生效',
                        enabled: cfg.autoCheckUpdate,
                        onClick: cfg.autoCheckUpdate
                            ? () => cfg.update(updateNotify: !cfg.updateNotify)
                            : null,
                        endActions: <Widget>[
                          MiuixSwitch(
                            value: cfg.updateNotify,
                            enabled: cfg.autoCheckUpdate,
                            onChanged: cfg.autoCheckUpdate
                                ? (bool v) => cfg.update(updateNotify: v)
                                : (_) {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('后台通知需允许系统通知。省电策略可能延迟定时检查；'
                      '强制停止应用后需重新打开恢复。'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickSource(String source) async {
    if (AppConfig.instance.updateSource == source) return;
    await AppConfig.instance.update(updateSource: source);
    if (mounted) setState(() {});
  }
}
