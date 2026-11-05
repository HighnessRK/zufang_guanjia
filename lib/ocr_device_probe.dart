// Isolated device-only smoke-test entrypoint. Does not initialize the ledger,
// configuration, cloud API, notifications or Feishu services.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:image/image.dart' as img;

import 'services/ocr/local_ocr_engine.dart';
import 'services/ocr/model_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String status = '点击测试：离线视觉识别';
  bool busy = false;
  Future<void> probe() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = '正在校验并加载模型…';
    });
    const channel = MethodChannel('com.zufang.guanjia/native');
    await channel.invokeMethod<void>('recognitionActive', {'active': true});
    final engine = LocalOcrEngine(ModelManager.instance);
    try {
      LlamaLibrary.load(path: LlamaLibrary.defaultFileName());
      LlamaLog.captureToFile(
          '${(await getTemporaryDirectory()).path}/ocr-native.log');
      await ModelManager.instance.init();
      // Synthetic fixture, never a real bill or tenant photo.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.white, BlendMode.src);
      final painter = TextPainter(
          text: const TextSpan(
              text: '24737',
              style: TextStyle(color: Colors.black, fontSize: 64)),
          textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(canvas, const Offset(20, 35));
      final image = await recorder.endRecording().toImage(300, 140);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/ocr-fixture.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      final watch = Stopwatch()..start();
      final external = File(
          '${(await getApplicationSupportDirectory()).path}/probe-input.jpg');
      final input = await external.exists() ? external : file;
      final floorFlag =
          File('${(await getApplicationSupportDirectory()).path}/probe-floor');
      if (await floorFlag.exists()) {
        debugPrint('OCR_FLOOR START input=${input.path}');
        final result = await engine.recognizeFloor(input, expected: 5);
        status =
            'FLOOR=${result.text}\nENGINE=${result.engine}\nSECONDS=${watch.elapsedMilliseconds / 1000}';
        debugPrint('OCR_FLOOR $status');
        return;
      }
      final tilesFlag =
          File('${(await getApplicationSupportDirectory()).path}/probe-tiles');
      if (await tilesFlag.exists()) {
        final source =
            img.bakeOrientation(img.decodeImage(await input.readAsBytes())!);
        final results = <String>[];
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 3; col++) {
            final left = source.width * col ~/ 3;
            final top = source.height * row ~/ 2;
            final tile = img.copyCrop(source,
                x: left,
                y: top,
                width: source.width * (col + 1) ~/ 3 - left,
                height: source.height * (row + 1) ~/ 2 - top);
            final tileFile = await File('${dir.path}/tile-$row-$col.jpg')
                .writeAsBytes(img.encodeJpg(tile));
            final result = await engine.recognize(tileFile,
                prompt: '读取图片中电表的黑色整数读数，忽略红色小数位。只输出整数。没有电表则输出null。');
            results.add(result.text);
            debugPrint('OCR_TILE $row,$col ${result.text}');
          }
        }
        status = 'TILES=$results\nSECONDS=${watch.elapsedMilliseconds / 1000}';
        return;
      }
      final promptFile = File(
          '${(await getApplicationSupportDirectory()).path}/probe-prompt.txt');
      debugPrint('OCR_PROBE START input=${input.path}');
      final result = await engine.recognize(input,
          prompt: await promptFile.exists()
              ? await promptFile.readAsString()
              : input == external
                  ? 'Read only the electricity meter reading in kWh. Ignore serial numbers and labels. Output only the integer digits.'
                  : 'Read the number in this image. Output only the digits, no explanation.');
      status =
          'OUTPUT=${result.text}\nENGINE=${result.engine}\nSECONDS=${watch.elapsedMilliseconds / 1000}';
      debugPrint('OCR_PROBE $status');
    } catch (e, st) {
      status = 'ERROR=$e';
      debugPrint('OCR_PROBE $e\n$st');
    } finally {
      await engine.dispose();
      await channel.invokeMethod<void>('recognitionActive', {'active': false});
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(status),
                ElevatedButton(
                    onPressed: busy ? null : probe,
                    child: const Text('测试离线 OCR')),
              ]))));
}
