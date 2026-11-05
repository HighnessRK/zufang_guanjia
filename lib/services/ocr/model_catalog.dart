/// Byte-identical Gitee mirror of xzl01/Xiaomi-OCR-0-GGUF v1.0.0.
/// SHA-256 values are the publisher's FULL assembled-file hashes, not prefixes.
/// Both full-file hashes remain unchanged; the mirror only splits transport files.
class ModelAsset {
  const ModelAsset(this.name, this.url, this.sha256,
      {this.parts = 0, this.byteSize, this.partBytes = 41943040});
  final String name, url, sha256;
  final int parts;
  final int? byteSize;
  final int partBytes;
  List<String> get sources => parts == 0
      ? [url]
      : [
          for (var i = 0; i < parts; i++) '$url${i.toString().padLeft(2, '0')}',
        ];
  String? apiSource(int index) {
    if (url != '${ModelCatalog.base}/q8_0.part-' &&
        url != '${ModelCatalog.base}/mmproj-f16.gguf') {
      return null;
    }
    const ids = [
      603002812,
      602958039,
      602958690,
      602959410,
      602960192,
      602960799,
      602961324,
      602961854,
      602962209,
      602963318,
      602963704,
      602964343,
      602964881,
      602965651,
      602966811,
      602969846,
      602973260,
      602980338,
      602986683,
      603004267
    ];
    final id = parts == 20 ? ids[index] : 602798743;
    return 'https://api.github.com/repos/xzl01/Xiaomi-OCR-0-GGUF/releases/assets/$id?download=1&nonce=${DateTime.now().millisecondsSinceEpoch}';
  }

  int? sourceSize(int index) {
    if (byteSize != null) {
      return parts == 0
          ? byteSize
          : index == parts - 1
              ? byteSize! - partBytes * (parts - 1)
              : partBytes;
    }
    if (url == '${ModelCatalog.base}/q8_0.part-' && parts == 20) {
      return index == 19 ? 36673824 : 41943040;
    }
    if (url == '${ModelCatalog.base}/mmproj-f16.gguf') return 207345856;
    return null;
  }

  bool get configured =>
      Uri.tryParse(url)?.scheme == 'https' &&
      RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256);
}

class ModelCatalog {
  static const base =
      'https://github.com/xzl01/Xiaomi-OCR-0-GGUF/releases/download/v1.0.0';
  static const domesticBase =
      'https://gitee.com/highnesssrk/xiaomi-ocr-0-gguf/releases/download/v1.0.0';
  static const sourceLabel =
      customModel == '' && customProjector == '' ? 'Gitee 国内镜像' : '自定义下载源';
  static const customProjector = String.fromEnvironment('OCR_PROJECTOR_URL');
  static const customModel = String.fromEnvironment('OCR_MODEL_URL');
  static const assets = [
    ModelAsset(
        'Xiaomi-OCR-0-Q8_0.gguf',
        customModel == '' ? '$domesticBase/q8_0.part-' : customModel,
        String.fromEnvironment('OCR_MODEL_SHA256',
            defaultValue:
                '1b3c4e37129cb29896c61c833589be2acfb9eb0370bb84d3df12759f1f0f457a'),
        parts: customModel == '' ? 20 : 0,
        byteSize: customModel == '' ? 833591584 : null),
    ModelAsset(
        'mmproj-Xiaomi-OCR-0-F16.gguf',
        customProjector == ''
            ? '$domesticBase/mmproj-f16.part-'
            : customProjector,
        String.fromEnvironment('OCR_PROJECTOR_SHA256',
            defaultValue:
                '037e6a655ff168a5decb51c16dc819c06b7e19684441e98f00cb732c2ac61084'),
        parts: customProjector == '' ? 5 : 0,
        byteSize: customProjector == '' ? 207345856 : null),
  ];
  static bool get configured => assets.every((a) => a.configured);
}
