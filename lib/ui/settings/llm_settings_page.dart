import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../services/llm_models_service.dart';
import '../widgets/app_widgets.dart';
import 'settings_edit.dart';
import 'ocr_settings_panel.dart';

/// 设置 · 大模型识别 API：电表拍照（单房间 / 整层批量）识别用。
class LlmSettingsPage extends StatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  State<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends State<LlmSettingsPage> {
  List<String> _models = <String>[];
  bool _loading = false;
  String _error = '';
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (AppConfig.instance.llmBaseUrl.isNotEmpty) _loadModels();
  }

  Future<void> _loadModels() async {
    final int id = ++_requestId;
    setState(() {
      _loading = true;
      _error = '';
      _models = <String>[];
    });
    final AppConfig cfg = AppConfig.instance;
    try {
      final List<String> models =
          await LlmModelsService.fetch(cfg.llmBaseUrl, cfg.llmApiKey);
      if (!mounted || id != _requestId) return;
      setState(() {
        _models = models;
        _error = models.isEmpty ? '接口返回空列表，可手动填写模型名' : '';
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e.toString());
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _chooseModel(bool vision) async {
    final AppConfig cfg = AppConfig.instance;
    final String title = vision ? '视觉模型' : '对话模型';
    final String? choice = await showOptionPicker<String>(context,
        title: title,
        current: vision ? cfg.llmVisionModel : cfg.llmModel,
        summary: vision ? '请选择支持图片输入的模型' : null,
        options: [
          for (final model in _models) MapEntry(model, model),
          const MapEntry('', '手动输入模型名')
        ]);
    if (!mounted || choice == null) return;
    Future<void> save(String value) async {
      await cfg.update(
          llmVisionModel: vision ? value.trim() : null,
          llmModel: vision ? null : value.trim());
      _refresh();
    }

    if (choice.isNotEmpty) {
      await save(choice);
      return;
    }
    editTextDialog(context, title, '填写服务商支持的模型 ID',
        vision ? cfg.llmVisionModel : cfg.llmModel, '模型 ID', save);
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: '大模型识别',
        subtitle: '拍照识表',
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
            const OcrSettingsPanel(),
            const SizedBox(height: 16),
            const SectionTitle('云端接口'),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: 20,
              child: Column(
                children: <Widget>[
                  MiuixArrowPreference(
                    title: 'API 地址',
                    summary:
                        cfg.llmBaseUrl.isEmpty ? '未配置 · 点击填写' : cfg.llmBaseUrl,
                    onClick: () => editTextDialog(
                      context,
                      'API 地址',
                      'OpenAI 兼容基地址',
                      cfg.llmBaseUrl,
                      'https://api.openai.com/v1',
                      (String v) async {
                        await cfg.update(llmBaseUrl: v);
                        _refresh();
                        _loadModels();
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
                        _loadModels();
                      },
                    ),
                  ),
                  const MiuixHorizontalDivider(),
                  MiuixArrowPreference(
                    title: '视觉模型',
                    summary: cfg.llmVisionModel.isEmpty
                        ? '未配置 · 选择视觉模型'
                        : cfg.llmVisionModel,
                    onClick: () => _chooseModel(true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
                label: _loading ? '正在获取模型…' : '刷新模型列表',
                icon: Icons.refresh_rounded,
                enabled: !_loading,
                onPressed: _loadModels),
            if (_error.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: MiuixText('获取失败，可手动填写模型名。',
                      fontSize: 12, color: c.error)),
            const SizedBox(height: 12),
            MiuixText('云端仅在识别时发送当前照片。',
                fontSize: 12, color: c.onSurfaceVariantSummary),
          ],
        );
      },
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
