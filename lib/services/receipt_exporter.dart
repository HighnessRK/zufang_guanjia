import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// 收据图片导出（v1.1.3）：把渲染中的 [RepaintBoundary] 截成 PNG，
/// 写入应用缓存目录（FileProvider 的 cache-path 已覆盖，原生分享可直接用）。
class ReceiptExporter {
  ReceiptExporter._();

  /// 把 [key] 对应的 RepaintBoundary 渲染为 PNG，返回文件绝对路径。
  ///
  /// pixelRatio 3.0：312 逻辑宽的收据卡 → 936px 宽，微信转发足够清晰。
  static Future<String> exportPng(GlobalKey key, {double pixelRatio = 3.0}) async {
    final BuildContext? ctx = key.currentContext;
    if (ctx == null) {
      throw StateError('收据尚未渲染，无法导出');
    }
    final RenderObject? obj = ctx.findRenderObject();
    if (obj is! RenderRepaintBoundary) {
      throw StateError('收据未包在 RepaintBoundary 中');
    }
    final ui.Image image = await obj.toImage(pixelRatio: pixelRatio);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('收据图片编码失败');
    }
    final Uint8List bytes = data.buffer.asUint8List();
    final Directory dir = await getTemporaryDirectory();
    final String path =
        '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
