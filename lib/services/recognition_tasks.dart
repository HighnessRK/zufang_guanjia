import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'llm_service.dart';

class RecognitionTask {
  RecognitionTask(this.id, this.rooms, this.baseline, this.bytes);
  final String id;
  final List<String> rooms;
  final Map<String, String> baseline;
  final Uint8List bytes;
  String state = '等待识别', error = '';
}

/// App-scoped queue: pages may disappear; persisted results remain until applied.
class RecognitionTasks extends ChangeNotifier {
  RecognitionTasks({this.directory, this.runner});
  final Directory? directory;
  final Future<List<int>> Function(Uint8List, List<String>)? runner;
  static final instance = RecognitionTasks();
  final List<RecognitionTask> tasks = [];
  final Map<String, Map<String, dynamic>> results = {};
  Future<void>? _initializing;
  Future<void> _writes = Future.value();
  late File _file;
  int _serial = 0;
  bool _running = false;
  Future<void> init() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      await _init();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _init() async {
    final root = directory ?? await getApplicationSupportDirectory();
    await root.create(recursive: true);
    _file = File('${root.path}/ocr-results.json');
    if (await _file.exists()) {
      final data =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      for (final e in data.entries) {
        results[e.key] = Map<String, dynamic>.from(e.value as Map);
      }
    }
  }

  Future<void> _save() {
    final data = jsonEncode(results);
    final write = _writes.catchError((Object _) {}).then((_) async {
      final temp = File('${_file.path}.tmp');
      await temp.writeAsString(data, flush: true);
      await temp.rename(_file.path);
    });
    _writes = write;
    return write;
  }

  bool busy(String room) => tasks.any((t) => t.rooms.contains(room));
  Future<void> submit(
      Uint8List bytes, List<String> rooms, Map<String, String> baseline) async {
    await init();
    if (rooms.any(busy)) throw StateError('所选房间已有识别任务，请完成后重试');
    tasks.add(RecognitionTask(
        '${DateTime.now().microsecondsSinceEpoch}-${_serial++}',
        List.of(rooms),
        Map.of(baseline),
        Uint8List.fromList(bytes)));
    // Start foreground protection while the activity is still foreground.
    if (!_running) {
      _running = true;
      try {
        await const MethodChannel('com.zufang.guanjia/native')
            .invokeMethod<void>('recognitionActive', {'active': true});
      } on MissingPluginException {/* desktop tests */} catch (_) {
        tasks.clear();
        _running = false;
        rethrow;
      }
      _drain();
    }
    notifyListeners();
  }

  Future<void> _drain() async {
    try {
      while (tasks.isNotEmpty) {
        final t = tasks.first;
        t.state = '识别中';
        notifyListeners();
        try {
          final values = runner != null
              ? await runner!(t.bytes, t.rooms)
              : t.rooms.length == 1
                  ? [await LlmService.recognizeElecMeter(t.bytes)]
                  : await LlmService.recognizeFloorMeterReadings(t.bytes,
                      roomNos: t.rooms);
          for (var i = 0; i < t.rooms.length; i++) {
            if (values[i] >= 0) {
              results[t.rooms[i]] = {
                'value': values[i],
                'baseline': t.baseline[t.rooms[i]]
              };
            }
          }
          await _save();
        } catch (e) {
          t.error = '$e';
          lastError = '识别失败（${t.rooms.join('、')}）：$e';
        }
        tasks.remove(t);
        notifyListeners();
      }
    } finally {
      try {
        await const MethodChannel('com.zufang.guanjia/native')
            .invokeMethod<void>('recognitionActive', {'active': false});
      } catch (_) {/* no platform channel on desktop */}
      _running = false;
      if (tasks.isNotEmpty) {
        _running = true;
        try {
          await const MethodChannel('com.zufang.guanjia/native')
              .invokeMethod<void>('recognitionActive', {'active': true});
        } catch (_) {/* current service may already be active */}
        _drain();
      }
    }
  }

  String lastError = '';
  Future<void> acknowledge(String room) async {
    results.remove(room);
    await _save();
  }
}
