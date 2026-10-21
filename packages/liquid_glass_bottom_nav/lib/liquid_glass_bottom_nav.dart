import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'src/liquid_glass_renderer/liquid_glass_renderer.dart'
    show LiquidGlass, LiquidGlassSettings, LiquidRoundedSuperellipse,
        GlassGlow, GlassGlowLayer, LiquidGlassLayer;
import 'src/liquid_glass_renderer/src/liquid_glass_render_scope.dart'
    show LiquidGlassRenderScope;

export 'src/liquid_glass_renderer/liquid_glass_renderer.dart'
    show LiquidGlassLayer, LiquidGlassSettings;

class LiquidGlassNavItem {
  final String id;
  final String label;

  /// Material/Cupertino icon. Required unless [iconWidget] is provided.
  final IconData? icon;

  /// Custom icon widget. Takes priority over [icon] when provided.
  /// Wrapped in [IconTheme] so widgets that respect it (Icon, SvgPicture, etc.)
  /// automatically inherit the active/inactive color.
  final Widget? iconWidget;

  /// Notification count shown as a small badge on the icon's top-right corner.
  /// Null or <= 0 hides the badge. Values above 99 display as "99+".
  final int? badgeCount;

  /// Background color of the badge. Defaults to [ColorScheme.error].
  final Color? badgeColor;

  /// Text color of the badge count. Defaults to [ColorScheme.onError].
  final Color? badgeTextColor;

  /// Corner radius of the badge shape. Defaults to 999 (fully rounded).
  final double badgeBorderRadius;

  const LiquidGlassNavItem({
    required this.id,
    required this.label,
    this.icon,
    this.iconWidget,
    this.badgeCount,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeBorderRadius = 999,
  }) : assert(
          icon != null || iconWidget != null,
          'LiquidGlassNavItem requires either icon or iconWidget.',
        );
}

/// Small pill/circle badge overlaid on a nav item's icon to show [badgeCount].
class _NavBadge extends StatelessWidget {
  final int count;
  final Color color;
  final Color textColor;
  final double borderRadius;

  const _NavBadge({
    required this.count,
    required this.color,
    required this.textColor,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: label.length > 1
          ? const EdgeInsets.symmetric(horizontal: 4)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Overlays [icon] with a [_NavBadge] when [item.badgeCount] is set.
/// Shared by both [_LiquidGlassNavBarState] and [_LegacyNavBar] so the badge
/// looks identical on Impeller and legacy fallback devices.
Widget _iconWithBadge(BuildContext context, LiquidGlassNavItem item, Widget icon) {
  final count = item.badgeCount;
  if (count == null || count <= 0) return icon;

  final colorScheme = Theme.of(context).colorScheme;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      icon,
      Positioned(
        top: -4,
        right: -6,
        child: _NavBadge(
          count: count,
          color: item.badgeColor ?? colorScheme.error,
          textColor: item.badgeTextColor ?? colorScheme.onError,
          borderRadius: item.badgeBorderRadius,
        ),
      ),
    ],
  );
}

/// Floating pill bottom navigation bar with a sliding glass bubble indicator.
///
/// On Impeller-capable devices the active indicator is an [AnimatedPositioned]
/// bubble that bounces between tabs on tap and follows a drag when the user
/// long-presses and slides. Falls back to [_LegacyNavBar] on devices without
/// Impeller/Vulkan support (Android API < 24) or if [impellerSupported] is false.
class LiquidGlassNavBar extends StatefulWidget {
  final List<LiquidGlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  
  /// Whether the device supports Impeller rendering. Defaults to true.
  final bool impellerSupported;

  /// Icon and label color for the selected tab.
  /// Defaults to [ColorScheme.primary].
  final Color? activeColor;

  /// Icon and label color for unselected tabs.
  /// Defaults to [ColorScheme.onSurface].
  final Color? inactiveColor;

  /// Size of the icon in each tab. Defaults to 22.
  final double iconSize;

  /// Label style applied to all tab labels.
  /// Merged over [TextTheme.bodySmall] — only the properties you set override
  /// the defaults. Color is always driven by [activeColor] / [inactiveColor].
  final TextStyle? labelStyle;

