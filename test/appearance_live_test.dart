import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/ui/widgets/app_widgets.dart';

void main() {
  testWidgets('已挂载的 const 背景即时响应光效设置和系统明暗变化', (tester) async {
    final cfg = AppConfig.instance;
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('appearance-live-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => dir.path);
      await cfg.init();
    });
    addTearDown(() async => dir.delete(recursive: true));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(MiuixThemeController(
        child: Builder(
            builder: (ctx) => MaterialApp(
                theme: ThemeData(brightness: MiuixTheme.of(ctx).brightness),
                home: const Scaffold(
                    body: AuroraBackground(key: ValueKey('ambient')))))));
    final mounted = tester.element(find.byKey(const ValueKey('ambient')));
    List<Color> palette() => tester
        .widgetList<Container>(find.descendant(
            of: find.byKey(const ValueKey('ambient')),
            matching: find.byType(Container)))
        .map((v) =>
            ((v.decoration! as BoxDecoration).gradient! as RadialGradient)
                .colors
                .first)
        .toList();
    final initial = palette();
    for (final style in ['ocean', 'sunset', 'jade', 'aurora']) {
      final before = palette();
      await tester.runAsync(() async {
        cfg.backgroundStyle = style;
        await cfg.save();
      });
      await tester.pump();
      expect(palette(), isNot(before));
      expect(
          identical(
              mounted, tester.element(find.byKey(const ValueKey('ambient')))),
          isTrue);
    }
    expect(palette(), initial);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(palette().first.a, lessThan(initial.first.a));
    await tester.runAsync(() async {
      cfg.backgroundStyle = 'none';
      await cfg.save();
    });
    await tester.pump();
    expect(palette(), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
