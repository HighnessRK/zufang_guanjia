import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_miuix/miuix.dart';
import 'package:liquid_glass_bottom_nav/liquid_glass_bottom_nav.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/notification_service.dart';
import '../../services/update_service.dart';
import '../home/home_page.dart';
import '../meter/meter_page.dart';
import '../rooms/collect_panel_page.dart';
import '../rooms/rooms_page.dart';
import '../settings/settings_page.dart';
import '../transitions.dart';
import '../widgets/update_dialog.dart';

/// 全局外壳：承载 5 个核心页面 + AndroidLiquidGlass 液态玻璃磨砂底部导航。
///
/// 【关键设计】
/// 1. 底部导航是「悬浮磨砂玻璃」材质，常驻在最上层，四个 Tab 与所有
///    二级页面（房间详情、编辑、通知中心…）都能透过它看到，实现全局适配；
/// 2. 每个 Tab 拥有独立的 Navigator，切换 Tab 不丢上下文，
///    二级页面压栈后底栏依然浮在最上层；
/// 3. 页面内容底部统一预留边距，保证最后一项不被玻璃导航栏遮挡。
/// 4. 【金标联盟】
///    * Tab 切换为「一镜到底」交叉淡化 + 微缩放（旧页淡出、新页放大浮现）；
///    * 二级页压栈统一走 [AppPageRoute]（缩放淡入 + 手势跟手返回）；
///    * Android 返回键 / 预测式返回手势优先弹出当前 Tab 的二级页
///      （didPopRoute 回链，见下）；
///    * 系统内存压力回调立即释放图片缓存（公平运行内存适配）。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  /// 当前选中的 Tab（用 ValueNotifier 承载，便于后代页面感知切换）
  final ValueNotifier<int> _index = ValueNotifier<int>(0);

  /// 是否有可编辑文本（输入框）持有焦点——用于键盘守卫：
  /// 聚焦时让框架上报 frameworkHandlesBack=true（见 build 处 PopScope），
  /// 否则预测式返回下系统会在根页"完全自行处理"返回、根本不通知 Flutter。
  bool _editableFocused = false;

  /// 当前主焦点是否在可编辑文本（TextField/EditableText）上。
  /// 查焦点链而非 viewInsets：系统常在把 back 递给应用前已隐藏 IME，
  /// viewInsets 瞬时归零不可靠，而输入框焦点不会随 IME 隐藏而消失。
  bool _isEditableFocused() {
    final FocusNode? node = FocusManager.instance.primaryFocus;
    return node != null &&
        node.hasFocus &&
        node.context != null &&
        node.context!.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _onFocusChanged() {
    final bool editable = _isEditableFocused();
    if (editable != _editableFocused && mounted) {
      setState(() => _editableFocused = editable);
    }
  }

  @override
  void initState() {
    super.initState();
    // 公平运行内存适配（金标联盟）：注册系统内存压力回调
    WidgetsBinding.instance.addObserver(this);
    // 键盘守卫：跟踪输入框焦点（用于 PopScope 拦截返回、只收键盘）
    FocusManager.instance.addListener(_onFocusChanged);
    // 应用内更新：首帧后静默检查，每次启动发现新版本均提醒。
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
  }

  /// 启动静默检查更新：发现新版本且开启提醒时**每次启动都弹**。
  ///
  /// v1.1.4 起改为「每版必弹」——不再按 `updatePromptedVersion` 去重。
  /// 老逻辑「同一版本只弹一次」让用户关掉一次就永远看不到，反而漏掉了
  /// 重要修复；这里保留配置项但不再做拦截，用户仍可用「更新提醒」开关
  /// 整体关闭，或用「稍后再说」关闭本次。
  bool _checkingUpdate = false;
  bool _wasBackground = false;

  Future<void> _autoCheckUpdate() async {
    final AppConfig cfg = AppConfig.instance;
    if (!cfg.autoCheckUpdate || _checkingUpdate) return;
    _checkingUpdate = true;
    try {
      final UpdateInfo? info = await UpdateService.checkLatest();
      if (info == null || !mounted) return;
      if (UpdateService.compareVersion(
              info.version, AppConstants.appVersion) <=
          0) {
        return;
      }
      if (!cfg.updateNotify) return;
      // 记录已提醒版本（用于「更新设置」页展示最近提醒到的版本），
      // 但不再用它拦截弹窗。
      if (cfg.updatePromptedVersion != info.version) {
        await cfg.update(updatePromptedVersion: info.version);
      }
      if (!mounted) return;
      await showUpdateDialog(context, info);
    } catch (_) {
      // 更新检查失败静默忽略，不打扰主流程
    } finally {
      _checkingUpdate = false;
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _index.dispose();
    super.dispose();
  }

  /// 系统内存吃紧（Android onTrimMemory / 内存压力）→ 立即丢弃图片缓存，
  /// 不在后台持有大位图，主动让出内存。
  @override
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// 五个 Tab 各自的 Navigator key
  final List<GlobalKey<NavigatorState>> _navKeys =
      List<GlobalKey<NavigatorState>>.generate(
          5, (int i) => GlobalKey<NavigatorState>());

  /// Tab 对应的根页面
  late final List<Widget> _roots = <Widget>[
    const HomePage(),
    const RoomsPage(),
    const MeterPage(),
    const CollectPanelPage(),
    const SettingsPage(),
  ];

  /// 液态玻璃导航栏条目
  late final List<LiquidGlassNavItem> _items = const <LiquidGlassNavItem>[
    LiquidGlassNavItem(id: 'home', icon: Icons.home_rounded, label: '首页'),
    LiquidGlassNavItem(
        id: 'rooms', icon: Icons.meeting_room_rounded, label: '房间'),
    LiquidGlassNavItem(id: 'meter', icon: Icons.speed_rounded, label: '抄表'),
    LiquidGlassNavItem(
        id: 'collect',
        icon: Icons.account_balance_wallet_rounded,
        label: '收款'),
    LiquidGlassNavItem(
        id: 'settings', icon: Icons.settings_rounded, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final int current = _index.value;
    // 【返回链路总纲】预测式返回（enableOnBackInvokedCallback=true）下，框架
    // 会按 Navigator 栈 / PopScope 状态提前告知系统 frameworkHandlesBack：
    // 报 false 时系统"完全自行处理"返回并直接 finish 掉 Activity，Flutter
    // 根本收不到通知。下面的 PopScope 恒定 canPop=false，让根路由
    // popDisposition 恒为 doNotPop → 框架恒报 true → 返回永远送达 Flutter，
    // 收键盘 / 弹二级页 / 退出由 onPopInvokedWithResult 统一裁决。
    //
    // 【键盘展开隐藏底栏】输入法弹起时 viewInsets.bottom > 0。玻璃导航是
    // 悬浮常驻层，不随 Scaffold resize 上移，会压住输入框底部；编辑房间 /
    // 录水表这类表单页尤甚。这里**条件不 include** 它（不是包裹隐藏）——
    // 组件必须直接作 Stack 子节点，包一层会 release 崩溃（见下方注释）。
    final bool imeOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // 【返回链路 / canPop 恒 false】根路由（AppShell）永不需要被 pop，让它的
    // popDisposition 恒为 doNotPop 有两个关键作用：
    //
    // ① 框架据此恒定上报 frameworkHandlesBack=true（ModalRoute 会在
    //    PopEntry 状态变化时派发 NavigationNotification，根导航器还会把子
    //    导航器的 false 改写成 true）→ 系统绝不会"自行处理"返回，返回永远
    //    送达 Flutter。此前 canPop 随焦点变化，失焦瞬间被上报成 false →
    //    系统直接 finish 掉 Activity：二级页上收完键盘再按返回就退出应用
    //    （真机复现过，v1.1.0 修复）。
    // ② WidgetsApp.didPopRoute → Navigator.maybePop 命中 doNotPop → 只回调
    //    本 onPopInvokedWithResult 并返回「已处理」，所以收键盘 / 弹二级页 /
    //    退出全部在这里完成。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !_handleBack()) {
          // 已在 Tab 根页且没有输入焦点 → 显式退出（等价于框架的兜底行为）
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: AppShellScope(
        switchTab: _switchTab,
        switchTabAndPush: _switchTabAndPush,
        selectedIndex: _index,
        // 【返回链路】本 Flutter 版本的 MaterialApp(home:) 不构建 Router，
        // BackButtonListener（依赖 Router.of）不可用；改走引擎的正统回链：
        // 返回键 / 预测式返回手势未被页面转场认领时 → handlePopRoute →
        // didPopRoute（下方实现）→ 先弹当前 Tab 的二级页，根页面再交给系统退出。
        child: Container(
            // 底衬与页面 surface 同色（随明暗模式）：Tab 交叉淡入淡出期间
            // 两个 Tab 都半透明，若底衬是深色渐变会透出「先变黑再跳页」的
            // 观感；用 surface 纯色衬底则全程与页面同色，无黑闪。
            color: c.surface,
            child: Stack(
              children: <Widget>[
                //=========== 页面内容区（Tab 切换 = 一镜到底交叉变换） ===========
                for (int i = 0; i < _roots.length; i++)
                  Positioned.fill(
                    child: _TabView(
                      selected: i == current,
                      child: _TabNavigator(
                        navigatorKey: _navKeys[i],
                        root: _roots[i],
                      ),
                    ),
                  ),

                //=========== 悬浮液态玻璃底部导航（大狗记紧凑风格） ===========
                // 导航组件的 build 自返回 Positioned（自带阴影/定位/安全区），
                // 必须直接作为 Stack 子节点；外层再包 Positioned/Container 会
                // 让它内部的 Positioned 父数据链跨过代理 RO 边界，release 下
                // 触发 BoxParentData→StackParentData 强转崩溃（profile 实证）。
                // 键盘展开时**直接不构建**，避免悬浮胶囊压在输入法上。
                if (!imeOpen)
                  LiquidGlassNavBar(
                    items: _items,
                    selectedIndex: current,
                    onTap: _handleTabTap,
                    iconSize: 22,
                    // 紧凑悬浮胶囊：高度 60、居中限宽 320、两侧留白，
                    // 不再横贯整屏（对齐大狗记 Pronto 的短 pill 观感）
                    height: 60,
                    maxWidth: 320,
                    insets: 16,
                    borderRadius: 30,
                    labelStyle: const TextStyle(fontSize: 10.5),
                    activeColor: c.primary,
                    inactiveColor: c.onSurfaceVariantSummary,
                  ),
              ],
            ),
          ),
      ),
      ),
    );
  }

  /// 【返回回链】引擎 back（返回键 / 手势条点击 / 预测式返回未被页面转场
  /// 认领的提交）→ WidgetsBinding.handlePopRoute → 逐观察者询问。
  ///
  /// 正常链路下返回先落在 build 处的 PopScope.onPopInvokedWithResult（根路由
  /// doNotPop → WidgetsApp.didPopRoute 命中 maybePop 后即消费），这里保留
  /// 同一套逻辑作为纵深防御：某些平台链路仍会直接问到 observer。
  @override
  Future<bool> didPopRoute() async => _handleBack();

  /// 返回处理：收键盘 → 弹当前 Tab 的二级页 → 都没得处理则交回系统退出。
  ///
  /// 返回 true 表示本次返回已被消费（收键盘也算消费，不会连带退出）。
  bool _handleBack() {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    final bool editable = _isEditableFocused();
    final bool ime = MediaQuery.viewInsetsOf(context).bottom > 0;
    final NavigatorState? nav = _navKeys[_index.value].currentState;
    if (editable || ime) {
      focus?.unfocus();
      return true;
    }
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    return false;
  }

  /// 回到前台时重算提醒（替代已移除的后台常驻前台服务的 30 分钟自检）：
  /// 开屏 / 从后台切回即刷新房租、到期、水电提醒与收款进度通知。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _wasBackground = true;
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.refresh();
      if (_wasBackground) {
        _wasBackground = false;
        _autoCheckUpdate();
      }
    }
  }

  /// 底部导航点击：点当前已选中的 Tab 时弹回该 Tab 的根页面，
  /// 否则切换 Tab。修复「从首页跳到二级页面后点首页不显示首页」。
  void _handleTabTap(int i) {
    if (i == _index.value) {
      final NavigatorState? nav = _navKeys[i].currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((Route<dynamic> route) => route.isFirst);
      }
      return;
    }
    _switchTab(i);
  }

  /// 供后代页面（快捷入口等）切换底部 Tab
  void _switchTab(int i) {
    if (i == _index.value) return;
    // 先释放输入焦点：隐藏 Tab 里残留焦点的输入框会在后续路由弹栈时
    // 让 IME 突然弹回（真机已复现），切 Tab 统一收掉。
    FocusManager.instance.primaryFocus?.unfocus();
    _index.value = i;
    setState(() {});
  }

  /// 引导类直达跳转：切换到 Tab [i]，把该 Tab 的导航栈重置回根页后
  /// 将 [page] 压到栈顶。避免「去配置」之类的引导落在遗留的旧二级页上
  ///（各 Tab 独立保活导航栈，直接 switchTab 会看到上次停留的页面）。
  void _switchTabAndPush(int i, Widget page) {
    _switchTab(i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final NavigatorState? nav = _navKeys[i].currentState;
      if (nav == null) return;
      nav.popUntil((Route<dynamic> r) => r.isFirst);
      nav.push(AppPageRoute<void>(builder: (_) => page));
    });
  }
}