  /// Inset padding (default is 16.0)
  final double insets;

  /// Height of the floating capsule in logical pixels. Defaults to 68.0.
  /// Lower values (e.g. 60) give a slimmer, more compact Pronto-style bar.
  final double height;

  /// Optional maximum width for the capsule. When set, the bar is centered
  /// horizontally and capped at this width (never wider than the screen
  /// minus [insets] on each side). Null = full width minus insets (legacy
  /// behaviour).
  final double? maxWidth;

  /// Corner radius of the floating capsule. Defaults to 34.0, which — at the
  /// fixed 68px bar height — renders as a full stadium/pill shape. Lower
  /// values produce a squarer capsule; the active tab bubble follows the same
  /// radius so its shape always matches the capsule around it.
  ///
  /// Only affects the Impeller-rendered capsule. [_LegacyNavBar] (used when
  /// [impellerSupported] is false) is a full-width bar with no capsule shape,
  /// so this has no effect there.
  final double borderRadius;

  /// When true, the held bubble's border is a soft iridescent sheen instead
  /// of the default light gray stroke. Defaults to `false`.
  final bool dragRainbowBorder;

  /// When true, the bubble renders as a real [LiquidGlass] shape (its own
  /// GPU layer, actual frosted refraction) instead of a plain tinted
  /// [BoxDecoration] — but only while actively held/dragging. The resting
  /// (selected-but-not-dragging) bubble always stays the plain tinted
  /// container regardless of this flag. Defaults to `true`.
  ///
  /// While held, this bubble's position and size animate every drag frame
  /// — enabling this means the glass shader recomputes (`toImageSync()`)
  /// every one of those frames, which is exactly the per-frame shader cost
  /// this package otherwise avoids by keeping all glass shapes static (see
  /// the package-level renderer performance notes). If you see jank while
  /// holding a tab on low-end Android hardware, set this to `false` to fall
  /// back to the plain tinted container.
  final bool liquidActiveBubble;

  /// Vertical space the floating nav occupies above the system bottom inset.
  /// Tab screens with scrollable content should add this as bottom padding.
  /// Composition: pill height 68 + bottom margin 16 + 12px breathing buffer = 96.0.
  static const double contentBottomInset = 96.0;

  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.impellerSupported = true,
    this.activeColor,
    this.inactiveColor,
    this.iconSize = 22.0,
    this.labelStyle,
    this.insets = 16.0,
    this.height = 68.0,
    this.maxWidth,
    this.borderRadius = 34.0,
    this.dragRainbowBorder = false,
    this.liquidActiveBubble = true,
  });

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

/// Soft iridescent "soap bubble" sheen drawn around the held bubble during
/// drag, in place of a tinted [activeColor] stroke: a blurred pastel sweep
/// gradient rim plus a glossy specular highlight near the top-left. No
/// animation — painted once per rebuild, so it adds no per-frame cost beyond
/// the drag rebuilds that already happen.
class _RainbowRingPainter extends CustomPainter {
  final double borderRadius;

  const _RainbowRingPainter({required this.borderRadius});

  static const double _strokeWidth = 1.5;

  // The pill is wide and short, so its ring is dominated by the left and
  // right arcs (top/bottom are compressed). A single pass around the wheel
  // put unrelated hues opposite each other -- mint on the right, lavender/
  // pink on the left -- reading as a hard two-tone split instead of a blend.
  // Repeating the same 5-hue cycle twice around the sweep gives it 2-fold
  // symmetry (same color at 0° and 180°), so left and right always show a
  // matching progression, while keeping the full pastel palette. Alpha
  // ~50% so the sheen blends into the capsule instead of reading as a
  // solid rainbow ring.
  static const _colors = [
    Color(0x80BFF0DC), // mint
    Color(0x80C6E3F7), // pale blue
    Color(0x80D9CCF5), // lavender
    Color(0x80F7CCE3), // pink
    Color(0x80FAE3C2), // peach
    Color(0x80BFF0DC), // mint (halfway repeat)
    Color(0x80C6E3F7), // pale blue
    Color(0x80D9CCF5), // lavender
    Color(0x80F7CCE3), // pink
    Color(0x80FAE3C2), // peach
    Color(0x80BFF0DC), // wrap back to mint
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(_strokeWidth / 2),
      Radius.circular(borderRadius),
    );

