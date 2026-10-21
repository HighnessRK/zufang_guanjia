import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/native_bridge.dart';
import '../../services/update_service.dart';
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
                  // 与桌面启动图标一致：深蓝底 + 白色房子（自适应图标安全区）
                  color: const Color(0xFF0F5CB4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const CustomPaint(
                  painter: _LauncherHousePainter(),
                ),
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
                ],
              ),
            ),
            const SectionTitle('更新日志'),
            const ChangelogSection(),
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

/// 与桌面启动图标一致的白色房子（深蓝底在容器上绘制）。
/// 居中绘制：三角屋顶 + 屋身 + 门，缩放适配 88×88 安全区。
class _LauncherHousePainter extends CustomPainter {
  const _LauncherHousePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 屋身宽度 / 高度，屋顶三角略宽于屋身
    final double bodyW = w * 0.42;
    final double bodyH = h * 0.30;
    final double cx = w / 2;
    final double bodyTop = h * 0.46;
    final double bodyBottom = bodyTop + bodyH;

    final Paint paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    // 屋身
    final Rect body = Rect.fromCenter(
      center: Offset(cx, (bodyTop + bodyBottom) / 2),
      width: bodyW,
      height: bodyH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(w * 0.03)),
      paint,
    );

    // 屋顶（三角形，顶点在屋身中轴上方）
    final double roofW = bodyW * 1.34;
    final double roofTop = bodyTop - h * 0.20;
    final Path roof = Path()
      ..moveTo(cx, roofTop)
      ..lineTo(cx + roofW / 2, bodyTop + h * 0.01)
      ..lineTo(cx - roofW / 2, bodyTop + h * 0.01)
      ..close();
    canvas.drawPath(roof, paint);

    // 门（镂空用底色）
    final Paint doorPaint = Paint()
      ..color = const Color(0xFF0F5CB4)
      ..style = PaintingStyle.fill;
    final Rect door = Rect.fromCenter(
      center: Offset(cx, bodyBottom - bodyH * 0.28),
      width: bodyW * 0.30,
      height: bodyH * 0.56,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(door, Radius.circular(w * 0.02)),
      doorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LauncherHousePainter oldDelegate) => false;
}
