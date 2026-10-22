import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/date_util.dart';

/// 全局可复用的 UI 小组件与工具：分组标题、信息行、统计卡片、
/// 空状态、HyperOS 风格确认弹窗、全局 Snackbar。
/// 集中管理，保证四个页面视觉完全统一、无冗余重复代码。

/// 液态玻璃底部导航栏的占位高度（内容需要预留，避免被导航栏遮挡）。
/// 紧凑胶囊：高 60 + 底距 16 + 手势区约 20 + 余量 ≈ 108。
const double kGlassNavClearance = 108;

/// 全局 Snackbar 状态（每个 MiuixScaffold 都挂载同一个 Host）
class AppSnackbar {
  AppSnackbar._();

  static final MiuixSnackbarHostState state = MiuixSnackbarHostState();

  /// 显示一条轻提示
  static void show(String message, {String? actionLabel, VoidCallback? onAction}) {
    state.showSnackbar(message, actionLabel: actionLabel);
  }
}

/// Snackbar 抬升量：悬浮玻璃导航条顶距屏底约 90，加上 16 间隙，再减去
/// scaffold 底部窗口内边距（vendor 布局已叠加该 inset），保证提示条完整
/// 显示在导航条上方、不被遮挡。
const double kSnackbarLift = 85;

/// 统一的 Snackbar 宿主（全 App 16 处页面共用）：
/// MiuixScaffold 的 bottomBar 槽位未使用（导航条是 AppShell 悬浮自绘），
/// vendor 只按安全区避让会被导航盖住，这里整体上抬 [kSnackbarLift]。
class AppSnackbarHost extends StatelessWidget {
  const AppSnackbarHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSnackbarLift),
      child: MiuixSnackbarHost(state: AppSnackbar.state),
    );
  }
}

/// 分组标题（HyperOS 设置页 / 列表页的分组小标题）
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: MiuixText(
        text,
        style: MiuixTheme.of(context).textStyles.subtitle,
        color: MiuixTheme.of(context).colors.onBackgroundVariant,
      ),
    );
  }
}

/// 详情页里的「标签 — 值」信息行
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: MiuixText(
              label,
              color: c.onSurfaceVariantSummary,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: MiuixText(
              value.isEmpty ? '—' : value,
              fontSize: 14,
              color: highlight ? c.primary : c.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 首页数据总览卡片
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Expanded(
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        onPressed: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            MiuixText(
              value,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: c.onSurfaceContainer,
            ),
            const SizedBox(height: 2),
            MiuixText(
              label,
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 快捷入口卡片（首页底部，玻璃样式）
class QuickEntry extends StatelessWidget {
  const QuickEntry({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 3),
        borderRadius: 20,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GradientIconBox(
              icon: icon,
              colors: <Color>[color, Color.lerp(color, Colors.white, 0.40)!],
              size: 38,
              radius: 12,
            ),
            const SizedBox(height: 8),
            // 单行不换行：5 项等宽平铺下 4 字标签保持一行
            MiuixText(
              label,
              fontSize: 12,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态占位：柔光渐变圆底 + 图标 + 主文案 + 副提示。
/// 相比纯灰图标，带一层液态玻璃质感的光晕，与整体风格统一。
class EmptyView extends StatelessWidget {
  const EmptyView(
    this.text, {
    super.key,
    this.icon = Icons.inbox_rounded,
    this.hint,
  });

  final String text;
  final IconData icon;

  /// 第二行小字提示（可空）
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(0xFF3482FF).withValues(alpha: 0.16),
                  const Color(0xFF7B5CFF).withValues(alpha: 0.10),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF3482FF).withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 34, color: const Color(0xFF5B7CFF)),
          ),
          const SizedBox(height: 16),
          MiuixText(
            text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.onSurface,
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(height: 6),
            MiuixText(
              hint!,
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        ],
      ),
    );
  }
}

/// 状态胶囊标签（已缴 / 未缴 / 即将到期 等）
class StatusTag extends StatelessWidget {
  const StatusTag(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: MiuixText(text, fontSize: 11, color: color),
    );
  }
}

//==================== 液态玻璃组件 ====================

/// 页面背景极光光斑（液态玻璃底色）：蓝 / 紫 / 粉三团径向渐变，
/// 铺在 ListView 之后，玻璃卡片的 BackdropFilter 会对它做毛玻璃模糊。
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    this.blue = const Color(0xFF4C8DFF),
    this.purple = const Color(0xFF8A6BFF),
    this.pink = const Color(0xFFFF7EB6),
  });

  final Color blue;
  final Color purple;
  final Color pink;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double a = dark ? 0.26 : 0.40;
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned(top: -60, left: -70, child: _blob(blue, 320, a)),
          Positioned(top: 30, right: -90, child: _blob(pink, 300, a * 0.9)),
          Positioned(top: 320, left: 70, child: _blob(purple, 260, a * 0.75)),
          Positioned(top: 620, right: -50, child: _blob(blue, 240, a * 0.6)),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// 顶栏「透明渐变模糊」面纱（页面级，由 AuroraScaffold 铺在正文之上）：