    // Soft pastel rim, blurred like a soap-bubble edge instead of a hard line.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..shader = const SweepGradient(colors: _colors).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    canvas.drawRRect(rrect, ringPaint);

    // Glossy specular highlight, like the bright spot on a glass sphere.
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.5),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.28, size.height * 0.22),
          radius: size.shortestSide * 0.35,
        ),
      );
    canvas.drawRRect(rrect, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _RainbowRingPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with SingleTickerProviderStateMixin {
  // Vertical squash for the held bubble: 0 = neutral, 1 = max squish. Tracks
  // the *magnitude* of horizontal drag movement continuously (direction-
  // independent, so it looks the same sliding either way — no rotation/skew
  // at all). Once the finger pauses, it springs back to neutral via
  // easeOutBack, which overshoots slightly past 1.0 before settling for a
  // natural bounce feel.
  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    value: 0.0,
  );
  Timer? _bounceDecayTimer;

  int? _dragIndex;
  double? _dragX;

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _bounceDecayTimer?.cancel();
    super.dispose();
  }

  int _indexFromX(double x, double itemWidth) =>
      (x / itemWidth).floor().clamp(0, widget.items.length - 1);

  @override
  Widget build(BuildContext context) {
    if (!widget.impellerSupported) {
      return _LegacyNavBar(
        items: widget.items,
        selectedIndex: widget.selectedIndex,
        onTap: widget.onTap,
        activeColor: widget.activeColor,
        inactiveColor: widget.inactiveColor,
        iconSize: widget.iconSize,
        labelStyle: widget.labelStyle,
        insets: widget.insets,
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalMargin = screenWidth < 360 ? widget.insets / 2 : widget.insets;
    final activeColor = widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final inactiveColor = widget.inactiveColor ?? Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Compact centered capsule: cap at maxWidth (Pronto-style floating pill)
    // while never exceeding the screen minus the side insets.
    final availableWidth = screenWidth - horizontalMargin * 2;
    final barWidth = widget.maxWidth == null
        ? availableWidth
        : math.min<double>(availableWidth, widget.maxWidth!);

    return Positioned(
      left: horizontalMargin,
      right: horizontalMargin,
      bottom: bottomPadding + widget.insets,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: barWidth,
          child: Container(
        decoration: ShapeDecoration(
          shape: LiquidRoundedSuperellipse(borderRadius: widget.borderRadius),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 0,
              spreadRadius: 1,
            ),
            BoxShadow(
              // 抬升投影：胶囊悬浮感（对齐大狗记 Pronto 的柔和深影）
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                foregroundDecoration: ShapeDecoration(
                  shape: LiquidRoundedSuperellipse(
                    borderRadius: widget.borderRadius,
                    side: BorderSide(
                      // 白色亮边定义胶囊轮廓：深色模式下 0.08 几乎不可见
                      // （质感发闷），提至 0.20 让玻璃边缘清晰「立起来」；
                      // 浅色模式维持强白边（mirrors iOS behaviour）。
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.white.withValues(alpha: 0.55),
                      width: 1.0,
                    ),
                  ),
                ),
                child: LiquidGlass.withOwnLayer(
                  shape: LiquidRoundedSuperellipse(borderRadius: widget.borderRadius),
                  settings: LiquidGlassSettings(
                    // 深色模式：白染 0.04 几乎无玻璃感、highlight 几乎熄灭，
                    // 胶囊像一块闷黑污渍；提亮染色 / 高光 / 环境光，配合
                    // 亮边与投影，达到大狗记 Pronto 那种通透「浮起」的质感。
                    // Light mode: high white tint for vibrancy, blur kept at 1
                    // so the capsule reads as clean white without any fogging.
                    glassColor: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.76),
                    thickness: 32,
                    blur: 1,
                    saturation: 1.8,
                    lightIntensity: isDark ? 0.55 : 1.0,
                    ambientStrength: isDark ? 0.32 : 0.2,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            SizedBox(
              height: widget.height,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / widget.items.length;
                  final displayIndex = _dragIndex ?? widget.selectedIndex;
                  final isDragging = _dragIndex != null;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      widget.onTap(
                        _indexFromX(details.localPosition.dx, itemWidth),
                      );
                    },
                    onHorizontalDragStart: (details) {
                      final x = details.localPosition.dx;
                      final index = _indexFromX(x, itemWidth);
                      setState(() {
                        _dragIndex = index;
                        _dragX = x;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      final x = details.localPosition.dx;
                      final index = _indexFromX(x, itemWidth);
                      setState(() {
                        _dragIndex = index;
                        _dragX = x;
                      });

                      // Direction-independent: only how far the finger moved
                      // this frame drives the squish, so it bounces the same
                      // regardless of which way you slide.
                      final targetSquish = (details.delta.dx.abs() / 6.0).clamp(0.0, 1.0);
                      _bounceCtrl.animateTo(
                        targetSquish,
                        duration: const Duration(milliseconds: 90),
                        curve: Curves.easeOut,
                      );

                      // Spring back to neutral once the finger settles.
                      _bounceDecayTimer?.cancel();
                      _bounceDecayTimer = Timer(const Duration(milliseconds: 80), () {
                        if (mounted) {
                          _bounceCtrl.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutBack,
                          );
                        }
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      if (_dragIndex != null) widget.onTap(_dragIndex!);
                      setState(() {
                        _dragIndex = null;
                        _dragX = null;
                      });
                      _bounceDecayTimer?.cancel();
                      _bounceCtrl.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                      );
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _dragIndex = null;
                        _dragX = null;
                      });
                      _bounceDecayTimer?.cancel();
                      _bounceCtrl.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Builder(
                          builder: (context) {
                            // Normal state: Original stadium pill capsule
                            final normalWidth = itemWidth - 8; 
                            final normalHeight =
                                widget.height - 10.0; // Fills most of the capsule
                            final normalTop =
                                (widget.height - normalHeight) / 2;
                            final normalLeft = displayIndex * itemWidth + 4.0;

                            // Held state: Enlarged capsule (maintains horizontal pill shape)
                            final heldWidth = itemWidth + 16.0; 
                            final heldHeight = widget.height +
                                12.0; // Overlaps top and bottom of the bar
                            final heldTop = (widget.height - heldHeight) / 2;
                            
                            // Track exact finger position clamped within the bar bounds
                            final exactCenterX = _dragX?.clamp(0.0, constraints.maxWidth) 
                                ?? (displayIndex * itemWidth + itemWidth / 2);
                            final heldLeft = exactCenterX - (heldWidth / 2);

                            return AnimatedPositioned(
                              duration: Duration(
                                // Shorter duration for position changes when dragging so it tightly tracks the finger
                                milliseconds: isDragging ? 50 : 400,
                              ),
                              curve: isDragging ? Curves.easeOut : Curves.elasticOut,
                              left: isDragging ? heldLeft : normalLeft,
                              width: isDragging ? heldWidth : normalWidth,
                              top: isDragging ? heldTop : normalTop,
                              height: isDragging ? heldHeight : normalHeight,
                              child: AnimatedBuilder(
                                animation: _bounceCtrl,
                                builder: (context, child) {
                                  final scaleY = 1.0 - _bounceCtrl.value * 0.12;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.diagonal3Values(1.0, scaleY, 1.0),
                                    child: child,
                                  );
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (widget.liquidActiveBubble && isDragging)
                                      // Real glass shape, only while held — its position/size
                                      // animate every drag frame, so the shader recomputes
                                      // every one of those frames. See the doc comment on
                                      // [LiquidGlassNavBar.liquidActiveBubble]. The resting
                                      // (non-dragging) active bubble always stays the plain
                                      // tinted container below.
                                      LiquidGlass.withOwnLayer(
                                        shape: LiquidRoundedSuperellipse(
                                          borderRadius: widget.borderRadius,
                                        ),
                                        settings: LiquidGlassSettings(
                                          glassColor: Colors.transparent,
                                          thickness: 32,
                                          blur: 1,
                                          saturation: 1.8,
                                          // 拖动中的气泡与静止胶囊同款提亮
                                          lightIntensity: isDark ? 0.55 : 1.0,
                                          ambientStrength:
                                              isDark ? 0.32 : 0.2,
                                        ),
                                        child: const SizedBox.expand(),
                                      )
                                    else
                                      AnimatedContainer(
                                        duration: Duration(
                                          milliseconds: isDragging ? 150 : 400,
                                        ),
                                        curve: isDragging ? Curves.easeOut : Curves.elasticOut,
                                        decoration: BoxDecoration(
                                          // No tint while held — the light gray stroke (or the
                                          // rainbow sheen, if opted into) is the only drag-state
                                          // accent.
                                          color: isDragging
                                              ? Colors.transparent
                                              : (isDark
                                                  // 激活气泡略提亮：与大狗记一致，
                                                  // 选中态在胶囊里清晰可辨
                                                  ? Colors.white.withValues(alpha: 0.12)
                                                  : activeColor.withValues(alpha: 0.15)),
                                          borderRadius: BorderRadius.circular(widget.borderRadius),
                                        ),
                                      ),
                                    // Stroke overlay lives outside the bubble-content branch
                                    // above so it shows the same way whether the bubble itself
                                    // is the real LiquidGlass shape or the plain tinted
                                    // container.
                                    if (isDragging && !widget.dragRainbowBorder)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(widget.borderRadius),
                                              border: Border.all(
                                                color: Colors.grey.shade500.withValues(alpha: 0.55),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isDragging && widget.dragRainbowBorder)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _RainbowRingPainter(
                                              borderRadius: widget.borderRadius,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                        ),
                        Row(
                          children: List.generate(widget.items.length, (index) {
                            final item = widget.items[index];
                            final bool isActive = index == displayIndex;
                            final color = isActive ? activeColor : inactiveColor;
                            return SizedBox(
                              width: itemWidth,
                              height: widget.height,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _iconWithBadge(
                                    context,
                                    item,
                                    IconTheme(
                                      data: IconThemeData(
                                        color: color,
                                        size: widget.iconSize,
                                      ),
                                      child: item.iconWidget ??
                                          Icon(
                                            item.icon,
                                            size: widget.iconSize,
                                            color: color,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.merge(widget.labelStyle)
                                        .copyWith(color: color, fontWeight: widget.labelStyle?.fontWeight ?? FontWeight.w500),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy fallback — identical visuals to the pre-existing flat white nav bar.
// ---------------------------------------------------------------------------

class _LegacyNavBar extends StatelessWidget {
  final List<LiquidGlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;
  final Color? inactiveColor;
  final double iconSize;
  final TextStyle? labelStyle;
  final double insets;

  const _LegacyNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
    required this.iconSize,
    this.labelStyle,
    required this.insets,
  });

  @override
  Widget build(BuildContext context) {
    final themeActiveColor = activeColor ?? Theme.of(context).colorScheme.primary;
    final themeInactiveColor = inactiveColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: insets * 0.625, // AppSpacing.sm is ~10 which is 16 * 0.625
          vertical: insets * 0.625,
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final bool isActive = index == selectedIndex;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(insets),
                onTap: () => onTap(index),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: insets * 0.375), // AppSpacing.xs is ~6
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconWithBadge(
                        context,
                        item,
                        IconTheme(
                          data: IconThemeData(
                            color: isActive ? themeActiveColor : themeInactiveColor,
                            size: iconSize,
                          ),
                          child: item.iconWidget ??
                              Icon(
                                item.icon,
                                size: iconSize,
                                color: isActive ? themeActiveColor : themeInactiveColor,
                              ),
                        ),
                      ),
                      SizedBox(height: insets * 0.375),
                      Text(
                        item.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.merge(labelStyle)
                            .copyWith(
                              color: isActive ? themeActiveColor : themeInactiveColor,
                              fontWeight: labelStyle?.fontWeight ?? FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: insets * 0.625 - 2), // AppSpacing.sm - 2 = 8
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: isActive ? 28.0 : 0.0,
                        decoration: BoxDecoration(
                          color: isActive ? themeActiveColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LiquidGlassBackButton
// ---------------------------------------------------------------------------

/// A floating frosted-glass back button with a chevron icon.
///
/// The glass shape is always static — press feedback is handled by a plain
/// Flutter [AnimatedScale] so no shader cost occurs during interaction.
///
/// Falls back to a plain [IconButton] when [impellerSupported] is false.
class LiquidGlassBackButton extends StatefulWidget {
  /// Called when the button is tapped. Defaults to [Navigator.maybePop].
  final VoidCallback? onTap;

  /// Color of the chevron icon. Defaults to [ColorScheme.onSurface].
  final Color? color;

  /// The icon to display. Defaults to [Icons.chevron_left_rounded].
  final IconData icon;

  /// Size of the glass pill. Defaults to 44.
  final double size;

  /// Corner radius of the glass shape. Defaults to 14.
  final double borderRadius;

  /// Whether the device supports Impeller. Defaults to true.
  final bool impellerSupported;

  /// When false, joins the nearest ancestor [LiquidGlassLayer] instead of
  /// creating its own. Use this when the button is grouped with other glass
  /// elements under a shared [LiquidGlassLayer] — reduces N GPU layers to 1.
  /// Falls back to own layer if no ancestor [LiquidGlassLayer] is found.
  final bool ownLayer;

  /// When true, renders the cheap [FakeGlass] approximation instead of the real
  /// refraction shader — no geometry shader, no per-frame transform tracking.
  /// Prefer this when the button sits on a flat/solid background (e.g. a
  /// gradient header) or inside scrolling/paging content, where the real
  /// effect is both invisible (nothing to refract) and a per-frame cost.
  final bool fake;

  const LiquidGlassBackButton({
    super.key,
    this.onTap,
    this.color,
    this.icon = Icons.chevron_left_rounded,
    this.size = 44.0,
    this.borderRadius = 14.0,
    this.impellerSupported = true,
    this.ownLayer = true,
    this.fake = false,
  });

  @override
  State<LiquidGlassBackButton> createState() => _LiquidGlassBackButtonState();
}

class _LiquidGlassBackButtonState extends State<LiquidGlassBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 200),
    lowerBound: 0.88,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressCtrl.reverse();
  void _onTapUp(_) => _pressCtrl.forward();
  void _onTapCancel() => _pressCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.color ?? Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.impellerSupported) {
      return IconButton(
        onPressed: widget.onTap ?? () => Navigator.of(context).maybePop(),
        icon: Icon(widget.icon, color: iconColor),
      );
    }

    final glassShape = LiquidRoundedSuperellipse(borderRadius: widget.borderRadius);
    final hasParentLayer = !widget.ownLayer &&
        LiquidGlassRenderScope.maybeOf(context) != null;

    final glassIcon = SizedBox.expand(
      child: Icon(widget.icon, size: widget.size * 0.55, color: iconColor),
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap ?? () => Navigator.of(context).maybePop(),
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) => Transform.scale(
          scale: _pressCtrl.value,
          child: child,
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: ShapeDecoration(
            shape: glassShape,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 0,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: glassShape),
            child: GlassGlowLayer(
              child: GlassGlow(
                glowColor: Colors.white.withValues(alpha: 0.35),
                glowRadius: 1.2,
                child: hasParentLayer
                    ? LiquidGlass(shape: glassShape, child: glassIcon)
                    : LiquidGlass.withOwnLayer(
                        shape: glassShape,
                        fake: widget.fake,
                        settings: LiquidGlassSettings(
                          glassColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.05),
                          thickness: 32,
                          blur: 1,
                          saturation: 1.8,
                          lightIntensity: isDark ? 0.15 : 0.9,
                          ambientStrength: 0.2,
                        ),
                        child: glassIcon,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LiquidGlassContainer
// ---------------------------------------------------------------------------

/// A general-purpose frosted-glass container.
///
/// Can be used to wrap any widget with the liquid glass effect.
/// If [onTap] is provided, it acts as a button with scale animation.
class LiquidGlassContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool impellerSupported;

  /// Glass tint color. Alpha controls opacity of the tint.
  ///
  /// For iOS-native-style colored material (e.g. dark gray widgets), set this
  /// to the desired color with alpha ~0.6–0.8 and pair with [blur] ≥ 20 and
  /// [saturation] ≥ 2.0.
  final Color? color;

  /// Solid fill painted inside the glass shape, beneath the content.
  ///
  /// Use this when you want a solid background (e.g. white cards) while
  /// still keeping glass edge glow and refraction effects at the border.
  /// Unlike [color] (which is a shader tint), this is a true opaque fill.
  final Color? backgroundColor;

  final double? blur;
  final double? lightIntensity;
  final double? ambientStrength;

  /// Saturation of content visible through the glass (vibrancy).
  ///
  /// 1.0 = no change. Values > 1.0 boost saturation (iOS vibrancy look).
  /// Defaults to 1.8. Set to 2.5+ for the iOS native material appearance.
  final double? saturation;

  /// Thickness of the glass surface (controls refraction strength).
  /// Defaults to 32.
  final double? thickness;

  /// When false, the container joins an ancestor [LiquidGlassLayer] instead
  /// of creating its own layer. Falls back to own layer if no ancestor exists.
  /// Use this when grouping many containers for better performance.
  final bool ownLayer;

  /// When true, renders the cheap [FakeGlass] approximation instead of the real
  /// refraction shader. [FakeGlass] skips the geometry shader and per-frame
  /// transform tracking entirely, so it stays smooth inside scrolling/paging
  /// content and does not distort under overscroll stretch.
  ///
  /// Use this for glass placed over a flat/solid background (e.g. a gradient
  /// header), where real refraction has nothing meaningful to refract and the
  /// result is visually indistinguishable from the cheap path. Reserve the real
  /// effect ([fake] = false) for glass floating over varied content.
  final bool fake;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.onTap,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = 14.0,
    this.impellerSupported = true,
    this.color,
    this.backgroundColor,
    this.blur,
    this.lightIntensity,
    this.ambientStrength,
    this.saturation,
    this.thickness,
    this.ownLayer = true,
    this.fake = false,
  });

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 200),
    lowerBound: 0.95,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressCtrl.reverse();
  void _onTapUp(_) => _pressCtrl.forward();
  void _onTapCancel() => _pressCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = widget.child;
    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }

    // Solid fill beneath the content — true opaque background independent
    // of the glass tint shader. Painted here so both Impeller and legacy
    // paths benefit.
    if (widget.backgroundColor != null) {
      content = ColoredBox(color: widget.backgroundColor!, child: content);
    }

    if (!widget.impellerSupported) {
      final plainContainer = Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor ??
              widget.color ??
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: widget.backgroundColor != null ? widget.child : content,
      );

      if (widget.onTap != null) {
        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: plainContainer,
        );
      }
      return plainContainer;
    }

    final glassShape = LiquidRoundedSuperellipse(borderRadius: widget.borderRadius);

    // Use parent layer if available and ownLayer is false — much cheaper
    // when many containers are grouped (e.g. a grid of cards).
    final hasParentLayer = !widget.ownLayer &&
        LiquidGlassRenderScope.maybeOf(context) != null;

    final glassSettings = LiquidGlassSettings(
      glassColor: widget.color ?? (isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.05)),
      thickness: widget.thickness ?? 32,
      blur: widget.blur ?? 1,
      saturation: widget.saturation ?? 1.8,
      lightIntensity: widget.lightIntensity ?? (isDark ? 0.15 : 0.9),
      ambientStrength: widget.ambientStrength ?? 0.2,
    );

    final container = Container(
      width: widget.width,
      height: widget.height,
      decoration: ShapeDecoration(
        shape: glassShape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 0,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: glassShape),
        child: GlassGlowLayer(
          child: GlassGlow(
            glowColor: Colors.white.withValues(alpha: 0.35),
            glowRadius: 1.2,
            child: hasParentLayer
                ? LiquidGlass(
                    shape: glassShape,
                    child: content,
                  )
                : LiquidGlass.withOwnLayer(
                    shape: glassShape,
                    settings: glassSettings,
                    fake: widget.fake,
                    child: content,
                  ),
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pressCtrl,
          builder: (context, child) => Transform.scale(
            scale: _pressCtrl.value,
            child: child,
          ),
          child: container,
        ),
      );
    }

    return container;
  }
}
