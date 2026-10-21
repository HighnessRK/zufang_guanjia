import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;

/// 页面转场路由（全流程统一使用）：HyperOS / Material 式「横向滑入」。
///
/// * **入场**：新页面自右侧整屏滑入（100%→0），旧页保持原位完全静止、
///   不淡出不缩小——实心推入，无「两页互隐互现」的发虚中段；
/// * **速率**：入场 240ms（easeOutCubic，起手即动）、弹出 200ms（easeIn，
///   收尾干脆），整体干脆利落；
/// * **跟手**：[_AppBackGestureDetector] 接收系统预测式返回手势
///   （Android U+ / API 36），把手掌进度直接写入路由动画控制器，
///   新页随手指 1:1 横向滑出，松手提交即弹出、回滑即取消；
/// * **按钮返回**：实体键 / 手势条点击走常规 back 链路（AppShell 的
///   BackButtonListener 弹出当前 Tab 栈），同样播放本动画；
/// * 全局所有页面均使用本路由，覆盖页面进出全流程。
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          // 快速滑入：入场 240ms / 弹出 200ms，起手即动，收尾干脆
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              builder(context),
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // 预测式返回手势驱动期间（含松手收尾）转场值与手指 1:1 线性
            // 映射 → 完全跟手；按钮 / 定时播放才用缓动：入场减速、弹出
            // 加速（easeIn 起手即动，不拖尾）
            final ModalRoute<Object?>? maybeRoute = ModalRoute.of(context);
            final bool gestureDriving =
                maybeRoute is AppPageRoute && maybeRoute.gestureDriving;
            final Curve curve = gestureDriving
                ? Curves.linear
                : (animation.status == AnimationStatus.reverse
                    ? Curves.easeInCubic
                    : Curves.easeOutCubic);
            final Animation<double> t = animation.drive(CurveTween(curve: curve));

            // 纯横向滑入：新页整屏自右向左推入，旧页静止在其下方，
            // 两页始终不透明——干净、实心、无闪烁
            return AnimatedBuilder(
              animation: t,
              builder: (BuildContext context, Widget? _) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(t),
                  child: child,
                );
              },
            );
          },
        );

  /// 预测式返回手势驱动中（含松手后的收尾动画）：转场值与手指 1:1 线性
  /// 映射（跟手）。收尾动画到达端点（completed / dismissed）后由状态监听
  /// 自动复位，此后该路由的按钮 / 定时转场恢复曲线缓动。
  bool gestureDriving = false;

  /// 由 [_AppBackGestureDetector] 在成功认领返回手势时调用。
  void beginGestureDrive() {
    gestureDriving = true;
    final Animation<double>? anim = animation;
    if (anim == null) {
      return;
    }
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        gestureDriving = false;
        anim.removeStatusListener(listener);
      }
    }

    anim.addStatusListener(listener);
  }

  /// 在转场层外套一层「预测式返回手势」探测器：
  /// 手势进度直接驱动本路由动画控制器（跟手），按钮返回交给常规链路。
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _AppBackGestureDetector(
      route: this,
      child: super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    );
  }
}

/// 预测式返回手势探测器（对照 Flutter 框架 PredictiveBackPageTransitionsBuilder
/// 的同名实现裁剪而成）：
///
/// * 边缘侧滑手势（非按钮事件）且本路由是当前顶层可弹路由时「认领」手势，
///   把 `1 - progress` 写入路由动画控制器 → 转场实时跟手；
/// * 松手提交 → 路由所在 Navigator 弹出本页；回滑取消 → 动画复位；
/// * 实体返回键 / 手势条点击（isButtonEvent）不认领，走常规 back 分发
///   （AppShell.BackButtonListener → 弹栈），保证两条链路互不抢占。
class _AppBackGestureDetector extends StatefulWidget {
  const _AppBackGestureDetector({
    required this.route,
    required this.child,
  });

  final AppPageRoute<dynamic> route;
  final Widget child;

  @override
  State<_AppBackGestureDetector> createState() =>
      _AppBackGestureDetectorState();
}

class _AppBackGestureDetectorState extends State<_AppBackGestureDetector>
    with WidgetsBindingObserver {
  /// 本路由当前是否可以认领返回手势：是顶层路由、无内部拦截、动画已稳定
  bool get _enabled =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.route.gestureDriving = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    // 按钮式返回交给常规 back 链路；非顶层 / 不可弹时同样放行
    if (backEvent.isButtonEvent || !_enabled) return false;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    // 认领成功 → 后续转场值改走 1:1 线性映射（跟手）
    widget.route.beginGestureDrive();
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    // 只有已认领的观察者会收到 update（由 binding 过滤）
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
