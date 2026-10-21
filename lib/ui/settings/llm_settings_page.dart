import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../widgets/app_widgets.dart';
import 'settings_edit.dart';

/// 设置 · 大模型识别 API：电表拍照（单房间 / 整层批量）识别用。
class LlmSettingsPage extends StatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  State<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends State<LlmSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '大模型识别',
        subtitle: 'OpenAI 兼容接口 · 拍照识表',
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
            const SectionTitle('接口配置'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixArrowPreference(
                    title: 'API 地址',
                    summary: cfg.llmBaseUrl.isEmpty
                        ? '未配置（OpenAI 兼容，填到 /v1）'
                        : cfg.llmBaseUrl,
                    onClick: () => editTextDialog(
                          context,
                          'API 地址',
                          'OpenAI 兼容基地址',
                          cfg.llmBaseUrl,
                          'https://api.openai.com/v1',
                          (String v) async {
                            await cfg.update(llmBaseUrl: v);
                            _refresh();
                          },
                        ),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: 'API Key',
                    summary: maskKey(cfg.llmApiKey),
                    onClick: () => editTextDialog(
                          context,
                          'API Key',
                          'OpenAI 兼容密钥',
                          cfg.llmApiKey,
                          'sk-…',
                          (String v) async {
                            await cfg.update(llmApiKey: v.trim());
                            _refresh();
                          },
                        ),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '视觉模型',
                    summary: cfg.llmVisionModel.isEmpty
                        ? '未配置（电表拍照识别用）'
                        : cfg.llmVisionModel,
                    onClick: () => editTextDialog(
                          context,
                          '视觉模型',
                          '用于电表照片识别读数（单房间 / 整层批量）',
                          cfg.llmVisionModel,
                          'qwen-vl-max / gpt-4o-mini …',
                          (String v) async {
                            await cfg.update(llmVisionModel: v.trim());
                            _refresh();
                          },
                        ),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '对话模型（预留）',
                    summary: cfg.llmModel.isEmpty ? '未配置' : cfg.llmModel,
                    onClick: () => editTextDialog(
                          context,
                          '对话模型',
                          '预留接口，后续智能记账等能力使用',
                          cfg.llmModel,
                          'deepseek-chat / gpt-4o-mini …',
                          (String v) async {
                            await cfg.update(llmModel: v.trim());
                            _refresh();
                          },
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MiuixText(
              '仅在点「拍照识别」时发送当前这张照片。',
              fontSize: 12,
              height: 1.6,
              color: c.onSurfaceVariantSummary,
            ),
          ],
        );
      },
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
