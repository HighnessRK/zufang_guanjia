import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/core/utils/date_util.dart';
import 'package:zufang_guanjia/data/db/database_helper.dart';
import 'package:zufang_guanjia/data/models/room.dart';
import 'package:zufang_guanjia/data/models/payment.dart';
import 'package:zufang_guanjia/ui/home/home_page.dart';
import 'package:zufang_guanjia/ui/rooms/rooms_page.dart';
import 'package:zufang_guanjia/ui/rooms/collect_panel_page.dart';
import 'package:zufang_guanjia/ui/meter/meter_page.dart';
import 'package:zufang_guanjia/ui/settings/settings_page.dart';
import 'package:zufang_guanjia/ui/settings/appearance_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/llm_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/mcp_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/feishu_settings_page.dart';
import 'package:zufang_guanjia/ui/stat/fee_report_page.dart';
import 'package:zufang_guanjia/ui/stat/stat_page.dart';
import 'package:zufang_guanjia/ui/receipt/receipt_list_page.dart';
import 'package:zufang_guanjia/ui/shell/app_shell.dart';

void main() {
  testWidgets('十二页面 × 深浅主题 × 五种背景，125% 字体渲染检查', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.zufang.guanjia/native'),
            (_) async => null);
    late Directory dir;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('theme-matrix-');
      await databaseFactory.setDatabasesPath(dir.path);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => dir.path);
      final db = await DatabaseHelper.instance.database;
      await db.insert(
          'rooms', Room(roomNo: '101', tenant: '合成测试', rent: 18000).toMap());
      for (final kind in ['rent', 'water', 'elec']) {
        await db.insert(
            'payments',
            Payment(
                    roomNo: '101',
                    payType: kind,
                    period: DateUtil.currentPeriod,
                    due: 1234567,
                    paid: 12345)
                .toMap());
      }
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    const pages = <Widget>[
      HomePage(),
      RoomsPage(),
      MeterPage(),
      CollectPanelPage(),
      SettingsPage(),
      AppearanceSettingsPage(),
      LlmSettingsPage(),
      McpSettingsPage(),
      FeishuSettingsPage(),
      FeeReportPage(),
      StatPage(),
      ReceiptListPage()
    ];
    for (final mode in [
      MiuixColorSchemeMode.light,
      MiuixColorSchemeMode.dark
    ]) {
      for (final bg in ['aurora', 'ocean', 'sunset', 'jade', 'none']) {
        AppConfig.instance.backgroundStyle = bg;
        for (final page in pages) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(MiuixThemeController(
              colorSchemeMode: mode,
              child: Builder(
                  builder: (ctx) => MaterialApp(
                      theme:
                          ThemeData(brightness: MiuixTheme.of(ctx).brightness),
                      builder: (ctx, child) => MediaQuery(
                          data: MediaQuery.of(ctx).copyWith(
                              textScaler: const TextScaler.linear(1.25)),
                          child: MiuixPopupHost(child: child!)),
                      home: AppShellScope(
                          selectedIndex: index,
                          switchTab: (_) {},
                          switchTabAndPush: (_, __) {},
                          child: Material(child: page))))));
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)));
          await tester.pump(const Duration(milliseconds: 250));
          expect(tester.takeException(), isNull,
              reason: '$mode / $bg / ${page.runtimeType}');
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
