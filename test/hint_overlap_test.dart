// 【v1.1.3 回归测试】输入框灰提示与输入数值的显隐互斥。
//
// 真机复现：新增/编辑房间「配套与资产」点「+」后，数值「0」压在灰提示
// 「0 = 无」上。根因是 v1.1.2 把 AppLabelField._sync 改成只在焦点变化时
// setState 后，MiuixTextField 内部按 build 时点判定的占位提示在
// 「空↔非空」翻转时无人重建 → 旧提示滞留。
//
// 本测试用与线上完全相同的组件跑用户的真实操作序列，断言两者永不同时在场。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/ui/widgets/app_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))),
    );

void main() {
  testWidgets('计数器字段：空→点+→清空，灰提示与数值互斥', (WidgetTester tester) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(
      AppLabelField(
        label: '钥匙数量（把）',
        hint: '0 = 无',
        controller: c,
        keyboardType: TextInputType.number,
        labelWidth: 112,
        stepper: const StepperRange(min: 0, max: 99),
      ),
    ));
    await tester.pumpAndSettle();

    // 1) 新房间默认空：只应有灰提示，无数值
    int hint = find.text('0 = 无').evaluate().length;
    int value = find.text('0').evaluate().length;
    // ignore: avoid_print
    print('STATE 空: hint=$hint value=$value');
    expect(hint, 1, reason: '空字段应显示灰提示');
    expect(value, 0, reason: '空字段不应有数值');
    expect(hint + value, 1, reason: '不变量：提示与数值有且只有一个在场');

    // 2) 点「+」→ 数值 0：提示必须退场，绝不许与数值同屏（真机 bug）
    c.text = '0';
    await tester.pumpAndSettle();
    hint = find.text('0 = 无').evaluate().length;
    value = find.text('0').evaluate().length;
    // ignore: avoid_print
    print('STATE 数值0: hint=$hint value=$value');
    expect(value, 1, reason: '点+后应显示数值 0');
    expect(hint, 0, reason: '【v1.1.3】点+后灰提示必须消失，不得与数值重叠');
    expect(hint + value, 1, reason: '提示与数值互斥，不得同屏');

    // 3) 清空（删除到底）：提示回归
    c.clear();
    await tester.pumpAndSettle();
    hint = find.text('0 = 无').evaluate().length;
    value = find.text('0').evaluate().length;
    // ignore: avoid_print
    print('STATE 清空后: hint=$hint value=$value');
    expect(hint, 1, reason: '清空后灰提示应回归');
    expect(value, 0, reason: '清空后无数值');
    expect(hint + value, 1, reason: '不变量：提示与数值有且只有一个在场');
  });

  testWidgets('普通输入框（AppTextField）：输入后提示不得与文字同屏', (WidgetTester tester) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);

    await tester.pumpWidget(_wrap(
      AppTextField(label: '姓名', controller: c),
    ));
    await tester.pumpAndSettle();

    expect(find.text('姓名').evaluate().length, 1, reason: '空字段显示提示');

    c.text = '张三';
    await tester.pumpAndSettle();
    final int hint = find.text('姓名').evaluate().length;
    final int value = find.text('张三').evaluate().length;
    // ignore: avoid_print
    print('AppTextField 输入后: hint=$hint value=$value');
    expect(value, 1);
    expect(hint, 0, reason: '【v1.1.3】输入后提示必须退场');
    expect(hint + value, 1, reason: '提示与内容互斥');
  });
}
