val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ── 子项目 buildscript 的仓库兜底（sherpa_onnx 需要）──
// settings.gradle.kts 里的阿里云镜像只管 pluginManagement 与
// dependencyResolutionManagement，**管不到子项目自己的 buildscript 块**。
// 而插件包习惯在自己的 android/build.gradle 里钉死 AGP 版本：
//   audioplayers_android  → 7.3.1 （本机 Gradle 缓存里有，所以一直没暴露）
//   sqflite_android       → 8.11.1（同上）
//   sherpa_onnx_android_* → 7.3.0 （**缓存里只有 7.3.1，没有 7.3.0**）
// 于是 sherpa 这四个子包在**配置阶段**就要去 dl.google.com 拉 7.3.0，
// 拉不到就 `Connection refused`，整个 assembleDebug 直接失败 —— 而且报错里
// 一行 Dart 都没提到，很容易误判成代码问题。
// 把同一组阿里云镜像补到每个项目的 buildscript 上即可。
allprojects {
    buildscript {
        repositories {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
