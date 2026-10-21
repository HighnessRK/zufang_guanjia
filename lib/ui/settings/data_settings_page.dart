import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../services/backup_service.dart';
import '../stat/stat_page.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';

/// 设置 · 数据管理：缴费统计 / 数据备份 / 数据恢复。
class DataSettingsPage extends StatefulWidget {
  const DataSettingsPage({super.key});

  @override
  State<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends State<DataSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '数据管理',
        subtitle: '统计 · 备份 · 恢复',
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
                    summary: '从备份文件恢复全部数据',
                    onClick: _restore,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MiuixText(
              '备份为单个压缩包，通过系统分享保存到云盘 / 电脑；恢复会覆盖当前全部数据。',
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        );
      },
    );
  }

  /// 备份数据
  Future<void> _backup() async {
    try {
      final String name = await BackupService.instance.backup();
      if (mounted) {
        AppSnackbar.show(name.isEmpty ? '备份已生成' : '备份完成：$name');
      }
    } catch (e) {
      if (mounted) AppSnackbar.show('备份失败：$e');
    }
  }

  /// 恢复数据
  Future<void> _restore() async {
    final bool? ok = await showAppDialog(
      context,
      title: '恢复备份数据？',
      summary: '恢复会覆盖当前全部数据，且无法撤销，确定继续吗？',
      confirmText: '恢复',
      danger: true,
    );
    if (ok != true) return;
    final bool done = await BackupService.instance.restore();
    if (!mounted) return;
    AppSnackbar.show(done ? '数据恢复成功，已重新加载' : '未选择备份文件');
    setState(() {});
  }
}
