import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/mcp_server.dart';
import '../../services/mcp_tools.dart';
import '../widgets/app_widgets.dart';

/// 设置 · MCP Server：AI 助手接入开关 / 运行状态 / 配置一键复制 /
/// AI 可用能力清单。
///
/// 【对齐大狗记 Pronto 的 MCP 页】自上而下四段：
///   服务状态（启用开关 + 运行状态）→ 复制本机 / 局域网配置 →
///   IP 与用途说明 → AI 可用能力分组图标列表。
class McpSettingsPage extends StatefulWidget {
  const McpSettingsPage({super.key});

  @override
  State<McpSettingsPage> createState() => _McpSettingsPageState();
}

class _McpSettingsPageState extends State<McpSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;
    final McpServer server = McpServer.instance;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: 'MCP Server',
        subtitle: 'AI 助手接入 · 全流程读写',
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
            //==================== 服务状态 ====================
            const SectionTitle('服务状态'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixSwitchPreference(
                    title: '启用 MCP Server',
                    summary:
                        '允许 AI 助手通过 MCP 协议访问 ${AppConstants.appName}',
                    value: cfg.mcpEnabled,
                    onChanged: (bool v) async {
                      await cfg.update(mcpEnabled: v);
                      await McpServer.instance.syncWithConfig();
                      _refresh();
                    },
                  ),
                  const MiuixHorizontalDivider(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: <Widget>[
                        const MiuixText('运行状态',
                            fontSize: 15, fontWeight: FontWeight.w600),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: server.running
                                ? const Color(0xFF34C759)
                                : c.onSurfaceVariantSummary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        MiuixText(
                          server.running ? '运行中' : '已停止',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: server.running
                              ? const Color(0xFF34C759)
                              : c.onSurfaceVariantSummary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (server.lastError != null) ...<Widget>[
              const SizedBox(height: 8),
              MiuixText(
                '启动失败：${server.lastError}（端口 ${AppConstants.mcpPort} 可能被占用）',
                fontSize: 12,
                color: c.error,
              ),
            ],
            const SizedBox(height: 8),
            MiuixText(
              '允许 AI 助手通过 MCP 协议访问 ${AppConstants.appName}',
              fontSize: 12,
              color: c.onSurfaceVariantSummary,
            ),

            //==================== 配置复制 ====================
            const SizedBox(height: 20),
            _buildCopyButton('复制本机地址'),
            const SizedBox(height: 14),
            _buildCopyButton('复制局域网地址'),
            const SizedBox(height: 12),
            MiuixText(
              '本机配置： 本机使用，IP 固定不变\n'
              '局域网配置： 其他设备通过 WiFi 访问，'
              '当前 IP: ${server.lanIp.isEmpty ? '未获取到（请确认已连接 WiFi）' : server.lanIp}',
              fontSize: 12,
              height: 1.7,
              color: c.onSurfaceVariantSummary,
            ),
            const SizedBox(height: 8),
            MiuixText(
               '仅复制服务地址，不含 JSON 语法；粘贴到 AI 客户端的 MCP 地址栏。'
               '端口固定 ${AppConstants.mcpPort}，局域网 IP 变化后需重新复制。',
              fontSize: 12,
              height: 1.6,
              color: c.onSurfaceVariantSummary,
            ),

            //==================== AI 可用能力 ====================
            const SizedBox(height: 20),
            const SectionTitle('AI 可用能力'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < McpTools.capabilities.length; i++) ...<Widget>[
                    if (i > 0) const MiuixHorizontalDivider(),
                    _buildCapability(McpTools.capabilities[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            MiuixText(
              '共 ${McpTools.all.length} 个工具。AI 的写操作与本 APP 界面操作走同一批数据，'
              '改完立即反映到界面上；涉及删除、收大额款项时建议让 AI 先与你确认。',
              fontSize: 12,
              height: 1.6,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        );
      },
    );
  }

  /// 配置复制按钮：整宽圆角浅色按钮（对齐 Pronto 的居中文案胶囊）
  Widget _buildCopyButton(String label) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _copyConfig(label),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MiuixTheme.of(context).colors.secondaryContainer,
          borderRadius: BorderRadius.circular(26),
        ),
        child: MiuixText(
          label,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MiuixTheme.of(context).colors.onSurfaceContainer,
        ),
      ),
    );
  }

  /// 能力分组行：图标 + 分组名 / 工具摘要 + 展开箭头，点击展开工具清单
  Widget _buildCapability(McpCapability cap) {
    return MiuixArrowPreference(
      title: cap.title,
      summary: '${cap.summary} · ${cap.tools.length} 个工具',
      onClick: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext ctx) {
            final MiuixColors dc = MiuixTheme.of(ctx).colors;
            return AlertDialog(
              backgroundColor: dc.surface,
              title: MiuixText(cap.title,
                  fontSize: 17, fontWeight: FontWeight.w700),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    MiuixText(cap.summary,
                        fontSize: 13,
                        height: 1.6,
                        color: dc.onSurfaceVariantSummary),
                    const SizedBox(height: 12),
                    for (final String t in cap.tools) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: MiuixText(
                          '· $t',
                          fontSize: 13,
                          height: 1.5,
                          fontFamily: 'monospace',
                          color: dc.onSurfaceContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: MiuixText('关闭',
                      fontSize: 14, color: dc.primary),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 复制配置 JSON 到剪贴板
  Future<void> _copyConfig(String which) async {
    final McpServer server = McpServer.instance;
    if (!server.running) {
      AppSnackbar.show('MCP Server 未运行，请先开启上面的开关');
      return;
    }
    if (which == '复制局域网地址' && server.lanIp.isEmpty) {
      AppSnackbar.show('未获取到局域网 IP，请确认手机已连接 WiFi');
      return;
    }
    final String address =
        which == '复制本机地址' ? server.addressLocal : server.addressLan;
    await Clipboard.setData(ClipboardData(text: address));
    if (mounted) AppSnackbar.show('$which 已复制');
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
