import '../core/config/app_config.dart';
import '../data/db/database_helper.dart';
import 'native_bridge.dart';
import 'data_bus.dart';

/// 一份可选的备份文件（用于「默认恢复最新备份」）
class BackupCandidate {
  const BackupCandidate({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.source,
  });

  /// 文件名（如 zufang_guanjia_backup_20261022_190000.zip）
  final String name;

  /// 完整路径
  final String path;

  /// 字节数
  final int size;

  /// 修改时间（毫秒时间戳）
  final int modified;

  /// 来源目录（展示用）
  final String source;

  /// 修改时间格式化 yyyy-MM-dd HH:mm（本地时区）
  String get modifiedText {
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(modified);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  /// 大小展示：B / KB / MB
  String get sizeText {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 数据备份 / 恢复服务。
///
/// 备份内容 = SQLite 数据库（rental.db）+ 本地配置文件（info.gwt）
/// 备份方式 = 打包为 zip 后调系统分享（用户自选去向）
/// 恢复方式 = 按优先级找备份：
///   1. 小米互传目录（内部存储/Download/MiShare）里最新的 zip
///   2. 应用自身备份目录里最新的 zip
///   3. 兜底：系统文件选择器（SAF）手工选
/// 全程离线，不经过任何云端。
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  /// 备份：把数据库 + info.gwt 交给系统分享
  Future<String> backup() async {
    final db = await DatabaseHelper.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final String dbPath = await DatabaseHelper.instance.backupPath();
    final String? configPath = AppConfig.instance.configPath;
    if (configPath == null) {
      throw Exception('配置文件尚未初始化，请先启动一次 APP');
    }
    return NativeBridge.backup(dbPath: dbPath, configPath: configPath);
  }

  /// 生成备份 zip 到应用备份目录（不弹分享），返回完整路径。
  /// MCP `create_backup` 工具注入此实现。
  Future<String?> createBackupFile() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final String dbPath = await DatabaseHelper.instance.backupPath();
      final String? configPath = AppConfig.instance.configPath;
      if (configPath == null) return null;
      final String path = await NativeBridge.backupToFile(
        dbPath: dbPath,
        configPath: configPath,
      );
      return path.isEmpty ? null : path;
    } catch (_) {
      return null;
    }
  }

  /// 应用自身备份目录下的 zip（最新在前）
  Future<List<BackupCandidate>> listAppBackups() async {
    final Map<String, dynamic> dirs = await NativeBridge.backupDirs();
    final String dir = '${dirs['appBackupDir'] ?? ''}';
    if (dir.isEmpty) return <BackupCandidate>[];
    return _toCandidates(await NativeBridge.listBackups(dir), dir);
  }

  /// 小米互传目录（内部存储/Download/MiShare）下的 zip（最新在前）。
  /// 无权限 / 目录不存在 → 空表（调用方按需引导授权）。
  Future<List<BackupCandidate>> listMiShareBackups() async {
    final Map<String, dynamic> dirs = await NativeBridge.backupDirs();
    final String dir = '${dirs['miShareDir'] ?? ''}';
    if (dir.isEmpty) return <BackupCandidate>[];
    return _toCandidates(await NativeBridge.listBackups(dir), dir);
  }

  /// 恢复：选择备份文件并覆盖数据库 + 配置
  Future<bool> restore() async {
    final String? source = await NativeBridge.pickBackupFile();
    if (source == null || source.isEmpty) return false;
    return restoreFrom(source);
  }

  /// 从指定路径恢复备份（覆盖数据库 + 配置），成功返回 true
  Future<bool> restoreFrom(String sourcePath) async {
    // 关闭数据库，避免覆盖时被占用
    await DatabaseHelper.instance.close();

    final String dbPath = await DatabaseHelper.instance.backupPath();
    final String? configPath = AppConfig.instance.configPath;
    final bool ok = await NativeBridge.restore(
      sourcePath: sourcePath,
      dbPath: dbPath,
      configPath: configPath ?? '',
    );

    // 重新加载配置与数据库
    if (ok) {
      await AppConfig.instance.load();
      DataBus.instance.notify();
    }
    return ok;
  }

  static List<BackupCandidate> _toCandidates(
    List<Map<String, dynamic>> rows,
    String source,
  ) =>
      rows
          .map((Map<String, dynamic> r) => BackupCandidate(
                name: '${r['name'] ?? ''}',
                path: '${r['path'] ?? ''}',
                size: (r['size'] as num?)?.toInt() ?? 0,
                modified: (r['modified'] as num?)?.toInt() ?? 0,
                source: source,
              ))
          .where((BackupCandidate c) => c.path.isNotEmpty)
          .toList();
}
