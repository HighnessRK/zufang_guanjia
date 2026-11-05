import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';

/// Shared, vector-native mark: a beveled glass house over the app aurora.
class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.size = 88, this.style});
  final String? style;
  final double size;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: AppConfig.instance,
      builder: (_, __) => Semantics(
          label: '租房管家',
          child: SizedBox.square(
              dimension: size,
              child: CustomPaint(
                  painter:
                      _BrandPainter(style ?? AppConfig.instance.iconStyle)))));
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter(this.style);
  final String style;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final frame = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(26));
    canvas.drawRRect(
        frame,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: switch (style) {
                    'ocean' => const [
                        Color(0xFF0B9BE1),
                        Color(0xFF1258AA),
                        Color(0xFF57D5D5)
                      ],
                    'sunset' => const [
                        Color(0xFFFFB76B),
                        Color(0xFFE97878),
                        Color(0xFFAF71BC)
                      ],
                    'jade' => const [
                        Color(0xFF3DC9AC),
                        Color(0xFF278879),
                        Color(0xFF8EC9B9)
                      ],
                    'mono' => const [
                        Color(0xFF657288),
                        Color(0xFF283345),
                        Color(0xFF121B28)
                      ],
                    'lavender' => const [
                        Color(0xFFB49AEF),
                        Color(0xFF7565B6),
                        Color(0xFFD4BDF4)
                      ],
                    'coral' => const [
                        Color(0xFFFF9C99),
                        Color(0xFFD76E87),
                        Color(0xFFFFC7AD)
                      ],
                    'amber' => const [
                        Color(0xFFF4C96B),
                        Color(0xFFC58F47),
                        Color(0xFFEDB784)
                      ],
                    _ => const [
                        Color(0xFF418EFF),
                        Color(0xFF6458DF),
                        Color(0xFFCA87BD)
                      ],
                  })
              .createShader(frame.outerRect));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 1, 98, 98), const Radius.circular(25)),
        Paint()
          ..color = Colors.white.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    if (style == 'lavender' || style == 'coral' || style == 'amber') {
      final ink = Paint()..color = Colors.white.withValues(alpha: .88);
      if (style == 'lavender') {
        final moon = Path.combine(
            PathOperation.difference,
            Path()..addOval(const Rect.fromLTWH(21, 20, 27, 27)),
            Path()..addOval(const Rect.fromLTWH(31, 15, 27, 27)));
        canvas.drawPath(moon, ink);
        canvas.drawPath(
            Path()
              ..moveTo(30, 63)
              ..lineTo(57, 39)
              ..lineTo(81, 63),
            ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(39, 60, 34, 24), const Radius.circular(5)),
            ink..style = PaintingStyle.fill);
      } else if (style == 'coral') {
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(24, 24, 52, 52), const Radius.circular(14)),
            ink);
        canvas.drawLine(const Offset(50, 25), const Offset(50, 75), ink);
        canvas.drawLine(const Offset(25, 50), const Offset(75, 50), ink);
      } else {
        canvas.drawPath(
            Path()
              ..moveTo(28, 80)
              ..lineTo(28, 46)
              ..arcToPoint(const Offset(72, 46),
                  radius: const Radius.circular(22))
              ..lineTo(72, 80)
              ..close(),
            ink);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(39, 44, 23, 36), const Radius.circular(11)),
            Paint()..color = const Color(0xFFC58F47));
        canvas.drawCircle(
            const Offset(56, 64), 2.5, Paint()..color = Colors.white);
      }
      canvas.restore();
      return;
    }
    if (style == 'ocean') {
      final ink = Paint()
        ..color = const Color(0xFFE1F6FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(const Offset(39, 38), 15, ink);
      canvas.drawPath(
          Path()
            ..moveTo(50, 50)
            ..lineTo(73, 73)
            ..moveTo(63, 63)
            ..lineTo(70, 56)
            ..moveTo(69, 69)
            ..lineTo(76, 62),
          ink);
      canvas.restore();
      return;
    }
    if (style == 'sunset') {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(29, 20, 43, 61), const Radius.circular(9)),
          Paint()..color = Colors.white.withValues(alpha: .8));
      final ink = Paint()..color = const Color(0xFFC97A89);
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 2; col++) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(38 + col * 16, 31 + row * 13, 8, 7),
                  const Radius.circular(2)),
              ink);
        }
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(46, 68, 10, 13), const Radius.circular(3)),
          ink);
      canvas.restore();
      return;
    }
    final house = Path()
      ..moveTo(21, 46)
      ..lineTo(46, 23)
      ..quadraticBezierTo(50, 19, 54, 23)
      ..lineTo(79, 46)
      ..quadraticBezierTo(82, 50, 78, 53)
      ..lineTo(73, 53)
      ..lineTo(73, 74)
      ..quadraticBezierTo(73, 80, 67, 80)
      ..lineTo(33, 80)
      ..quadraticBezierTo(27, 80, 27, 74)
      ..lineTo(27, 53)
      ..lineTo(22, 53)
      ..quadraticBezierTo(18, 50, 21, 46)
      ..close();
    if (style == 'mono') {
      canvas.drawPath(
          house,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(43, 55, 14, 25), const Radius.circular(5)),
          Paint()..color = Colors.white.withValues(alpha: .7));
      canvas.restore();
      return;
    }
    canvas.drawPath(
        house.shift(const Offset(0, 3)),
        Paint()
          ..color = const Color(0xFF283C93).withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(
        house,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xBFF8FDFF), Color(0x38B9DAFF)])
              .createShader(const Rect.fromLTWH(20, 20, 60, 60)));
    canvas.drawPath(
        house,
        Paint()
          ..color = Colors.white.withValues(alpha: .72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.drawPath(
        Path()
          ..moveTo(25, 48)
          ..lineTo(50, 26)
          ..lineTo(75, 48),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(43, 54, 14, 26), const Radius.circular(5)),
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFF687AE7), Color(0xFF4678DB)])
              .createShader(const Rect.fromLTWH(43, 54, 14, 26)));
    canvas.drawCircle(
        const Offset(52, 66), 1.5, Paint()..color = const Color(0xFFE2F4FF));
    canvas.drawCircle(const Offset(77, 25), 4,
        Paint()..color = Colors.white.withValues(alpha: .8));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandPainter oldDelegate) =>
      oldDelegate.style != style;
}
