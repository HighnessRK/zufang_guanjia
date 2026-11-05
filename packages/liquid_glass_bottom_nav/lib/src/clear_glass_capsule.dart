import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

/// One analytic lens pass. No geometry readback, blur, or displacement bitmap.
class ClearGlassCapsule extends StatefulWidget {
  const ClearGlassCapsule({super.key});
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
      ? const SizedBox.expand()
      : _Lens(
          shader: _shader!,
          ratio: MediaQuery.devicePixelRatioOf(context),
          dark: Theme.of(context).brightness == Brightness.dark,
        );
}

class _Lens extends LeafRenderObjectWidget {
  const _Lens({required this.shader, required this.ratio, required this.dark});
  final ui.FragmentShader shader;
  final double ratio;
  final bool dark;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLens(shader, ratio, dark);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLens renderObject,
  ) {
    renderObject
      ..shader = shader
      ..ratio = ratio
      ..dark = dark
      ..markNeedsPaint();
  }
}

class _RenderLens extends RenderBox {
  _RenderLens(this.shader, this.ratio, this.dark);
  ui.FragmentShader shader;
  double ratio;
  bool dark;
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
      ..setFloat(6, dark ? 1 : 0);
    final layer = (_filter.layer ??= BackdropFilterLayer())
      ..filter = ui.ImageFilter.shader(shader);
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
