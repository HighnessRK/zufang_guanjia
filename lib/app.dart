import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_miuix/miuix.dart';

import 'core/constants/app_constants.dart';
import 'ui/shell/app_shell.dart';

/// 应用根 Widget：接入 miuix 主题（HyperOS 原生风格）。
class RentalApp extends StatelessWidget {
  const RentalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MiuixSystemTheme 自动跟随系统明暗模式，提供整套 HyperOS 语义配色
    return MiuixSystemTheme(
      child: Builder(
        builder: (BuildContext context) {
          final MiuixThemeData theme = MiuixTheme.of(context);
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            // 中文本地化（Material 日期选择器等原生控件文案）
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const <Locale>[
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            locale: const Locale('zh', 'CN'),
            // 关闭系统默认的 Material 涟漪与配色，统一走 miuix 质感
            theme: ThemeData(
              useMaterial3: true,
              brightness: theme.brightness,
              // 全局统一字体：小米 MiSans
              fontFamily: 'MiSans',
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.colors.primary,
                brightness: theme.brightness,
              ),
              scaffoldBackgroundColor: theme.colors.background,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            builder: (BuildContext context, Widget? child) {
              // 【关键修复】全局弹窗宿主（置于 Navigator 之上、Directionality 之内）。
              //
              // showGeneralDialog 推出的对话框路由不处于任何 MiuixScaffold 的
              // MiuixPopupScope 作用域内，MiuixOverlayDialog 的内容会注册到
              // 进程级 fallback 注册表；若没有宿主渲染它，对话框永远不显示，
              // 表现为"设置里的条目点不进去"。挂在这里既让对话框正常显示，
              // 又保证它盖在悬浮液态玻璃导航栏之上。
              return MiuixPopupHost(
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
