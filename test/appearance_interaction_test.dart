import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/ui/settings/appearance_settings_page.dart';
import 'package:zufang_guanjia/ui/widgets/app_brand.dart';

void main() {
  final cfg = AppConfig.instance;
  testWidgets('图标选择调用原生切换并同步保存，主题可立即切换', (tester) async {
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.zufang.guanjia/native'), (value) async {
      call = value;
      return null;
    });
    await tester.pumpWidget(MiuixSystemTheme(
        child: MaterialApp(
            builder: (_, child) => MiuixPopupHost(child: child!),
            home: const AppearanceSettingsPage())));
    await tester.pumpAndSettle();
    final icons = find.byType(AppBrand);
    expect(icons, findsNWidgets(8));
    for (var i = 1; i < 4; i++) {
      expect(
          tester.getTopLeft(icons.at(i)).dy, tester.getTopLeft(icons.first).dy);
      expect(tester.getTopLeft(icons.at(i + 4)).dy,
          tester.getTopLeft(icons.at(4)).dy);
    }
    await tester.tap(find.text('海蓝钥匙'));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    expect(call?.method, 'setAppIcon');
    expect(call?.arguments, {'style': 'ocean'});
    expect(cfg.iconStyle, 'ocean');
    await tester.tap(find.text('明暗模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    expect(cfg.themeMode, 'dark');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });
}
