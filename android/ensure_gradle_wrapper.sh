#!/usr/bin/env bash
#===============================================================================
# ensure_gradle_wrapper.sh
# 生成 / 补齐 Gradle Wrapper（gradlew / gradlew.bat / gradle-wrapper.jar）
#
# 为什么需要这一步：
#   Gradle Wrapper 的 gradle-wrapper.jar 是二进制文件，不适合放进文本仓库，
#   所以仓库里只保留 gradle-wrapper.properties。
#
# 设计原则：
#   1. 尽一切可能补齐 wrapper（多路下载 + 重试 + 断点续传）；
#   2. 实在补不齐也不会让流水线失败 —— Flutter 3.x 的 `flutter build`
#      在检测不到 wrapper 时会自行引导生成，这里只要「尽力而为」即可。
#
# 用法：
#   bash android/ensure_gradle_wrapper.sh
#===============================================================================

GRADLE_VERSION="${GRADLE_VERSION:-8.4}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 0

WRAPPER_DIR="gradle/wrapper"
mkdir -p "$WRAPPER_DIR"

need_jar=0
need_scripts=0
[ -f "$WRAPPER_DIR/gradle-wrapper.jar" ] || need_jar=1
[ -f "gradlew" ] || need_scripts=1

if [ "$need_jar" -eq 0 ] && [ "$need_scripts" -eq 0 ]; then
  echo "✅ Gradle Wrapper 已存在，跳过生成"
  exit 0
fi

echo "==> 正在补齐 Gradle ${GRADLE_VERSION} Wrapper ..."

#-------------------------------------------------------------------------------
# 通用下载函数：多地址 + 重试 + 断点续传
#-------------------------------------------------------------------------------
download() {
  # $1=目标文件  $2...=候选 URL
  local target="$1"; shift
  local url
  for url in "$@"; do
    echo "    尝试: $url"
    if curl -fL --retry 5 --retry-delay 2 --retry-all-errors -C - \
         --connect-timeout 20 --max-time 600 -o "$target" "$url"; then
      # 空文件视为失败
      if [ -s "$target" ]; then
        echo "    ✅ 下载成功"
        return 0
      fi
    fi
    rm -f "$target"
  done
  return 1
}

OK=1

#-------------------------------------------------------------------------------
# 方式一：下载官方 wrapper 三件套（最快）
#-------------------------------------------------------------------------------
if [ "$need_jar" -eq 1 ]; then
  download "$WRAPPER_DIR/gradle-wrapper.jar" \
    "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar" \
    "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar" \
    || OK=0
fi

if [ "$need_scripts" -eq 1 ]; then
  download "gradlew" \
    "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}/gradlew" \
    "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradlew" \
    || OK=0
  download "gradlew.bat" \
    "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}/gradlew.bat" \
    "https://github.com/gradle/gradle/raw/v${GRADLE_VERSION}/gradlew.bat" \
    || true
fi

#-------------------------------------------------------------------------------
# 方式二：下载官方发行包，执行 `gradle wrapper` 生成
#-------------------------------------------------------------------------------
if [ ! -f "$WRAPPER_DIR/gradle-wrapper.jar" ]; then
  echo "==> 直接下载 wrapper 失败，改用 Gradle 发行包生成 ..."
  TMP_DIR="${TMPDIR:-/tmp}/gradle-dist"
  mkdir -p "$TMP_DIR"

  if [ ! -x "$TMP_DIR/gradle-${GRADLE_VERSION}/bin/gradle" ]; then
    download "$TMP_DIR/gradle.zip" \
      "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
      "https://mirrors.cloud.tencent.com/gradle/gradle-${GRADLE_VERSION}-bin.zip" \
      "https://mirrors.aliyun.com/macports/distfiles/gradle/gradle-${GRADLE_VERSION}-bin.zip" \
      || OK=0
    if [ -f "$TMP_DIR/gradle.zip" ]; then
      unzip -q -o "$TMP_DIR/gradle.zip" -d "$TMP_DIR" || OK=0
    fi
  fi

  if [ -x "$TMP_DIR/gradle-${GRADLE_VERSION}/bin/gradle" ]; then
    echo "==> 执行 gradle wrapper 生成 ..."
    "$TMP_DIR/gradle-${GRADLE_VERSION}/bin/gradle" wrapper \
      --gradle-version "$GRADLE_VERSION" || OK=0
  fi
fi

chmod +x gradlew 2>/dev/null || true

#-------------------------------------------------------------------------------
# 结果判定：补齐了就成功；没补齐也不阻断流程（交给 flutter build 自举）
#-------------------------------------------------------------------------------
if [ -f "$WRAPPER_DIR/gradle-wrapper.jar" ] && [ -f "gradlew" ]; then
  echo "✅ Gradle Wrapper 就绪"
  exit 0
fi

echo "⚠️  Gradle Wrapper 未能自动补齐（网络原因），已跳过。"
echo "   Flutter 构建时会自动引导生成，不影响后续流程。"
exit 0
