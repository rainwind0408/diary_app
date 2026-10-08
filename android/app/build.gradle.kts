plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.diary_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.diary_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        ndk {
            // 只打包 arm64-v8a。
            //
            // 原因：sherpa_onnx 的 Android 依赖把 4 个 ABI 的预编译 .so 全带进来
            // （arm64 26MB / armeabi 19MB / x86 31MB / x86_64 30MB，合计 107MB），
            // 而 Flutter 插件默认会放行 [armeabi-v7a, arm64-v8a, x86_64] 三个。
            // 真机是 arm64，其余纯属白占体积。
            //
            // 配套：android/gradle.properties 里的 `disable-abi-filtering=true`
            // 让 Flutter 插件不再自己覆写这个列表（否则会被它 clear 掉）。
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // 日记「指纹解锁」：BiometricPrompt（原生系统指纹弹框）。
    // 走 Kotlin MethodChannel 而不是 local_auth 插件 —— 见 BiometricPlugin.kt 的注释。
    implementation("androidx.biometric:biometric:1.1.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
