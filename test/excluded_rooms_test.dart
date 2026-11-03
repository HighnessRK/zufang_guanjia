import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zufang_guanjia/core/config/app_config.dart';
import 'package:zufang_guanjia/core/utils/date_util.dart';
import 'package:zufang_guanjia/data/db/database_helper.dart';
import 'package:zufang_guanjia/data/models/payment.dart';
import 'package:zufang_guanjia/data/models/room.dart';
import 'package:zufang_guanjia/data/repository/payment_repository.dart';
import 'package:zufang_guanjia/data/repository/room_repository.dart';
import 'package:zufang_guanjia/services/reminder_engine.dart';

void main() {
  test('白名单汇总、历史、提醒排除，原流水/抄表/房间数量保留', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('excluded-rooms-');
    await databaseFactory.setDatabasesPath(dir.path);
    final db = await DatabaseHelper.instance.database;
    final cfg = AppConfig.instance;
    final previous = cfg.excludedRooms;
    addTearDown(() async {
      cfg.excludedRooms = previous;
      await db.close();
      await dir.delete(recursive: true);
    });
    final repo = PaymentRepository.instance;
    final period = DateUtil.currentPeriod;
    for (final no in ['101', '102']) {
      await db.insert(
          'rooms',
          Room(
                  roomNo: no,
                  tenant: '测试',
                  checkIn: '2020-01-01',
                  expire: DateUtil.format(DateTime.now()),
                  elecCurr: 24737,
                  waterCurr: 12345)
              .toMap());
      for (final type in ['rent', 'water', 'elec']) {
        await repo.insert(Payment(
            roomNo: no,
            payType: type,
            period: period,
            due: no == '101' ? 1000 : 100,
            paid: no == '101' ? 500 : 50));
      }
    }
    cfg.excludedRooms = {'101'};
    await db.update('rooms', {'rent': 1000.5, 'paid': 500, 'utility_fee': 80});
    expect(await RoomRepository.instance.sumRent(), 1001);
    expect(await RoomRepository.instance.sumPaid(), 500);
    expect(await RoomRepository.instance.sumUnpaidUtility(), 80);
    final stat = await repo.statSummary();
    expect(stat.due, 300);
    expect(stat.paid, 150);
    final sums = await repo.sumByTypeRange(period, period);
    expect(sums.length, 3);
    expect(sums.every((s) => s.due == 100 && s.rooms == 1), true);
    final home = await ReminderEngine.computeHomeStat();
    expect(home.totalRooms, 2);
    expect(home.occupiedRooms, 2);
    expect(home.rentDue, 100);
    expect(home.utilityDue, 200);
    expect((await ReminderEngine.computeAll()).every((n) => n.roomNo != '101'),
        true);
    expect((await repo.byRoom('101')).length, 3);
    final readings =
        await db.query('rooms', where: 'room_no = ?', whereArgs: ['101']);
    expect(readings.single['elec_curr'], 24737);
    cfg.excludedRooms = {};
    expect((await repo.statSummary()).due, 3300);
    expect(
        (await repo.sumByTypeRange(period, period)).every((s) => s.rooms == 2),
        true);
  });
}
