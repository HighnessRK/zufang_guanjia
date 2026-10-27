import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/ui/settings/feishu_settings_page.dart';
import 'package:zufang_guanjia/ui/widgets/app_widgets.dart';

void main() {
  testWidgets('飞书参数页使用统一分组卡片且密钥编辑默认隐藏', (tester) async {
    final cfg = AppConfig.instance;
    final old = cfg.feishuClientSecret;
    cfg.feishuClientSecret = 'private-test-secret';
    addTearDown(() => cfg.feishuClientSecret = old);
    await tester.pumpWidget(MiuixSystemTheme(child: MaterialApp(
      builder: (_, child) => MiuixPopupHost(child: child!),
      home: const FeishuSettingsPage())));
    await tester.pumpAndSettle();
    expect(find.byType(GlassCard), findsWidgets);
    expect(find.byType(MiuixArrowPreference), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('private-test-secret'), findsNothing);
    await tester.tap(find.text('应用 App Secret'));
    await tester.pumpAndSettle();
    expect(find.text('设置应用 App Secret'), findsWidgets);
    expect(tester.widget<AppTextField>(find.byType(AppTextField)).obscureText, isTrue);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(cfg.feishuClientSecret, 'private-test-secret');
  });
}
