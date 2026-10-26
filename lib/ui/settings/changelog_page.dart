import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/constants/app_changelog.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/app_widgets.dart';

/// 更新日志内容区：按版本倒序，条目带「新增 / 优化 / 修复」彩色标签。
///
/// 【v1.1.3】**最新版本默认展开、历史版本默认折叠**，点头部整卡可展开 /
/// 收起（带高度与箭头动画）；折叠时显示条数提示。以纯内容块形式内嵌在
/// 「关于」一级页面中。
class ChangelogSection extends StatefulWidget {
  const ChangelogSection({super.key});

  @override
  State<ChangelogSection> createState() => _ChangelogSectionState();
}

class _ChangelogSectionState extends State<ChangelogSection> {
  /// 已展开的版本号。初始只放最新版本（本次更新默认展开，历史默认折叠）。
  late final Set<String> _open = <String>{
    if (AppChangelog.versions.isNotEmpty) AppChangelog.versions.first.version,
  };

  void _toggle(String version) {
    setState(() {
      if (!_open.add(version)) {
        _open.remove(version);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < AppChangelog.versions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 14),
          _versionCard(
            context,
            c,
            AppChangelog.versions[i],
            open: _open.contains(AppChangelog.versions[i].version),
          ),
        ],
      ],
    );
  }

  Widget _versionCard(
    BuildContext context,
    MiuixColors c,
    ChangelogVersion v, {
    required bool open,
  }) {
    final bool current = v.version == AppConstants.appVersion;
    final int n = v.entries.length;
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      // 整卡可点：展开 / 收起本版本
      onPressed: () => _toggle(v.version),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              MiuixText('V${v.version}',
                  fontSize: 17, fontWeight: FontWeight.w700),
              if (current) ...<Widget>[
                const SizedBox(width: 8),
                StatusTag('当前版本', color: c.primary),
              ],
              const Spacer(),
              MiuixText(v.date,
                  fontSize: 12, color: c.onSurfaceVariantSummary),
              const SizedBox(width: 6),
              // 展开箭头：展开时旋转 180°
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: c.onSurfaceVariantSummary,
                ),
              ),
            ],
          ),
          // 折叠态：给一条「N 条 · 点击展开」提示，避免历史版本看着空
          if (!open)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MiuixText(
                '$n 条更新 · 点击展开',
                fontSize: 12,
                color: c.onSurfaceVariantSummary,
              ),
            ),
          // 展开态：条目列表（高度动画跟随折叠/展开）
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (int j = 0; j < n; j++)
                          Padding(
                            padding:
                                EdgeInsets.only(bottom: j == n - 1 ? 0 : 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Color(
                                            AppChangelog.colorOf(v.entries[j].type))
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: MiuixText(v.entries[j].type,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(AppChangelog.colorOf(
                                          v.entries[j].type))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: MiuixText(v.entries[j].text,
                                      fontSize: 13.5, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
