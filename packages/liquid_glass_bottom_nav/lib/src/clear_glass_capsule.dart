import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

/// Analytic curved glass over a continuous softened backdrop. No geometry
/// readback or displacement bitmap; the foreground controls are never filtered.
class ClearGlassCapsule extends StatefulWidget {
  const ClearGlassCapsule({
    super.key,
    this.bubble = false,
    this.held = 0,
    this.tint = const Color(0x00000000),
  });
  final bool bubble;
  final double held;
  final Color tint;
  @override
  State<ClearGlassCapsule> createState() => _ClearGlassCapsuleState();
}

class _ClearGlassCapsuleState extends State<ClearGlassCapsule> {
  static final _program = ui.FragmentProgram.fromAsset(
    'packages/liquid_glass_bottom_nav/lib/src/liquid_glass_renderer/assets/shaders/clear_capsule.frag',
  );
  ui.FragmentShader? _shader;
  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) {
      _program.then((program) {
        if (mounted) setState(() => _shader = program.fragmentShader());
      }, onError: (Object _) {});
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _shader == null
      ? (widget.bubble
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.tint,
                  borderRadius: BorderRadius.circular(100),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? const [Color(0x38FFFFFF), Color(0x24FFFFFF)]
                            : const [Color(0xB3FFFFFF), Color(0x80FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ))
      : _Lens(
          shader: _shader!,
          bubble: widget.bubble,
          held: widget.held,
          tint: widget.tint,
          ratio: MediaQuery.devicePixelRatioOf(context),
          dark: Theme.of(context).brightness == Brightness.dark,
        );
}

class _Lens extends LeafRenderObjectWidget {
  const _Lens({
    required this.shader,
    required this.ratio,
    required this.dark,
    required this.bubble,
    required this.held,
    required this.tint,
  });
  final ui.FragmentShader shader;
  final double ratio;
  final bool dark;
  final bool bubble;
  final double held;
  final Color tint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLens(shader, ratio, dark, bubble, held, tint);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLens renderObject,
  ) {
    renderObject
      ..shader = shader
      ..ratio = ratio
      ..dark = dark
      ..bubble = bubble
      ..held = held
      ..tint = tint
      ..markNeedsPaint();
  }
}

class _RenderLens extends RenderBox {
  _RenderLens(
    this.shader,
    this.ratio,
    this.dark,
    this.bubble,
    this.held,
    this.tint,
  );
  ui.FragmentShader shader;
  double ratio;
  bool dark;
  bool bubble;
  double held;
  Color tint;
  final _filter = LayerHandle<BackdropFilterLayer>();
  final _clip = LayerHandle<ClipRRectLayer>();
  @override
  bool get alwaysNeedsCompositing => true;
  @override
  void performLayout() => size = constraints.biggest;
  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    shader
      ..setFloat(2, bounds.left * ratio)
      ..setFloat(3, bounds.top * ratio)
      ..setFloat(4, bounds.width * ratio)
      ..setFloat(5, bounds.height * ratio)
      ..setFloat(6, dark ? 1 : 0)
      ..setFloat(7, bubble ? 1 : 0)
      ..setFloat(8, held)
      ..setFloat(9, ratio)
      ..setFloat(10, tint.r)
      ..setFloat(11, tint.g)
      ..setFloat(12, tint.b)
      ..setFloat(13, tint.a);
    final layer = (_filter.layer ??= BackdropFilterLayer())
      ..filter = ui.ImageFilter.compose(
        outer: ui.ImageFilter.shader(shader),
        inner: ui.ImageFilter.blur(
          sigmaX: bubble ? 1.5 : 6,
          sigmaY: bubble ? 1.5 : 6,
        ),
      );
    _clip.layer = context.pushClipRRect(
      true,
      offset,
      Offset.zero & size,
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ),
      (context, offset) => context.pushLayer(layer, (_, __) {}, offset),
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _filter.layer = null;
    _clip.layer = null;
    super.dispose();
  }
}
