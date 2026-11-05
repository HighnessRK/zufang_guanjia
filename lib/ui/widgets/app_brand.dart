import 'package:flutter/material.dart';

/// Shared, vector-native mark: a beveled glass house over the app aurora.
class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.size = 88});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '租房管家',
      child: SizedBox.square(
          dimension: size, child: const CustomPaint(painter: _BrandPainter())));
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final frame = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(26));
    canvas.drawRRect(
        frame,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF418EFF),
                Color(0xFF6458DF),
                Color(0xFFCA87BD)
              ]).createShader(frame.outerRect));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 1, 98, 98), const Radius.circular(25)),
        Paint()
          ..color = Colors.white.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
