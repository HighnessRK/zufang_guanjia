import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/services/recognition_tasks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('多任务后台队列互不覆盖，离开页面后保留结果，重启仍可核对', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-tasks-');
    addTearDown(() => dir.delete(recursive: true));
    final active = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.zufang.guanjia/native'), (call) async {
      active.add(call.arguments['active'] as bool);
      return null;
    });
    final gate = Completer<void>();
    final queue = RecognitionTasks(
        directory: dir,
        runner: (bytes, rooms) async {
          if (rooms.first == '101') await gate.future;
          return List.filled(rooms.length, bytes.first);
        });
    await queue.submit(Uint8List.fromList([123]), ['101'], {'101': '0'});
    await queue.submit(
        Uint8List.fromList([234]), ['102', '103'], {'102': '0', '103': '0'});
    expect(queue.tasks.length, 2);
    expect(queue.busy('101'), isTrue);
    await expectLater(
        queue.submit(Uint8List(1), ['101'], {}), throwsStateError);
    gate.complete();
    for (var i = 0; i < 100 && queue.tasks.isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(queue.results['101']!['value'], 123);
    expect(queue.results['102']!['value'], 234);
    final restarted = RecognitionTasks(directory: dir);
    await restarted.init();
    expect(restarted.results.length, 3);
    await restarted.acknowledge('101');
    expect(restarted.results.containsKey('102'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(active, [true, false]);
  });
  test('一个任务失败后后续任务仍继续处理', () async {
    final dir = await Directory.systemTemp.createTemp('ocr-error-');
    addTearDown(() => dir.delete(recursive: true));
    final gate = Completer<void>();
    final queue = RecognitionTasks(
        directory: dir,
        runner: (bytes, rooms) async {
          if (rooms.first == '1') {
            await gate.future;
            throw StateError('bad image');
          }
          return [456];
        });
    await queue.submit(Uint8List(1), ['1'], {});
    await queue.submit(Uint8List(1), ['2'], {});
    gate.complete();
    for (var i = 0; i < 100 && queue.tasks.isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(queue.results['2']!['value'], 456);
    expect(queue.lastError, contains('bad image'));
  });
}
