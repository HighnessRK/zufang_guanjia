import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zufang_guanjia/data/db/database_helper.dart';
import 'package:zufang_guanjia/data/models/room.dart';
import 'package:zufang_guanjia/data/models/payment.dart';
import 'package:zufang_guanjia/data/models/receipt.dart';
import 'package:zufang_guanjia/ui/rooms/collect_panel_page.dart';
import 'package:zufang_guanjia/ui/shell/app_shell.dart';
import 'package:zufang_guanjia/ui/stat/fee_report_page.dart';
import 'package:zufang_guanjia/ui/receipt/receipt_list_page.dart';
import 'package:zufang_guanjia/ui/rooms/room_edit_page.dart';
import 'package:zufang_guanjia/ui/rooms/rooms_page.dart';

void main() {
  testWidgets('非空收款、报表、收据列表与编辑全长三档系统字体布局', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('collect-layout-');
      await databaseFactory.setDatabasesPath(dir.path);
      final db = await DatabaseHelper.instance.database;
      await db.insert(
          'rooms',
          Room(roomNo: '101', tenant: '合成测试租户（长姓名）', expire: '2027-04-18')
              .toMap());
      await db.insert(
          'payments',
          Payment(
                  roomNo: '101',
                  payType: 'rent',
                  period: '2026-11',
                  due: 1234567)
              .toMap());
      await db.insert(
          Receipt.table,
          Receipt(
                  roomNo: '101',
                  period: '2026-11',
                  tenant: '合成测试租户（长姓名）',
                  total: 1234567,
                  no: 'SJ-202611-101-0001',
                  createdAt: '2026-11-02 12:30')
              .toMap());
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selectedIndex = ValueNotifier<int>(3);
    addTearDown(selectedIndex.dispose);
    for (final scale in [1.0, 1.1, 1.25]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: MiuixPopupHost(child: child!)),
        home: AppShellScope(
            switchTab: (_) {},
            switchTabAndPush: (_, __) {},
            selectedIndex: selectedIndex,
            child: const Material(child: RoomsPage())),
      )));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('2027-04-18'), findsOneWidget);
      expect(tester.getTopLeft(find.text('租约到期')).dy,
          lessThan(tester.getTopLeft(find.text('押金')).dy));
      expect(tester.getSize(find.text('2027-04-18')).height, lessThan(30),
          reason: '到期日期保持完整单行');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: MiuixPopupHost(child: child!)),
        home: AppShellScope(
          switchTab: (_) {},
          switchTabAndPush: (_, __) {},
          selectedIndex: selectedIndex,
          child: const Material(child: CollectPanelPage()),
        ),
      )));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('待收合计'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('确认收款'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('合成测试租户（长姓名）'), findsOneWidget);
      expect(find.text('¥1234567'), findsWidgets);
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: MiuixPopupHost(child: child!)),
        home: const FeeReportPage(),
      )));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('开始日期'), findsOneWidget);
      expect(find.text('结束日期'), findsOneWidget);
      final firstPreset = tester.getTopLeft(find.text('本月'));
      final secondPreset = tester.getTopLeft(find.text('近3月'));
      expect(secondPreset.dy, closeTo(firstPreset.dy, 1));
      expect(secondPreset.dx, greaterThan(firstPreset.dx));
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: MiuixPopupHost(child: child!)),
        home: const ReceiptListPage(),
      )));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('¥1234567'), findsOneWidget);
      await tester.pumpWidget(MiuixSystemTheme(
          child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: MiuixPopupHost(child: child!)),
        home: const Material(child: RoomEditPage(roomNo: '101')),
      )));
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 16; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('保存'), findsOneWidget);
    }
  });
}
