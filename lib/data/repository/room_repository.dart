import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../db/database_helper.dart';
import '../models/room.dart';

/// 房间表（rooms）数据访问层：增删改查 + 统计。
class RoomRepository {
  RoomRepository._();

  static final RoomRepository instance = RoomRepository._();

  /// 查询全部房间（按房间号自然排序：数字优先）
  Future<List<Room>> all() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows =
        await db.query(AppConstants.tableRooms, orderBy: 'room_no ASC');
    return rows.map(Room.fromMap).toList();
  }

  /// 按房间号查询单个房间
  Future<Room?> byRoomNo(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tableRooms,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
      limit: 1,
    );
    return rows.isEmpty ? null : Room.fromMap(rows.first);
  }

  /// 新增房间（房间号重复则抛出异常，由界面层提示）
  Future<void> insert(Room room) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tableRooms,
      room.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// 更新房间（按房间号）
  Future<void> update(Room room) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableRooms,
      room.toMap(),
      where: 'room_no = ?',
      whereArgs: <Object?>[room.roomNo],
    );
  }

  /// 删除房间（同时级联删除该房间的租户，缴费流水保留作历史留痕）
  Future<void> delete(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tableRooms,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
    await db.delete(
      AppConstants.tablePeople,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
    await db.delete(
      AppConstants.tablePayments,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
  }

  /// 统计：房间总数
  Future<int> countAll() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> r =
        await db.rawQuery('SELECT COUNT(*) AS c FROM ${AppConstants.tableRooms}');
    return (r.first['c'] as int?) ?? 0;
  }

  /// 统计：在租房间数（有承租人）
  Future<int> countOccupied() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> r = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${AppConstants.tableRooms} WHERE tenant <> ''");
    return (r.first['c'] as int?) ?? 0;
  }

  /// 统计：全部房间月租金合计
  Future<int> sumRent() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> r = await db.rawQuery(
        'SELECT IFNULL(SUM(rent),0) AS s FROM ${AppConstants.tableRooms} WHERE tenant <> \'\'');
    return (r.first['s'] as int?) ?? 0;
  }

  /// 统计：本月实收房租合计
  Future<int> sumPaid() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> r = await db.rawQuery(
        'SELECT IFNULL(SUM(paid),0) AS s FROM ${AppConstants.tableRooms} WHERE tenant <> \'\'');
    return (r.first['s'] as int?) ?? 0;
  }

  /// 统计：本月未收水电费合计
  Future<int> sumUnpaidUtility() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> r = await db.rawQuery(
        'SELECT IFNULL(SUM(utility_fee),0) AS s FROM ${AppConstants.tableRooms} '
        'WHERE utility_paid = 0 AND utility_fee > 0');
    return (r.first['s'] as int?) ?? 0;
  }

  /// 只更新抄表与水电费字段（水电抄录页使用，避免覆盖其它信息）
  Future<void> updateMeter({
    required String roomNo,
    required int elecPrev,
    required int elecCurr,
    required int waterPrev,
    required int waterCurr,
    required int elecFee,
    required int waterFee,
    required int utilityFee,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableRooms,
      <String, Object?>{
        'elec_prev': elecPrev,
        'elec_curr': elecCurr,
        'water_prev': waterPrev,
        'water_curr': waterCurr,
        'elec_fee': elecFee,
        'water_fee': waterFee,
        'utility_fee': utilityFee,
      },
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
  }

  /// 月度滚动：把本期读数结转为上期读数，并清零本期费用（新账期开始）
  Future<void> rollMeterToNextPeriod(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''
      UPDATE ${AppConstants.tableRooms}
      SET elec_prev = elec_curr,
          water_prev = water_curr,
          elec_fee = 0,
          water_fee = 0,
          utility_fee = 0,
          utility_paid = 0
      WHERE room_no = ?
      ''',
      <Object?>[roomNo],
    );
  }

  /// 月度滚动：把本期实付结转为上期（新账期房租重新应收）——
  /// 仅旧版月度数据迁移时使用，新周期引擎在「上一收租周期结清」时清零
  Future<void> rollRentToNextPeriod(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableRooms,
      <String, Object?>{'paid': 0},
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
  }

  /// 清零房租实收（新收租周期开始时调用）
  Future<void> clearRentPaid(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tableRooms,
      <String, Object?>{'paid': 0},
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
  }

  /// 结清一笔水/电费：该费累计清零 + 该表读数滚动为本期
  /// （下一周期从当前读数重新累计），合计字段同步重算。
  Future<void> settleUtility(String roomNo, String payType) async {
    final db = await DatabaseHelper.instance.database;
    if (payType == AppConstants.payTypeWater) {
      await db.rawUpdate(
        'UPDATE ${AppConstants.tableRooms} '
        'SET water_fee = 0, water_prev = water_curr, utility_fee = elec_fee '
        'WHERE room_no = ?',
        <Object?>[roomNo],
      );
    } else {
      await db.rawUpdate(
        'UPDATE ${AppConstants.tableRooms} '
        'SET elec_fee = 0, elec_prev = elec_curr, utility_fee = water_fee '
        'WHERE room_no = ?',
        <Object?>[roomNo],
      );
    }
  }
}
