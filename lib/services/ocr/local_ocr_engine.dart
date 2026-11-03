import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'meter_locator.dart';
import 'model_manager.dart';
import 'ocr_engine.dart';

/// Image preprocessing runs off the UI isolate. Cap the LONG edge as well as
/// the short edge so panoramas cannot exhaust the vision token budget.
List<int> _thumbnail(List<int> bytes) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) throw const FormatException('无法解码照片');
  final oriented = img.bakeOrientation(decoded);
  final scale = math.min(
      1.0,
      math.min(384 / math.min(oriented.width, oriented.height),
          1024 / math.max(oriented.width, oriented.height)));
  return img.encodeJpg(img.copyResize(oriented,
      width: math.max(1, (oriented.width * scale).round()),
      height: math.max(1, (oriented.height * scale).round())));
}

class LocalOcrEngine implements OcrEngine {
  LocalOcrEngine(this.models);
  final ModelManager models;
  LlamaEngine? _engine;
  String backend = 'CPU';

  Future<LlamaEngine> _load() async {
    if (_engine != null) return _engine!;
    if (!models.ready) throw StateError('本地模型未下载或校验未通过');
    // This distribution uses the default CPU AAR. No invented runtime AAR API.
    final engine = await LlamaEngine.spawn(
      modelParams:
          ModelParams(path: models.file(models.assets[0]).path, gpuLayers: 0),
      contextParams: const ContextParams(nCtx: 4096, nBatch: 256, nUbatch: 256),
      multimodalParams: MultimodalParams(
          mmprojPath: models.file(models.assets[1]).path, useGpu: false),
    );
    if (!engine.supportsVision || !engine.multimodalLoaded) {
      await engine.dispose();
      throw StateError('投影器未提供视觉能力，已停止本地识别');
    }
    // Devices enumerate available backends, not evidence of tensor placement.
    // gpuLayers=0 and useGpu=false deliberately guarantee this build's CPU path.
    debugPrint(
        'OCR backend CPU; devices=${engine.devices.map((d) => d.registryName).join(',')}');
    _engine = engine;
    return engine;
  }

  @override
  Future<OcrResult> recognize(File image, {String? prompt}) async {
    final engine = await _load();
    final temp = await Directory.systemTemp.createTemp('ocr-image-');
    try {
      final small = File('${temp.path}/input.jpg');
      await small
          .writeAsBytes(await compute(_thumbnail, await image.readAsBytes()));
      final text =
          await _run(engine, small.path, prompt ?? '读取图片中的数字', maxTokens: 2048);
      return OcrResult(text, '本地 Xiaomi-OCR-0 · $backend');
    } finally {
      await temp.delete(recursive: true);
    }
  }

  /// 整层电表：先定位每块表的示数窗，再逐窗识别。
  ///
  /// 整图缩到短边 384 后一位数字只有几个像素，整图一次推理无法稳定读出
  /// 五块表。这里仍然遵守同样的短边上限，只是把每个窗口单独缩放；定位
  /// 失败、窗口数量不符或任一窗无法解析时抛错，交给上层按用户设置回退或
  /// 停止（本地模式绝不上传照片）。
  Future<OcrResult> recognizeFloor(File image, {required int expected}) async {
    final engine = await _load();
    final crops = await compute(
        _locateCrops, _CropRequest(await image.readAsBytes(), expected));
    if (crops == null || crops.isEmpty) {
      throw const FormatException('未能定位到与房间数一致的电表示数窗，请重新拍照');
    }
    final temp = await Directory.systemTemp.createTemp('ocr-windows-');
    try {
      final List<int?> readings = <int?>[];
      for (int i = 0; i < crops.length; i++) {
        final File crop = File('${temp.path}/window-$i.jpg');
        await crop.writeAsBytes(crops[i]);
        int? value;
        for (final String prompt in _cropPrompts) {
          try {
            final String text =
                await _run(engine, crop.path, prompt, maxTokens: 64);
            value = parseMeterCropReading(text);
            debugPrint('OCR_WINDOW $i value=$value');
            if (value != null) break;
          } catch (e) {
            debugPrint('OCR_WINDOW $i retry failed: $e');
          }
        }
        // null 在 JSON 中作为「看不清」占位，由上层转成 -1；
        // 不会用猜测值填补，也不会因一块表失败而伪造读数。
        readings.add(value);
      }
      if (readings.every((int? v) => v == null)) {
        throw const FormatException('本地模型未能读出任何电表示数');
      }
      return OcrResult(jsonEncode(readings), '本地 Xiaomi-OCR-0 · $backend');
    } finally {
      await temp.delete(recursive: true);
    }
  }

  static const List<String> _cropPrompts = <String>[
    '读取这张电表照片示数窗里的整数读数。从左到右读取整数位；'
        '最右侧红色小数轮不要读，表号、倍率、型号和铭牌数字也不要读。'
        '只输出一个整数，不要小数点、解释或单位。',
    '只输出电表示数窗里的整数数字，不要小数点。',
  ];

  Future<String> _run(LlamaEngine engine, String path, String prompt,
      {required int maxTokens}) async {
    final chat = await engine.createChat();
    try {
      chat.addUser(prompt, media: [LlamaMedia.imageFile(path)]);
      final text = StringBuffer();
      await for (final event in chat.generate(
          sampler: const SamplerParams(temperature: 0), maxTokens: maxTokens)) {
        if (event is TokenEvent) text.write(event.text);
        if (event is DoneEvent) {
          if (event.reason is! StopEog) {
            throw const FormatException('本地识别输出被截断或中止，请重新识别');
          }
          text.write(event.trailingText);
        }
      }
      if (text.toString().trim().isEmpty) {
        throw const FormatException('本地模型未返回内容');
      }
      return text.toString();
    } finally {
      await chat.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    await engine?.dispose();
  }
}

/// 单窗读数的严格解析：允许空格分组和常见单位，拒绝解释、多个数字、
/// 小数与非法范围。结果不合法返回 null，由调用方重试或留空。
@visibleForTesting
int? parseMeterCropReading(String raw) {
  final String text = raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
      .trim()
      .replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), '')
      .trim();
  final String compact = text.replaceAll(RegExp(r'[\s,，]'), '');
  final RegExpMatch? match =
      RegExp(r'^(\d{1,9})(?:kwh|kw·h|度|千瓦时)?\.?$', caseSensitive: false)
          .firstMatch(compact);
  if (match == null) return null;
  final int? value = int.tryParse(match.group(1)!);
  if (value == null || value > 999999999) return null;
  return value;
}

class _CropRequest {
  const _CropRequest(this.bytes, this.expected);
  final Uint8List bytes;
  final int expected;
}

List<Uint8List>? _locateCrops(_CropRequest request) =>
    cropMeterWindows(request.bytes, expected: request.expected);
