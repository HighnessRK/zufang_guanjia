import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../data/db/database_helper.dart';
import '../../services/backup_service.dart';
import '../../services/native_bridge.dart';
import '../stat/stat_page.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';

/// 设置 · 数据管理：存储路径 / 数据备份 / 数据恢复。
///
/// 【路径可视化】展示数据（db / info.gwt）与备份 zip 的落地位置，并识别
/// 小米互传目录（内部存储/Download/MiShare）——用户在电脑 / 平板上用
/// 「小米互传」传过来的备份会落到这里，点「数据恢复」会优先读它下面
/// 最新的备份 zip，无需再翻文件。
class DataSettingsPage extends StatefulWidget {
  const DataSettingsPage({super.key});

  @override
  State<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends State<DataSettingsPage> {
  /// 目录信息（appBackupDir / miShareDir / miShareExists / downloadDir）
  Map<String, dynamic> _dirs = <String, dynamic>{};

  /// 小米互传目录里的备份（最新在前）
  List<BackupCandidate> _miShare = <BackupCandidate>[];

  /// 应用备份目录里的备份（最新在前）
  List<BackupCandidate> _local = <BackupCandidate>[];

  /// 是否已具备共享存储读取权限
  bool _storageOk = true;

  /// 数据库文件路径（initState 后填充）
  String _dbPath = '…';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    // 数据库路径：打开过即有；未打开先推一次（不阻塞 UI）
    final String? db = DatabaseHelper.instance.dbFilePath;
    _dbPath = db ?? await DatabaseHelper.instance.backupPath();

    final Map<String, dynamic> dirs = await NativeBridge.backupDirs();
    final bool ok = await NativeBridge.hasStorageAccess();
    final List<BackupCandidate> mi =
        ok ? await BackupService.instance.listMiShareBackups() : const [];
    final List<BackupCandidate> local =
        await BackupService.instance.listAppBackups();

    if (!mounted) return;
    setState(() {
      _dirs = dirs;
      _storageOk = ok;
      _miShare = mi;
      _local = local;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final bool miShareExists = _dirs['miShareExists'] == true;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '数据管理',
        subtitle: '路径 · 备份 · 恢复',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
              20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
          children: <Widget>[
            //==================== 统计 ====================
            const SectionTitle('统计与报表'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: MiuixArrowPreference(
                title: '缴费统计',
                summary: '月度收支报表 · 欠费累计 · 结清率',
                onClick: () => Navigator.of(context).push(
                      AppPageRoute<void>(
                          builder: (BuildContext _) => const StatPage()),
                    ),
              ),
            ),

            //==================== 存储路径 ====================
            const SectionTitle('存储路径'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              borderRadius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _pathRow(
                    icon: Icons.storage_rounded,
                    title: '数据存储路径',
                    value: _dbPath,
                    sub: '数据库 rental.db',
                    c: c,
                  ),
                  const MiuixHorizontalDivider(),
                  _pathRow(
                    icon: Icons.tune_rounded,
                    title: '配置文件路径',
                    value: AppConfig.instance.configPath ?? '未初始化',
                    sub: 'info.gwt（单价 / 周期 / 提醒设置）',
                    c: c,
                  ),
                  const MiuixHorizontalDivider(),
                  _pathRow(
                    icon: Icons.folder_zip_rounded,
                    title: '数据备份路径',
                    value: '${_dirs['appBackupDir'] ?? '…'}',
                    sub: _local.isEmpty
                        ? '暂无备份，点下方「数据备份」生成'
                        : '本机备份 ${_local.length} 个'
                            '（最新 ${_local.first.modifiedText}）',
                    c: c,
                  ),
                  const MiuixHorizontalDivider(),
                  _pathRow(
                    icon: Icons.phonelink_rounded,
                    title: '小米互传路径',
                    value: '${_dirs['miShareDir'] ?? '…'}',
                    sub: !miShareExists
                        ? '目录尚未创建（用小米互传收过文件后出现）'
                        : _storageOk
                            ? (_miShare.isEmpty
                                ? '已识别，暂无备份 zip'
                                : '已识别 ${_miShare.length} 个备份'
                                    '（最新 ${_miShare.first.modifiedText}）')
                            : '缺少读取权限，点「数据恢复」授权后即可读取',
                    c: c,
                    warn: miShareExists && !_storageOk,
                  ),
                ],
              ),
            ),

            //==================== 备份与恢复 ====================
            const SectionTitle('备份与恢复'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixArrowPreference(
                    title: '数据备份',
                    summary: '导出 rental.db + info.gwt',
                    onClick: _backup,
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '数据恢复',
                    summary: _restoreSummary(miShareExists),
                    onClick: _restore,
                  ),
                ],
              ),
            ),

