import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/constants/app_constants.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';
import 'about_page.dart';
import 'appearance_settings_page.dart';
import 'billing_settings_page.dart';
import 'data_settings_page.dart';
import 'lab_page.dart';
import 'llm_settings_page.dart';
import 'mcp_settings_page.dart';
import 'notify_settings_page.dart';
import 'update_settings_page.dart';
import 'feishu_settings_page.dart';

/// 设置中心（一级页）：只保留模块入口与状态摘要，保持一屏可浏览；
/// 每个模块的详细设置都在对应的二级页（自带返回按钮）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 顶栏折叠行为：上滑时大标题平滑收起
  final MiuixExitUntilCollapsedScrollBehavior _appBarBehavior =
      miuixScrollBehavior();

  @override
  Widget build(BuildContext context) {
    return AuroraScaffold(
      topBar: MiuixTopAppBar(
        scrollBehavior: _appBarBehavior,
        color: Colors.transparent,
        title: '设置中心',
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        // MiuixScrollBehaviorListener：把列表滚动桥接给顶栏（大标题折叠）
        return MiuixScrollBehaviorListener(
          behavior: _appBarBehavior,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
            children: <Widget>[
              //==================== 常用 ====================
              const SectionTitle('常用'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                borderRadius: 20,
                child: Column(
                  children: <Widget>[
                    MiuixArrowPreference(
                      title: '计费参数',
                      summary: '水电单价 · 缴费周期',
                      onClick: () =>
                          _push(const BillingSettingsPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '外观与显示',
                      summary: '主题与材质',
                      onClick: () =>
                          _push(const AppearanceSettingsPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '通知与提醒',
                      summary: '提醒时间 · 通知渠道',
                      onClick: () => _push(const NotifySettingsPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '大模型识别',
                      summary: '拍照识别配置',
                      onClick: () => _push(const LlmSettingsPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: 'MCP Server',
                      summary: 'AI 助手全流程接入',
                      onClick: () => _push(const McpSettingsPage()),
                    ),
                  ],
                ),
              ),

              //==================== 数据与关于 ====================
              const SectionTitle('数据与关于'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                borderRadius: 20,
                child: Column(
                  children: <Widget>[
                    MiuixArrowPreference(
                      title: '数据管理',
                      summary: '统计 · 备份 · 恢复',
                      onClick: () => _push(const DataSettingsPage()),
                    ),
                    MiuixArrowPreference(
                      title: '飞书多维表格',
                      summary: '云端数据 · 本地缓存 · 同步状态',
                      onClick: () => _push(const FeishuSettingsPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '通知实验室',
                      summary: '实验功能',
                      onClick: () => _push(const LabPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '更新设置',
                      summary: '下载源 · 自动检查 · 提醒',
                      onClick: () => _push(const UpdateSettingsPage()),
                    ),
                    const MiuixHorizontalDivider(),
                    MiuixArrowPreference(
                      title: '关于 ${AppConstants.appName}',
                      summary: 'V${AppConstants.appVersion}',
                      onClick: () => _push(const AboutPage()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _push(Widget page) {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(builder: (BuildContext _) => page),
        )
        .then((_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
