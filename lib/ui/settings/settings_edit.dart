import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

/// 设置各二级页共用的参数编辑对话框与小工具。
/// 全部走 [showAppDialog]（液态玻璃对话框），保存后由调用方自行刷新页面。
///
/// 【控制器释放时机】这些对话框的局部 TextEditingController 一律**不手动
/// dispose**：showAppDialog 的 Future 在路由 pop 的瞬间就完成，而对话框的
/// 220ms 退出动画尚未结束，内部 MiuixTextField / EditableText 仍持有该
/// controller（输入法也未收起）。此时释放会抛
/// "A TextEditingController was used after being disposed"，真机表现为保存后
/// 闪一下红色报错页 / 被弹回首页（v1.1.1 修复）。它们是局部变量，对话框
/// 卸载后监听随之解除，交给 GC 回收即可。

/// 修改一个数值参数（浮点，允许 0）
Future<void> editNumberDialog(
  BuildContext context,
  String title,
  String unit,
  double current,
  Future<void> Function(double) onSave,
) async {
  final TextEditingController ctrl =
      TextEditingController(text: trimNumber(current));
  final bool? ok = await showAppDialog(
    context,
    title: '设置$title',
    summary: '单位：$unit，修改后立即保存到 info.gwt',
    content: AppTextField(
      label: title,
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
  );
  if (ok != true) return;
  final double? v = double.tryParse(ctrl.text.trim());
  if (v != null && v >= 0) {
    await onSave(v);
  }
}

/// 修改一个整数参数（允许 0）
Future<void> editIntDialog(
  BuildContext context,
  String title,
  String unit,
  int current,
  Future<void> Function(int) onSave,
) async {
  final TextEditingController ctrl = TextEditingController(text: '$current');
  final bool? ok = await showAppDialog(
    context,
    title: '设置$title',
    summary: '单位：$unit，修改后立即保存到 info.gwt',
    content: AppTextField(
      label: title,
      controller: ctrl,
      keyboardType: TextInputType.number,
    ),
  );
  if (ok != true) return;
  final int? v = int.tryParse(ctrl.text.trim());
  if (v != null && v >= 0) {
    await onSave(v);
  }
}

/// 修改一个文本参数（API 地址 / Key / 模型名，允许清空）
Future<void> editTextDialog(
  BuildContext context,
  String title,
  String summary,
  String current,
  String hint,
  Future<void> Function(String) onSave,
) async {
  final TextEditingController ctrl = TextEditingController(text: current);
  final bool? ok = await showAppDialog(
    context,
    title: '设置$title',
    summary: summary,
    content: AppTextField(
      label: hint,
      controller: ctrl,
    ),
  );
  if (ok != true) return;
  await onSave(ctrl.text.trim());
}

/// Key 打码显示：sk-abcdef123456 → sk-a•••••3456
String maskKey(String key) {
  if (key.isEmpty) return '未配置（仅保存在本机）';
  if (key.length <= 8) return key;
  return '${key.substring(0, 5)}••••${key.substring(key.length - 4)}';
}

/// 去掉多余的 .0（用于摘要展示价格等）
String trimNumber(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