            //==================== 备份清单 ====================
            if (_miShare.isNotEmpty || _local.isNotEmpty) ...<Widget>[
              const SectionTitle('可恢复的备份'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                borderRadius: 20,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < _backupList().length; i++) ...<Widget>[
                      if (i > 0) const MiuixHorizontalDivider(),
                      _backupRow(_backupList()[i], i == 0, c),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            MiuixText(
              '备份为单个压缩包，通过系统分享保存到云盘 / 电脑；'
              '电脑与手机在同一 WiFi 下用「小米互传」传回的备份，'
              '会自动出现在上面的互传目录里，恢复时优先读取。',
              fontSize: 12,
              height: 1.7,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        );
      },
    );
  }

  //========================= 组合 =========================

  /// 备份清单（互传在前，本机在后）
  List<BackupCandidate> _backupList() =>
      <BackupCandidate>[..._miShare, ..._local];

  /// 恢复入口摘要：体现「默认读互传最新」这一条路径
  String _restoreSummary(bool miShareExists) {
    if (_miShare.isNotEmpty) {
      return '默认恢复小米互传最新：${_miShare.first.name}';
    }
    if (_local.isNotEmpty) {
      return '互传目录无备份，可恢复本机最新 / 手动选择';
    }
    if (miShareExists && !_storageOk) {
      return '需授权读取小米互传备份（Download/MiShare）';
    }
    return '从小米互传 / 本机备份 / 文件选择器恢复';
  }

  /// 路径行：图标 + 标题 + 路径（可点复制）+ 副标题
  Widget _pathRow({
    required IconData icon,
    required String title,
    required String value,
    required String sub,
    required MiuixColors c,
    bool warn = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 8, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: c.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MiuixText(title,
                    fontSize: 15, fontWeight: FontWeight.w600),
                const SizedBox(height: 3),
                // 路径较长：整行截断 + 点按复制
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyPath(value),
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: c.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                MiuixText(
                  sub,
                  fontSize: 11,
                  height: 1.5,
                  color: warn ? const Color(0xFFFF9500) : c.onSurfaceVariantSummary,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyPath(value),
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: c.onSurfaceVariantSummary,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: '复制路径',
          ),
        ],
      ),
    );
  }

  /// 备份清单行：文件名 + 来源 · 时间 · 大小 + 恢复
  Widget _backupRow(BackupCandidate b, bool newest, MiuixColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 6, 11),
      child: Row(
        children: <Widget>[
          Icon(Icons.folder_zip_rounded,
              size: 19,
              color: newest ? c.primary : c.onSurfaceVariantSummary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                    if (newest) ...<Widget>[
                      const SizedBox(width: 6),
                      StatusTag('最新', color: c.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                MiuixText(
                  '${b.source.contains('MiShare') ? '小米互传' : '本机备份'}'
                  ' · ${b.modifiedText} · ${b.sizeText}',
                  fontSize: 11,
                  color: c.onSurfaceVariantSummary,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _restoreConfirm(b),
            child: MiuixText('恢复', fontSize: 13, color: c.primary),
          ),
        ],
      ),
    );
  }

  //========================= 动作 =========================

  /// 备份数据（系统分享）
  Future<void> _backup() async {
    try {
      final String name = await BackupService.instance.backup();
      if (mounted) {
        AppSnackbar.show(name.isEmpty ? '备份已生成' : '备份完成：$name');
      }
      await _refresh();
    } catch (e) {
      if (mounted) AppSnackbar.show('备份失败：$e');
    }
  }

  /// 恢复数据：默认读小米互传目录里最新的备份 zip；
  /// 无互传备份 → 本机最新；都没有 → 系统文件选择器。
  Future<void> _restore() async {
    // 1) 小米互传目录存在但没权限 → 引导授权（Android 11+ 所有文件访问）
    final bool miShareExists = _dirs['miShareExists'] == true;
    if (miShareExists && !_storageOk) {
      final bool? go = await showAppDialog(
        context,
        title: '需要读取权限',
        summary: '小米互传备份存放在系统下载目录（Download/MiShare），'
            '读取它需要授予「所有文件访问」权限。现在去授权吗？',
        confirmText: '去授权',
      );
      if (go != true || !mounted) return;
      await NativeBridge.requestStorageAccess();
      AppSnackbar.show('授权后请重新点「数据恢复」');
      await _refresh();
      return;
    }

    // 2) 已有可直读的备份 → 确认后恢复（互传优先）
    final List<BackupCandidate> list = _backupList();
    if (list.isNotEmpty) {
      await _restoreConfirm(list.first);
      return;
    }

    // 3) 兜底：系统文件选择器
    await _restorePicker();
  }

  /// 确认并恢复指定备份
  Future<void> _restoreConfirm(BackupCandidate b) async {
    final String source =
        b.source.contains('MiShare') ? '小米互传' : '本机备份';
    final bool? ok = await showAppDialog(
      context,
      title: '恢复备份数据？',
      summary: '将用 $source 里最新的备份覆盖当前全部数据，且无法撤销。\n\n'
          '${b.name}\n${b.modifiedText} · ${b.sizeText}',
      confirmText: '恢复',
      danger: true,
    );
    if (ok != true) return;
    await _doRestore(b.path);
  }

  /// 走系统选择器恢复
  Future<void> _restorePicker() async {
    final bool? ok = await showAppDialog(
      context,
      title: '恢复备份数据？',
      summary: '小米互传与本机备份目录里暂无备份，将打开系统文件选择器，'
          '恢复会覆盖当前全部数据，且无法撤销。',
      confirmText: '选择文件',
      danger: true,
    );
    if (ok != true) return;
    final bool done = await BackupService.instance.restore();
    if (!mounted) return;
    AppSnackbar.show(done ? '数据恢复成功，已重新加载' : '未选择备份文件');
    if (done) await _refresh();
  }

  Future<void> _doRestore(String path) async {
    final bool done = await BackupService.instance.restoreFrom(path);
    if (!mounted) return;
    AppSnackbar.show(done ? '数据恢复成功，已重新加载' : '恢复失败：备份文件不可读');
    if (done) {
      await _refresh();
      if (mounted) setState(() {});
    }
  }

  Future<void> _copyPath(String p) async {
    if (p.isEmpty || p == '…') return;
    await Clipboard.setData(ClipboardData(text: p));
    if (mounted) AppSnackbar.show('路径已复制');
  }
}
