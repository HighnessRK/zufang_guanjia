import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/stat/fee_report_page.dart';
import 'package:zufang_guanjia/data/repository/payment_repository.dart';
import 'package:flutter_miuix/miuix.dart';

void main() {
  testWidgets('分类卡片窄屏大字及深浅模式无溢出', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MiuixSystemTheme(child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const MediaQuery(data: MediaQueryData(
          textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: Center(child: SizedBox(width: 280,
            child: FeeCategoryCard(row: FeeTypeSum(payType: 'rent',
              due: 123456789, paid: 1234567, count: 100, rooms: 13)))))))));
      await tester.pumpAndSettle();
      expect(find.text('房租'), findsOneWidget);
      expect(find.text('¥123,456,789'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('实收合计在窄列和大字体下保持完整单行', (tester) async {
    for (final width in [45.0, 65.0, 100.0]) {
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Center(child: SizedBox(width: width, child: const ReportAmount(
          '¥12,345,678', fontSize: 14.5, color: Colors.green, bold: true,
          alignment: Alignment.centerRight))))));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('¥12,345,678'));
      expect(paragraph.maxLines, 1);
      expect(paragraph.softWrap, false);
      expect(paragraph.didExceedMaxLines, false);
      expect(tester.takeException(), isNull);
    }
  });
}