///   高度 = 顶栏区域（`padding.top`），**不越过顶栏底边**——分界线下方
/// 的正文永远完全清晰。
///
/// 【无分界线的关键 —— 连续渐隐】单个 BackdropFilter 无法做空间渐变的
/// 高斯模糊；分带近似（多条窄带逐级降 sigma）会在带边界留下淡淡接缝。
/// 改用「滤镜链」方案：`ImageFilter.compose(outer: 渐隐蒙版着色器,
/// inner: 高斯模糊)` —— 先把背景整体高斯模糊，再由 shaders/top_bar_fade.frag
/// 按 y 坐标把模糊结果经 smoothstep 平滑降到全透明（透出底下原图）。
/// 顶栏底边处模糊恰好归零，全程连续，任何位置无台阶、无接缝。
///
/// 渐隐蒙版着色器仅 Impeller 支持（`ImageFilter.isShaderFilterSupported`）；
/// Skia 等环境静默降级为分带近似。着色器在 main.dart 启动时预加载。
///
/// 面纱铺在页面级 Stack（全屏高度）里、由 `padding.top` 直接定位高度，
/// 不随顶栏槽位被裁剪；IgnorePointer 保证不挡正文手势。顶栏本体（标题 /
/// 操作按钮）由 MiuixScaffold 在其上层绘制，始终清晰。
class _TopBarVeil extends StatefulWidget {
  const _TopBarVeil();

  @override
  State<_TopBarVeil> createState() => _TopBarVeilState();
}

class _TopBarVeilState extends State<_TopBarVeil> {
  /// 渐隐蒙版着色器：一次加载、全局共用（u_size 由引擎逐次自动绑定，
  /// 其余 uniform 恒定，多页面同时挂载可安全共享同一实例）
  static final Future<FragmentShader?> _maskFuture = _loadMask();

  /// 启动期预热（main.dart 调用）：触发一次性加载，不阻塞首帧可用性
  static void preload() {
    _maskFuture.then((_) {});
  }