/// 单个 Tab 的显隐变换：选中页放大浮现、未选中页缩小淡出（一镜到底），
/// 隐去的 Tab 不响应点击、退出语义树，但保活页面状态。
class _TabView extends StatelessWidget {
  const _TabView({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hidden: !selected,
      child: IgnorePointer(
        ignoring: !selected,
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: selected ? 1 : 0.97,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            // 【v1.1.2 优化】给每个 Tab 一层光栅边界：交叉淡入淡出的 240ms 里，
            // 页面的极光背景 + 十几张玻璃卡模糊层本该逐帧重画两遍；有了边界，
            // 引擎可把整页缓成一张纹理，切换时只做合成（缩放 / 透明度），
            // 掉帧与发热都明显下降，视觉完全一致。
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}

/// 提供给后代页面切换底部 Tab 与感知当前 Tab 的能力。
///
/// 首页快捷入口通过它跳到对应 Tab，而不是把 Tab 根页面再 push 一份，
/// 避免二级页面压栈后点「首页」回不去的问题。
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.switchTab,
    required this.switchTabAndPush,
    required this.selectedIndex,
    required super.child,
  });

  /// 请求切换到底部 Tab（0 首页 / 1 房间 / 2 抄表 / 3 收款 / 4 设置）
  final ValueChanged<int> switchTab;

  /// 切换到 Tab 并把 [page] 直接压到该 Tab 导航栈顶（先重置到根页）。
  /// 用于引导类跳转（如「未配置大模型 → 去配置」直达配置页）。
  final void Function(int index, Widget page) switchTabAndPush;

  /// 当前的 Tab，页面可监听它感知自己重新可见
  final ValueListenable<int> selectedIndex;

  static AppShellScope of(BuildContext context) {
    final AppShellScope? scope = context
        .getElementForInheritedWidgetOfExactType<AppShellScope>()
        ?.widget as AppShellScope?;
    assert(scope != null, '未在 Widget 树中找到 AppShellScope');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      switchTab != oldWidget.switchTab ||
      switchTabAndPush != oldWidget.switchTabAndPush ||
      selectedIndex != oldWidget.selectedIndex;
}

/// 单个 Tab 的独立导航容器（根路由也走一镜到底，形成 App 启动推入感）
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navigatorKey,
    required this.root,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return AppPageRoute<void>(
          settings: settings,
          builder: (BuildContext _) => root,
        );
      },
    );
  }
}
