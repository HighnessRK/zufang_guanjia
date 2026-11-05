/// 应用内更新日志数据（本地内置）。
///
/// 「更新日志」页按版本倒序展示：**最新版本默认展开、历史版本默认折叠**，
/// 点卡片可展开 / 收起。发新版本时在此追加一条 [ChangelogVersion]。
///
/// 本地日志与 Release 使用同一份条目。
/// 只记录用户可感知的新增、修复、优化；不收录测试报告和发布元数据。
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
    ChangelogVersion('1.2.8', '2026-11-06', <ChangelogEntry>[
      ChangelogEntry('修复', '底部导航统一裁切到胶囊轮廓，消除四角虚影和选项背后的球状光晕'),
      ChangelogEntry('优化', '玻璃折射集中在外缘，保留清晰选项与一整片连续反光'),
      ChangelogEntry('修复', '直接切换系统明暗主题时，导航玻璃材质同步更新'),
      ChangelogEntry('修复', '背景光效选择后立即生效，无需重新打开应用'),
      ChangelogEntry('优化', '顶栏增强文字区域遮蔽和模糊，向正文连续渐隐，避免标题与正文重叠'),
    ]),
    ChangelogVersion('1.2.7', '2026-11-05', <ChangelogEntry>[
      ChangelogEntry('新增', '本地识别接入 Hexagon NPU，支持的骁龙设备自动加速，并提供 CPU 兼容模式'),
      ChangelogEntry('修复', '修正 NPU 运行库初始化顺序，实际引擎随识别状态更新'),
      ChangelogEntry('优化', '底部导航采用全透玻璃、曲面折射与边缘高光，修复轮廓破碎感'),
      ChangelogEntry('新增', '个性化支持八款应用图标，两行四列，可同步切换桌面与应用内图标'),
      ChangelogEntry('新增', '新增多种背景光效、深浅主题与跟随系统设置，默认跟随系统'),
      ChangelogEntry('新增', '支持动效风格、减少动效、触感反馈和全透／磨砂玻璃切换'),
      ChangelogEntry('优化', '统一识别方式、推理加速、图片来源及确认弹窗的卡片选择界面'),
      ChangelogEntry('优化', '租金报表突出实收与收款进度，分类金额右对齐，适配深浅主题'),
      ChangelogEntry('修复', '浅色导航不再透出灰色投影，导航选项增加对比保护，顶部模糊连续渐隐'),
      ChangelogEntry('优化', '切换导航时仅绘制当前页面，停用隐藏页动效，减少玻璃背景重复绘制'),
      ChangelogEntry('优化', '引擎准备移至后台，压缩原生运行库体积，并增强红色小数位过滤'),
    ]),
    ChangelogVersion('1.2.6', '2026-11-05', <ChangelogEntry>[
      ChangelogEntry('新增', '飞书增加从云端更新入口，双向同步显示上传与下载数量'),
      ChangelogEntry('修复', '识别设置显示就绪、运行和上次实际引擎，芯片使用完整商品名'),
      ChangelogEntry('优化', '区分芯片 NPU 硬件能力与当前 CPU 推理状态'),
      ChangelogEntry('优化', '统一轻提示、MCP 操作卡片和弹窗，改善字体与按钮层级'),
      ChangelogEntry('优化', '玻璃导航增强磨砂折射与边缘高光，减少背景文字重影'),
      ChangelogEntry('优化', '重新设计应用图标，桌面和关于页使用一致的玻璃房屋造型'),
    ]),
    ChangelogVersion('1.2.5', '2026-11-05', <ChangelogEntry>[
      ChangelogEntry('修复', '重新打开应用时先检查本地模型，不再把校验中的模型显示为未下载'),
      ChangelogEntry('修复', '一图多表定位失败时支持整图识别，按位置保留无法读取的表位'),
      ChangelogEntry('新增', '识别任务可后台执行并连续提交其他电表，结果保留供返回后核对'),
      ChangelogEntry('优化', '更新弹窗使用圆角渐变下载进度，突出百分比与下载大小'),
      ChangelogEntry('优化', '整理全部历史日志，仅保留新增、修复、优化和简明功能说明'),
    ]),
    ChangelogVersion('1.2.4', '2026-11-05', <ChangelogEntry>[
      ChangelogEntry('优化', 'Xiaomi-OCR-0 改用 Gitee 国内镜像，保留原模型与完整校验'),
      ChangelogEntry('修复', '下载进度按主模型和投影器总量累计，完整显示约 1.04 GB，不再只显示 40 MB 分片'),
      ChangelogEntry('优化', '下载进度采用圆角渐变条，显示百分比、累计大小和当前分片'),
      ChangelogEntry('修复', '暂停与重启保留整体进度，兼容旧版下载断点和已下载模型'),
    ]),
    ChangelogVersion('1.2.3', '2026-11-04', <ChangelogEntry>[
      ChangelogEntry('修复', '补齐关于页历史更新日志，与更新弹窗展示的发布内容一致'),
      ChangelogEntry('优化', '大模型识别统一设置卡片与按钮样式，精简文案，模型和设备说明按需展开'),
      ChangelogEntry('优化', '房间卡片将租约到期日期和剩余天数移至右上，底部独立展示押金、钥匙和磁卡'),
      ChangelogEntry('优化', '房间卡片适配窄屏和大字体，到期信息不再挤占资产栏'),
    ]),
    ChangelogVersion('1.2.2', '2026-11-03', <ChangelogEntry>[
      ChangelogEntry('新增', '白名单房间不计房租水电汇总、不提醒，保留流水与拍照识别'),
      ChangelogEntry('新增', 'Xiaomi-OCR-0 离线识图：下载、暂停恢复、校验与本地优先'),
      ChangelogEntry('新增', '整层多表自动分窗识别，五块表实拍读数全部通过'),
      ChangelogEntry('优化', '100%、110%、125% 系统字体紧凑适配，长姓名和大金额不截断'),
      ChangelogEntry('优化', '识别失败自动回退云端；仅本地模式绝不上传照片'),
      ChangelogEntry('修复', '本地输出截断或格式异常时不再填入错误读数'),
    ]),
    ChangelogVersion('1.2.1', '2026-10-27', <ChangelogEntry>[
      ChangelogEntry('修复', '修正连接参数删除后续输时旧内容回弹'),
      ChangelogEntry('优化', '飞书 App Secret 使用普通输入法，支持复制粘贴，列表摘要仍隐藏'),
      ChangelogEntry('修复', '弹窗文字选择菜单层级，补齐复制、剪切、粘贴与全选操作'),
      ChangelogEntry('优化', '租金报表采用实收总览、进度条和独立费用卡片，日期筛选更紧凑'),
      ChangelogEntry('修复', '描述性更新分组补充新增标签，保留字段名称中的下划线'),
    ]),
    ChangelogVersion('1.2.0', '2026-10-27', <ChangelogEntry>[
      ChangelogEntry('新增', '飞书多维表格同步：本地缓存、自动续期、前台定时与变更后同步'),
      ChangelogEntry('优化', '首次上传和下载前自动备份，双方修改冲突时停止覆盖'),
      ChangelogEntry('新增', '飞书连接参数随配置备份分享，公开安装包不内置个人凭证'),
      ChangelogEntry('修复', 'AI 识图请求使用 UTF-8 编码，修复中文提示词发送失败'),
      ChangelogEntry('修复', '租金报表分类明细与汇总金额保持完整单行'),
    ]),
    ChangelogVersion('1.1.6', '2026-10-27', <ChangelogEntry>[
      ChangelogEntry('新增', '收据支持自定义水印、房租收据及水费/电费分开开据'),
      ChangelogEntry('优化', '收据编号加入费用类型与流水号，账期显示完整起止日期'),
      ChangelogEntry('修复', '按未结清流水结算水电费，避免已收款仍显示待收'),
      ChangelogEntry('优化', '电表识别明确舍弃红色小数位，并增强空响应与格式校验'),
      ChangelogEntry('优化', '备份恢复更可靠，恢复后自动刷新数据'),
    ]),
    ChangelogVersion('1.1.5', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('优化', '提醒批量读取欠费，减少房间较多时的重复查询'),
      ChangelogEntry('优化', '合并并发通知刷新，避免重复计算与通知竞争'),
      ChangelogEntry('修复', '抄表刷新保护未保存读数，避免并发刷新覆盖'),
      ChangelogEntry('修复', '快速切换报表日期时旧结果不再覆盖新筛选'),
      ChangelogEntry('修复', 'API 配置删除文字后续写不再恢复旧内容'),
      ChangelogEntry('优化', '更新下载增加响应与断流超时，避免一直等待'),
    ]),
    ChangelogVersion('1.1.4', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('修复', '更新说明解析与中文发布编码校验'),
      ChangelogEntry('新增', '每次启动提醒新版本，每天早晚后台检查'),
      ChangelogEntry('优化', '更新弹窗显示包大小及已下载 / 总大小'),
      ChangelogEntry('优化', '收据增加上下期读数、单价和大写金额，去除品牌'),
      ChangelogEntry('新增', 'MCP 支持收据管理、区间报表，复制仅含地址'),
      ChangelogEntry('新增', '大模型配置自动获取模型列表，支持选择或手填'),
      ChangelogEntry('优化', '下载进度限频刷新，更新说明缓存解析'),
    ]),
    ChangelogVersion('1.1.3', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry(
          '新增',
          '电子收据：一键生成水、电收据图片，'
              '可保存相册、转发微信'),
      ChangelogEntry('新增', '收据管理：历史收据随时查看、重发、删除'),
      ChangelogEntry(
          '新增',
          '租金报表：按起止日期汇总房租、水费、电费的'
              '应收 / 实收 / 欠费'),
      ChangelogEntry(
          '优化',
          '收电日期默认跟随收水日期，'
              '需不同时可开「收电日期独立设置」'),
      ChangelogEntry(
          '优化',
          '抄表楼层按钮按「拍电 → 录电 → 录水」排序，'
              '文字完整显示'),
      ChangelogEntry('修复', '配套与资产点「+」后，数字与灰提示文字重叠'),
      ChangelogEntry('优化', '更新日志改为最新版展开、历史折叠，全部条目精简'),
    ]),
    ChangelogVersion('1.1.2', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry(
          '修复',
          '输完身份证后整页变灰白无法编辑'
              '（校验码表缺 X 档越界）'),
      ChangelogEntry('修复', '身份证校验码表错位，正常号码被误判不通过'),
      ChangelogEntry(
          '新增',
          '配套与资产改「− +」增减按钮，'
              '点按 ±1、长按连发，不用输入法'),
      ChangelogEntry(
          '新增',
          '电话、身份证实时位数格子条，'
              '错误变红、自动识别省份'),
      ChangelogEntry('新增', '抄表页新增「整层录电表」批量输入按钮'),
      ChangelogEntry('优化', '玻璃卡片共享背景快照，滚动更省电不发热'),
      ChangelogEntry('优化', 'Tab 切换改为光栅缓存合成，不再逐帧重画整页'),
      ChangelogEntry('优化', '打字不再触发整页重建，提示只在框内小块刷新'),
      ChangelogEntry('优化', '切回首页静默刷新，不再先闪转圈'),
      ChangelogEntry('修复', '编辑房间页两个输入框控制器未释放'),
    ]),
    ChangelogVersion('1.1.1', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('修复', '新增租户保存后偶发红色报错页或弹回首页'),
      ChangelogEntry('修复', '电话退格删掉的数字又被输入法写回来'),
      ChangelogEntry('修复', '年付整周期租金被按月取整少收几元'),
      ChangelogEntry('修复', '楼层按钮小屏文字溢出漏出黄黑条'),
      ChangelogEntry(
          '新增',
          '楼层自定义（1~20 层 + 自定义），'
              '房间与抄表分组口径一致'),
      ChangelogEntry(
          '新增',
          '添加 / 编辑房间即可填主租户电话与身份证，'
              '实时校验'),
      ChangelogEntry('新增', '改入住日期自动顺延到期日期一年（可关）'),
      ChangelogEntry('新增', '长按房间卡片弹快捷菜单（编辑 / 复制为新房）'),
    ]),
    ChangelogVersion('1.1.0', '2026-10-25', <ChangelogEntry>[
      ChangelogEntry(
          '新增',
          'MCP Server：同一 WiFi 下电脑可让 AI '
              '全流程操控本应用数据（设置 → MCP Server）'),
      ChangelogEntry('新增', '整层拍照按位置识别读数，自动按房号顺序填入'),
      ChangelogEntry('新增', '抄表拍照支持从相册导入图片识别'),
      ChangelogEntry(
          '新增',
          '数据管理展示存储 / 配置 / 备份路径，'
              '自动识别小米互传目录'),
      ChangelogEntry('优化', '日期选择器加月份面板，年 → 月 → 日历逐级切换'),
      ChangelogEntry('优化', '输入法弹起时隐藏底部导航，不再压住输入框'),
      ChangelogEntry('优化', '房间详情租户信息改两行布局，小屏不再被裁切'),
      ChangelogEntry('修复', '表单页用过输入法后返回键失灵直至退出应用'),
    ]),
    ChangelogVersion('1.0.6', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry(
          '新增',
          '房间详情抄表卡新增「编辑」入口，'
              '改读数实时预览费用'),
      ChangelogEntry('优化', '日期选择器点标题快速切年份，弹窗背景模糊'),
      ChangelogEntry('优化', '版本号统一显示大写 V 前缀，不显示构建号'),
      ChangelogEntry('修复', '更新弹窗彩色类型标签不显示'),
      ChangelogEntry('修复', '日期选择器连点多个日期报错'),
    ]),
    ChangelogVersion('1.0.5', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('新增', '底部「收款」Tab：房租 / 水费 / 电费一处收齐'),
      ChangelogEntry('新增', '房型下拉选择，支持自定义'),
      ChangelogEntry('优化', '房间管理按楼层分组，可折叠 / 展开'),
      ChangelogEntry('优化', '编辑表单标签常驻输入框左侧'),
      ChangelogEntry('优化', '房租金额按缴费周期口径显示'),
      ChangelogEntry('优化', '日期选择器换液态玻璃 + 澎湃OS 月历样式'),
    ]),
    ChangelogVersion('1.0.4', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('修复', '关于页「更新」卡片多余的细分隔线'),
      ChangelogEntry('修复', '更新源 GitHub 地址修正，检查更新可连通'),
      ChangelogEntry('优化', '页面切换动画提速，去除切换时的黑闪'),
    ]),
    ChangelogVersion('1.0.2', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('优化', '关于页应用图标与桌面启动图标保持一致'),
      ChangelogEntry('优化', '更新弹窗适配深色模式，内容按彩色标签展示'),
      ChangelogEntry('优化', '更新下载显示进度与百分比，完成后一键安装'),
      ChangelogEntry('新增', '外观新增「预测手势返回」开关（默认关）'),
      ChangelogEntry('优化', '更新日志直接在关于页展示'),
    ]),
    ChangelogVersion('1.0.1', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('优化', '关于页应用图标与桌面启动图标保持一致'),
    ]),
    ChangelogVersion('1.0.0', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('新增', '极光渐变主题与液态玻璃材质（可切高斯模糊）'),
      ChangelogEntry('新增', '悬浮液态玻璃底部导航'),
      ChangelogEntry('新增', '房间管理：增删改查，按楼层浏览'),
      ChangelogEntry('新增', '多租户：一房多租户、主租户标记与切换'),
      ChangelogEntry('新增', '租户电话一键拨号与复制、身份证跟随租户'),
      ChangelogEntry('新增', '房间资产登记：钥匙、磁卡、配套家电'),
      ChangelogEntry('新增', '租约周期收缴：年 / 半年 / 季 / 月付'),
      ChangelogEntry('新增', '智能账单：押金、水电、违约金并账'),
      ChangelogEntry('新增', '缴费历史与收据明细'),
      ChangelogEntry('新增', '全楼层统一收水 / 收电日历'),
      ChangelogEntry('新增', '电费智能周期：夏季月付、其余季付'),
      ChangelogEntry('新增', '水电抄表台账，整层批量录入'),
      ChangelogEntry('新增', '大模型拍照识别水电表读数'),
      ChangelogEntry('新增', '首页资产总览与待收联动'),
      ChangelogEntry('新增', '租期到期与未缴费提醒'),
      ChangelogEntry('新增', '系统通知与澎湃 OS 焦点通知 / 超级岛'),
      ChangelogEntry('新增', '应用内通知中心、数据一键备份恢复'),
      ChangelogEntry('新增', '数据统计页、应用内更新（GitHub / Gitee 双源）'),
      ChangelogEntry('新增', '版本更新日志页、全中文本地化'),
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
