package com.example.diary_app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * ⚠️ 基类是 **FlutterFragmentActivity**，不是 FlutterActivity。
 *
 * 原因：指纹验证用 `androidx.biometric.BiometricPrompt`，
 * 它的构造函数要求一个 `FragmentActivity`。
 * `FlutterFragmentActivity` 继承自 `FragmentActivity`，
 * 同时仍然提供 `configureFlutterEngine` —— 下面两个 MethodChannel 不受影响。
 */
class MainActivity : FlutterFragmentActivity() {
    private var sharingPlugin: SharingPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val sharingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.diary_app/sharing")
        sharingPlugin = SharingPlugin(this, sharingChannel)
        // 处理冷启动时的分享 intent
        sharingPlugin!!.handleIntent(intent)

        // 保存图片到系统相册（AI 生图 / 长按保存）
        val mediaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.diary_app/media_store")
        MediaStorePlugin(this, mediaChannel)

        // 指纹 / 生物识别（复用系统已录入的指纹）
        val biometricChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.diary_app/biometric")
        BiometricPlugin(this, biometricChannel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharingPlugin?.handleIntent(intent)
    }
}
