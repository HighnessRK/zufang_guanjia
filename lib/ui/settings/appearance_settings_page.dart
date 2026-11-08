import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/config/app_config.dart';
import '../widgets/app_widgets.dart';
import '../widgets/app_brand.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});
  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  final cfg = AppConfig.instance;
  Future<void> _choose(
      String title,
      String current,
      List<MapEntry<String, String>> options,
      void Function(String) change) async {
    final choice = await showOptionPicker<String>(context,
        title: title, current: current, options: options);
    if (choice == null || !mounted) return;
    change(choice);
    await cfg.save();
    if (mounted) setState(() {});
  }

  Future<void> _icon(String style) async {
    try {
      await const MethodChannel('com.zufang.guanjia/native')
          .invokeMethod<void>('setAppIcon', {'style': style});
      cfg.iconStyle = style;
      await cfg.save();
      if (mounted) setState(() {});
      AppSnackbar.show('图标已切换，桌面可能需要片刻刷新');
    } catch (e) {
      if (mounted) AppSnackbar.show('图标切换失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MiuixTheme.of(context).colors;
    const themes = [
      MapEntry('system', '跟随系统'),
      MapEntry('light', '浅色模式'),
      MapEntry('dark', '深色模式')
    ];
    const backgrounds = [
      MapEntry('aurora', '极光'),
      MapEntry('ocean', '海盐蓝'),
      MapEntry('sunset', '落日霞'),
      MapEntry('jade', '青竹'),
      MapEntry('none', '纯净无光效')
    ];
    const motions = [
      MapEntry('standard', '灵动'),
      MapEntry('gentle', '舒缓'),
      MapEntry('off', '减少动效')
    ];
    String name(List<MapEntry<String, String>> options, String key) => options
        .firstWhere((e) => e.key == key, orElse: () => options.first)
        .value;
    return AuroraScaffold(
        topBar: MiuixSmallTopAppBar(
            title: '个性化',
            subtitle: '让每一处都合你心意',
            color: Colors.transparent,
            navigationIcon: MiuixIconButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded))),
        snackbarHost: const AppSnackbarHost(),
        content: (padding) => ListView(
                padding: EdgeInsets.fromLTRB(20, padding.top + 8, 20,
                    kGlassNavClearance + padding.bottom),
                children: [
                  const SectionTitle('应用图标'),
                  GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final width = (constraints.maxWidth - 36) / 4;
                        return Wrap(spacing: 12, runSpacing: 18, children: [
                          for (final entry in AppConfig.iconStyles.entries)
                            Semantics(
                                button: true,
                                selected: cfg.iconStyle == entry.key,
                                child: GestureDetector(
                                    onTap: () => _icon(entry.key),
                                    child: SizedBox(
                                        width: width,
                                        child: Column(children: [
                                          AppBrand(
                                              size: width.clamp(1, 62),
                                              style: entry.key),
                                          const SizedBox(height: 8),
                                          MiuixText(entry.value,
                                              fontSize: 11,
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 4),
                                          Icon(
                                              cfg.iconStyle == entry.key
                                                  ? Icons.check_circle_rounded
                                                  : Icons.circle_outlined,
                                              size: 17,
                                              color: cfg.iconStyle == entry.key
                                                  ? colors.primary
                                                  : colors
                                                      .onSurfaceVariantSummary)
                                        ]))))
                        ]);
                      })),
                  const SectionTitle('主题与光效'),
                  GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        MiuixArrowPreference(
                            title: '明暗模式',
                            summary: name(themes, cfg.themeMode),
                            onClick: () => _choose('明暗模式', cfg.themeMode,
                                themes, (v) => cfg.themeMode = v)),
                        const MiuixHorizontalDivider(),
                        MiuixArrowPreference(
                            title: '背景光效',
                            summary: name(backgrounds, cfg.backgroundStyle),
                            onClick: () => _choose('背景光效', cfg.backgroundStyle,
                                backgrounds, (v) => cfg.backgroundStyle = v)),
                        const MiuixHorizontalDivider(),
                        MiuixSwitchPreference(
                            title: '全透玻璃',
                            summary:
                                cfg.clearGlass ? '通透折射 · 清晰导航' : '柔和磨砂 · 更强遮蔽',
                            value: cfg.clearGlass,
                            onChanged: (v) async {
                              cfg.clearGlass = v;
                              await cfg.save();
                              if (mounted) setState(() {});
                            }),
                        const MiuixHorizontalDivider(),
                        MiuixSwitchPreference(
                            title: '高级材质',
                            summary: '玻璃卡片与环境光',
                            value: cfg.premiumMaterial,
                            onChanged: (v) async {
                              await cfg.update(premiumMaterial: v);
                              if (mounted) setState(() {});
                            }),
                      ])),
                  const SectionTitle('动效与触感'),
                  GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        MiuixArrowPreference(
                            title: '动效风格',
                            summary: name(motions, cfg.motionStyle),
                            onClick: () => _choose('动效风格', cfg.motionStyle,
                                motions, (v) => cfg.motionStyle = v)),
                        const MiuixHorizontalDivider(),
                        MiuixSwitchPreference(
                            title: '轻触反馈',
                            summary: '切换导航时轻振',
                            value: cfg.haptics,
                            onChanged: (v) async {
                              cfg.haptics = v;
                              await cfg.save();
                              if (mounted) setState(() {});
                            }),
                        const MiuixHorizontalDivider(),
                        MiuixSwitchPreference(
                            title: '预测手势返回',
                            summary: '边缘侧滑跟手返回',
                            value: cfg.predictiveBack,
                            onChanged: (v) async {
                              await cfg.update(predictiveBack: v);
                              if (mounted) setState(() {});
                            }),
                      ])),
                  const SizedBox(height: 16),
                  MiuixText('默认跟随系统明暗设置。系统开启减少动态效果时，应用也会尊重该设置。',
                      fontSize: 12,
                      height: 1.5,
                      color: colors.onSurfaceVariantSummary),
                ]));
  }
}
