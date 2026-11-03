import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zufang_guanjia/data/db/database_helper.dart';
import 'package:zufang_guanjia/data/models/room.dart';
import 'package:zufang_guanjia/ui/meter/meter_page.dart';

void main() {
  testWidgets('抄表页 2 倍字体保留五位读数且不溢出', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('meter-layout-');
      await databaseFactory.setDatabasesPath(dir.path);
      final db = await DatabaseHelper.instance.database;
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await db.insert(
          'rooms',
          Room(roomNo: '101', tenant: '测试', elecCurr: 24737, waterCurr: 12345)
              .toMap());
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MiuixSystemTheme(
        child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: MiuixPopupHost(child: child!),
      ),
      home: const Material(child: MeterPage()),
    )));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(
        fields.map((f) => f.controller!.text), containsAll(['24737', '12345']));
    for (final field in fields) {
      final size = tester.getSize(find.byWidget(field));
      final painter = TextPainter(
        text: TextSpan(text: field.controller!.text, style: field.style),
        textScaler: const TextScaler.linear(2),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(size.width, greaterThanOrEqualTo(painter.width));
    }
  });
}
