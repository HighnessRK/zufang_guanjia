# 租房管家（zufang_guanjia）

> 纯本地离线 · 个人房东房源 / 租户 / 房租 / 水电费管理安卓 APP
> UI 全程对标小米澎湃OS HyperOS 原生风格 · 液态玻璃磨砂底部导航

---

## 一、功能特性

| 模块 | 功能 |
|---|---|
| **水电抄录** | 选房间 → 录本期电表/水表 → 自动算用量/电费/水费/合计 → 一键保存 + 标记收缴 |
| **房间管理** | 新增/编辑/删除房间；租金、房型、押金、钥匙、大门磁卡、家电、入退租日期 |
| **租户管理** | 租户与房间绑定，姓名/电话/身份证，数据联动展示 |
| **缴费统计** | 月度收支报表、欠费累计、结清率、各房间欠费明细 |
| **到期提醒** | 房租未缴、水电未收、租期到期三类提醒，提前天数可自定义 |
| **三端通知** | APP 内置通知中心 + Android 系统通知 + 澎湃OS 焦点通知 |
| **数据管理** | 本地备份/恢复（zip 含 SQLite + info.gwt），全程不联网 |

## 二、技术栈

| 项目 | 选型 | 协议 |
|---|---|---|
| 框架 | Flutter 3.24+（稳定版） | BSD-3 |
| UI 组件库 | `flutter_miuix`（miuix 的 Flutter 1:1 移植版） | Apache-2.0 |
| 底部导航 | `liquid_glass_bottom_nav`（液态玻璃磨砂） | MIT |
| 数据库 | `sqflite`（SQLite） | MIT |
| 路径 | `path_provider` / `path` | MIT |
| 存储 | SQLite（rental.db） + 文本配置（info.gwt） | — |
| CI | CODING 云原生构建 `.coding-ci.yml` | 免费 |

> 全部依赖均为开源免费，无任何付费资源；数据 100% 保存在本机，不联网、不上传。

## 三、项目结构

```
zufang_guanjia/
├── .coding-ci.yml              # CODING 免费流水线（自动构建+签名+归档）
├── info.gwt                    # 全局配置文件模板（水费/电费单价、提醒天数）
├── pubspec.yaml
├── assets/info.gwt             # 内置默认配置（首次启动释放到应用私有目录）
├── docs/
│   ├── 01_新手部署文档.md      # 从零到 APK 的完整步骤
│   ├── 02_Keystore生成与CODING配置.md
│   └── 03_数据库与业务逻辑说明.md
├── android/
│   ├── app/build.gradle.kts    # 签名配置（key.properties）
│   ├── ensure_gradle_wrapper.sh
│   └── app/src/main/kotlin/com/zufang/guanjia/
│       ├── MainActivity.kt              # 原生能力桥接
│       ├── notify/NotificationHelper.kt # 通知渠道与发送
│       ├── notify/FocusNotificationHelper.kt # 澎湃OS 焦点通知
│       └── service/ReminderForegroundService.kt # 后台常驻服务
└── lib/
    ├── main.dart                # 入口：初始化配置/库/账期引擎/通知
    ├── app.dart                 # miuix 主题接入
    ├── core/
    │   ├── config/app_config.dart   # info.gwt 读写
    │   ├── constants/…              # 常量
    │   └── utils/                   # 水电费计算、日期工具
    ├── data/
    │   ├── db/database_helper.dart  # 建库建表
    │   ├── models/                  # Room / Person / Payment / NoticeItem
    │   └── repository/              # 增删改查 + 账期引擎 + 统计
    ├── services/                    # 通知调度 / 提醒引擎 / 备份恢复 / 原生桥接
    └── ui/
        ├── shell/app_shell.dart     # 液态玻璃底部导航外壳
        ├── home/  rooms/  meter/  settings/  stat/  notification/
        └── widgets/app_widgets.dart # 全局复用组件
```

## 四、快速开始

```bash
# 1. 安装依赖
flutter pub get

# 2. 本地调试运行
flutter run

# 3. 本地打包（未配置签名时为 debug 签名）
flutter build apk --release

# 4. 配置正式签名后打包
bash android/ensure_gradle_wrapper.sh
flutter build apk --release
```

详细步骤见 **docs/01_新手部署文档.md**。

## 五、核心计算公式

```
用电量 = 本期电表 − 上期电表（负数按 0）
用水量 = 本期水表 − 上期水表（负数按 0）
电费   = 用电量 × 电费单价（info.gwt: elec_price，默认 1.2 元/度）
水费   = 用水量 × 水费单价（info.gwt: water_price，默认 6 元/吨）
水电费合计 = 电费 + 水费
```

月度账期引擎：每月首次打开 APP 自动结转上期流水、把本期读数滚动为上期、清零本期费用。

## 六、开源声明

- `flutter_miuix` — Apache License 2.0（miuix 的社区 Flutter 移植版，与小米公司无关）
- `liquid_glass_bottom_nav` — MIT
- `sqflite` / `path_provider` / `path` — MIT

「MIUI」「HyperOS」「miuix」等名称归各自权利人所有，此处仅用于描述设计语言。
