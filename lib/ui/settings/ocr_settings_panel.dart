import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/config/app_config.dart';
import '../../services/ocr/model_manager.dart';
import '../../services/ocr/model_catalog.dart';
import '../widgets/model_download_progress.dart';
import '../../services/ocr/ocr_engine_resolver.dart';
import '../../services/ocr/soc_info.dart';
import '../widgets/app_widgets.dart';

class OcrSettingsPanel extends StatefulWidget {
  const OcrSettingsPanel({super.key});
  @override
  State<OcrSettingsPanel> createState() => _OcrSettingsPanelState();
}

class _OcrSettingsPanelState extends State<OcrSettingsPanel> {
  final models = ModelManager.instance;
  final resolver = OcrEngineResolver.instance;
  SocInfo soc = const SocInfo('正在读取…', 0);
  String error = '';
  bool _details = false;
  @override
  void initState() {
    super.initState();
    models.addListener(_refresh);
    resolver.addListener(_refresh);
    _run(resolver.restoreStatus);
    SocInfo.read().then((value) {
      if (mounted) setState(() => soc = value);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action) async {
    if (mounted) setState(() => error = '');
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
    _refresh();
  }

  @override
  void dispose() {
    models.removeListener(_refresh);
    resolver.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _chooseMode() async {
    final value = await showOptionPicker<String>(context,
        title: '识别方式',
        current: AppConfig.instance.ocrMode,
        summary: '自动模式在本地失败时使用云端；仅本地不上传照片。',
        options: [
          const MapEntry('auto', '自动 · 本地优先'),
          if (models.ready) const MapEntry('local', '仅本地 · 不上传照片'),
          const MapEntry('cloud', '仅云端')
        ]);
    if (value != null && mounted) await _run(() => resolver.setMode(value));
  }

  @override
  Widget build(BuildContext context) {
    final c = MiuixTheme.of(context).colors;
    final status = switch (models.status) {
      ModelStatus.missing => '未下载',
      ModelStatus.downloading => '下载中',
      ModelStatus.paused => '已暂停 · 可继续下载',
      ModelStatus.verifying => '正在检查本地模型…',
      ModelStatus.ready => '已就绪',
      ModelStatus.corrupt => '下载失败 · 请重试',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('识别方式'),
      GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          borderRadius: 20,
          child: MiuixArrowPreference(
              title: switch (AppConfig.instance.ocrMode) {
                'local' => '仅本地',
                'cloud' => '仅云端',
                _ => '自动 · 本地优先',
              },
              summary: AppConfig.instance.ocrMode == 'local'
                  ? '照片不上传'
                  : AppConfig.instance.ocrMode == 'cloud'
                      ? '使用下方配置的视觉模型'
                      : '本地不可用时使用云端',
              onClick: _chooseMode)),
      const SectionTitle('本地模型'),
      GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MiuixArrowPreference(
              title: '推理加速',
              summary: AppConfig.instance.ocrAcceleration == 'cpu'
                  ? 'CPU · 兼容模式'
                  : '自动 · 优先 Hexagon NPU',
              onClick: () async {
                final value = await showOptionPicker<String>(context,
                    title: '推理加速',
                    current: AppConfig.instance.ocrAcceleration,
                    summary: '支持的骁龙设备使用 Hexagon；不可用时回退 CPU。',
                    options: const [
                      MapEntry('auto', '自动 · NPU 优先'),
                      MapEntry('cpu', 'CPU · 兼容模式')
                    ]);
                if (value != null && mounted) {
                  await _run(() => resolver.setAcceleration(value));
                }
              })),
      const SizedBox(height: 12),
      GlassCard(
          padding: const EdgeInsets.all(18),
          borderRadius: 20,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const MiuixText('Xiaomi-OCR-0',
                        fontSize: 16, fontWeight: FontWeight.w600),
                    const SizedBox(height: 6),
                    MiuixText(status,
                        fontSize: 12, color: c.onSurfaceVariantSummary),
                  ])),
              StatusTag(models.ready ? '已下载' : '约 1.04 GB', color: c.primary),
            ]),
            const SizedBox(height: 14),
            if (models.busy ||
                models.status == ModelStatus.paused ||
                models.received > 0 && !models.ready) ...[
              ModelDownloadProgress(
                  received: models.received,
                  total: models.total,
                  verifying: models.status == ModelStatus.verifying,
                  detail: models.currentFile),
              const SizedBox(height: 14),
            ],
            if (!models.ready && models.initialized)
              GradientButton(
                  label: models.busy
                      ? '暂停下载'
                      : models.status == ModelStatus.paused
                          ? '继续下载'
                          : '下载本地模型',
                  icon: models.busy
                      ? Icons.pause_rounded
                      : Icons.download_rounded,
                  enabled: models.configured,
                  onPressed: () =>
                      _run(models.busy ? models.pause : models.download)),
            if (models.busy || models.status == ModelStatus.paused)
              MiuixArrowPreference(
                  title: '取消下载', onClick: () => _run(models.cancel)),
            if (models.ready)
              MiuixArrowPreference(
                  title: '删除模型',
                  summary: '释放本地存储空间',
                  onClick: () async {
                    final yes = await showAppDialog(context,
                        title: '删除本地模型？',
                        summary: '将释放模型文件，识别恢复为自动模式。',
                        confirmText: '删除',
                        danger: true);
                    if (yes == true && mounted) {
                      await _run(resolver.deleteModels);
                    }
                  }),
            if (!models.ready) ...[
              const SizedBox(height: 10),
              MiuixText('Gitee 国内镜像 · 请预留 2 GB 空间',
                  fontSize: 12, color: c.onSurfaceVariantSummary)
            ],
            for (final message in [
              if (!models.configured) '下载配置无效，请使用云端识别。',
              models.error,
              error,
              resolver.warning
            ])
              if (message.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: MiuixText(message, fontSize: 12, color: c.error)),
          ])),
      const SizedBox(height: 12),
      GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          borderRadius: 20,
          child: Column(children: [
            MiuixArrowPreference(
                title: '模型与设备信息',
                summary: _details ? '点击收起' : '来源、运行状态与设备',
                onClick: () => setState(() => _details = !_details)),
            if (_details)
              Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InfoRow('实际引擎', resolver.actualEngine),
                        InfoRow('设备芯片', soc.description),
                        InfoRow('NPU 硬件', soc.npu),
                        InfoRow(
                            '加速策略',
                            AppConfig.instance.ocrAcceleration == 'cpu'
                                ? 'CPU 兼容模式'
                                : 'Hexagon NPU 优先 · 视觉编码与不支持的算子由 CPU 处理'),
                        const InfoRow('下载来源', ModelCatalog.sourceLabel),
                        const SizedBox(height: 8),
                        MiuixText(
                            '来源：xzl01/Xiaomi-OCR-0-GGUF v1.0.0（社区转换版）。包含 Q8_0 主模型和 F16 投影器，下载后自动校验。准确度请以人工核对为准。',
                            fontSize: 12,
                            height: 1.5,
                            color: c.onSurfaceVariantSummary),
                      ])),
          ])),
    ]);
  }
}
