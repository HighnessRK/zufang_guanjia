import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/db/database_helper.dart';
import 'data/models/room.dart';
import 'data/repository/payment_repository.dart';
import 'data/repository/room_repository.dart';
import 'services/backup_service.dart';
import 'services/mcp_server.dart';
import 'services/mcp_tools.dart';
import 'services/notification_service.dart';
import 'ui/widgets/app_widgets.dart';

/// 程序入口。
///
/// 启动顺序：
///   1. 释放并读取本地配置文件 info.gwt；
///   2. 打开 SQLite 数据库并建表；
///   3. 执行月度账期引擎（自动结转上期、创建本期流水、重置抄表）；
///   4. 初始化三端通知（内置通知中心 / 系统通知 / 焦点通知）；
///   5. 注入备份动作并按配置启停 MCP Server（AI 助手全流程接入）；
///   6. 进入 HyperOS 风格主界面。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 沉浸式状态栏，配合 HyperOS 顶栏做到全屏沉浸
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 1) 读取 info.gwt
  await AppConfig.instance.init();

  // 2) 打开数据库
  await DatabaseHelper.instance.database;

  // 3) 月度账期引擎：跨月自动结转上期 + 创建本期流水 + 重置抄表
  final List<Room> rooms = await RoomRepository.instance.all();
  await PaymentRepository.instance.ensureCurrentPeriod(rooms);

  // 4) 三端通知初始化（含后台常驻前台服务）
  await NotificationService.instance.init();

  // 5) MCP：注入备份能力（避免 mcp_tools → backup_service → mcp_tools 循环
  //    依赖），再按 info.gwt 的 mcp_enabled 启停 HTTP 服务。失败只记日志，
  //    绝不阻塞 APP 启动。
  BackupActions.createBackupFile =
      BackupService.instance.createBackupFile;
  try {
    await McpServer.instance.syncWithConfig();
  } catch (e) {
    debugPrint('MCP Server 启动异常：$e');
  }

  // 6) 预热顶栏「界内渐隐模糊」着色器（Impeller 运行时滤镜；
  //    Skia 等环境静默降级为分带近似，不阻塞启动）
  preloadTopBarVeilShader();

  runApp(const RentalApp());
}
