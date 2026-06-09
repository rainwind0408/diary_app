package com.example.diary_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sharingPlugin: SharingPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.diary_app/sharing")
        sharingPlugin = SharingPlugin(this, channel)
        // 处理冷启动时的分享 intent
        sharingPlugin!!.handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharingPlugin?.handleIntent(intent)
    }
}
