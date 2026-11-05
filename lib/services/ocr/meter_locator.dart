import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 一块电表数字窗在原图中的位置（像素，左上角 + 宽高）。
class MeterWindow {
  const MeterWindow(this.left, this.top, this.width, this.height);

  final int left;
  final int top;
  final int width;
  final int height;
}

/// 定位照片中的电表数字窗，按「从上到下、每行从左到右」排序。
///
/// 机械电表的示数窗是照片里最大的一批「高亮、低饱和」矩形。整图直接缩到
/// 短边 384 时一位数字只剩几个像素，视觉模型无法稳定读数；因此先在缩小到
/// 长边 1200 的副本上做亮度/饱和度掩膜和连通域分析，再把候选窗口映射回
/// 原图裁切。找不到恰好 [expected] 个可信窗口时返回 null，由调用方回退到
/// 整图识别，不能凭空猜测位置或读数。
List<MeterWindow>? locateMeterWindows(img.Image source,
    {required int expected}) {
  final bright = _locateBright(source, expected: expected);
  if (bright != null) return bright;
  // LCD windows and dark faceplates also form bounded rectangles. Try inverted
  // contrast with the same count/geometry checks; never invent a grid of readings.
  final inverse = img.invert(img.Image.from(source));
  return _locateBright(inverse, expected: expected);
}

List<MeterWindow>? _locateBright(img.Image source, {required int expected}) {
  if (expected <= 0 || source.width < 32 || source.height < 32) {
    return null;
  }
  final int longEdge = math.max(source.width, source.height);
  final double scale = longEdge > 1200 ? 1200 / longEdge : 1.0;
  final int w = math.max(1, (source.width * scale).round());
  final int h = math.max(1, (source.height * scale).round());
  final img.Image small = scale == 1.0
      ? source
      : img.copyResize(source,
          width: w, height: h, interpolation: img.Interpolation.average);

  final Uint8List mask = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    final int row = y * w;
    for (int x = 0; x < w; x++) {
      final img.Pixel p = small.getPixel(x, y);
      final double r = p.r.toDouble();
      final double g = p.g.toDouble();
      final double b = p.b.toDouble();
      final double high = math.max(r, math.max(g, b));
      final double low = math.min(r, math.min(g, b));
      final double saturation = high <= 0 ? 0 : (high - low) / high;
      final double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
      if (luminance > 165 && saturation < 0.35) {
        mask[row + x] = 1;
      }
    }
  }

  // 7x7 闭运算（长边 1200 下约等于原图 9x9）：把被数字、色带切成
  // 多块的示数窗重新连成一个矩形，同时不把邻近的两块表粘在一起。
  final Uint8List closed = _close(_close(mask, w, h, 3), w, h, 3);
  final List<MeterWindow> analysis = _components(closed, w, h);
  final List<MeterWindow> filtered = analysis.where((MeterWindow box) {
    final double bw = box.width / w;
    final double bh = box.height / h;
    final double aspect = box.width / math.max(1, box.height);
    final double area = bw * bh;
    return bw >= 0.05 &&
        bw <= (expected <= 2 ? 0.6 : 0.32) &&
        bh >= 0.015 &&
        bh <= 0.26 &&
        aspect >= 0.9 &&
        aspect <= 4.4 &&
        area >= 0.002 &&
        area <= 0.08;
  }).toList();

  final List<MeterWindow> merged = _mergeNearby(filtered, w, h);
  if (merged.length != expected) return null;

  // 过滤掉明显比同组窗口小/大的伪候选（灯罩、纸张等）。
  final List<int> areas =
      merged.map((MeterWindow b) => b.width * b.height).toList()..sort();
  final double median = areas[areas.length ~/ 2].toDouble();
  final List<MeterWindow> consistent = merged.where((MeterWindow b) {
    final double a = (b.width * b.height).toDouble();
    return a >= median * 0.25 && a <= median * 4.0;
  }).toList();
  if (consistent.length != expected) return null;

  final List<MeterWindow> ordered = _rowMajor(consistent);
  final double inv = 1 / scale;
  final List<MeterWindow> out = <MeterWindow>[];
  for (final MeterWindow b in ordered) {
    // 返回紧贴白色表窗的坐标；裁切时再按需要向外扩，避免把表框金属边
    // 当成示数带的一部分。
    final int left = (b.left * inv).floor().clamp(0, source.width - 1);
    final int top = (b.top * inv).floor().clamp(0, source.height - 1);
    final int right =
        ((b.left + b.width) * inv).ceil().clamp(left + 1, source.width);
    final int bottom =
        ((b.top + b.height) * inv).ceil().clamp(top + 1, source.height);
    out.add(MeterWindow(left, top, right - left, bottom - top));
  }
  return out;
}

