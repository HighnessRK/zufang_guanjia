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
    const names = {
      8450: '骁龙 8 Gen 1',
      8475: '骁龙 8+ Gen 1',
      8550: '骁龙 8 Gen 2',
      8650: '骁龙 8 Gen 3',
      8750: '骁龙 8 Elite',
      8850: '骁龙 8 Elite Gen 5'
    };
    for (final id in ids) {
      if (names.containsKey(id)) return SocInfo(names[id]!, id >= 8550 ? 2 : 1);
    }
    const mediatek = {
      'MT6993': '天玑 9500',
      'MT6991': '天玑 9400',
      'MT6989': '天玑 9300',
      'MT6985': '天玑 9200'
    };
    for (final entry in mediatek.entries) {
      if (text.toUpperCase().contains(entry.key)) {
        return SocInfo(entry.value, 3);
      }
    }
    // Use a friendly name supplied by Android, never expose board codenames.
    final name = '${info['socModel'] ?? ''}';
    return SocInfo(
        RegExp(r'Snapdragon|Dimensity|天玑|骁龙', caseSensitive: false)
                .hasMatch(name)
            ? name.replaceAll('Snapdragon', '骁龙').replaceAll('Dimensity', '天玑')
            : '芯片信息未识别',
        0);
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

  String get npu => level == 1 || level == 2
      ? '硬件支持 Hexagon NPU'
      : level == 3
          ? '硬件支持联发科 NPU'
          : '硬件能力待确认';
  String get hint => '$npu；支持的骁龙设备可使用 Hexagon 后端，不可用时使用 CPU。';
}
