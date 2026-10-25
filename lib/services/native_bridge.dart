import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

/// 原生（Android / Kotlin）能力桥接。
///
/// 承担 Flutter 不适合直接做的三件事：
///   1. Android 系统通知（渠道、优先级、大文本、常驻）；
///   2. 小米澎湃OS / HyperOS 焦点通知（状态栏胶囊）；
///   3. 数据库备份 / 恢复（SAF 系统文件选择器 + 分享）。
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel =
      MethodChannel(AppConstants.nativeChannel);

  /// 查询原生层基本信息（厂商、系统版本、是否小米）
  static Future<Map<String, dynamic>> systemInfo() async {
    final Map<dynamic, dynamic> r =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('systemInfo') ??
            <dynamic, dynamic>{};
    return r.map((dynamic k, dynamic v) =>
        MapEntry<String, dynamic>(k.toString(), v));
  }

  /// 申请 Android 13+ 的通知运行时权限
  static Future<bool> requestNotifyPermission() async {
    final bool? ok =
        await _channel.invokeMethod<bool>('requestNotifyPermission');
    return ok ?? false;
  }

  /// 查询超级岛 / 焦点通知状态
  ///
  /// 返回字段：
  ///   isXiaomi            是否小米 / Redmi / POCO
  ///   protocol            焦点协议版本（0=不支持 1=OS1 2=OS2 3=OS3 超级岛）
  ///   supportIsland       系统是否支持超级岛
  ///   hasFocusPermission  本应用焦点通知权限是否开启
  static Future<Map<String, dynamic>> focusStatus() async {
    final Map<dynamic, dynamic> r =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('focusStatus') ??
            <dynamic, dynamic>{};
    return r.map((dynamic k, dynamic v) =>
        MapEntry<String, dynamic>(k.toString(), v));
  }

  /// 发送一条系统通知
  ///
  /// [focus] 为 true 时尝试走澎湃OS 焦点通知（不支持则自动降级为普通通知）。
  ///
  /// [live] 为 true 时走 Android 16 Live Updates：晋升常驻进度通知，
  /// 同一 [id] 重复发送即"原地更新"。[restart] 表示新生命周期（清除用户
  /// 的"已划掉"记录），常规刷新传 false 以尊重用户的划掉操作。
  /// [criticalText] 为状态栏小芯片文案（建议 ≤7 字符，如 "65%"）。
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? bigText,
    required String channelId,
    bool focus = false,
    bool ongoing = false,
    bool live = false,
    int progress = 0,
    int progressMax = 100,
    String? criticalText,
    bool restart = false,
  }) async {
    await _channel.invokeMethod<void>('showNotification', <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'bigText': bigText,
      'channelId': channelId,
      'focus': focus,
      'ongoing': ongoing,
      'live': live,
      'progress': progress,
      'progressMax': progressMax,
      'criticalText': criticalText,
      'restart': restart,
    });
  }

  /// 取消一条通知
  static Future<void> cancelNotification(int id) async {
    await _channel.invokeMethod<void>('cancelNotification', <String, Object?>{
      'id': id,
    });
  }

  /// 取消全部通知
  static Future<void> cancelAll() async {
    await _channel.invokeMethod<void>('cancelAll');
  }

  /// 备份数据库与配置文件，返回系统分享出去的文件名
  static Future<String> backup({
    required String dbPath,
    required String configPath,
  }) async {
    final String? r = await _channel.invokeMethod<String>('backup', <String,
        Object?>{
      'dbPath': dbPath,
      'configPath': configPath,
    });
    return r ?? '';
  }

  /// 打开系统文件选择器选择备份文件，返回可读取的临时路径
  static Future<String?> pickBackupFile() async {
    return _channel.invokeMethod<String>('pickBackupFile');
  }

  /// 用选中的备份文件覆盖数据库与配置文件
  static Future<bool> restore({
    required String sourcePath,
    required String dbPath,
    required String configPath,
  }) async {
    final bool? ok = await _channel.invokeMethod<bool>('restore', <String,
        Object?>{
      'sourcePath': sourcePath,
      'dbPath': dbPath,
      'configPath': configPath,
    });
    return ok ?? false;
  }

  /// 调起系统安装器安装本地 APK（文件须位于 FileProvider 可见目录，如缓存）
  static Future<void> installApk(String path) async {
    await _channel.invokeMethod<void>('installApk', <String, Object?>{
      'path': path,
    });
  }

  //========================= 备份 / 存储 =========================

  /// 只生成备份 zip 到应用备份目录（不弹系统分享），返回完整路径。
  /// MCP 的 create_backup 与数据管理页共用。
  static Future<String> backupToFile({
    required String dbPath,
    required String configPath,
  }) async {
    final String? r = await _channel.invokeMethod<String>('backupToFile',
        <String, Object?>{
      'dbPath': dbPath,
      'configPath': configPath,
    });
    return r ?? '';
  }

  /// 列出指定目录下的备份 zip（按修改时间倒序，最新在前）。
  /// [dirPath] 传空串 = 应用自身备份目录；传小米互传目录 = 读互传备份。
  ///
  /// 返回 `[{name, path, size, modified}]`，目录不存在 / 无权限返回空表。
  static Future<List<Map<String, dynamic>>> listBackups(String dirPath) async {
    final List<dynamic>? r =
        await _channel.invokeMethod<List<dynamic>>('listBackups',
            <String, Object?>{'dirPath': dirPath});
    return (r ?? <dynamic>[])
        .map((dynamic e) => (e as Map<dynamic, dynamic>).map(
            (dynamic k, dynamic v) =>
                MapEntry<String, dynamic>(k.toString(), v)))
        .toList();
  }

  /// 备份相关目录：应用备份目录 / 小米互传目录 / 下载目录
  ///
  /// 返回 `appBackupDir`、`miShareDir`、`miShareExists`、`downloadDir`
  static Future<Map<String, dynamic>> backupDirs() async {
    final Map<dynamic, dynamic> r =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('backupDirs') ??
            <dynamic, dynamic>{};
    return r.map(
        (dynamic k, dynamic v) => MapEntry<String, dynamic>(k.toString(), v));
  }

  /// 是否已具备共享存储（Download/MiShare）读取权限
  static Future<bool> hasStorageAccess() async {
    final bool? ok =
        await _channel.invokeMethod<bool>('hasStorageAccess');
    return ok ?? false;
  }

  /// 申请共享存储读取权限：Android 11+ 拉起「所有文件访问」设置页，
  /// Android 10 走 READ_EXTERNAL_STORAGE 运行时授权
  static Future<bool> requestStorageAccess() async {
    final bool? ok =
        await _channel.invokeMethod<bool>('requestStorageAccess');
    return ok ?? false;
  }
}
