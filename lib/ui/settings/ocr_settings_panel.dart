import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../services/ocr/model_manager.dart';
import '../../services/ocr/ocr_engine_resolver.dart';
import '../../services/ocr/soc_info.dart';

class OcrSettingsPanel extends StatefulWidget {
  const OcrSettingsPanel({super.key});
  @override
  State<OcrSettingsPanel> createState() => _OcrSettingsPanelState();
}

class _OcrSettingsPanelState extends State<OcrSettingsPanel> {
  final models = ModelManager.instance;
  final resolver = OcrEngineResolver.instance;
  SocInfo soc = const SocInfo('正在读取 SoC…', 0);
  String error = '';
  @override
  void initState() {
    super.initState();
    models.addListener(_refresh);
    resolver.addListener(_refresh);
    _run(models.init);
    SocInfo.read().then((value) {
      if (mounted) setState(() => soc = value);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action) async {
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

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OCR 引擎 / Xiaomi-OCR-0',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(AppConfig.instance.ocrMode),
            initialValue: AppConfig.instance.ocrMode,
            isExpanded: true,
            itemHeight: null,
            items: [
              const DropdownMenuItem(
                  value: 'auto', child: Text('自动（本地失败回退云端）')),
              DropdownMenuItem(
                  value: 'local',
                  enabled: models.ready,
                  child: const Text('本地优先（失败时不上传照片）')),
              const DropdownMenuItem(value: 'cloud', child: Text('仅云端（不加载本地）')),
            ],
            onChanged: (value) {
              if (value != null) _run(() => resolver.setMode(value));
            },
          ),
          const SizedBox(height: 8),
          Text('当前实际引擎：${resolver.actualEngine}'),
          Text(
              '主模型 Q8_0 约 0.83 GB + 必需 F16 投影器约 0.2 GB\n状态：${switch (models.status) {
            ModelStatus.missing => '未下载',
            ModelStatus.downloading => '下载中',
            ModelStatus.paused => '已暂停（可恢复）',
            ModelStatus.verifying => '校验中',
            ModelStatus.ready => '已下载并校验',
            ModelStatus.corrupt => '损坏 / 下载失败',
          }}'),
          if (models.busy) ...[
            LinearProgressIndicator(
                value: models.total > 0
                    ? (models.received / models.total).clamp(0.0, 1.0)
                    : null),
            Text('${(models.received / 1048576).toStringAsFixed(1)} MB / '
                '${models.total > 0 ? '${(models.total / 1048576).toStringAsFixed(1)} MB' : '大小待获取'}（当前文件）'),
          ],
          if (!models.configured)
            const Text('下载配置无效：需要 HTTPS 地址及完整 SHA-256。云端仍可正常使用。'),
          const Text('下载来源：xzl01/Xiaomi-OCR-0-GGUF v1.0.0（GitHub 社区转换版）。'
              '下载约 1.04 GB，分片合并还需要额外空间；请预留至少 2 GB。'),
          Wrap(spacing: 8, children: [
            TextButton(
                onPressed: models.configured && !models.busy && !models.ready
                    ? () => _run(models.download)
                    : null,
                child: const Text('下载 / 恢复')),
            TextButton(
                onPressed: models.busy ? () => _run(models.pause) : null,
                child: const Text('暂停')),
            TextButton(
                onPressed: () => _run(models.cancel),
                child: const Text('取消下载')),
            TextButton(
                onPressed: () async {
                  final yes = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                              title: const Text('删除本地模型？'),
                              content: const Text('将释放模型文件，识别恢复为自动模式。'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('删除'))
                              ]));
                  if (yes == true) await _run(resolver.deleteModels);
                },
                child: const Text('删除模型')),
          ]),
          if (models.error.isNotEmpty) Text(models.error),
          if (error.isNotEmpty) Text(error),
          if (resolver.warning.isNotEmpty) Text(resolver.warning),
          const Divider(),
          const CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('启用 Snapdragon Hexagon NPU 加速（实验性）'),
              subtitle: Text('构建选项：当前为 CPU AAR，不支持运行时切换'),
              value: false,
              onChanged: null),
          Text('检测芯片：${soc.description}\n${soc.hint}'),
          const Text('更换 Hexagon AAR 需要修改 hooks.user_defines 并重新构建；'
              '本版本始终使用 CPU，不声称 NPU 已生效。社区 GGUF 尚未获小米独立准确度验证。'
              '首次使用请用清晰单表小图测试，并人工核对所有读数。'
              '自动模式可能把照片发送到已配置的云端 API；仅本地失败时不会上传。'),
        ]),
      ));
}
