import '../core/config/app_config.dart';
import '../data/db/database_helper.dart';
import 'native_bridge.dart';

/// 数据备份 / 恢复服务。
///
/// 备份内容 = SQLite 数据库（rental.db） + 本地配置文件（info.gwt）
/// 备份方式 = 调用系统分享，把两份文件打包发到微信 / 网盘 / 本地文件
/// 恢复方式 = 调用系统文件选择器（SAF）选取备份文件后覆盖写回
/// 全程离线，不经过任何云端。
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  /// 备份：把数据库 + info.gwt 交给系统分享
  Future<String> backup() async {
    final String dbPath = await DatabaseHelper.instance.backupPath();
    final String? configPath = AppConfig.instance.configPath;
    if (configPath == null) {
      throw Exception('配置文件尚未初始化，请先启动一次 APP');
    }
    return NativeBridge.backup(dbPath: dbPath, configPath: configPath);
  }

  /// 恢复：选择备份文件并覆盖数据库 + 配置
  Future<bool> restore() async {
    final String? source = await NativeBridge.pickBackupFile();
    if (source == null || source.isEmpty) return false;

    // 关闭数据库，避免覆盖时被占用
    await DatabaseHelper.instance.close();

    final String dbPath = await DatabaseHelper.instance.backupPath();
    final String? configPath = AppConfig.instance.configPath;
    final bool ok = await NativeBridge.restore(
      sourcePath: source,
      dbPath: dbPath,
      configPath: configPath ?? '',
    );

    // 重新加载配置与数据库
    if (ok) {
      await AppConfig.instance.load();
    }
    return ok;
  }
}
