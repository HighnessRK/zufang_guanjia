import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/settings/settings_edit.dart';

void main() {
  for (final initial in <String>[
    'https://api.example.com/v1',
    'sk-example-secret',
    'qwen-vl-max',
  ]) {
    testWidgets('API 配置删除后续写不恢复旧文字：$initial', (tester) async {
      String? saved;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => Overlay(initialEntries: <OverlayEntry>[
          OverlayEntry(builder: (_) => MiuixPopupHost(child: child!)),
        ]),
        home: Builder(builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => editTextDialog(context, 'API 配置', '', initial,
                '标识符', (value) async => saved = value),
            child: const Text('编辑'),
          ),
        )),
      ));
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final field = find.byType(EditableText);
      await tester.tap(field);
      await tester.pumpAndSettle();
      final shortened = initial.substring(0, initial.length - 3);
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: shortened,
        selection: TextSelection.collapsed(offset: shortened.length),
        composing: TextRange(start: 0, end: shortened.length),
      ));
      await tester.pump();
      final controller = tester.widget<EditableText>(field).controller;
      expect(controller.text, shortened);
      expect(controller.value.composing, TextRange.empty);
      final continued = '${shortened}x';
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: continued,
        selection: TextSelection.collapsed(offset: continued.length),
        composing: TextRange(start: 0, end: continued.length),
      ));
      await tester.pump();
      expect(controller.text, continued);
      expect(controller.value.composing, TextRange.empty);
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '', selection: TextSelection.collapsed(offset: 0)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'z', selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1)));
      await tester.pump();
      expect(controller.text, 'z');
      expect(controller.value.composing, TextRange.empty);
      expect(tester.takeException(), isNull);
      expect(saved, isNull, reason: '编辑过程不能提前保存配置');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  }
}
