import 'dart:io';

class OcrResult {
  const OcrResult(this.text, this.engine);
  final String text, engine;
}

abstract class OcrEngine {
  Future<OcrResult> recognize(File image, {String? prompt});
  Future<void> dispose();
}

typedef CloudVision = Future<String> Function(File image, String prompt);

class CloudOcrEngine implements OcrEngine {
  CloudOcrEngine(this.request);
  final CloudVision request;
  @override
  Future<OcrResult> recognize(File image, {String? prompt}) async =>
      OcrResult(await request(image, prompt ?? '读取图片中的数字'), '云端 API');
  @override
  Future<void> dispose() async {}
}
