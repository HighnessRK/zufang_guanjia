import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter 3.47 + AGP 9：不再应用 KGP（kotlin-android），改用 AGP 内置 Kotlin
    // 参见 https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers
    // Flutter Gradle 插件必须在 Android 插件之后应用
    id("dev.flutter.flutter-gradle-plugin")
}

// ====== 读取签名配置（android/key.properties），CI 中由环境变量生成 ======
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.zufang.guanjia"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zufang.guanjia"
        // 兼容绝大多数 Android 机型（Android 5.0+）
        minSdk = flutter.minSdkVersion
        // Android 16：适配 edge-to-edge 强制开启与小米超级岛 / 焦点通知
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // ====== 体积瘦身：仅打包 arm64-v8a ======
        // 金标联盟要求 64 位原生库；去掉 armeabi-v7a / x86 / x86_64
        // 各省一份 libflutter+libapp（约 -40MB 级别）。
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 有 keystore 用正式签名；没有则退回 debug 签名，保证总能出包
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // 稳定性优先（MethodChannel / 插件反射敏感），不做 R8 混淆压缩；
            // 体积主要靠「去打包字体 + 单 ABI + split-debug-info」削减
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// 内置 Kotlin 的 JVM 目标配置（与 compileOptions 的 Java 17 保持一致）
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 通知渠道 / 前台服务 / FileProvider 需要的核心库
    implementation("androidx.core:core-ktx:1.13.1")
    // 超级岛：绕过隐藏 API 限制，调用 HyperOS Aurogon 校验接口
    // （LSPosed HiddenApiBypass，Apache-2.0）
    implementation("org.lsposed.hiddenapibypass:hiddenapibypass:6.1")
}
