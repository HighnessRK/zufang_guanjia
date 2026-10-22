import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/constants/app_changelog.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/app_widgets.dart';

/// 更新日志内容区（对标大狗记）：按版本倒序，每个版本一张卡片，
/// 条目带「新增 / 优化 / 修复」彩色标签。
///
/// 以纯内容块形式存在，直接内嵌在「关于」一级页面中展示。
class ChangelogSection extends StatelessWidget {
  const ChangelogSection({super.key});

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < AppChangelog.versions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 14),
          _versionCard(context, c, AppChangelog.versions[i]),
        ],
      ],
    );
  }

  Widget _versionCard(
      BuildContext context, MiuixColors c, ChangelogVersion v) {
    final bool current = v.version == AppConstants.appVersion;
    final int n = v.entries.length;
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
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
            ],
          ),
          const SizedBox(height: 14),
          for (int j = 0; j < n; j++)
            Padding(
              padding: EdgeInsets.only(bottom: j == n - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(AppChangelog.colorOf(v.entries[j].type))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: MiuixText(v.entries[j].type,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            Color(AppChangelog.colorOf(v.entries[j].type))),
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
    );
  }
}
