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
    ChangelogVersion('1.1.2', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('修复', '添加 / 编辑房间输完身份证后整页变灰白、只剩左上角'
          '返回和底部导航能点：身份证校验位码表漏了「X」那一档，余数为 10 的'
          '合法号码会数组越界，把整个页面打成灰屏（真机每次必现）；已换成标准'
          'ISO 7064:1983 码表并加越界保护，任何输入都不会再白屏'),
      ChangelogEntry('修复', '身份证校验位码表整体错位一位，正常身份证会被误判'
          '「位数或校验位不符」；现在正确号码显示绿色「校验通过」'),
      ChangelogEntry('新增', '编辑房间「配套与资产」（钥匙、大门磁卡、空调、'
          '热水器、冰箱、洗衣机）改成「− 数值 +」增减按钮：点按 ±1、长按连发，'
          '全程不用唤起输入法'),
      ChangelogEntry('新增', '电话、身份证输入框下方新增实时位数格子条：每输一位'
          '亮一格（已填绿实线、未填灰短横），输错方向转红；身份证前两位识别出'
          '省份时会显示在格子下方（如 33 → 浙江）'),
      ChangelogEntry('新增', '抄表页每个楼层新增「整层录电表」批量输入按钮，'
          '与「整层录水表」同构，作为拍照识别之外的手输冗余入口'),
      ChangelogEntry('优化', '整页毛玻璃卡片改为共享同一次背景快照，引擎把多次'
          '高斯模糊融合成一次渲染，滚动明显更省 GPU 与发热'),
      ChangelogEntry('优化', 'Tab 切换的交叉淡出改为光栅缓存合成，切换时不再'
          '逐帧重画两整个页面（含极光背景与所有玻璃卡）'),
      ChangelogEntry('优化', '打字不再触发整页重建：实时提示全部下沉到输入框内部'
          '小块刷新，租金 / 电话 / 身份证边输入边整页 setState 的写法已移除'),
      ChangelogEntry('优化', '切回首页不再先闪一下转圈，统计与提醒改为静默刷新，'
          '减少切换界面时的卡顿与掉帧'),
      ChangelogEntry('修复', '编辑房间页「楼层」「主租户电话」两个输入框的控制器'
          '从未释放，页面每进出一次就漏一个'),
    ]),
    ChangelogVersion('1.1.1', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('修复', '新增租户填完电话点「确定」后偶发闪一下红色报错页、'
          '甚至被弹回首页：对话框关闭瞬间其内部输入框仍在使用刚释放的输入'
          '内容控制器，现已统一延后回收，保存后稳定停在当前页面'),
      ChangelogEntry('修复', '电话号码框按退格删掉的数字、紧接着再输入时又跳回来：'
          '输入法还记着删除前的「正在输入」段并按旧内容回写，现改为每次输入后'
          '即刻清除该合成段，退格不再被写回'),
      ChangelogEntry('修复', '年付 / 季付填的整周期租金被按月取整后再乘回去，'
          '7600 会算成 7596 少收几元；月租改为保留小数，应收处再四舍五入，'
          '年付即按年付金额原样入账'),
      ChangelogEntry('修复', '抄表页「整层拍电表」等楼层按钮在小屏下文字溢出、'
          '右端漏出黄黑溢出条；按钮改为弹性宽度、超长文字自动省略'),
      ChangelogEntry('新增', '楼层支持自定义：编辑房间新增「楼层」下拉框'
          '（1~20 层 + 自定义），一楼是店面这类不叫 101 的房间可填'
          '「一楼」「店面」单独成组，房间管理页与抄表页分组口径一致'),
      ChangelogEntry('新增', '添加 / 编辑房间即可填写主租户电话与身份证号，'
          '无需先进详情页补租户；两者实时校验，位数或校验位不符立即红字提醒'),
      ChangelogEntry('新增', '入住日期一改，到期日期自动算成「入住 + 1 年」；'
          '可在「设置 → 计费参数」关闭该自动计算'),
      ChangelogEntry('新增', '长按房间卡片弹出快捷菜单：编辑房间 / '
          '复制为新房（沿用楼层、房型、租金、押金、钥匙磁卡与配套家电，'
          '新房号留空待填，租户与抄表不带过去）'),
    ]),
    ChangelogVersion('1.1.0', '2026-10-25', <ChangelogEntry>[
      ChangelogEntry('新增', 'MCP Server：APP 变身 AI 助手可全流程操控的服务端——'
          '同一 WiFi 下的电脑装好 MCP 客户端即可查房间、加租户、收房租、'
          '收水电费、抄表、改计费设置、看统计、做备份；所有改动与界面操作'
          '同源，改完界面立即刷新（设置 → MCP Server）'),
      ChangelogEntry('新增', '整层抄表拍照内置「按位置读取」提示词：'
          '模型按行从左到右、行与行从上到下识别每块电表，读数自动按房号'
          '顺序填入本层输入框，不再需要手动指派房间'),
      ChangelogEntry('新增', '抄表拍照支持从系统相册导入（金标联盟照片选择器），'
          '已拍好的电表照片 / 截图可直接交给 AI 识别'),
      ChangelogEntry('新增', '设置 · 数据管理展示数据存储路径、配置文件路径、'
          '数据备份路径，并识别小米互传目录（Download/MiShare）；'
          '点「数据恢复」默认读取互传目录下最新的备份 zip'),
      ChangelogEntry('优化', '日期选择器年份面板后新增月份面板（年 → 月 → 日历），'
          '跨月选择不必逐月翻日历'),
      ChangelogEntry('优化', '编辑房间 / 录入表单时输入法弹起即隐藏底部悬浮导航，'
          '不再压住输入框'),
      ChangelogEntry('优化', '房间详情「租户信息」改为两行布局（姓名 + 主租户标签 / '
          '电话），拨打 / 复制 / 编辑 / 删除 四个操作按钮固定在右侧，'
          '小屏不再被右边缘裁切'),
      ChangelogEntry('修复', '表单页（编辑房间 / 录入抄表等）用过输入法后按返回'
          '会连续失灵、最后直接退出应用；返回链路改为恒定由框架接管，'
          '现在依次是「收起键盘 → 失焦 → 返回上一页 → 退出」'),
    ]),
    ChangelogVersion('1.0.6', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('新增', '房间详情「水电抄表」卡片新增「编辑」入口，可直接修改上期 / 本期电表、水表读数并实时预览费用'),
      ChangelogEntry('优化', '日期选择器点击顶部「xx年x月」可快速切换年份，弹窗打开时背景高斯模糊遮罩'),
      ChangelogEntry('优化', '版本号显示统一为大写 V 前缀（如 V1.0.6），不再显示构建号'),
      ChangelogEntry('修复', '应用内更新弹窗「新增 / 修复 / 优化」彩色标签不显示的问题'),
      ChangelogEntry('修复', '日期选择器连续点选多个日期时报错、选中日期不更新的问题'),
    ]),
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