/// 把原图按定位结果裁成短边不超过 [shortEdge]、长边不超过 1024 的 JPEG。
List<Uint8List>? cropMeterWindows(Uint8List bytes,
    {required int expected, int shortEdge = 384, int maxLongEdge = 1536}) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final img.Image oriented = img.bakeOrientation(decoded);
  final List<MeterWindow>? windows =
      locateMeterWindows(oriented, expected: expected);
  if (windows == null) return null;
  final List<Uint8List> crops = <Uint8List>[];
  for (final MeterWindow box in windows) {
    final img.Image window = img.copyCrop(oriented,
        x: box.left, y: box.top, width: box.width, height: box.height);
    // 机械表红色轮通常表示 0.1 位。先按「红色明显高于绿/蓝」把红色
    // 数字轮和红色边框涂白，避免模型把红位拼进整数；全黑表盘不受影响。
    _whitenRed(window);
    // 示数位是表窗中部的一条横向数字带，上下还有厂名、型号等小字。
    // 只裁这条带能显著放大数字，减少铭牌数字干扰；定位失败则退回整窗。
    final List<int>? band = _digitBand(window);
    final img.Image target;
    if (band == null) {
      target = _padded(oriented, box, 0.15);
    } else {
      final int pad = math.max(2, ((band[1] - band[0]) * 0.8).round());
      final int top = math.max(0, band[0] - pad);
      final int bottom = math.min(window.height, band[1] + pad);
      target = img.copyCrop(window,
          x: 0, y: top, width: window.width, height: bottom - top);
    }
    final double s = math.min(shortEdge / math.min(target.width, target.height),
        maxLongEdge / math.max(target.width, target.height));
    final img.Image resized = img.copyResize(target,
        width: math.max(1, (target.width * s).round()),
        height: math.max(1, (target.height * s).round()),
        interpolation: img.Interpolation.average);
    crops.add(img.encodeJpg(resized, quality: 92));
  }
  return crops;
}

void _whitenRed(img.Image image) {
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel p = image.getPixel(x, y);
      if (p.r.toInt() - math.max(p.g.toInt(), p.b.toInt()) > 10) {
        image.setPixelRgb(x, y, 255, 255, 255);
      }
    }
  }
}

img.Image _padded(img.Image source, MeterWindow box, double ratio) {
  final int padX = (box.width * ratio).round();
  final int padY = (box.height * ratio).round();
  final int left = math.max(0, box.left - padX);
  final int top = math.max(0, box.top - padY);
  final int right = math.min(source.width, box.left + box.width + padX);
  final int bottom = math.min(source.height, box.top + box.height + padY);
  return img.copyCrop(source,
      x: left, y: top, width: right - left, height: bottom - top);
}

