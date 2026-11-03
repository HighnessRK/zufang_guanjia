import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zufang_guanjia/data/db/database_helper.dart';
import 'package:zufang_guanjia/data/models/room.dart';
import 'package:zufang_guanjia/ui/meter/meter_page.dart';

void main() {
  testWidgets('三档字体水电读数等宽同行且五位数字完整', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('meter-layout-');
      await databaseFactory.setDatabasesPath(dir.path);
      final db = await DatabaseHelper.instance.database;
      await db.insert('rooms',
          Room(roomNo: 'A-1001', elecCurr: 24737, waterCurr: 12345).toMap());
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.1, 1.25]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: MiuixPopupHost(child: child!),
        ),
        home: const Material(child: MeterPage()),
      )));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      final electric = tester.getRect(fields.at(0));
      final water = tester.getRect(fields.at(1));
      expect(electric.top, closeTo(water.top, 1));
      expect(water.left, greaterThan(electric.right));
      for (final field in [fields.at(0), fields.at(1)]) {
        final editable = tester.widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)));
        final painter = TextPainter(
          text: TextSpan(text: editable.controller.text, style: editable.style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout();
        final viewport = tester
            .getSize(
                find.descendant(of: field, matching: find.byType(EditableText)))
            .width;
        expect(painter.width, lessThanOrEqualTo(viewport));
        painter.dispose();
      }
      await tester.tap(fields.first);
      await tester.enterText(fields.first, '54321');
      await tester.pump();
      expect(find.text('未保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
