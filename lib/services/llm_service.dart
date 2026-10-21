import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';

/// 识别到的一块电表：读数 + 照片中看到的标识（房号 / 表号 / 位置文字）。
class MeterReading {
  const MeterReading({required this.label, required this.reading});

  /// 照片中该电表旁的标识文字（房号 / 表号 / 位置），可能为空
  final String label;

  /// 表盘读数
  final int reading;
}

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
      prompt: '这是一张电表读数照片。只输出表盘上显示的数字读数，'
          '不要任何其他文字、单位或标点。',
      imageBytes: imageBytes,
      maxTokens: 32,
    );
    final Match? match = RegExp(r'\d+').firstMatch(text);
    if (match == null) {
      throw FormatException('未能解析读数（返回：${_snippet(text)}）');
    }
    return int.parse(match.group(0)!);
  }

  /// 整层批量识别：一次识别照片中的多块电表，按出现顺序返回全部读数与标识。
  /// [roomNos] 为本层房间号，用于提示模型优先摘录对应标识。
  static Future<List<MeterReading>> recognizeFloorElecMeters(
    Uint8List imageBytes, {
    required List<String> roomNos,
  }) async {
    final AppConfig cfg = _requireVisionConfig();
    final String text = await _chatVision(
      cfg,
      prompt: '这是一张楼房电表照片，可能包含多块电表。'
          '本层房间号：${roomNos.join('、')}。'
          '请逐块识别每块电表当前的数字读数；若表盘旁贴有房号、表号或'
          '位置标识，请一并摘录。严格只输出一个 JSON 数组，不要输出'
          '任何其他文字、解释或代码块标记，格式：'
          '[{"label":"101","reading":12345},{"label":"102","reading":23456}]',
      imageBytes: imageBytes,
      maxTokens: 768,
    );

    final Match? m = RegExp(r'\[[\s\S]*?\]').firstMatch(text);
    if (m == null) {
      throw FormatException('未识别到电表读数（返回：${_snippet(text)}）');
    }
    final Object? decoded = jsonDecode(m.group(0)!);
    if (decoded is! List<dynamic>) {
      throw FormatException('识别结果不是 JSON 数组（返回：${_snippet(text)}）');
    }
    final List<MeterReading> out = <MeterReading>[];
    for (final Object? e in decoded) {
      if (e is! Map<String, dynamic>) continue;
      final int? reading = _toInt(e['reading']);
      if (reading == null || reading < 0) continue;
      out.add(MeterReading(label: '${e['label'] ?? ''}', reading: reading));
    }
    if (out.isEmpty) {
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

      return switch (content) {
        final String s => s,
        // OpenAI 新格式 content 为分段数组
        final List<dynamic> list => list
            .map((dynamic e) =>
                e is Map<String, dynamic> ? (e['text'] ?? '') : '')
            .join(),
        _ => '',
      };
    } finally {
      client.close(force: true);
    }
  }

  /// 宽容的整数解析（int / num / 含数字字符串）
  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      return int.tryParse(RegExp(r'\d+').firstMatch(v)?.group(0) ?? '');
    }
    return null;
  }

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static String _snippet(String s) {
    final String t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= 120 ? t : t.substring(0, 120);
  }
}
