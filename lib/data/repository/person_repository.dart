import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../db/database_helper.dart';
import '../models/person.dart';

/// 租户表（people）数据访问层：增删改查 + 主租户联动。
///
/// 【主租户】一个房间可有多位租户，其中一位标记为主租户（is_primary）。
/// `rooms.tenant` 始终镜像为主租户姓名，列表 / 统计 / 提醒口径不变；
/// 主租户的增删改都会通过本类同步这份镜像。
class PersonRepository {
  PersonRepository._();

  static final PersonRepository instance = PersonRepository._();

  /// 查询全部租户（主租户排前）
  Future<List<Person>> all() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePeople,
      orderBy: 'room_no ASC, is_primary DESC, id ASC',
    );
    return rows.map(Person.fromMap).toList();
  }

  /// 按房间号查询该房间的全部租户（主租户排前，其余按加入顺序）
  Future<List<Person>> byRoom(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePeople,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
      orderBy: 'is_primary DESC, id ASC',
    );
    return rows.map(Person.fromMap).toList();
  }

  /// 新增租户，返回自增 id
  Future<int> insert(Person person) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert(AppConstants.tablePeople, person.toMap());
  }

  /// 更新租户
  Future<void> update(Person person) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      AppConstants.tablePeople,
      person.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[person.id],
    );
  }

  /// 设为 / 取消主租户，并同步房间镜像字段 rooms.tenant：
  ///   * 设为主租户 → 同房间其它租户取消主租户标记，rooms.tenant = 其姓名；
  ///   * 取消主租户 → 房间暂无主租户，rooms.tenant 清空（房间呈空置）。
  Future<void> applyPrimary(int id, String roomNo, bool primary) async {
    final Database db = await DatabaseHelper.instance.database;
    await db.transaction((Transaction txn) async {
      await txn.update(
        AppConstants.tablePeople,
        <String, Object?>{'is_primary': 0},
        where: 'room_no = ?',
        whereArgs: <Object?>[roomNo],
      );
      if (primary) {
        await txn.update(
          AppConstants.tablePeople,
          <String, Object?>{'is_primary': 1},
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        final List<Map<String, Object?>> rows = await txn.query(
          AppConstants.tablePeople,
          columns: <String>['name'],
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await txn.update(
          AppConstants.tableRooms,
          <String, Object?>{'tenant': rows.isEmpty ? '' : rows.first['name']},
          where: 'room_no = ?',
          whereArgs: <Object?>[roomNo],
        );
      } else {
        await txn.update(
          AppConstants.tableRooms,
          <String, Object?>{'tenant': ''},
          where: 'room_no = ?',
          whereArgs: <Object?>[roomNo],
        );
      }
    });
  }

  /// 删除租户；若删的是主租户，剩余租户中最早的一位升为主租户
  /// （一人不剩则房间主租户清空）。
  Future<void> deleteAndReassign(Person person) async {
    final Database db = await DatabaseHelper.instance.database;
    await delete(person.id!);
    if (!person.isPrimary) return;
    final List<Person> left = await byRoom(person.roomNo);
    if (left.isEmpty) {
      await db.update(
        AppConstants.tableRooms,
        <String, Object?>{'tenant': ''},
        where: 'room_no = ?',
        whereArgs: <Object?>[person.roomNo],
      );
    } else {
      await applyPrimary(left.first.id!, person.roomNo, true);
    }
  }

  /// 房间编辑页保存后对齐主租户：rooms.tenant 与 people 表保持一致，
  /// 主租户姓名 / 电话 / 身份证一并同步（电话、身份证跟随租户本人，
  /// 不再挂在房间上）。
  ///   * 姓名非空：有主租户则改名同步；有租户无主则首位升主并改名；
  ///     无租户记录则补一条主租户；
  ///   * 姓名清空：取消主租户标记（租户记录保留），房间呈空置。
  Future<void> syncFromRoom(String roomNo, String mainName, String idCard,
      [String phone = '']) async {
    final List<Person> people = await byRoom(roomNo);
    Person? primary;
    for (final Person p in people) {
      if (p.isPrimary) {
        primary = p;
        break;
      }
    }
    if (mainName.isEmpty) {
      if (primary != null) {
        await applyPrimary(primary.id!, roomNo, false);
      }
      return;
    }
    if (primary != null) {
      // 电话只在表单有值时覆盖，避免只是改个房型就把号码抹掉
      final String newPhone = phone.isEmpty ? primary.phone : phone;
      if (primary.name != mainName ||
          primary.idCard != idCard ||
          primary.phone != newPhone) {
        primary.name = mainName;
        primary.idCard = idCard;
        primary.phone = newPhone;
        await update(primary);
      }
    } else if (people.isNotEmpty) {
      final Person first = people.first;
      first.name = mainName;
      first.idCard = idCard;
      first.phone = phone.isEmpty ? first.phone : phone;
      first.isPrimary = true;
      await update(first);
    } else {
      await insert(Person(
          roomNo: roomNo,
          name: mainName,
          idCard: idCard,
          phone: phone,
          isPrimary: true));
    }
  }

  /// 删除租户
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tablePeople,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 删除某房间的全部租户（删除房间时联动）
  Future<void> deleteByRoom(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tablePeople,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
    );
  }

  /// 统计：租户总人数
  Future<int> countAll() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ${AppConstants.tablePeople}');
    return (r.first['c'] as int?) ?? 0;
  }

  /// 按手机号精确查询（找人）
  Future<List<Person>> searchByPhone(String phone) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePeople,
      where: 'phone = ?',
      whereArgs: <Object?>[phone],
    );
    return rows.map(Person.fromMap).toList();
  }
}
