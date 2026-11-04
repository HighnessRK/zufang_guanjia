/// 应用内更新日志数据（本地内置）。
///
/// 「更新日志」页按版本倒序展示：**最新版本默认展开、历史版本默认折叠**，
/// 点卡片可展开 / 收起。发新版本时在此追加一条 [ChangelogVersion]。
///
/// 本地日志与 Release 使用同一份条目。
/// 历史条目保留完整发布内容；新版本发布正文由此文件导出，避免遗漏。
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
    ChangelogVersion('1.2.3', '2026-11-04', <ChangelogEntry>[
      ChangelogEntry('修复', '补齐关于页历史更新日志，与更新弹窗展示的发布内容一致'),
      ChangelogEntry('优化', '大模型识别统一设置卡片与按钮样式，精简文案，模型和设备说明按需展开'),
      ChangelogEntry('优化', '房间卡片将租约到期日期和剩余天数移至右上，底部独立展示押金、钥匙和磁卡'),
      ChangelogEntry('优化', '房间卡片适配窄屏和大字体，到期信息不再挤占资产栏'),
    ]),
    ChangelogVersion('1.2.2', '2026-11-03', <ChangelogEntry>[
      ChangelogEntry(
          '新增', '白名单房间：房租、水电不计入首页和报表汇总，也不发送提醒；流水、抄表记录、房间数和拍照识别完整保留。'),
      ChangelogEntry('新增',
          'Xiaomi-OCR-0 离线识图：可主动下载 Q8_0 模型与 F16 投影器，支持进度、暂停/恢复、取消、删除、完整 SHA-256 校验和重启后状态恢复。'),
      ChangelogEntry(
          '新增', '统一识别模式：自动 / 本地优先 / 仅云端。自动模式在本地推理或解析失败时回退云端；仅本地模式失败绝不上传照片。'),
      ChangelogEntry('新增', '整层多表识别：自动定位每块电表的示数窗，逐个裁切数字带识别，不再依赖整图一次猜五块表。'),
      ChangelogEntry('优化',
          '按系统字体 100%、110%、125% 重新适配首页、房间、抄表、收款、详情、编辑、统计、报表、收据和设置页面；长姓名、七位金额、五位水电读数不再截断。'),
      ChangelogEntry('优化', '抄表水电读数改为稳定双列，房号与费用摘要分层；顶栏、弹窗、数字键盘和玻璃导航栏避让同步修正。'),
      ChangelogEntry(
          '优化', '白名单房间设置页、离线模型管理页和 SoC 信息展示补齐；Hexagon 仅显示构建状态，不宣称 NPU 已生效。'),
      ChangelogEntry('修复', '本地识别输出被截断、数量不符或包含解释文字时不再填入错误读数，按设置回退或停止并明确提示。'),
      ChangelogEntry('修复', '红色 0.1 小数轮、表号、倍率和铭牌数字不再混入整数读数。'),
      ChangelogEntry('修复', '大字体下按钮文字溢出、日期栏缩字、收据合计被挤压等问题。'),
      ChangelogEntry('说明', '静态检查无问题，103 项自动化测试全部通过。'),
      ChangelogEntry(
          '说明', '真机独立测试包完成五块电表实拍识别，结果与人工核对值全部一致；识别过程未使用任何答案提示，照片与裁剪图不随安装包公开。'),
      ChangelogEntry('说明',
          '正式 APK：com.zufang.guanjia，版本 1.2.2+17，仅 arm64-v8a；与 1.2.1 使用同一签名证书，APK Signature Scheme v2 校验通过，可直接覆盖安装并保留数据。'),
      ChangelogEntry('说明',
          '整层五表在测试机 CPU 上约需 4–5 分钟，请预留时间；单表仍明显更快。覆盖安装保留本地账本与飞书配置。离线模型不内置在安装包内，需在设置中主动下载并校验。'),
    ]),
    ChangelogVersion('1.2.1', '2026-10-27', <ChangelogEntry>[
      ChangelogEntry('修复',
          '飞书连接参数删除后续输恢复旧字符串：标识符在输入处理阶段结束合成，禁用自动纠正与联想，不再在 onChanged 中反复改写控制器。'),
      ChangelogEntry('修复', '弹窗文字选择菜单的 Overlay 层级，支持复制、剪切、粘贴和全选；普通展示文字可长按选择复制。'),
      ChangelogEntry('修复',
          '更新弹窗描述性功能分组缺少“新增”标签；支持“新增功能 / 修复问题”等标题，并保留 rental_key 等字段的下划线。'),
      ChangelogEntry('优化', '飞书 App Secret 改用普通文本输入法，编辑时支持明文选择和粘贴，设置列表摘要仍隐藏密钥。'),
      ChangelogEntry(
          '优化', '租金报表重新设计为实收大数字总览、收款进度条和独立费用卡片；日期范围并排展示，保留完整单行金额与按账期统计口径。'),
      ChangelogEntry('说明',
          '静态检查通过，41项自动化测试通过，覆盖删除续输、中文合成、弹窗粘贴、普通 Secret 输入、更新标签与窄屏大字金额布局。'),
      ChangelogEntry('说明', '实机覆盖安装成功；Secret 普通输入、清空后续输及长按复制菜单验证通过；租金报表实机检查通过。'),
      ChangelogEntry(
          '说明', '版本 1.2.1+16。覆盖安装保留本地数据与飞书配置。编辑密钥时为明文，请注意周围环境，勿公开分享备份或密钥。'),
    ]),
    ChangelogVersion('1.2.0', '2026-10-27', <ChangelogEntry>[
      ChangelogEntry('新增', '设置新增飞书连接入口，采用与其他页面一致的玻璃分组卡片、参数编辑弹窗和统一按钮；应用密钥默认隐藏。'),
      ChangelogEntry(
          '新增', '使用 tenant_access_token 自动获取、提前刷新及失效重试。公开源码和安装包不预置个人凭证。'),
      ChangelogEntry(
          '新增', '房间、租户、缴费流水、收据及配置按行同步到多维表格，本地 rental.db 和 info.gwt 用作离线缓存。'),
      ChangelogEntry('新增', '前台每30秒同步，数据修改后延迟同步；支持首次上传与从飞书初始化缓存。'),
      ChangelogEntry('新增', '上传/下载前自动备份，同一条数据双方修改冲突时停止覆盖；飞书参数支持随备份分享。'),
      ChangelogEntry('新增',
          '云端按 rental_key / rental_json 保存完整行，既有非同步记录保留。Android 后台不保证实时，多设备同时写入不提供强一致事务。'),
      ChangelogEntry('修复',
          '电表识图请求显式使用 UTF-8 字节发送，修复中文提示导致 Contains invalid characters 错误。'),
      ChangelogEntry('修复', '原电表照片使用实际视觉 API 回归，返回整数17157（舍弃红色小数位，提示词不包含测试答案）。'),
      ChangelogEntry('修复', '租金报表分类明细与汇总金额完整单行显示，窄列时适配缩放，不再拆开数字。'),
      ChangelogEntry('说明', '静态检查通过，37项测试通过。'),
      ChangelogEntry('说明', '实机覆盖安装、70条本地数据/配置上传并逐条回读一致，原有5条记录保留。'),
      ChangelogEntry('说明', '飞书临时非计费配置下载到实机缓存通过，备份包含飞书参数。'),
      ChangelogEntry(
          '说明', '版本 1.2.0+15。覆盖安装保留数据。直连方案的备份和云端配置含密钥，请勿公开分享，并限制多维表格访问权限。'),
    ]),
    ChangelogVersion('1.1.6', '2026-10-27', <ChangelogEntry>[
      ChangelogEntry('新增', '收据支持自定义文字水印，设置后自动应用到后续新收据。'),
      ChangelogEntry('新增', '房租收据，并支持水费、电费、水电合并分别开据。'),
      ChangelogEntry('新增', '收据编号加入费用类型和三位流水号，同月多次收款可分别开据。'),
      ChangelogEntry(
          '新增', '收据账期支持自定义开始日期与结束日期，完整显示为 year-month-day — year-month-day。'),
      ChangelogEntry('修复', '水电收款改为按未结清流水事务结算，修复已收款仍显示待收。'),
      ChangelogEntry('修复', '电表视觉识别明确读取黑色整数位，自动舍弃红色小数位；改善空响应、格式和截断处理。'),
      ChangelogEntry('修复', '收据数据库升级保留历史收据，收据金额按实收并防止重复开据同一实收金额。'),
      ChangelogEntry(
          '修复', '备份前执行 WAL checkpoint；恢复前校验 SQLite 文件并使用临时文件替换，恢复后刷新页面。'),
      ChangelogEntry('修复', '数据配置文件与数据库备份继续同步大模型配置、计费参数、水印和收据数据。'),
      ChangelogEntry('修复', '版本 1.1.6+14。支持覆盖安装，保留现有数据。'),
    ]),
    ChangelogVersion('1.1.5', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('优化', '提醒计算改为批量读取未结清流水，避免按房间、费用类型反复读取整段历史。'),
      ChangelogEntry('优化', '单房欠费查询在数据库内筛选并只取最新一条，减少无关数据传输。'),
      ChangelogEntry('优化', '合并并发通知刷新，减少重复计算，避免通知更新相互竞争。'),
      ChangelogEntry('优化', '首页、房间、收款和报表增加异步结果序号保护，旧查询不再覆盖新结果。'),
      ChangelogEntry('修复', '抄表页等待读取完成后再更新控制器，页面退出或过期请求不再继续修改状态。'),
      ChangelogEntry('修复', '后台刷新不覆盖未保存的抄表读数，保存成功后正常刷新。'),
      ChangelogEntry('修复', 'API 地址、密钥和模型名删除部分文字后继续输入，不再恢复已删内容。'),
      ChangelogEntry('修复', '更新下载增加连接、响应及断流等待超时，避免网络异常时一直等待。'),
      ChangelogEntry('修复', '版本 1.1.5+13。支持覆盖安装，保留本地数据。'),
      ChangelogEntry('修复', '后台更新检查仍受 Android 省电策略影响，不能保证所有机型准点执行。'),
    ]),
    ChangelogVersion('1.1.4', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('修复', '更新说明乱码：修正发布正文编码并校验远端中文；优化 Markdown 条目解析。'),
      ChangelogEntry('修复', 'MCP 设置传入 false 无法关闭开关的问题。'),
      ChangelogEntry('修复', '旧版本跨级升级时收据数据库迁移的兼容问题。'),
      ChangelogEntry('新增', '每次启动及从后台重新打开时检查新版本并弹窗提醒。'),
      ChangelogEntry('新增', '每天 09:00、21:00 安排后台检查，发现新版本发送系统通知。'),
      ChangelogEntry('新增', '收据增加水电上期、本期读数、用量、单价和人民币大写金额，去除品牌字样。'),
      ChangelogEntry('新增', 'MCP 新增生成、查询、查看、删除收据及区间费用报表工具，共 24 个工具。'),
      ChangelogEntry('新增', '大模型 API 配置自动获取模型清单，支持从列表选择或手动填写。'),
      ChangelogEntry('优化', '更新弹窗显示安装包大小，下载进度显示已下载 MB / 总 MB。'),
      ChangelogEntry('优化', 'MCP 复制仅复制地址，不再包含 JSON 配置语法。'),
      ChangelogEntry('优化',
          '说明：后台检查受 Android 省电策略影响，可能延迟；需允许通知，强制停止应用后需重新打开。历史收据未保存的读数、单价显示“未留存”，不会借用当前读数。'),
    ]),
    ChangelogVersion('1.1.3', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('新增', '电子收据：选房选账期即生成水电费收据图片，支持保存相册与转发微信，历史收据可查看/重生成/删除'),
      ChangelogEntry(
          '新增', '租金报表：按开始-截止日期汇总房租/水费/电费，预设本月/近3月/近6月/近1年，分类型列出应收/实收/欠费'),
      ChangelogEntry('优化', '抄表整层按钮顺序改为 AI拍电表/录电表/录水表（电类相邻），文字完整显示'),
      ChangelogEntry('优化', '收电日期默认跟随收水日期，新增独立设置开关'),
      ChangelogEntry('优化', '更新日志条目精简，本次版本默认展开、历史版本折叠'),
      ChangelogEntry('修复', '配套与资产计数器数值与"0 = 无"灰提示重叠'),
      ChangelogEntry('修复', '收据用量为 0 时不再显示矛盾的"0 吨 × 单价"乘式'),
      ChangelogEntry('修复', '版本 1.1.3+11'),
    ]),
    ChangelogVersion('1.1.2', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('修复',
          '编辑/新增房间输完身份证后整页变灰白、只剩左上角返回和底部导航能点：身份证校验位码表只有 10 项、漏了「X」那一档，余数为 10 的合法号码（如 330782199001010092）会 check[10] 数组越界，而它跑在 build() 里，整个页面被 ErrorWidget 灰屏盖住（真机每次必现）。现已换成标准 ISO 7064:1983 的 11 项码表并加越界保护，任何输入都不会再白屏。'),
      ChangelogEntry('修复',
          '身份证校验位码表整体错位一位，正常身份证会被误判「位数或校验位不符」；现在正确号码显示绿色「✓ 18 位身份证校验通过（浙江）」。'),
      ChangelogEntry('修复', '编辑房间页「楼层」「主租户电话」两个输入框的控制器从未释放，页面每进出一次就漏一个。'),
      ChangelogEntry('新增',
          '配套与资产改成「− 数值 +」增减按钮（钥匙、大门磁卡、空调、热水器、冰箱、洗衣机）：点按 ±1、长按 120ms 连发、限制 099，字段只读，全程不用唤起输入法。'),
      ChangelogEntry('新增',
          '电话、身份证输入框下方新增实时位数格子条：11 / 18 格，每输一位亮一格（已填绿实线、未填灰短横），方向输错转红；身份证前两位命中省份时显示在格子下方（如 33 → 浙江）。新增租户弹窗同样生效。'),
      ChangelogEntry('新增',
          '抄表页每层新增「整层录电表」批量输入按钮：与「整层录水表」同构（闪电图标、单位「度」、上期取电表读数），作为 AI 拍表之外的手输冗余入口。'),
      ChangelogEntry('优化',
          '整页毛玻璃卡片改为 BackdropFilter.grouped 共享同一次背景快照，引擎把多次高斯模糊融合成一次渲染，滚动更省 GPU 与发热。'),
      ChangelogEntry('优化',
          'Tab 交叉淡出外包 RepaintBoundary 光栅缓存合成，切换时不再逐帧重画两整个页面（含极光背景与所有玻璃卡）。'),
      ChangelogEntry('优化',
          '打字不再触发整页重建：实时提示全部下沉到输入框内部 ValueListenableBuilder 小块刷新，租金 / 电话 / 身份证边输入边整页 setState 的写法已移除。'),
      ChangelogEntry('优化', '切回首页不再先闪一下转圈，统计与提醒改为静默刷新。'),
      ChangelogEntry('优化', '> 真机验证：6 次暴力滚动 + 5 次快速切 Tab，掉帧 0 条。'),
    ]),
    ChangelogVersion('1.1.1', '2026-10-26', <ChangelogEntry>[
      ChangelogEntry('新增',
          '租户填完电话点「确定」后偶发闪一下红色报错页、甚至被弹回首页：对话框关闭瞬间其内部输入框仍在使用刚释放的输入内容控制器，现已统一延后回收，保存后稳定停在当前页面'),
      ChangelogEntry('新增',
          '电话号码框按退格删掉的数字、紧接着再输入时又跳回来：输入法还记着删除前的「正在输入」段并按旧内容回写，现改为每次输入后即刻清除该合成段'),
      ChangelogEntry('新增',
          '年付 7600 会算成 7596：整周期租金此前被按月取整后再乘回去（633 × 12 = 7596）少收几元；月租改为保留小数、应收处再四舍五入，年付即按年付金额原样入账'),
      ChangelogEntry(
          '新增', '抄表页「整层拍电表」等楼层按钮在小屏下文字溢出、右端漏出黄黑溢出条：按钮改为弹性宽度、超长文字自动省略'),
      ChangelogEntry('新增',
          '楼层支持自定义：编辑房间新增「楼层」下拉框（120 层 + 自定义），一楼是店面这类不叫 101 的房间可填「一楼」「店面」单独成组；房间管理页与抄表页分组口径一致，排序为数字楼层升序 → 汉字序数 → 自定义文本 → 无法推导的殿后（数据库 v3 → v4，升级自动加列，无需卸载重装）'),
      ChangelogEntry('新增',
          '添加 / 编辑房间即可填写主租户电话与身份证号，无需先进详情页补租户；两者实时校验，位数或 ISO 7064 校验位不符立即红字提醒'),
      ChangelogEntry(
          '新增', '入住日期一改，到期日期自动算成「入住 + 1 年」；可在「设置 → 计费参数」关闭该自动计算（默认开启）'),
      ChangelogEntry('新增',
          '长按房间卡片弹出快捷菜单：编辑房间 / 复制为新房（沿用楼层、房型、租金、押金、钥匙磁卡与配套家电，新房号留空待填，租户与抄表不带过去）'),
      ChangelogEntry('新增',
          'SHA256：3C62F549DFDB637F0FA9EE6102DFA5C009FD194A00E99120D339859D17D58F18'),
    ]),
    ChangelogVersion('1.1.0', '2026-10-25', <ChangelogEntry>[
      ChangelogEntry('新增',
          'MCP Server：APP 变身 AI 助手可全流程操控的服务端——同一 WiFi 下的电脑装好 MCP 客户端即可查房间、加租户、收房租、收水电费、抄表、改计费设置、看统计、做备份，共 18 个工具；所有改动与界面操作同源，改完界面立即刷新（设置 → MCP Server）'),
      ChangelogEntry('新增',
          '整层抄表拍照内置「按位置读取」提示词：模型按行从左到右、行与行从上到下识别每块电表，读数自动按房号顺序填入本层输入框，不再需要手动指派房间'),
      ChangelogEntry('新增', '抄表拍照支持从系统相册导入（金标联盟照片选择器），已拍好的电表照片 / 截图可直接交给 AI 识别'),
      ChangelogEntry('新增',
          '设置 · 数据管理展示数据存储路径、配置文件路径、数据备份路径，并识别小米互传目录（Download/MiShare）；点「数据恢复」默认读取互传目录下最新的备份 zip'),
      ChangelogEntry('新增', '日期选择器年份面板后新增月份面板（年 → 月 → 日历），跨月选择不必逐月翻日历'),
      ChangelogEntry('新增', '编辑房间 / 录入表单时输入法弹起即隐藏底部悬浮导航，不再压住输入框'),
      ChangelogEntry('新增',
          '房间详情「租户信息」改为两行布局（姓名 + 主租户标签 / 电话），拨打 / 复制 / 编辑 / 删除 四个操作按钮固定在右侧，小屏不再被右边缘裁切'),
      ChangelogEntry('新增',
          '表单页（编辑房间 / 录入抄表等）用过输入法后按返回会连续失灵、最后直接退出应用；返回链路改为恒定由框架接管，现在依次是「收起键盘 → 失焦 → 返回上一页 → 退出」'),
      ChangelogEntry('新增',
          'SHA256：703F2DEEE5A65242BC712DC6D3167135AC2BA7D82BA7CA3B727ABC07B8628B77'),
    ]),
    ChangelogVersion('1.0.6', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('说明', '租房管家 V1.0.6 更新日志'),
      ChangelogEntry('说明', '【新增】'),
      ChangelogEntry('说明',
          '房间详情「水电抄表」卡片新增「编辑」入口，可直接修改上期 / 本期电表、水表读数并实时预览费用，保存后按当前单价自动重算并生成待收'),
      ChangelogEntry('说明', '【优化】'),
      ChangelogEntry('说明', '日期选择器点击顶部「xx年x月」可快速切换年份，弹窗打开时背景高斯模糊遮罩'),
      ChangelogEntry('说明', '版本号显示统一为大写 V 前缀（如 V1.0.6），不再显示构建号'),
      ChangelogEntry('说明', '【修复】'),
      ChangelogEntry('说明', '应用内更新弹窗「新增 / 修复 / 优化」彩色标签不显示的问题'),
      ChangelogEntry('说明', '日期选择器连续点选多个日期时报错、选中日期不更新的问题'),
      ChangelogEntry('说明', '附件校验'),
    ]),
    ChangelogVersion('1.0.5', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry(
          '新增', '底部导航新增「收款」Tab：房租 / 水费 / 电费一处收齐，首页待办卡片与快捷入口均可直达，无需逐间进入房间详情'),
      ChangelogEntry('新增', '房型下拉选择：店面 / 单间 / 一室一厅 / 两室一厅 / 其他（可自定义输入）'),
      ChangelogEntry('优化', '房间管理按楼层分组，楼层标题可点击折叠 / 展开，长列表更快定位'),
      ChangelogEntry('优化', '房间编辑表单标签常驻在输入框外左侧（同行左右分布），输入内容后含义不再丢失'),
      ChangelogEntry(
          '优化', '房租金额统一按「设置 · 计费参数」的缴费周期口径显示（年付显示年总额），编辑页 / 列表 / 详情口径一致'),
      ChangelogEntry('优化', '日期选择器改为液态玻璃面板 + 极光透底 + 澎湃OS 月历样式，替换系统默认弹窗'),
      ChangelogEntry('修复', '周期内修改「房租实付」与收款操作不生效、欠款状态永远不变的问题'),
      ChangelogEntry('修复', '从收款 / 抄表切回房间管理页时欠款标签不刷新的问题'),
    ]),
    ChangelogVersion('1.0.4', '2026-10-22', <ChangelogEntry>[
      ChangelogEntry('修复', '「关于」页「更新」卡片顶部多余的细分隔线'),
      ChangelogEntry('修复', '应用内更新源 GitHub 仓库地址修正，检查更新可正常连通'),
      ChangelogEntry('优化', '页面切换动画提速，去除切换时的黑闪（底衬改为随主题同色）'),
    ]),
    ChangelogVersion('1.0.2', '2026-10-21', <ChangelogEntry>[
      ChangelogEntry('优化', '「关于」页应用图标与桌面启动图标保持一致'),
      ChangelogEntry(
          '优化', '更新弹窗适配深色模式，更新内容去除 Markdown 符号并按「新增 / 优化 / 修复」彩色标签展示'),
      ChangelogEntry('优化', '更新下载体验：弹窗内显示进度条与百分比，下载完成后出现「安装」按钮，通知栏同步进度'),
      ChangelogEntry('新增', '设置 · 外观新增「预测手势返回」开关（默认关闭）'),
      ChangelogEntry('优化', '更新日志直接在「关于」页展示，无需进入二级页面'),
      ChangelogEntry('优化', '更新提醒文案精简'),
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
