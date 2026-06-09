package com.example.diary_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class SharingPlugin(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    private var sharedFilePath: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getSharedFile" -> result.success(sharedFilePath)
            "clearSharedFile" -> {
                sharedFilePath = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun handleIntent(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND) return false
        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return false

        val copiedPath = copyUriToFile(uri)
        if (copiedPath != null) {
            sharedFilePath = copiedPath
            channel.invokeMethod("onSharedFile", copiedPath)
            return true
        }
        return false
    }

    private fun copyUriToFile(uri: Uri): String? {
        try {
            val fileName = getFileName(uri) ?: "shared_file"
            val tempDir = File(context.cacheDir, "shared_files")
            if (!tempDir.exists()) tempDir.mkdirs()
            val destFile = File(tempDir, fileName)

            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            return destFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun getFileName(uri: Uri): String? {
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && nameIndex >= 0) {
                return cursor.getString(nameIndex)
            }
        }
        return uri.lastPathSegment
    }
}
