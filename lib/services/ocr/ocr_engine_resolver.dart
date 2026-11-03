import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import 'local_ocr_engine.dart';
import 'model_manager.dart';
import 'ocr_engine.dart';

/// Serializes inference, model deletion and setting changes so a file cannot
/// be removed while native code is using it. No model is loaded in cloud mode.
class OcrEngineResolver extends ChangeNotifier {
  OcrEngineResolver({ModelManager? models, OcrEngine? local})
      : models = models ?? ModelManager.instance,
        _local = local;
  static final instance = OcrEngineResolver();
  final ModelManager models;
  OcrEngine? _local;
  Future<void> _tail = Future<void>.value();
  String actualEngine = '尚未识别', warning = '';

  Future<T> _exclusive<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// [localRunner] 让整层多表识别复用同一套本地/云端回退顺序：默认走
  /// 单张识别，整层入口传入逐窗识别；云端仍只收到一次整图请求。
  Future<OcrResult> recognize(File image,
          {required CloudOcrEngine cloud,
          String? prompt,
          void Function(String)? validate,
          Future<OcrResult> Function(LocalOcrEngine engine)? localRunner}) =>
      _exclusive(() async {
        warning = '';
        if (AppConfig.instance.ocrMode != 'cloud' && models.configured) {
          try {
            await models.init();
          } catch (e) {
            warning = '模型状态读取失败，使用云端：$e';
          }
        }
        if (AppConfig.instance.ocrMode != 'cloud' && models.ready) {
          try {
            _local ??= LocalOcrEngine(models);
            final result = localRunner == null
                ? await _local!.recognize(image, prompt: prompt)
                : await localRunner(_local! as LocalOcrEngine);
            validate?.call(result.text);
            actualEngine = result.engine;
            notifyListeners();
            return result;
          } catch (e) {
            await _local?.dispose();
            _local = null;
            if (AppConfig.instance.ocrMode == 'local') rethrow;
            warning = '本地识别失败，已回退云端：$e';
          }
        }
        if (AppConfig.instance.ocrMode == 'local') {
          actualEngine = '本地不可用（未上传照片）';
          notifyListeners();
          throw StateError('本地模型不可用，请重新下载并校验；照片未上传');
        }
        actualEngine = '云端 API';
        notifyListeners();
        final result = await cloud.recognize(image, prompt: prompt);
        validate?.call(result.text);
        return result;
      });

  Future<void> setMode(String mode) => _exclusive(() async {
        if (!['auto', 'local', 'cloud'].contains(mode)) {
          throw ArgumentError.value(mode);
        }
        await models.init();
        if (mode == 'local' && !models.ready) throw StateError('请先下载并校验模型');
        await _local?.dispose();
        _local = null;
        AppConfig.instance.ocrMode = mode;
        await AppConfig.instance.save();
        actualEngine = '尚未识别';
        notifyListeners();
      });

  Future<void> deleteModels() => _exclusive(() async {
        await _local?.dispose();
        _local = null;
        await models.delete();
        AppConfig.instance.ocrMode = 'auto';
        await AppConfig.instance.save();
        actualEngine = '云端 API（模型已删除）';
        notifyListeners();
      });
}