/// 在表窗内寻找横向示数带：取中部 12%–68% 宽度的行亮度，边缘 12% 行
/// 不参与统计（表框和阴影较暗），用局部最低亮度自适应定阈值，找高度
/// 4%–35%、中心位于上半部的连续暗带，返回 [起始行, 结束行)。
List<int>? _digitBand(img.Image window) {
  final int w = window.width;
  final int h = window.height;
  if (w < 40 || h < 30) return null;
  final int x0 = (w * 0.12).round();
  final int x1 = (w * 0.68).round();
  if (x1 - x0 < 10) return null;
  final List<double> means = List<double>.filled(h, 0);
  for (int y = 0; y < h; y++) {
    double sum = 0;
    for (int x = x0; x < x1; x++) {
      final img.Pixel p = window.getPixel(x, y);
      sum += 0.299 * p.r.toDouble() +
          0.587 * p.g.toDouble() +
          0.114 * p.b.toDouble();
    }
    means[y] = sum / (x1 - x0);
  }
  // 3 行滑动平均，压掉单行噪点。
  final List<double> smooth = List<double>.filled(h, 0);
  for (int y = 0; y < h; y++) {
    final int a = math.max(0, y - 1);
    final int b = math.min(h - 1, y + 1);
    double s = 0;
    for (int k = a; k <= b; k++) {
      s += means[k];
    }
    smooth[y] = s / (b - a + 1);
  }
  final int y0 = (h * 0.12).round();
  final int y1 = (h * 0.88).round();
  final List<double> interior = smooth.sublist(y0, math.max(y0 + 1, y1))
    ..sort();
  final double low = interior[(interior.length * 0.05).floor()];
  final double high = interior[(interior.length * 0.90).floor()];
  final double threshold = low + math.max(10.0, (high - low) * 0.30);

  final List<List<int>> runs = <List<int>>[];
  int? start;
  for (int y = y0; y < y1; y++) {
    final bool dark = smooth[y] < threshold;
    if (dark && start == null) start = y;
    if ((!dark || y == y1 - 1) && start != null) {
      runs.add(<int>[start, dark ? y + 1 : y]);
      start = null;
    }
  }
  List<int>? best;
  int bestHeight = 0;
  for (final List<int> run in runs) {
    final int height = run[1] - run[0];
    final double center = (run[0] + run[1]) / 2 / h;
    final double fraction = height / h;
    if (fraction >= 0.04 &&
        fraction <= 0.35 &&
        center < 0.66 &&
        height > bestHeight) {
      best = run;
      bestHeight = height;
    }
  }
  return best;
}

/// 水平、垂直两遍滑动窗口实现方形膨胀/腐蚀。
Uint8List _close(Uint8List src, int w, int h, int radius) {
  final Uint8List dil = _sliding(src, w, h, radius, erode: false);
  return _sliding(dil, w, h, radius, erode: true);
}

Uint8List _sliding(Uint8List src, int w, int h, int r, {required bool erode}) {
  final Uint8List horizontal = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    final int row = y * w;
    int sum = 0;
    for (int x = 0; x < w; x++) {
      if (x == 0) {
        for (int k = 0; k <= r && k < w; k++) {
          sum += src[row + k];
        }
      } else {
        final int add = x + r;
        final int remove = x - r - 1;
        if (add < w) sum += src[row + add];
        if (remove >= 0) sum -= src[row + remove];
      }
      final int need = math.min(w, x + r + 1) - math.max(0, x - r);
      if (erode ? sum == need : sum > 0) horizontal[row + x] = 1;
    }
  }
  final Uint8List out = Uint8List(w * h);
  for (int x = 0; x < w; x++) {
    int sum = 0;
    for (int y = 0; y < h; y++) {
      if (y == 0) {
        for (int k = 0; k <= r && k < h; k++) {
          sum += horizontal[k * w + x];
        }
      } else {
        final int add = y + r;
        final int remove = y - r - 1;
        if (add < h) sum += horizontal[add * w + x];
        if (remove >= 0) sum -= horizontal[remove * w + x];
      }
      final int need = math.min(h, y + r + 1) - math.max(0, y - r);
      if (erode ? sum == need : sum > 0) out[y * w + x] = 1;
    }
  }
  return out;
}

