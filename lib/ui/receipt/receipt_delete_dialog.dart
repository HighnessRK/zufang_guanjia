import 'package:flutter/material.dart';
import '../widgets/app_widgets.dart';
import '../../data/models/receipt.dart';

Future<bool> confirmDeleteReceipt(
        BuildContext context, Receipt receipt) async =>
    await showAppDialog(context,
        title: '删除收据？',
        summary: '${receipt.no}\n可按同账期重新生成',
        confirmText: '删除',
        danger: true) ??
    false;
