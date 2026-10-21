import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/native_bridge.dart';
import '../../services/update_service.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';
import '../widgets/update_dialog.dart';
import 'changelog_page.dart';

/// 关于页面：版本信息、检查更新、更新日志、系统信息、开源声明。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  Map<String, dynamic> _sys = <String, dynamic>{};

  /// 检查更新进行中（手动检查时显示进度指示）
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> sys = await NativeBridge.systemInfo();
      if (mounted) setState(() => _sys = sys);
    } catch (_) {
      // 桌面 / 调试环境没有原生通道，忽略即可
    }
  }

  /// 手动检查更新：已是最新 → 提示；有新版本 → 弹更新窗（含下载安装）
  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final UpdateInfo? info = await UpdateService.checkLatest();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      AppSnackbar.show('检查更新失败，请检查网络');
      return;
    }
    if (UpdateService.compareVersion(
            info.version, AppConstants.appVersion) <=
        0) {
      AppSnackbar.show('已是最新版本 v${AppConstants.appVersion}');
      return;
    }
    await showUpdateDialog(context, info);
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final String sourceLabel =
        AppConfig.instance.updateSource == 'github' ? 'GitHub' : 'Gitee';

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '关于',
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
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(26),
                ),
                child:
                    Icon(Icons.home_work_rounded, size: 46, color: c.primary),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: MiuixText(
                AppConstants.appName,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: MiuixText(
                '版本 ${AppConstants.appVersion} (${AppConstants.appBuild})',
                fontSize: 13,
                color: c.onSurfaceVariantSummary,
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('应用信息', padding: EdgeInsets.zero),
            const GlassCard(
              borderRadius: 20,
              padding: EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  InfoRow('应用名称', AppConstants.appName),
                  InfoRow('版本号', AppConstants.appVersion),
                  InfoRow('构建号', AppConstants.appBuild),
                  InfoRow('数据存储', '本地 SQLite + info.gwt'),
                ],
              ),
            ),
            const SectionTitle('更新'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixBasicComponent(
                    title: '检查更新',
                    summary: _checking
                        ? '正在检查…'
                        : '当前版本 v${AppConstants.appVersion} · 下载源 $sourceLabel',
                    onClick: _checking ? null : _checkUpdate,
                    endActions: <Widget>[
                      if (_checking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        MiuixIcon(
                          icon: Icons.arrow_forward_ios_rounded,
                          size: 14,
                          tint: c.onSurfaceVariantSummary,
                        ),
                    ],
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixBasicComponent(
                    title: '更新日志',
                    summary: '版本历史与新功能一览',
                    onClick: () => Navigator.of(context).push(
                      AppPageRoute<void>(
                          builder: (_) => const ChangelogPage()),
                    ),
                    endActions: <Widget>[
                      MiuixIcon(
                        icon: Icons.arrow_forward_ios_rounded,
                        size: 14,
                        tint: c.onSurfaceVariantSummary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionTitle('运行环境'),
            GlassCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  InfoRow('设备厂商', '${_sys['manufacturer'] ?? '未知'}'),
                  InfoRow('设备型号', '${_sys['model'] ?? '未知'}'),
                  InfoRow('系统版本', '${_sys['androidVersion'] ?? '未知'}'),
                  InfoRow('是否小米设备', (_sys['isXiaomi'] == true) ? '是' : '否'),
                ],
              ),
            ),
            const SectionTitle('开源声明'),
            const GlassCard(
              borderRadius: 20,
              padding: EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  InfoRow('flutter_miuix', 'Apache-2.0'),
                  InfoRow('liquid_glass_bottom_nav', 'MIT'),
                  InfoRow('sqflite', 'MIT'),
                  InfoRow('path_provider', 'MIT'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
