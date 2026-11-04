import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/settings/appearance_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/billing_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/notify_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/mcp_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/feishu_settings_page.dart';
import 'package:zufang_guanjia/ui/settings/about_page.dart';
import 'package:zufang_guanjia/ui/settings/llm_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory modelDir;
  setUpAll(() async {
    modelDir = await Directory.systemTemp.createTemp('ocr-settings-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => modelDir.path);
  });
  tearDownAll(() async {
    await modelDir.delete(recursive: true);
  });
  final pages = <String, Widget>{
    '大模型识别': const LlmSettingsPage(),
    '外观': const AppearanceSettingsPage(),
    '计费': const BillingSettingsPage(),
    '提醒': const NotifySettingsPage(),
    'MCP': const McpSettingsPage(),
    '飞书': const FeishuSettingsPage(),
    '关于': const AboutPage(),
  };
  for (final entry in pages.entries) {
    for (final scale in [1.0, 1.1, 1.25]) {
      testWidgets('${entry.key}设置全长布局 $scale', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MiuixSystemTheme(
            child: MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: MiuixPopupHost(child: child!)),
          home: entry.value,
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 10; i++) {
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
