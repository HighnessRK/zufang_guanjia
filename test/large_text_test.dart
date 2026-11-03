import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/settings/settings_page.dart';
import 'package:zufang_guanjia/ui/widgets/app_widgets.dart';

void main() {
  testWidgets('大字体短字段仍保持同行，避免详情卡过度拉长', (tester) async {
    await tester.pumpWidget(MiuixSystemTheme(
        child: MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: const Scaffold(
          body: SizedBox(width: 320, child: InfoRow('押金', '¥0'))),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        (tester.getCenter(find.text('押金')).dy -
                tester.getCenter(find.text('¥0')).dy)
            .abs(),
        lessThan(2));
  });
  for (final scale in [1.0, 1.1, 1.25]) {
    testWidgets('长操作按钮随字体增高且不截断 $scale', (tester) async {
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SizedBox(
                width: 240,
                child: GradientButton(
                    label: '立即同步 / 首次上传',
                    icon: Icons.sync_rounded,
                    onPressed: () {}))),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(GradientButton));
      final label = tester.getRect(find.text('立即同步 / 首次上传'));
      expect(label.left, greaterThanOrEqualTo(button.left));
      expect(label.right, lessThanOrEqualTo(button.right));
      expect(label.bottom, lessThanOrEqualTo(button.bottom));
    });
    testWidgets('编辑输入框大字体重排 $scale', (tester) async {
      final controller = TextEditingController(text: '30788');
      addTearDown(controller.dispose);
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: 320,
                    child: AppLabelField(
                        label: '电表上期',
                        controller: controller,
                        caption: '填写上期账单的整数读数')))),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scale >= 1.4) {
        expect(tester.getTopLeft(find.byType(TextField)).dy,
            greaterThan(tester.getBottomLeft(find.text('电表上期')).dy));
      }
    });
    testWidgets('详情信息行保持标签和值层级 $scale', (tester) async {
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: const Scaffold(
            body: SizedBox(
                width: 320, child: InfoRow('小豆豆（大门磁卡）', '已交付 12 张，请妥善保管'))),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final label = tester.getTopLeft(find.text('小豆豆（大门磁卡）'));
      final value = tester.getTopLeft(find.text('已交付 12 张，请妥善保管'));
      if (scale >= 1.4) {
        expect(value.dy, greaterThan(label.dy));
        expect(value.dx, label.dx);
      }
    });
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.1, 1.25]) {
      testWidgets('设置页大字体 $scale / ${brightness.name}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: MiuixPopupHost(child: child!),
            ),
            home: const SettingsPage(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('计费参数'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('水费单价'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      });
    }
  }
}
