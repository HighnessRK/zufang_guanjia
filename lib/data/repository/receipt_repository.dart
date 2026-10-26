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
      limit: 1,
    );
    return rows.isEmpty ? null : Receipt.fromMap(rows.first);
  }

  /// 保存收据：同房间同账期已存在则覆盖（重新生成语义）
  Future<void> upsert(Receipt receipt) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableReceipts,
      receipt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
