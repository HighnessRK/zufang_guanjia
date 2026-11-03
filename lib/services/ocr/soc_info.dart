import 'package:flutter/services.dart';

class SocInfo {
  const SocInfo(this.description, this.level);
  final String description;

  /// 0 unknown/unsupported, 1 experimental Gen1, 2 recommended.
  final int level;
  static SocInfo parse(Map<String, dynamic> info) {
    final text = ['socModel', 'hardware', 'board']
        .map((key) => info[key] ?? '')
        .join(' ')
        .trim();
    final ids = RegExp(r'\bSM(\d{4})\b', caseSensitive: false)
        .allMatches(text)
        .map((m) => int.parse(m[1]!))
        .toList();
    // Explicit known IDs only: numeric ordering is NOT proof of a future SoC.
    final level = ids.any([8550, 8650, 8750, 8850].contains)
        ? 2
        : ids.any([8450, 8475].contains)
            ? 1
            : 0;
    return SocInfo(text.isEmpty ? 'SoC 未知' : text, level);
  }

  static Future<SocInfo> read() async {
    try {
      final info = await const MethodChannel('com.zufang.guanjia/native')
          .invokeMapMethod<String, dynamic>('systemInfo');
      return parse(info ?? {});
    } on PlatformException {
      return const SocInfo('SoC 未知', 0);
    } on MissingPluginException {
      return const SocInfo('SoC 未知', 0);
    }
  }

  String get hint => level == 2
      ? '检测到骁龙 8 Gen 2 或较新系列，可作为未来 Hexagon 构建的候选测试设备。当前版本仍为 CPU，未验证该模型的 NPU 兼容性或加速效果。'
      : level == 1
          ? '检测到骁龙 8 Gen 1 系列。当前版本使用 CPU；其他 Hexagon 构建需要单独验证兼容性，不能在此开启。'
          : '当前设备芯片不在推荐范围内，NPU 加速可能无法工作。';
}
