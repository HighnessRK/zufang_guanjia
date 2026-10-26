import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/data/models/payment.dart';
import 'package:zufang_guanjia/data/repository/payment_repository.dart';

void main() {
  test('批量欠费索引与逐房逐类型历史扫描结果一致', () {
    final rows = <Payment>[
      for (int room = 1; room <= 100; room++)
        for (final type in ['rent', 'water', 'elec', 'utility'])
          for (int month = 1; month <= 12; month++)
            Payment(roomNo: '$room', payType: type,
              period: '2026-${month.toString().padLeft(2, '0')}',
              due: month == 11 ? 0 : 100, paid: 20,
              isSettled: month == 12),
    ];
    final index = PaymentRepository.latestUnsettledIndex(rows.reversed);
    expect(index.length, 100);
    for (final entry in index.entries) {
      final room = entry.value;
      expect(room.length, 4);
      for (final p in room.values) {
        final history = rows.where((row) => row.roomNo == entry.key).toList()
          ..sort((a, b) => b.period.compareTo(a.period));
        final previousResult = history.firstWhere((row) =>
            row.payType == p.payType && row.due > 0 && !row.isSettled);
        expect(identical(p, previousResult), isTrue);
        expect(p.period, '2026-10');
        expect(p.debt, 80);
      }
    }
    expect(PaymentRepository.latestUnsettledIndex([]), isEmpty);
  });
}
