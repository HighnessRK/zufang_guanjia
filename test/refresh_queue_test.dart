import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zufang_guanjia/core/utils/refresh_queue.dart';

void main() {
  test('并发刷新合并为一次补刷，且不重叠执行', () async {
    final queue = RefreshQueue();
    final gate = Completer<void>();
    int calls = 0;
    Future<void> action() async {
      calls++;
      if (calls == 1) await gate.future;
    }
    final first = queue.run(action);
    final second = queue.run(action);
    final third = queue.run(action);
    expect(identical(first, second), isTrue);
    expect(identical(first, third), isTrue);
    expect(calls, 1);
    gate.complete();
    await first;
    expect(calls, 2);
    await queue.run(action);
    expect(calls, 3);
  });

  test('失败会传递给调用者，后续刷新仍可执行', () async {
    final queue = RefreshQueue();
    await expectLater(queue.run(() async => throw StateError('failed')),
        throwsStateError);
    int calls = 0;
    await queue.run(() async { calls++; });
    expect(calls, 1);
  });
}
