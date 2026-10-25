import 'package:flutter/widgets.dart';

/// 全局数据变更总线。
///
/// 【为什么需要】MCP Server 允许 AI 助手在 APP 之外改动数据库 / 配置，
/// 而各 Tab 页面都是「打开时拉取一次」的保活导航栈，不会自动感知外部
/// 改动。所有写操作完成后广播一次 [notify]，已挂载的页面立刻重新拉取，
/// AI 改的数据在界面上立即可见，不会出现「AI 说改好了、界面还是旧的」。
///
/// 【不依赖 ChangeNotifier】ChangeNotifier.notifyListeners 是 @protected，
/// 只能在子类实例成员里调；本类是独立单例，故自行维护监听表。
class DataBus {
  DataBus._();

  static final DataBus instance = DataBus._();

  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// 页面在 initState 注册、dispose 注销
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// 广播一次数据变更。
  ///
  /// 正在输入时不广播：用户正在编辑房间 / 抄表时被外部改动冲掉输入内容
  /// 比刷新慢一拍更糟（此时界面上的数据本就以用户输入为准）。
  void notify() {
    if (_editingText) return;
    // 拷贝一份：监听器可能在回调里增删自己（如 dispose）
    for (final VoidCallback cb in List<VoidCallback>.of(_listeners)) {
      cb();
    }
  }

  /// 当前主焦点是否在可编辑文本上
  static bool get _editingText {
    final FocusNode? node = FocusManager.instance.primaryFocus;
    return node != null &&
        node.hasFocus &&
        node.context != null &&
        node.context!.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
