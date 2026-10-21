import 'package:flutter/material.dart';

import '../widgets/app_widgets.dart';

/// 设置各二级页共用的参数编辑对话框与小工具。
/// 全部走 [showAppDialog]（液态玻璃对话框），保存后由调用方自行刷新页面。

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
  ctrl.dispose();
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
  ctrl.dispose();
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
  ctrl.dispose();
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
