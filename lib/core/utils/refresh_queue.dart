import 'dart:async';

/// 同时触发的刷新串行合并；运行中再来请求，结束前补一次最新数据。
class RefreshQueue {
  Future<void>? _running;
  bool _pending = false;

  Future<void> run(Future<void> Function() action) {
    _pending = true;
    if (_running != null) return _running!;
    final completer = Completer<void>();
    _running = completer.future;
    () async {
      try {
        do {
          _pending = false;
          await action();
        } while (_pending);
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _running = null;
      }
    }();
    return completer.future;
  }
}
