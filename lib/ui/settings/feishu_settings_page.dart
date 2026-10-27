import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../services/feishu_sync_service.dart';
import '../widgets/app_widgets.dart';
import 'settings_edit.dart';

class FeishuSettingsPage extends StatefulWidget {
  const FeishuSettingsPage({super.key});
  @override
  State<FeishuSettingsPage> createState() => _FeishuSettingsPageState();
}

class _FeishuSettingsPageState extends State<FeishuSettingsPage> {
  bool _busy = false;
  Future<void> _edit(int index) async {
    if (_busy) return;
    final c = AppConfig.instance;
    final values = [c.feishuAppToken, c.feishuTableId, c.feishuClientId, c.feishuClientSecret];
    try {
      await editTextDialog(context,
        ['多维表格 App Token', '数据表 Table ID', '应用 App ID', '应用 App Secret'][index],
        index == 3 ? '应用密钥仅存私有配置；备份与云端配置中会包含，请勿公开分享。'
            : '填写飞书开放平台参数，保存后立即生效。',
        values[index], ['app_token', 'table_id', 'cli_…', 'App Secret'][index],
        (value) async {
          if (value.contains('\n') || value.contains('\r')) throw StateError('参数不能含换行');
          switch (index) {
            case 0: c.feishuAppToken = value;
            case 1: c.feishuTableId = value;
            case 2: c.feishuClientId = value;
            case 3: c.feishuClientSecret = value;
          }
          await c.save();
          if (mounted) setState(() {});
        });
    } catch (e) {
      if (mounted) AppSnackbar.show(e is StateError ? e.message : '保存失败');
    }
  }

  Future<void> _sync({bool initialize = false, bool download = false}) async {
    if (_busy) return;
    final ok = await showAppDialog(context, title: download ? '从飞书初始化缓存？' : '同步至飞书？',
        summary: download ? '先备份，再用飞书同步记录替换本地缓存。未上传的本地修改将不再使用。'
            : '租户、账单、收据及配置（含 API 密钥）将上传至当前多维表格。请限制该表格访问权限。首次上传会先备份。',
        confirmText: '继续', danger: download);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await FeishuSyncService.instance.sync(initialize: initialize, download: download);
      if (mounted) AppSnackbar.show('飞书同步完成');
    } catch (e) {
      if (mounted) AppSnackbar.show(e is StateError ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppConfig.instance;
    final colors = MiuixTheme.of(context).colors;
    final values = [c.feishuAppToken, c.feishuTableId, c.feishuClientId, c.feishuClientSecret];
    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(title: '飞书多维表格', color: Colors.transparent,
        subtitle: '云端数据 · 本地缓存',
        navigationIcon: MiuixIconButton(onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded))),
      snackbarHost: const AppSnackbarHost(),
      content: (padding) => ListView(padding: EdgeInsets.fromLTRB(
        20, padding.top + 8, 20, kGlassNavClearance + padding.bottom), children: [
        const SectionTitle('连接配置'),
        GlassCard(padding: const EdgeInsets.symmetric(vertical: 4), borderRadius: 20,
          child: Column(children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const MiuixHorizontalDivider(),
              MiuixArrowPreference(
                title: ['多维表格 App Token', '数据表 Table ID', '应用 App ID', '应用 App Secret'][i],
                summary: values[i].isEmpty ? '未配置 · 点击填写'
                    : i == 3 ? '已配置 · ••••••••' : values[i],
                onClick: () => _edit(i)),
            ],
          ])),
        const SizedBox(height: 16),
        const SectionTitle('同步管理'),
        GlassCard(padding: const EdgeInsets.symmetric(vertical: 4), borderRadius: 20,
          child: Column(children: [
        MiuixSwitchPreference(title: '前台自动同步',
          summary: '每 30 秒检查 · 数据修改后自动同步', value: c.feishuEnabled,
          onChanged: (bool v) async {
            if (_busy) return;
            try {
              c.feishuEnabled = v;
              await c.save();
              if (mounted) setState(() {});
            } catch (e) { if (mounted) AppSnackbar.show('保存失败'); }
          }),
        const MiuixHorizontalDivider(),
        ValueListenableBuilder<String>(valueListenable: FeishuSyncService.instance.status,
          builder: (_, s, __) => Padding(padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_busy ? Icons.sync_rounded : Icons.cloud_sync_outlined,
                color: colors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const MiuixText('同步状态', fontSize: 14, fontWeight: FontWeight.w600),
                const SizedBox(height: 4),
                MiuixText(s, fontSize: 12, height: 1.5, color: colors.onSurfaceVariantSummary),
              ])),
            ]))),
          ])),
        const SizedBox(height: 20),
        GradientButton(label: _busy ? '正在同步…' : '立即同步 / 首次上传',
          icon: Icons.sync_rounded, enabled: !_busy, onPressed: () => _sync(initialize: true)),
        const SizedBox(height: 12),
        GlassCard(padding: const EdgeInsets.symmetric(vertical: 4), borderRadius: 20,
          child: MiuixArrowPreference(title: '从飞书初始化缓存',
            summary: '先备份，再下载 · 将替换本地数据',
            onClick: () { if (!_busy) _sync(download: true); })),
        const SizedBox(height: 16),
        MiuixText('连接参数保存在本机私有配置。备份及飞书配置行包含密钥，请勿公开分享，并限制表格访问权限。',
          fontSize: 12, height: 1.6, color: colors.onSurfaceVariantSummary),
        const SizedBox(height: 8),
        MiuixText('双方同时修改同一条数据时会停止覆盖并提示冲突。Android 后台不保证实时同步。',
          fontSize: 12, height: 1.6, color: colors.onSurfaceVariantSummary),
      ]),
    );
  }
}
