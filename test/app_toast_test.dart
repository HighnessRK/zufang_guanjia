import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/widgets/app_widgets.dart';

void main() {
  for (final scale in [1.0, 1.25, 2.0]) {
    testWidgets('统一轻提示适配字体并执行操作 $scale', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: AppToastLayer(child: child!)),
              home: const Scaffold(body: Text('page')))));
      AppSnackbar.show('云端更新完成，请核对下载的数据。',
          actionLabel: '查看', onAction: () => tapped = true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('云端更新完成，请核对下载的数据。'));
      expect(text.style?.decoration, TextDecoration.none);
      expect(text.style?.color, isNotNull);
      expect(find.text('云端更新完成，请核对下载的数据。'), findsOneWidget);
      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
      await tester.pump(const Duration(seconds: 6));
    });
  }
}
