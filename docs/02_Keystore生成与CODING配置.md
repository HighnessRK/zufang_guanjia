# 02 · Keystore 生成与 CODING 环境变量配置

> 目标：让 CODING 流水线自动打出 **已签名的 Release 正式 APK**。

---

## 一、生成 Keystore（签名文件）

### 1.1 安装 JDK（已有可跳过）

- Windows / macOS：安装 Android Studio 自带 JDK，或到 <https://adoptium.net/> 下载 JDK 17
- Linux：`sudo apt install openjdk-17-jdk`

验证：

```bash
keytool -help
```

### 1.2 生成 key.jks

在 **任意空目录** 执行（不要放进代码仓库！）：

```bash
keytool -genkeypair \
  -v \
  -keystore key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

执行过程中会依次询问：

| 提问 | 填什么 | 示例 |
|---|---|---|
| 输入密钥库口令 | keystore 密码（记住它） | `myStorePass123` |
| 您的名字与姓氏 | 随意 | `zufang` |
| 组织单位名称 | 随意 | `personal` |
| 组织名称 | 随意 | `personal` |
| 城市 / 省份 / 国家 | 随意 | `Beijing / Beijing / CN` |
| 输入密钥口令 | 直接回车 = 与密钥库口令相同 | （回车） |

> ⚠️ **务必保存好 `key.jks` 与密码**。丢失后将无法为同一个 APP 升级签名版本。

### 1.3 Windows 用户注意

Windows 自带 JDK 的 `keytool` 生成的是 `.jks`，命令相同。若提示找不到 `keytool`，
把 JDK 的 `bin` 目录加入 `PATH`。

---

## 二、把 keystore 转成 Base64

CODING 流水线不方便传二进制文件，因此用 **Base64 文本** 通过环境变量传入。

### 2.1 Linux / macOS

```bash
base64 -w 0 key.jks > key.jks.b64
cat key.jks.b64
```

`-w 0` 表示不换行（很重要，否则还原会失败）。

### 2.2 Windows（CMD）

```cmd
certutil -encode key.jks key.b64
type key.b64
```

> ⚠️ `certutil` 生成的文件首尾各有一行 `-----BEGIN/END CERTIFICATE-----`，
> 复制到 CODING 时请 **删掉这两行**，只保留中间的 Base64 内容。

### 2.3 Windows（PowerShell）

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("key.jks")) | Set-Content -NoNewline key.b64
Get-Content key.b64
```

### 2.4 校验（可选）

```bash
base64 -d key.jks.b64 > key_check.jks
keytool -list -keystore key_check.jks
# 能列出证书信息说明转换正确
```

---

## 三、在 CODING 配置环境变量

### 3.1 入口

> CODING 项目 → 左侧「项目设置」→ 研发资源 → **环境变量** → 添加变量

### 3.2 变量清单

| 变量名 | 类型 | 值 | 说明 |
|---|---|---|---|
| `KEYSTORE_BASE64` | **私密** | `key.jks` 的 Base64 整串 | 签名文件本体 |
| `KEYSTORE_PASSWORD` | **私密** | 生成时填的密钥库口令 | |
| `KEY_PASSWORD` | **私密** | 密钥口令（与上相同则填一样的） | |
| `KEY_ALIAS` | 明文 | `upload` | 生成时 `-alias` 的值 |

> **私密变量** 一定要选「私密」，否则可能泄露。

### 3.3（可选）制品库归档变量

想让 APK 自动上传到 CODING 制品库、网页直接下载，再加：

| 变量名 | 类型 | 值 |
|---|---|---|
| `CODING_ARTIFACT_URL` | 明文 | 制品仓库的 generic 推送地址 |
| `CODING_ARTIFACT_TOKEN` | **私密** | 制品仓库访问令牌 |
| `CODING_USERNAME` | 明文 | 你的 CODING 账号邮箱 |

**获取方式：**

1. CODING 项目 → **制品管理** → 制品仓库 → 新建仓库 → 类型选 **generic**
2. 进入仓库 → 「操作指引」→ 里面给出的 `curl -T ... -u 账号:令牌 "地址"` 就是所需信息
3. 把地址填入 `CODING_ARTIFACT_URL`，令牌填入 `CODING_ARTIFACT_TOKEN`

---

## 四、在 CODING 配置签名（本地打包用）

本地打包也想用正式签名？在 `android/` 目录下新建 `key.properties`：

```properties
storePassword=myStorePass123
keyPassword=myStorePass123
keyAlias=upload
storeFile=key.jks
```

然后把 `key.jks` 复制到 `android/` 目录下，执行：

```bash
flutter build apk --release
```

> `key.properties` 与 `key.jks` **已被 `.gitignore` 排除**，不会被提交到仓库。
> 注意：CI 里生成的 `key.properties` 中 `storeFile=key.jks`，相对于 `android/` 目录，
> 与 `android/app/build.gradle.kts` 里的 `file(it)` 解析一致。

---

## 五、验证签名成功

构建完成后，在流水线日志「归档 APK 制品」阶段会打印 APK 文件名。
安装到手机后，用下面命令验证签名：

```bash
# Linux / macOS（需要 Android SDK build-tools）
$ANDROID_HOME/build-tools/34.0.0/apksigner verify --print-certs app-release.apk
```

输出里的 `Signer #1 certificate DN` 应当是你生成证书时填的信息。

---

## 六、常见问题

### Q1：流水线日志显示「未检测到 KEYSTORE_BASE64」
说明环境变量没配或名字写错。检查「项目设置 → 环境变量」里 4 个变量是否齐全。

### Q2：`Failed to load keystore` / `Cannot recover key`
密码错误。重新生成 keystore 或核对 `KEYSTORE_PASSWORD` / `KEY_PASSWORD`。

### Q3：Base64 还原后文件损坏
多半是复制时带了换行或首尾标记。Linux 用 `base64 -w 0`；Windows 用 certutil 时删掉首尾两行。

### Q4：换了电脑，APP 覆盖安装失败（签名不一致）
必须用 **同一份 key.jks** 签名才能覆盖安装。请妥善备份 key.jks 与密码。
