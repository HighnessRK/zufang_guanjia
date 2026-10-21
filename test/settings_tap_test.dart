import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zufang_guanjia/ui/settings/settings_page.dart';

/// 复现：设置页「计费参数」三行无法点进去修改的问题。
void main() {
  testWidgets('计费参数三行均可点击并弹出编辑对话框', (WidgetTester tester) async {
    await tester.pumpWidget(MiuixSystemTheme(
      child: Builder(builder: (BuildContext context) {
        // 复刻 lib/app.dart 的真实根结构（MaterialApp.builder 内的 MiuixPopupHost）
        return MaterialApp(
          builder: (BuildContext context, Widget? child) =>
              MiuixPopupHost(child: child ?? const SizedBox.shrink()),
          home: const SettingsPage(),
        );
      }),
    ));
    await tester.pumpAndSettle();

    // 对照组：通知分组的行（_editInt）
    await tester.tap(find.text('缴费提醒提前天数'));
    await tester.pumpAndSettle();
    expect(find.text('设置缴费提醒提前天数'), findsOneWidget, reason: '对照组：缴费提醒行应能打开对话框');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final Map<String, String> targets = <String, String>{
      '水费单价': '设置水费单价',
      '电费单价': '设置电费单价',
    };
    for (final MapEntry<String, String> e in targets.entries) {
      await tester.tap(find.text(e.key));
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsWidgets, reason: '${e.key} 应能打开对话框');
      expect(find.text('取消'), findsOneWidget, reason: '${e.key} 对话框应有取消按钮');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }
    // 实验室 Beta 分组应存在（滚动到底部）
    await tester.scrollUntilVisible(
      find.text('手动触发小米超级岛通知'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('手动触发小米超级岛通知'), findsOneWidget);
    expect(find.text('清除测试通知'), findsOneWidget);
  });
}
