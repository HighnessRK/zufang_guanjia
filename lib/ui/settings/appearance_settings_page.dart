import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../widgets/app_widgets.dart';

/// 设置 · 外观：高级材质（液态玻璃 / 高斯模糊）开关。
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;
    final bool premium = cfg.premiumMaterial;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '外观与显示',
        subtitle: '材质风格 · 全局生效',
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
            const SectionTitle('材质'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: MiuixSwitchPreference(
                title: '高级材质',
                summary: premium
                    ? '液态玻璃：极光渐变底 + 光效卡片'
                    : '高斯模糊：纯色底 + 毛玻璃卡片',
                value: premium,
                onChanged: (bool v) async {
                  await cfg.update(premiumMaterial: v);
                  _refresh();
                },
              ),
            ),
            const SizedBox(height: 16),
            MiuixText(
              '开启：整页极光渐变背景 + 液态玻璃卡片与顶栏，光影随内容流动；\n'
              '关闭：纯色背景 + 高斯模糊磨砂卡片，更省电、更保守。',
              fontSize: 12,
              height: 1.6,
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
