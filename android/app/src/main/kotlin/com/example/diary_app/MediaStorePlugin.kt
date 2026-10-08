package com.example.diary_app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 把应用私有目录里的图片写进系统相册。
 *
 * 为什么不用第三方插件：Android 10（API 29）起是分区存储，应用**不能**再直接往
 * `/storage/emulated/0/Pictures` 写文件；而通过 MediaStore 插入的记录属于
 * 「应用自己创建的媒体」，**不需要任何存储权限**（API 29+）。
 * 与其引一个插件再配一堆权限，不如在原生侧写这几十行。
 *
 * API 28 及以下没有分区存储，往 MediaStore 插记录需要 WRITE_EXTERNAL_STORAGE，
 * 已在 AndroidManifest 里用 `maxSdkVersion="28"` 声明。
 */
class MediaStorePlugin(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveImage" -> {
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val mimeType = call.argument<String>("mimeType") ?: "image/png"
                if (path.isNullOrEmpty()) {
                    result.error("BAD_ARGS", "缺少 path 参数", null)
                    return
                }
                try {
                    result.success(saveImage(path, name, mimeType))
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message ?: "保存失败", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** 保存成功返回相册里的 content:// uri */
    private fun saveImage(sourcePath: String, displayName: String?, mimeType: String): String {
        val source = File(sourcePath)
        if (!source.exists()) {
            throw IllegalArgumentException("文件不存在：$sourcePath")
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, sanitize(displayName ?: source.name))
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/折花日记"
                )
                // 写完之前先标记为 pending，避免相册扫到一个半截文件
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = context.contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("无法在相册中创建文件")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("无法写入相册")
        } catch (e: Exception) {
            // 写失败要把刚插入的空记录删掉，否则相册里会留一张裂图
            runCatching { resolver.delete(uri, null, null) }
            throw e
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri.toString()
    }

    /** 文件名里的路径分隔符等字符会让 MediaStore 建不出文件，统一换成下划线 */
    private fun sanitize(name: String): String {
        val cleaned = name.replace(Regex("[\\\\/:*?\"<>|\\r\\n]"), "_").trim()
        return if (cleaned.isEmpty()) "AI图片.png" else cleaned
    }
}