/// 8 邻域连通域的外接矩形。过滤掉过小的噪点，减少大图遍历耗时。
List<MeterWindow> _components(Uint8List mask, int w, int h) {
  final Uint8List visited = Uint8List(w * h);
  final Int32List stack = Int32List(w * h);
  final List<MeterWindow> boxes = <MeterWindow>[];
  for (int start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || visited[start] == 1) continue;
    int sp = 0;
    stack[sp++] = start;
    visited[start] = 1;
    int minX = w, minY = h, maxX = 0, maxY = 0, count = 0;
    while (sp > 0) {
      final int idx = stack[--sp];
      final int x = idx % w;
      final int y = idx ~/ w;
      count++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (int dy = -1; dy <= 1; dy++) {
        final int ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (int dx = -1; dx <= 1; dx++) {
          final int nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          final int ni = ny * w + nx;
          if (mask[ni] == 1 && visited[ni] == 0) {
            visited[ni] = 1;
            stack[sp++] = ni;
          }
        }
      }
    }
    if (count < w * h * 0.0015) continue;
    boxes.add(MeterWindow(minX, minY, maxX - minX + 1, maxY - minY + 1));
  }
  return boxes;
}

/// 合并重叠或间距很小的候选（示数窗上下两块白色区域可能被分割）。
List<MeterWindow> _mergeNearby(
    List<MeterWindow> boxes, int imageWidth, int imageHeight) {
  final List<MeterWindow> out = <MeterWindow>[];
  final int gap = (math.min(imageWidth, imageHeight) * 0.012).round();
  for (final MeterWindow b in boxes) {
    MeterWindow current = b;
    bool merged = true;
    while (merged) {
      merged = false;
      for (int i = 0; i < out.length; i++) {
        final MeterWindow o = out[i];
        final int dx = math.max(
            0,
            math.max(current.left - (o.left + o.width),
                o.left - (current.left + current.width)));
        final int dy = math.max(
            0,
            math.max(current.top - (o.top + o.height),
                o.top - (current.top + current.height)));
        if (dx <= gap && dy <= gap) {
          final int l = math.min(current.left, o.left);
          final int t = math.min(current.top, o.top);
          final int r =
              math.max(current.left + current.width, o.left + o.width);
          final int bo =
              math.max(current.top + current.height, o.top + o.height);
          current = MeterWindow(l, t, r - l, bo - t);
          out.removeAt(i);
          merged = true;
          break;
        }
      }
    }
    out.add(current);
  }
  return out;
}

/// 按行分组后行内按 x 排序；行判断用候选高度的中位数，避免倾斜照片
/// 把同一行的表拆成两行。
List<MeterWindow> _rowMajor(List<MeterWindow> boxes) {
  final List<MeterWindow> sorted = List<MeterWindow>.of(boxes)
    ..sort((MeterWindow a, MeterWindow b) {
      final double ay = a.top + a.height / 2;
      final double by = b.top + b.height / 2;
      final int c = ay.compareTo(by);
      return c != 0 ? c : a.left.compareTo(b.left);
    });
  final List<double> heights =
      sorted.map((MeterWindow b) => b.height.toDouble()).toList()..sort();
  final double tolerance = heights[heights.length ~/ 2] * 0.55;
  final List<List<MeterWindow>> rows = <List<MeterWindow>>[];
  for (final MeterWindow box in sorted) {
    final double cy = box.top + box.height / 2;
    if (rows.isEmpty) {
      rows.add(<MeterWindow>[box]);
      continue;
    }
    final MeterWindow anchor = rows.last.first;
    final double anchorY = anchor.top + anchor.height / 2;
    if ((cy - anchorY).abs() <= tolerance) {
      rows.last.add(box);
    } else {
      rows.add(<MeterWindow>[box]);
    }
  }
  for (final List<MeterWindow> row in rows) {
    row.sort((MeterWindow a, MeterWindow b) => a.left.compareTo(b.left));
  }
  return <MeterWindow>[for (final List<MeterWindow> row in rows) ...row];
}