  static Future<FragmentShader?> _loadMask() async {
    if (!ImageFilter.isShaderFilterSupported) return null;
    try {
      final FragmentProgram program =
          await FragmentProgram.fromAsset('shaders/top_bar_fade.frag');
      final FragmentShader mask = program.fragmentShader();
      // float 0..1 = u_size（引擎自动绑定）；float 2..3 = u_fade：
      // 自顶栏 25% 处起渐隐，到顶栏底边（分界线）恰好归零
      mask.setFloat(2, 0.25);
      mask.setFloat(3, 1.0);
      return mask;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return FutureBuilder<FragmentShader?>(
      future: _maskFuture,
      builder: (BuildContext context, AsyncSnapshot<FragmentShader?> snap) {
        final FragmentShader? mask = snap.data;
        return Stack(
          children: <Widget>[
            // 模糊层：高斯模糊 + 纵向平滑渐隐（Impeller 主路径，无接缝）
            if (mask != null)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.compose(
                      outer: ImageFilter.shader(mask),
                      inner: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              )
            else
              // Skia 降级：分带近似（带边界可能有极淡接缝）
              const Positioned.fill(child: _BandBlurFallback()),
            // 界内渐隐色调：顶 52% → 中 34% → 底边 0%，与模糊同步收尾
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      c.surface.withValues(alpha: 0.52),
                      c.surface.withValues(alpha: 0.34),
                      c.surface.withValues(alpha: 0),
                    ],
                    stops: const <double>[0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Skia 等不支持运行时滤镜着色器时的降级：4 条窄带逐级降 sigma 近似渐隐
class _BandBlurFallback extends StatelessWidget {
  const _BandBlurFallback();

  /// 4 条模糊带的 sigma（自上而下逐带减弱，底边处≈0）
  static const List<double> _bandSigmas = <double>[14, 7, 3, 1.2];

  /// 4 条模糊带的高度占比（合计 100，铺满顶栏区域）
  static const List<int> _bandFlex = <int>[35, 25, 20, 20];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < _bandSigmas.length; i++)
          Expanded(
            flex: _bandFlex[i],
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _bandSigmas[i],
                  sigmaY: _bandSigmas[i],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}

/// 应用启动时预热顶栏面纱的渐隐蒙版着色器（main.dart 调用）。
/// 不支持运行时滤镜着色器的环境（Skia）静默降级为分带近似。
void preloadTopBarVeilShader() => _TopBarVeilState.preload();

/// 全页极光脚手架：底色 + 极光铺满**整屏（含顶栏与状态栏区域）**，
/// MiuixScaffold 以透明底渲染在其上。
///
/// 【为什么这样】此前极光只铺在内容区（顶栏之下），顶栏区是纯色，
/// 交界处出现一道生硬的“割裂线”。把极光移到最底层、脚手架整体透明后，
/// 一张背景贯穿全页；「高级材质」关闭时极光不渲染，退化为纯色高斯模糊底。
///
/// 监听 [AppConfig]：设置页切换高级材质后，所有已挂载页面立即生效。
class AuroraScaffold extends StatefulWidget {
  const AuroraScaffold({
    super.key,
    this.topBar,
    this.snackbarHost,
    this.floatingActionButton,
    required this.content,
  });

  final Widget? topBar;
  final Widget? snackbarHost;
  final Widget? floatingActionButton;
  final MiuixScaffoldContentBuilder content;

  @override
  State<AuroraScaffold> createState() => _AuroraScaffoldState();
}

class _AuroraScaffoldState extends State<AuroraScaffold> {
  @override
  void initState() {
    super.initState();
    AppConfig.instance.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    AppConfig.instance.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final bool premium = AppConfig.instance.premiumMaterial;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 最底层：与原 MiuixScaffold 默认背景一致的 surface 底色
        // （三子节点均带 key：开关「高级材质」时增删极光层不会按位置
        // 重挂 MiuixScaffold，保住页面滚动位置与输入状态）
        ColoredBox(key: const ValueKey<String>('surface'), color: c.surface),
        // 高级材质开：极光光斑铺满全屏（关：纯色底 + 卡片高斯模糊）
        if (premium)
          const Positioned.fill(
            key: ValueKey<String>('aurora'),
            child: AuroraBackground(),
          ),
        // 透明脚手架：顶栏 / 内容 / Snackbar 全部叠在极光之上；
        // 正文层顶部铺页面级渐变模糊面纱（顶栏底边定位 + 向下晕染），
        // 与极光无缝衔接（各页顶栏 color 须透明）
        Positioned.fill(
          key: const ValueKey<String>('scaffold'),
          child: MiuixScaffold(
            containerColor: Colors.transparent,
            topBar: widget.topBar,
            snackbarHost: widget.snackbarHost,
            floatingActionButton: widget.floatingActionButton,
            content: (EdgeInsets padding) {
              final Widget body = widget.content(padding);
              if (widget.topBar == null) return body;
              // 面纱高度 = 顶栏区域（padding.top），不越过底边：
              // 界内渐隐模糊，分界线下方的正文完全清晰
              return Stack(
                children: <Widget>[
                  body,
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: padding.top,
                    child: const IgnorePointer(child: _TopBarVeil()),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 液态玻璃卡片：毛玻璃模糊 + 半透明渐变填充 + 亮边描边 + 顶部高光。
/// 可直接作为 MiuixCard 的替代品（支持 onPressed 点按反馈由手势层承担）。
///
/// 「高级材质」关闭时退化为高斯模糊磨砂卡：无渐变、无亮边、无顶部高光，
/// 仅保留 BackdropFilter 的高斯模糊与极淡底色。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.onPressed,
    this.blurSigma = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onPressed;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool premium = AppConfig.instance.premiumMaterial;
    final BorderRadius r = BorderRadius.circular(borderRadius);

    final Widget card = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: premium ? _glassDecoration(dark, r) : _frostDecoration(dark, r),
          foregroundDecoration: premium
              ? BoxDecoration(
                  borderRadius: r,
                  border: Border(
                    top: BorderSide(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.95),
                      width: 1,
                    ),
                  ),
                )
              : null,
          child: child,
        ),
      ),
    );

    if (onPressed == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: card,
    );
  }

  /// 液态玻璃：渐变填充 + 亮边 + 柔光投影 + 顶部高光
  BoxDecoration _glassDecoration(bool dark, BorderRadius r) {
    return BoxDecoration(
      borderRadius: r,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? <Color>[
                Colors.white.withValues(alpha: 0.13),
                Colors.white.withValues(alpha: 0.05),
              ]
            : <Color>[
                Colors.white.withValues(alpha: 0.82),
                Colors.white.withValues(alpha: 0.52),
              ],
      ),
      border: Border.all(
        color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.85),
        width: 1,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.30)
              : const Color(0xFF35507A).withValues(alpha: 0.10),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// 高斯模糊磨砂：极淡底色 + 细分隔边，无光效
  BoxDecoration _frostDecoration(bool dark, BorderRadius r) {
    return BoxDecoration(
      borderRadius: r,
      color: dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.62),
      border: Border.all(
        color: dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFF98A7BD).withValues(alpha: 0.22),
        width: 1,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.24)
              : const Color(0xFF35507A).withValues(alpha: 0.07),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

/// 渐变圆角图标块（玻璃卡片上的彩色小图标，自带柔光投影）
class GradientIconBox extends StatelessWidget {
  const GradientIconBox({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 42,
    this.radius = 14,
    this.iconSize,
  });

  final IconData icon;
  final List<Color> colors;
  final double size;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: Colors.white),
    );
  }
}

/// 蓝 → 紫 → 粉 渐变主按钮（液态玻璃风格 CTA）
///
/// 【圆角矩形 + 玻璃质感】圆角 16（非胶囊）；渐变色保留原蓝→紫→粉，但
/// 以半透明形式呈现并叠加毛玻璃背景、亮边描边与顶部高光——与整页液态
/// 玻璃语言统一，按钮"浮"在极光之上而不是实色贴片。
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;

  /// 紧凑档：卡片头部等小空间的行动点（高度 34，字号 13）
  final bool compact;

  /// 主渐变三色（同时用于底色与光晕）
  static const List<Color> kColors = <Color>[
    Color(0xFF3482FF),
    Color(0xFF7B5CFF),
    Color(0xFFFF6B9D),
  ];

  static const LinearGradient kGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: kColors,
  );

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;
    final BorderRadius r = BorderRadius.circular(compact ? 12 : 16);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: active ? 1 : 0.45,
        child: ClipRRect(
          borderRadius: r,
          // 毛玻璃底：身后极光 / 卡片透上来，按钮呈"玻璃片"
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: compact ? 34 : 52,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 14)
                  : EdgeInsets.zero,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 半透明渐变主色（保留原色彩识别度）
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: kColors
                      .map((Color c) => c.withValues(alpha: 0.82))
                      .toList(),
                ),
                borderRadius: r,
                // 亮边描边：玻璃质感的关键
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32),
                ),
                boxShadow: active
                    ? <BoxShadow>[
                        BoxShadow(
                          color:
                              const Color(0xFF7B5CFF).withValues(alpha: 0.32),
                          blurRadius: compact ? 10 : 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              // 顶部高光：玻璃上沿的一道反光
              foregroundDecoration: BoxDecoration(
                borderRadius: r,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: compact ? 16 : 20, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  MiuixText(
                    label,
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// HyperOS 风格确认弹窗。
///
/// 通过 [MiuixOverlayDialog] 实现：圆角面板、标题 + 摘要、底部双按钮，
/// 点击遮罩可关闭，与澎湃OS 系统弹窗质感一致。
Future<bool?> showAppDialog(
  BuildContext context, {
  required String title,
  String? summary,
  Widget? content,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) {
      final MiuixColors c = MiuixTheme.of(ctx).colors;
      return MiuixOverlayDialog(
        show: true,
        renderInRootScaffold: false,
        title: title,
        summary: summary,
        onDismissRequest: () => Navigator.of(ctx).pop(false),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (content != null) content,
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: MiuixTextButton(
                    cancelText,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // 常规确认 = 蓝色渐变主按钮；危险操作 = 红色实底
                  child: danger
                      ? MiuixButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          colors: MiuixButtonColors(
                            color: c.error,
                            disabledColor: c.disabledPrimaryButton,
                            contentColor: c.onError,
                            disabledContentColor: c.disabledOnPrimaryButton,
                          ),
                          child: MiuixText(confirmText),
                        )
                      : GradientButton(
                          label: confirmText,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// 通用单选弹窗（HyperOS 风格列表）：点选即返回所选值，取消返回 null。
/// 计费周期 / 收水收电间隔 / 房型 等所有下拉选择项共用。
Future<T?> showOptionPicker<T>(
  BuildContext context, {
  required String title,
  String? summary,
  required T current,
  required List<MapEntry<T, String>> options,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) {
      final MiuixColors c = MiuixTheme.of(ctx).colors;
      return MiuixOverlayDialog(
        show: true,
        renderInRootScaffold: false,
        title: title,
        summary: summary,
        onDismissRequest: () => Navigator.of(ctx).pop(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < options.length; i++) ...<Widget>[
              if (i != 0) const MiuixHorizontalDivider(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(options[i].key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: MiuixText(
                          options[i].value,
                          fontSize: 15,
                          fontWeight: options[i].key == current
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: options[i].key == current
                              ? c.primary
                              : c.onSurface,
                        ),
                      ),
                      if (options[i].key == current)
                        Icon(Icons.check_circle_rounded,
                            size: 19, color: c.primary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// HyperOS 风格日期选择弹窗（液态玻璃面板 + 身后极光透底 + miuix 月历）。
///
/// 替换 Material 的 showDatePicker：整块面板是液态玻璃卡（页面极光从身后
/// 透上来），内部是澎湃OS 月历（月份切换 / 周名行 / 6×7 日期网格 / 选中态
/// 主色圆块 / 今天描边），底部「取消 / 确定」与全 App 弹窗按钮一致。
Future<DateTime?> showDatePickDialog(
  BuildContext context, {
  required String title,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext ctx, Animation<double> a, Animation<double> b) =>
        _DatePickDialog(
      title: title,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(1970),
      lastDate: lastDate ?? DateTime(2100, 12, 31),
    ),
  );
}

class _DatePickDialog extends StatefulWidget {
  const _DatePickDialog({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime? initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DatePickDialog> createState() => _DatePickDialogState();
}

class _DatePickDialogState extends State<_DatePickDialog> {
  /// 当前选中日期（始终落在可选区间内）
  late final DateTime _selected;

  @override
  void initState() {
    super.initState();
    DateTime d = widget.initialDate ?? DateTime.now();
    if (d.isBefore(widget.firstDate)) d = widget.firstDate;
    if (d.isAfter(widget.lastDate)) d = widget.lastDate;
    _selected = DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final MiuixDatePickerColors dc =
        MiuixDatePickerColors.defaultColors(context);

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          // 上下留出安全区，避免小屏被状态栏 / 手势条压住
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: MediaQuery.paddingOf(context).top + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                borderRadius: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 标题 + 当前选中日期（含星期）
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: MiuixText(
                            widget.title,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.onSurfaceContainer,
                          ),
                        ),
                        MiuixText(
                          _selectedLabel,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 澎湃OS 月历：透明底，玻璃面板与极光从格子间透出
                    MiuixDatePicker(
                      initialDate: _selected,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      onDateChanged: (DateTime d) =>
                          setState(() => _selected = d),
                      colors: MiuixDatePickerColors(
                        backgroundColor: Colors.transparent,
                        headerColor: dc.headerColor,
                        weekdayColor: dc.weekdayColor,
                        weekendWeekdayColor: dc.weekendWeekdayColor,
                        dayColor: dc.dayColor,
                        weekendDayColor: dc.weekendDayColor,
                        outOfMonthDayColor: dc.outOfMonthDayColor,
                        selectedDayColor: dc.selectedDayColor,
                        selectedDayTextColor: dc.selectedDayTextColor,
                        todayBorderColor: dc.todayBorderColor,
                        disabledDayColor: dc.disabledDayColor,
                        navigationIconColor: dc.navigationIconColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: MiuixTextButton(
                            '取消',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GradientButton(
                            label: '确定',
                            onPressed: () =>
                                Navigator.of(context).pop(_selected),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 选中日期摘要：2026-10-22 · 周三
  String get _selectedLabel {
    const List<String> weeks = <String>[
      '周一', '周二', '周三', '周四', '周五', '周六', '周日',
    ];
    return '${DateUtil.format(_selected)} · ${weeks[_selected.weekday - 1]}';
  }
}

/// 表单输入框统一封装（HyperOS 风格文本框）
///
/// 【占位提示修复】flutter_miuix 的 MiuixTextField 占位标签只随内部动画
/// 控制器重建，输入文字 / 聚焦都不会触发 build，导致灰色占位文字与已输入
/// 内容重叠。这里在外层监听文字与焦点变化强制重建，并在聚焦时传入空
/// label，让灰色提示在文本框被激活的瞬间立即消失。
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.hint,
    this.onChanged,
    this.leadingIcon,
    this.trailingIcon,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? hint;
  final ValueChanged<String>? onChanged;

  /// 左侧图标（如搜索）
  final Widget? leadingIcon;

  /// 右侧图标（如日历选择器）
  final Widget? trailingIcon;

  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _focusNode.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant AppTextField old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focusNode.dispose();
    super.dispose();
  }

  /// 文字或焦点变化 → 强制外层重建，令 MiuixTextField 重新判定标签状态
  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MiuixTextField(
        // 聚焦瞬间传空 label → 内部判定 hidden → 灰色提示立即消失
        label: _focusNode.hasFocus ? '' : widget.label,
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        singleLine: true,
        onChanged: widget.onChanged,
        leadingIcon: widget.leadingIcon,
        trailingIcon: widget.trailingIcon,
        useLabelAsPlaceholder: true,
      ),
    );
  }
}

/// 【提示做成标签】左标签 + 右输入的输入框（同行左右分布）。
///
/// 编辑房间等长表单：文字框一旦输入内容，灰色占位提示就消失，这一栏是
/// 什么全靠猜。这里把提示升级为框内左侧的常驻标签（HyperOS 设置页风格），
/// 右侧才是输入区，填没填内容都能一眼看清字段含义。
class AppLabelField extends StatefulWidget {
  const AppLabelField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.trailingIcon,
    this.labelWidth = 92,
    this.caption,
    this.autofocus = false,
  });

  /// 左侧常驻标签（如「房间号」「押金」）
  final String label;

  final TextEditingController controller;

  /// 右侧输入区的灰色占位（示例值 / 单位）
  final String? hint;

  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  /// 右侧图标（如日历选择器）
  final Widget? trailingIcon;

  /// 标签列宽
  final double labelWidth;

  /// 框下方的灰色小字说明（如房租周期换算口径）
  final String? caption;

  final bool autofocus;

  @override
  State<AppLabelField> createState() => _AppLabelFieldState();
}

class _AppLabelFieldState extends State<AppLabelField> {
  final FocusNode _focusNode = FocusNode();

  bool _focus = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _focusNode.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant AppLabelField old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focusNode.dispose();
    super.dispose();
  }

  /// 文字或焦点变化 → 重建（标签高亮 / 占位提示同步）
  void _sync() {
    if (!mounted) return;
    setState(() => _focus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 标签在框外左侧，与输入框同行左右分布（不贴框、不遮内容）
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: widget.labelWidth,
                  child: MiuixText(
                    widget.label,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _focus ? c.primary : c.onSurfaceContainer,
                  ),
                ),
              ),
              Expanded(
                child: MiuixTextField(
                  // 聚焦瞬间把占位传空 → 灰色提示立即消失，不与输入内容打架
                  label: _focus ? '' : (widget.hint ?? ''),
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  singleLine: true,
                  onChanged: widget.onChanged,
                  useLabelAsPlaceholder: true,
                  trailingIcon: widget.trailingIcon,
                ),
              ),
            ],
          ),
          if (widget.caption != null)
            Padding(
              // 与输入框左缘对齐（标签宽 + 间距）
              padding: EdgeInsets.only(left: widget.labelWidth + 10, top: 5),
              child: MiuixText(
                widget.caption!,
                fontSize: 11,
                color: c.onSurfaceVariantSummary,
              ),
            ),
        ],
      ),
    );
  }
}

/// 只读展示行（用于弹窗内的计算结果）
class CalcLine extends StatelessWidget {
  const CalcLine(this.label, this.value, {super.key, this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: MiuixText(
              label,
              fontSize: 14,
              color: c.onSurfaceVariantSummary,
            ),
          ),
          MiuixText(
            value,
            fontSize: emphasis ? 17 : 14,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
            color: emphasis ? c.primary : c.onSurface,
          ),
        ],
      ),
    );
  }
}
