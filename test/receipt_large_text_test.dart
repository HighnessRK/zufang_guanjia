import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/data/models/receipt.dart';
import 'package:zufang_guanjia/ui/receipt/receipt_card.dart';
import 'package:zufang_guanjia/ui/receipt/receipt_viewer_page.dart';

void main() {
  for (final scale in [1.0, 1.1, 1.25]) {
    testWidgets('收据预览操作区可滚动且不挤压 $scale', (tester) async {
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
        home: ReceiptViewerPage(
            receipt: Receipt(
                roomNo: 'A-1001',
                period: '2026-11',
                total: 1234567,
                createdAt: '2026-11-02 12:30')),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('删除收据'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('保存到相册'), findsOneWidget);
      expect(find.text('转发微信'), findsOneWidget);
    });
  }
  for (final scale in [1.0, 1.1, 1.25]) {
    testWidgets('收据长姓名与大金额完整显示 $scale', (tester) async {
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReceiptCard(
          receipt: Receipt(
              roomNo: 'A-1001',
              period: '2026-11',
              no: 'SJ-202611-A1001-0001',
              tenant: '合成测试租户（长姓名）',
              total: 1234567,
              createdAt: '2026-11-02 12:30',
              periodStart: '2026-11-01',
              periodEnd: '2027-10-31'),
        ))),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('¥1,234,567'), findsNWidgets(2));
      expect(find.text('合成测试租户（长姓名）'), findsOneWidget);
    });
  }
}
