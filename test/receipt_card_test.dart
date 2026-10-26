import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/data/models/receipt.dart';
import 'package:zufang_guanjia/ui/receipt/receipt_card.dart';

void main() {
  testWidgets('收据展示完整读数、单价与大写且不含品牌', (tester) async {
    final receipt = Receipt(roomNo: '201', period: '2026-10',
        waterFee: 30, elecFee: 120, total: 150,
        waterPrev: 100, waterCurr: 105, waterUse: 5, waterPrice: 6,
        elecPrev: 200, elecCurr: 300, elecUse: 100, elecPrice: 1.2,
        createdAt: '2026-10-26 12:00');
    await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: SingleChildScrollView(child: ReceiptCard(receipt: receipt)))));
    expect(find.text('100 吨'), findsOneWidget);
    expect(find.text('105 吨'), findsOneWidget);
    expect(find.text('6 元/吨'), findsOneWidget);
    expect(find.text('1.20 元/度'), findsOneWidget);
    expect(find.text('人民币壹佰伍拾元整'), findsOneWidget);
    expect(find.textContaining('租房管家'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('收据读数快照序列化往返', () {
    final receipt = Receipt(roomNo: '201', period: '2026-10',
        waterPrev: 1, waterCurr: 2, elecPrev: 3, elecCurr: 4, createdAt: 'now');
    final copy = Receipt.fromMap(receipt.toMap());
    expect(copy.waterPrev, 1);
    expect(copy.waterCurr, 2);
    expect(copy.elecPrev, 3);
    expect(copy.elecCurr, 4);
  });
}
