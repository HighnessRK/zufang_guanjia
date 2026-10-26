import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zufang_guanjia/core/constants/app_constants.dart';
import 'package:zufang_guanjia/ui/settings/settings_page.dart';

/// 设置页结构回归：一级分组可点进二级页，二级页参数行可点开编辑对话框。
///
/// 原测试写于「通知分组内联在设置首页」的旧结构（缴费提醒行与实验室 Beta
/// 项都在首页），通知设置 / 实验室拆成子页后失效。现按当前结构更新，并补
/// 上 v1.1.3「收电日期默认跟随收水日期」的展示断言。
void main() {
  testWidgets('设置分组与计费参数行均可点击并弹出编辑对话框',
      (WidgetTester tester) async {
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

    // 对照组：进入「通知与提醒」子页，参数行应能打开对话框
    await tester.tap(find.text('通知与提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('缴费提醒提前天数'));
    await tester.pumpAndSettle();
    expect(find.text('设置缴费提醒提前天数'), findsWidgets,
        reason: '对照组：通知页参数行应能打开对话框');
    expect(find.text('取消'), findsOneWidget, reason: '对话框应有取消按钮');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    // 返回设置页（设置首页是根路由、无返回按钮，点子页顶栏返回图标即可）
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pumpAndSettle();

    // 主测：计费参数页两行单价均可点开编辑弹窗
    await tester.tap(find.text('计费参数'));
    await tester.pumpAndSettle();
    const List<MapEntry<String, String>> targets = <MapEntry<String, String>>[
      MapEntry<String, String>('水费单价', '设置水费单价'),
      MapEntry<String, String>('电费单价', '设置电费单价'),
    ];
    for (final MapEntry<String, String> e in targets) {
      await tester.tap(find.text(e.key));
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsWidgets, reason: '${e.key} 应能打开对话框');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }

    // v1.1.3：收电日期默认跟随收水日期（未开独立开关时只读展示跟随结果）
    await tester.scrollUntilVisible(
      find.text('收电日期独立设置'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('收电日期独立设置'), findsOneWidget,
        reason: '应有「收电日期独立设置」开关行');
    expect(find.textContaining('跟随收水日期'), findsOneWidget,
        reason: '默认跟随：收电日期行应显示跟随收水日期文案');

    // 回到设置页，确认分组入口齐全
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('通知实验室'), findsOneWidget);
    expect(find.text('关于 ${AppConstants.appName}'), findsOneWidget);
  });
}
