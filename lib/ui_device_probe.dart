// Disposable UI acceptance profile: never starts cloud/sync/notification services.
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'data/db/database_helper.dart';
import 'data/models/room.dart';
import 'data/models/payment.dart';
import 'data/models/receipt.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.instance.init();
  AppConfig.instance.autoCheckUpdate = false;
  final db = await DatabaseHelper.instance.database;
  for (final no in ['101', '102', '201']) {
    if ((await db.query('rooms', where: 'room_no = ?', whereArgs: [no]))
        .isEmpty) {
      await db.insert(
          'rooms',
          Room(
                  roomNo: no,
                  tenant: '测试租户',
                  rent: 1500,
                  elecCurr: 24737,
                  waterCurr: 12345,
                  elecPrev: 24000,
                  waterPrev: 12000)
              .toMap());
    }
  }
  // Additional synthetic stress case; only this isolated acceptance entry uses it.
  const stressRoom = 'A-1001';
  if ((await db.query('rooms', where: 'room_no = ?', whereArgs: [stressRoom]))
      .isEmpty) {
    await db.insert(
        'rooms',
        Room(
                roomNo: stressRoom,
                tenant: '合成测试租户（长姓名）',
                rent: 18000,
                roomType: '两室一厅 · 长文本户型说明',
                deposit: 36000,
                elecPrev: 30000,
                elecCurr: 30788,
                waterPrev: 12000,
                waterCurr: 12345)
            .toMap());
    await db.insert(
        'payments',
        Payment(
                roomNo: stressRoom,
                payType: 'rent',
                period: '2026-11',
                due: 1234567)
            .toMap());
  }
  if ((await db
          .query(Receipt.table, where: 'room_no = ?', whereArgs: [stressRoom]))
      .isEmpty) {
    await db.insert(
        Receipt.table,
        Receipt(
                roomNo: stressRoom,
                period: '2026-11',
                kind: 'rent',
                no: 'SJ-202611-A1001-0001',
                tenant: '合成测试租户（长姓名）',
                total: 1234567,
                createdAt: '2026-11-02 12:30',
                periodStart: '2026-11-01',
                periodEnd: '2027-10-31')
            .toMap());
  }
  runApp(const RentalApp());
}
