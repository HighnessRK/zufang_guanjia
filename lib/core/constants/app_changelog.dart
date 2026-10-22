/// 应用内更新日志数据（本地内置）。
///
/// 「更新日志」页按版本倒序展示；发新版本时在此追加一条 [ChangelogVersion]，
/// 并把该版本的变化按 type='新增' / '优化' / '修复' 录入条目。
class ChangelogEntry {
  const ChangelogEntry(this.type, this.text);

  /// 条目类型：新增 / 优化 / 修复
  final String type;

  final String text;
}

class ChangelogVersion {
  const ChangelogVersion(this.version, this.date, this.entries);

  /// 语义化版本号（不带 v 前缀），如 1.0.0
  final String version;

  /// 发布日期 yyyy-MM-dd
  final String date;

  final List<ChangelogEntry> entries;
}

class AppChangelog {
  AppChangelog._();

  /// 全部版本（倒序：最新在最前）
  static const List<ChangelogVersion> versions = <ChangelogVersion>[
    ChangelogVersion('1.0.5', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('新增', '底部导航新增「收款」Tab：房租 / 水费 / 电费一处收齐，无需逐间进入详情'),
      ChangelogEntry('新增', '房型下拉选择（店面 / 单间 / 一室一厅 / 两室一厅 / 其他可自定义）'),
      ChangelogEntry('优化', '房间管理按楼层分组，楼层可折叠 / 展开，长列表更快定位'),
      ChangelogEntry('优化', '房间编辑表单标签常驻在输入框左侧，输入内容后含义不再丢失'),
      ChangelogEntry('优化', '房租金额统一按设置的缴费周期口径显示（年付显示年总额）'),
      ChangelogEntry('优化', '日期选择器改为液态玻璃 + 极光 + 澎湃OS 月历样式，替换系统默认弹窗'),
    ]),
    ChangelogVersion('1.0.4', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('修复', '「关于」页「更新」卡片顶部多余的细分隔线'),
      ChangelogEntry('修复', '应用内更新源 GitHub 仓库地址修正，检查更新可正常连通'),
      ChangelogEntry('优化', '页面切换动画提速，去除切换时的黑闪（底衬改为随主题同色）'),
    ]),
    ChangelogVersion('1.0.2', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('优化', '「关于」页应用图标与桌面启动图标保持一致（深蓝底白色房子）'),
      ChangelogEntry('优化', '更新弹窗适配深色模式，更新内容去除 Markdown 符号并按「新增 / 优化 / 修复」彩色标签展示'),
      ChangelogEntry('优化', '更新下载体验：弹窗内显示进度条与百分比，下载完成后出现「安装」按钮，通知栏同步进度'),
      ChangelogEntry('新增', '设置 · 外观新增「预测手势返回」开关（默认关闭）'),
      ChangelogEntry('优化', '更新日志直接在「关于」页展示，无需进入二级页面'),
      ChangelogEntry('优化', '更新提醒文案精简'),
    ]),
    ChangelogVersion('1.0.1', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('优化', '「关于」页应用图标与桌面启动图标保持一致（深蓝底白色房子）'),
    ]),
    ChangelogVersion('1.0.0', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('新增', '极光渐变主题与液态玻璃高级材质（可切换高斯模糊）'),
      ChangelogEntry('新增', '悬浮液态玻璃底部导航（大狗记风格紧凑胶囊）'),
      ChangelogEntry('新增', '房间管理：新增 / 编辑 / 删除，按楼层分布浏览'),
      ChangelogEntry('新增', '多租户支持：一房多租户、主租户标记与一键切换'),
      ChangelogEntry('新增', '租户电话一键拨号与复制'),
      ChangelogEntry('新增', '身份证跟随租户管理（选填）'),
      ChangelogEntry('新增', '房间资产登记：钥匙、大门磁卡与配套家电'),
      ChangelogEntry('新增', '租约周期收缴：年付 / 半年付 / 季付 / 月付自由设置'),
      ChangelogEntry('新增', '智能账单：押金、水电、违约金与其它费用并账'),
      ChangelogEntry('新增', '缴费历史与收据明细'),
      ChangelogEntry('新增', '全楼层统一收水 / 收电日历（收缴日期与间隔可设）'),
      ChangelogEntry('新增', '电费智能周期：夏季月付、其余季节季付'),
      ChangelogEntry('新增', '水电抄表：水表 / 电表分开台账，整层批量录入'),
      ChangelogEntry('新增', '大模型拍照识别水电表读数（OpenAI 兼容接口）'),
      ChangelogEntry('新增', '首页资产总览：应收 / 实收 / 押金统计与待收联动'),
      ChangelogEntry('新增', '租期到期提醒与未缴费提醒（提前天数可设）'),
      ChangelogEntry('新增', '系统通知与澎湃 OS 焦点通知 / 超级岛'),
      ChangelogEntry('新增', '应用内通知中心（已读标记）'),
      ChangelogEntry('新增', '数据一键备份与恢复'),
      ChangelogEntry('新增', '数据统计页'),
      ChangelogEntry('新增', '应用内更新：GitHub / Gitee 双下载源与自动检查更新'),
      ChangelogEntry('新增', '版本更新日志页'),
      ChangelogEntry('新增', '全中文本地化（日期选择器等）'),
    ]),
  ];

  /// 条目类型对应的主题色（ARGB）
  static int colorOf(String type) {
    switch (type) {
      case '修复':
        return 0xFFFF9500;
      case '优化':
        return 0xFF3478F6;
    }
    return 0xFF34C759; // 新增
  }
}
