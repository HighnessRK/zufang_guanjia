import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// 大模型视觉识别服务：把电表照片发送到 OpenAI 兼容接口识别读数。
///
/// 【隐私边界】只在用户主动点「拍照识别」时发送当前这一张照片，
/// 不上传任何房间 / 租户 / 账单数据；API 地址 / Key 仅存本机 info.gwt。
///
/// 【接口约定】POST {llm_base_url}/chat/completions
///   Authorization: Bearer {llm_api_key}
///   {"model": 视觉模型, "messages":[{"role":"user","content":[文本提示, 图片base64]}]}
class LlmService {
  LlmService._();

  /// 单块电表识别：返回整数读数。
  /// 配置缺失抛 [StateError]，HTTP / 解析失败抛带中文说明的异常。
  static Future<int> recognizeElecMeter(Uint8List imageBytes) async {
    final AppConfig cfg = _requireVisionConfig();
    final String text = await _chatVision(
      cfg,
      prompt: '这是一张电表读数照片。只识别黑色数字轮的整数读数。'
          '红色小数位、红色数字和小数点全部舍弃，不要四舍五入。'
          '机械表红色数字轮通常表示0.1位，不能拼入整数。不要读取表号、倍率或铭牌。'
          '只输出一个整数，不要任何解释、单位或其他数字。',
      imageBytes: imageBytes,
      maxTokens: 1024,
    );
    return parseReading(text);
  }

  /// 整层批量识别：**按位置顺序**读出照片里每块电表的读数。
  ///
  /// 【内置提示词】电表箱里表的排布是「按行、从左到右、从上到下」，
  /// 与本层房间号升序一一对应（4 块表 → x01、x02、x03、x05；
  /// 5 块表 → x01、x02、x03、x05、x06 —— 房号里不含 04，跳过它）。
  /// 因此这里不再让模型猜表旁的文字标识，而是把预期房间号列表直接写进
  /// 提示词，要求模型**按同样的空间顺序**只吐一个数字数组。
  ///
  /// [roomNos] 必须是本层已按房号升序排好的房间号。
  /// 返回与 [roomNos] 等长（或更短，模型漏读时）的读数列表。
  static Future<List<int>> recognizeFloorMeterReadings(
    Uint8List imageBytes, {
    required List<String> roomNos,
  }) async {
    final AppConfig cfg = _requireVisionConfig();
    final String text = await _chatVision(
      cfg,
      prompt: '这是一张楼房电表箱照片，里面有多块电表，安装排布规律为：'
          '按行排列，每一行内从左到右，逐行从上到下。\n'
          '本层房间号（已按这个顺序排好）：${roomNos.join('、')}。\n'
          '请按同样的空间顺序（每行从左到右、行与行从上到下）逐块读取'
           '每块电表表盘上的数字读数，第 n 个数字对应第 n 个房间号。\n'
          '只取黑色整数位，舍弃红色小数位，不四舍五入；看不清的表用null占位，不能省略。\n'
          '只输出一个 JSON 数字数组，元素个数与看到的电表块数一致，'
          '不要任何其他文字、解释或代码块标记，例如：'
          '[24737,35298,11111,21466]',
      imageBytes: imageBytes,
      maxTokens: 2048,
    );

    final Match? m = RegExp(r'\[[\s\S]*?\]').firstMatch(text);
    if (m == null) {
      throw FormatException('未识别到电表读数（返回：${_snippet(text)}）');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(m.group(0)!);
    } catch (_) {
      throw FormatException('识别结果不是 JSON 数组（返回：${_snippet(text)}）');
    }
    if (decoded is! List<dynamic>) {
      throw FormatException('识别结果不是 JSON 数组（返回：${_snippet(text)}）');
    }
    final List<int> out = <int>[];
    for (final Object? e in decoded) {
      final int? reading = _toInt(e);
      if (reading == null || reading < 0) {
        // 数组里混入非数字（模型偶发输出 null / 字符串）→ 用 -1 占位，
        // 保住「下标 ↔ 房间号」的对位关系，调用方据此跳过该格
        out.add(-1);
        continue;
      }
      out.add(reading);
    }
    if (out.every((int v) => v < 0)) {
      throw FormatException('未解析出有效读数（返回：${_snippet(text)}）');
    }
    return out;
  }

  //========================= 内部实现 =========================

  static AppConfig _requireVisionConfig() {
    final AppConfig cfg = AppConfig.instance;
    if (cfg.llmBaseUrl.isEmpty ||
        cfg.llmApiKey.isEmpty ||
        cfg.llmVisionModel.isEmpty) {
      throw StateError('未配置大模型 API，请先到设置页填写');
    }
    return cfg;
  }

  /// 调一次视觉对话接口，返回模型输出的纯文本
  static Future<String> _chatVision(
    AppConfig cfg, {
    required String prompt,
    required Uint8List imageBytes,
    required int maxTokens,
  }) async {
    final Uri uri = Uri.parse('${_trimSlash(cfg.llmBaseUrl)}/chat/completions');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);

    try {
      final HttpClientRequest request =
          await client.postUrl(uri).timeout(const Duration(seconds: 30));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${cfg.llmApiKey}');

      final String imageB64 = base64Encode(imageBytes);
      request.write(
        jsonEncode(<String, Object?>{
          'model': cfg.llmVisionModel,
          'max_tokens': maxTokens,
          'temperature': 0,
          'messages': <Object?>[
            <String, Object?>{
              'role': 'user',
              'content': <Object?>[
                <String, Object?>{'type': 'text', 'text': prompt},
                <String, Object?>{
                  'type': 'image_url',
                  'image_url': <String, String>{
                    'url': 'data:image/jpeg;base64,$imageB64',
                  },
                },
              ],
            },
          ],
        }),
      );

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 120));
      final String body = await response.transform(utf8.decoder).join().timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('API 返回 ${response.statusCode}：${_snippet(body)}');
      }

      final Object? json = jsonDecode(body);
      final Object? choices =
          json is Map<String, dynamic> ? json['choices'] : null;
      final Object? message = (choices is List && choices.isNotEmpty)
          ? (choices.first as Map<String, dynamic>)['message']
          : null;
      final Object? content =
          message is Map<String, dynamic> ? message['content'] : null;

      final text = switch (content) {
        final String s => s,
        // OpenAI 新格式 content 为分段数组
        final List<dynamic> list => list
            .map((dynamic e) =>
                e is Map<String, dynamic> ? (e['text'] ?? '') : '')
            .join(),
        _ => '',
      };
      if (text.trim().isEmpty) {
        throw const FormatException('模型没有返回可用识别内容，请确认模型支持图片，或提高服务端输出额度');
      }
      return text;
    } finally {
      client.close(force: true);
    }
  }

  /// 宽容的整数解析（int / num / 含数字字符串）
  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.truncate();
    if (v is String) {
      return num.tryParse(v.trim())?.truncate();
    }
    return null;
  }

  /// 拒绝从解释中的多个数字猜读数；小数统一截断。
  @visibleForTesting
  static int parseReading(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), '').trim();
    if (!RegExp(r'^\d{1,9}(?:\.\d+)?$').hasMatch(cleaned)) {
      throw FormatException('未能解析唯一读数（返回：${_snippet(text)}）');
    }
    return num.parse(cleaned).truncate();
  }

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static String _snippet(String s) {
    final String t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= 120 ? t : t.substring(0, 120);
  }
}
