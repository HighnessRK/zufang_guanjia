import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_bottom_nav/liquid_glass_bottom_nav.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/ui/settings/settings_page.dart';
import 'package:zufang_guanjia/ui/widgets/app_widgets.dart';

void main() {
  testWidgets('深浅主题选择弹窗标题都有足够对比度', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(MiuixTheme(
          data: dark ? MiuixThemeData.dark() : MiuixThemeData.light(),
          child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => showOptionPicker<String>(context,
                              title: '推理加速',
                              current: 'auto',
                              options: const [MapEntry('auto', '自动 · NPU 优先')]),
                          child: const Text('打开')))))));
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(AppModalPanel),
              matching: find.byType(BackdropFilter)),
          findsOneWidget);
      final title = tester.widget<Text>(find.text('推理加速'));
      final colors = MiuixTheme.of(tester.element(find.text('推理加速'))).colors;
      final fg = title.style!.color!.computeLuminance();
      final bg = colors.surface.computeLuminance();
      expect((fg > bg ? (fg + .05) / (bg + .05) : (bg + .05) / (fg + .05)),
          greaterThanOrEqualTo(4.5));
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    }
  });

  test('五套主按钮配色的白字对比度至少 4.5:1', () {
    for (final style in ['aurora', 'ocean', 'sunset', 'jade', 'none']) {
      for (final color in AppPalette.forStyle(style).actions) {
        expect(
            1.05 / (color.computeLuminance() + .05), greaterThanOrEqualTo(4.5),
            reason: '$style / $color');
      }
    }
  });

  testWidgets('已挂载按钮和背景同步换色，主按钮不重复模糊页面', (tester) async {
    final cfg = AppConfig.instance;
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('palette-live-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => dir.path);
      await cfg.init();
    });
    addTearDown(() async => dir.delete(recursive: true));
    await tester.pumpWidget(MiuixSystemTheme(
        child: MaterialApp(
            home: AppPaletteScope(
                child: const Scaffold(
                    body: GradientButton(label: '确认收款', onPressed: _noop))))));
    final mounted = tester.element(find.byType(GradientButton));
    List<Color> colors() => tester
        .widgetList<Container>(find.descendant(
            of: find.byType(GradientButton), matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.gradient != null)
        .gradient!
        .colors;
    for (final style in ['ocean', 'sunset', 'jade', 'none', 'aurora']) {
      await tester.runAsync(() async {
        cfg.backgroundStyle = style;
        await cfg.save();
      });
      await tester.pumpAndSettle();
      expect(colors(), AppPalette.forStyle(style).actions);
      expect(identical(mounted, tester.element(find.byType(GradientButton))),
          isTrue);
    }
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('设置中心每组设置之间都有分割线', (tester) async {
    await tester.pumpWidget(
        const MiuixSystemTheme(child: MaterialApp(home: SettingsPage())));
    await tester.pumpAndSettle();
    var groups = 0;
    for (final column in tester.widgetList<Column>(find.byType(Column))) {
      final children = column.children;
      if (children.whereType<MiuixArrowPreference>().length < 2) continue;
      groups++;
      for (var i = 1; i < children.length; i++) {
        if (children[i] is MiuixArrowPreference) {
          expect(children[i - 1], isA<MiuixHorizontalDivider>());
        }
      }
    }
    expect(groups, 2);
  });

  testWidgets('拖动预览不切页，释放到目标页，取消保持当前页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selections = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: Stack(children: [
      LiquidGlassNavBar(
        items: List.generate(
            5,
            (i) => LiquidGlassNavItem(
                id: '$i', label: '页面$i', icon: Icons.home_rounded)),
        selectedIndex: 0,
        onTap: selections.add,
        height: 60,
        maxWidth: 320,
        reduceMotion: true,
      ),
    ])));
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(const Offset(67, 798));
    await drag.moveTo(const Offset(322, 798));
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    expect(
        tester.getSize(find.byKey(const ValueKey('nav-selection-lens'))).height,
        greaterThan(60));
    await drag.up();
    await tester.pumpAndSettle();
    expect(selections, [4]);
    final cancel = await tester.startGesture(const Offset(67, 798));
    await cancel.moveTo(const Offset(196, 798));
    await tester.pumpAndSettle();
    await cancel.cancel();
    await tester.pumpAndSettle();
    expect(selections, [4]);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
