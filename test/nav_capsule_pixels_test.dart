import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_bottom_nav/liquid_glass_bottom_nav.dart';

void main() {
  testWidgets('胶囊四角没有残影，未选中项不绘制球状底色', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    const backdrop = Color(0xFF35876A);
    for (final mode in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: mode),
          home: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                  color: backdrop,
                  child: Stack(children: [
                    LiquidGlassNavBar(
                        items: const [
                          LiquidGlassNavItem(
                              id: '0', label: '首页', icon: Icons.home_rounded),
                          LiquidGlassNavItem(
                              id: '1',
                              label: '房间',
                              icon: Icons.meeting_room_rounded),
                          LiquidGlassNavItem(
                              id: '2', label: '抄表', icon: Icons.speed_rounded),
                          LiquidGlassNavItem(
                              id: '3', label: '收款', icon: Icons.wallet_rounded),
                          LiquidGlassNavItem(
                              id: '4',
                              label: '设置',
                              icon: Icons.settings_rounded)
                        ],
                        selectedIndex: 0,
                        onTap: (_) {},
                        clearGlass: true,
                        reduceMotion: true,
                        liquidActiveBubble: false,
                        height: 60,
                        maxWidth: 320,
                        insets: 16,
                        borderRadius: 30),
                  ])))));
      await tester.pumpAndSettle();
      final image = await tester.runAsync(() async => (boundary.currentContext!
              .findRenderObject()! as RenderRepaintBoundary)
          .toImage());
      final data = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      final bytes = data!.buffer.asUint8List();
      Color pixel(int x, int y) {
        final i = (y * image!.width + x) * 4;
        return Color.fromARGB(
            bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
      }

      for (final point in const [
        Offset(43, 771),
        Offset(347, 771),
        Offset(43, 825),
        Offset(347, 825)
      ]) {
        expect(pixel(point.dx.toInt(), point.dy.toInt()), backdrop,
            reason: '$mode / corner $point');
      }
      final continuousPane = pixel(35 + 64 + 32, 774);
      for (var item = 1; item < 5; item++) {
        expect(pixel(35 + item * 64 + 32, 774), continuousPane,
            reason: '$mode / inactive $item');
      }
      image!.dispose();
      expect(tester.takeException(), isNull);
    }
  });
}
