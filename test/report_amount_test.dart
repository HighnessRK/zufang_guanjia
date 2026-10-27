import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/stat/fee_report_page.dart';

void main() {
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
