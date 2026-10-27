import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/receipt.dart';

/// 电子收据仓储：增删查 + 按 房间+账期 幂等覆盖（UNIQUE 约束）。
class ReceiptRepository {
  ReceiptRepository._();

  static final ReceiptRepository instance = ReceiptRepository._();

  /// 全部收据（生成时间倒序，最新在前）
  Future<List<Receipt>> all() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tableReceipts,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(Receipt.fromMap).toList();
  }

  /// 某房间某账期是否已有收据
  Future<Receipt?> find(String roomNo, String period) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tableReceipts,
      where: 'room_no = ? AND period = ?',
      whereArgs: <Object?>[roomNo, period],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Receipt.fromMap(rows.first);
  }

  /// 保存独立快照；流水号、已开金额校验与插入在同一事务内完成。
  Future<Receipt> issue(Receipt snapshot) async {
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final previous = await txn.query(AppConstants.tableReceipts,
          where: 'room_no = ? AND period = ?',
          whereArgs: [snapshot.roomNo, snapshot.period]);
      int sequence = 1, water = 0, elec = 0, rent = 0, merged = 0;
      for (final row in previous) {
        final r = Receipt.fromMap(row);
        if (r.sequence >= sequence) sequence = r.sequence + 1;
        if (r.kind == 'rent') {
          rent += r.total;
        } else {
          water += r.waterFee;
          elec += r.elecFee;
          if (r.waterFee == 0 && r.elecFee == 0) merged += r.total;
        }
      }
      final map = snapshot.toMap();
      final isRent = snapshot.kind == 'rent';
      final int remainingWater =
          (snapshot.waterFee - water).clamp(0, snapshot.waterFee).toInt();
      final int remainingElec =
          (snapshot.elecFee - elec).clamp(0, snapshot.elecFee).toInt();
      final total = isRent ? snapshot.total - rent
          : snapshot.waterFee == 0 && snapshot.elecFee == 0
              ? snapshot.total - merged : remainingWater + remainingElec;
      if (total <= 0) throw StateError('该账期实收金额已开具收据，请查看历史收据');
      map['water_fee'] = remainingWater;
      map['elec_fee'] = remainingElec;
      map['total'] = total;
      map['sequence'] = sequence;
      final code = switch (snapshot.kind) {
        'rent' => 'R', 'water' => 'W', 'elec' => 'E', _ => 'U',
      };
      map['no'] = 'SJ-${snapshot.period.replaceAll('-', '')}-${snapshot.roomNo}-$code-${sequence.toString().padLeft(3, '0')}';
      final id = await txn.insert(AppConstants.tableReceipts, map);
      return Receipt.fromMap({...map, 'id': id});
    });
  }

  /// 保存快照（兼容旧调用）；不会覆盖旧收据。
  Future<void> upsert(Receipt receipt) async {
    final db = await DatabaseHelper.instance.database;
    receipt.id = await db.insert(
      AppConstants.tableReceipts,
      receipt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> nextSequence(String roomNo, String period) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('SELECT COALESCE(MAX(sequence), 0) AS n FROM '
        '${AppConstants.tableReceipts} WHERE room_no = ? AND period = ?',
        <Object?>[roomNo, period]);
    return ((rows.first['n'] as num?)?.toInt() ?? 0) + 1;
  }

  /// 删除一条收据
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableReceipts,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
