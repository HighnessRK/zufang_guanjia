import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/widgets/app_editable_field.dart';
import 'package:zufang_guanjia/ui/settings/settings_edit.dart';

void main() {
  testWidgets('姓名输入保留中文拼音合成，不套用标识符规则', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AppEditableField(controller: controller))));
    await tester.tap(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'zhang', selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 0, end: 5)));
    await tester.pump();
    expect(controller.value.composing, const TextRange(start: 0, end: 5));
    await tester.enterText(find.byType(EditableText), '张三');
    expect(controller.text, '张三');
  });
  testWidgets('弹窗选中文字可显示复制粘贴菜单并实际粘贴', (tester) async {
    String clipboard = 'pasted-value';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
        return null;
      });
    addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MiuixSystemTheme(child: MaterialApp(
      builder: (_, child) => AppClipboardOverlay(
        child: MiuixPopupHost(child: child!)),
      home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => editTextDialog(context, '参数', '', 'old-value', '', (_) async {}),
        child: const Text('编辑')))),
    )));
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final field = find.byType(EditableText);
    await tester.tap(field);
    await tester.pumpAndSettle();
    final state = tester.state<EditableTextState>(field);
    state.widget.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
    state.showToolbar();
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(state.contextMenuButtonItems.map((e) => e.type),
      containsAll([ContextMenuButtonType.copy, ContextMenuButtonType.paste]));
    await state.pasteText(SelectionChangedCause.toolbar);
    await tester.pumpAndSettle();
    expect(state.widget.controller.text, 'pasted-value');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
}
