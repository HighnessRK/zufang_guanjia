import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zufang_guanjia/services/ocr/meter_locator.dart';

void main() {
  test('红色小数轮及中性压缩残边均移除，黑色整数保留', () {
    final image = img.Image(width: 200, height: 60);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(image,
        x1: 20, y1: 10, x2: 100, y2: 50, color: img.ColorRgb8(25, 25, 25));
    img.fillRect(image,
        x1: 150, y1: 10, x2: 160, y2: 50, color: img.ColorRgb8(140, 40, 40));
    image.setPixelRgb(155, 30, 45, 45, 45);
    image.setPixelRgb(161, 30, 45, 45, 45);
    removeRedMeterDigits(image);
    expect(image.getPixel(155, 30).r, 255);
    expect(image.getPixel(161, 30).r, 255);
    expect(image.getPixel(50, 30).r, 25);
  });
  test('五块高亮示数窗按行从左到右定位并裁成小图', () {
    final img.Image source = img.Image(width: 1200, height: 900);
    img.fill(source, color: img.ColorRgb8(45, 45, 50));
    // 顶部灯带：高亮但过宽，必须被过滤，不能当成第六块表。
    img.fillRect(source,
        x1: 20, y1: 10, x2: 1180, y2: 45, color: img.ColorRgb8(250, 250, 250));
    final List<List<int>> boxes = <List<int>>[
      <int>[240, 220, 120, 95],
      <int>[515, 222, 120, 95],
      <int>[790, 224, 120, 95],
      <int>[230, 640, 120, 95],
      <int>[505, 642, 120, 95],
    ];
    for (final List<int> box in boxes) {
      img.fillRect(source,
          x1: box[0],
          y1: box[1],
          x2: box[0] + box[2],
          y2: box[1] + box[3],
          color: img.ColorRgb8(248, 248, 246));
      // 深色数字，模拟被数字切开的白色示数窗。
      for (int i = 0; i < 5; i++) {
        img.fillRect(source,
            x1: box[0] + 18 + i * 17,
            y1: box[1] + 30,
            x2: box[0] + 30 + i * 17,
            y2: box[1] + 66,
            color: img.ColorRgb8(20, 20, 20));
      }
    }
    final Uint8List bytes =
        Uint8List.fromList(img.encodeJpg(source, quality: 92));
    final List<MeterWindow>? found =
        locateMeterWindows(img.decodeImage(bytes)!, expected: 5);
    expect(found, isNotNull);
    expect(found!.length, 5);
    for (int i = 0; i < 2; i++) {
      expect(found[i].left, lessThan(found[i + 1].left));
      expect(found[i].top, lessThan(500));
    }
    expect(found[3].left, lessThan(found[4].left));
    expect(found[3].top, greaterThan(500));

    final List<Uint8List>? crops =
        cropMeterWindows(bytes, expected: 5, shortEdge: 384);
    expect(crops, isNotNull);
    expect(crops!.length, 5);
    for (final Uint8List crop in crops) {
      final img.Image image = img.decodeImage(crop)!;
      expect(image.width, lessThanOrEqualTo(1024));
      expect(image.height, lessThanOrEqualTo(1024));
      expect(image.width < image.height ? image.width : image.height,
          lessThanOrEqualTo(384));
    }
    final List<Uint8List>? small =
        cropMeterWindows(bytes, expected: 5, shortEdge: 100);
    expect(small, isNotNull);
    for (final Uint8List crop in small!) {
      final img.Image image = img.decodeImage(crop)!;
      expect(image.width < image.height ? image.width : image.height, 100);
    }
  });

  test('窗口数与预期房间数不一致时返回 null，由上层回退', () {
    final img.Image source = img.Image(width: 800, height: 600);
    img.fill(source, color: img.ColorRgb8(40, 40, 40));
    img.fillRect(source,
        x1: 200,
        y1: 200,
        x2: 360,
        y2: 300,
        color: img.ColorRgb8(250, 250, 250));
    final Uint8List bytes =
        Uint8List.fromList(img.encodeJpg(source, quality: 90));
    expect(locateMeterWindows(img.decodeImage(bytes)!, expected: 2), isNull);
    expect(cropMeterWindows(bytes, expected: 2), isNull);
  });
}
