package com.example.diary_app

import android.os.Handler
import android.os.Looper
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 指纹 / 生物识别，复用**系统已录入**的指纹。
 *
 * 为什么不用 `local_auth` 插件：
 *   本机 agent 环境跑不了 `flutter pub get`（pub cache 里也没有该包），
 *   还要手工补 `.flutter-plugins-dependencies` 与 `GeneratedPluginRegistrant.java`
 *   —— 项目之前就踩过 `MissingPluginException`。
 *   而本项目本来就有 SharingPlugin / MediaStorePlugin 两个 MethodChannel，
 *   在原生侧多写这几十行，比引一个插件风险小得多。
 *
 * 为什么用 `BIOMETRIC_WEAK or DEVICE_CREDENTIAL`：
 *   允许「指纹 + 设备 PIN/图案/密码」两种。用户只想要指纹，但一旦指纹
 *   连续失败被锁定（LOCKOUT），还有设备凭据这条路，不会把用户彻底挡在门外。
 *   设备本身没有任何生物识别时，也能退化成设备凭据验证。
 *
 * ⚠️ 这里只做**门禁**，不参与密钥派生 —— 日记的 `pinHash` 仍是唯一密钥。
 */
class BiometricPlugin(
    private val activity: FragmentActivity,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> handleIsAvailable(result)
            "authenticate" -> handleAuthenticate(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * 返回 `{ available, enrolled, reason }`。
     * - available：现在能不能弹验证框（含设备凭据这条退路）
     * - enrolled：系统里是否**确实录入了指纹/人脸**（决定设置页开关是否置灰）
     */
    private fun handleIsAvailable(result: MethodChannel.Result) {
        mainHandler.post {
            try {
                val manager = BiometricManager.from(activity)
                val combined = manager.canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)
                val bioOnly = manager.canAuthenticate(BIOMETRIC_WEAK)

                val available = combined == BiometricManager.BIOMETRIC_SUCCESS
                val enrolled = bioOnly == BiometricManager.BIOMETRIC_SUCCESS

                result.success(
                    mapOf(
                        "available" to available,
                        "enrolled" to enrolled,
                        "reason" to describe(if (available) combined else bioOnly)
                    )
                )
            } catch (t: Throwable) {
                // 有些 ROM 的 BiometricManager 会直接抛异常（而非返回错误码）
                result.success(
                    mapOf(
                        "available" to false,
                        "enrolled" to false,
                        "reason" to (t.message ?: "生物识别不可用")
                    )
                )
            }
        }
    }

    private fun handleAuthenticate(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: "验证身份"
        val subtitle = call.argument<String>("subtitle") ?: ""
        val negativeText = call.argument<String>("negativeText") ?: "取消"

        mainHandler.post {
            // result 只能回调一次：取消 / 失败 / 成功 三条路都可能触发，
            // 用 AtomicBoolean 兜底，否则会 "Reply already submitted"。
            val replied = AtomicBoolean(false)

            fun replyOnce(payload: Map<String, Any?>) {
                if (replied.compareAndSet(false, true)) {
                    result.success(payload)
                }
            }

            try {
                val manager = BiometricManager.from(activity)
                var authenticators = BIOMETRIC_WEAK or DEVICE_CREDENTIAL
                var can = manager.canAuthenticate(authenticators)
                if (can == BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED) {
                    // 老系统 / 该组合不被支持 → 退回纯生物识别
                    authenticators = BIOMETRIC_WEAK
                    can = manager.canAuthenticate(authenticators)
                }

                if (can != BiometricManager.BIOMETRIC_SUCCESS) {
                    replyOnce(
                        mapOf(
                            "success" to false,
                            "errorCode" to "UNAVAILABLE",
                            "errorMessage" to describe(can)
                        )
                    )
                    return@post
                }

                val executor = ContextCompat.getMainExecutor(activity)
                val prompt = BiometricPrompt(
                    activity,
                    executor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(
                            authResult: BiometricPrompt.AuthenticationResult
                        ) {
                            replyOnce(
                                mapOf(
                                    "success" to true,
                                    "errorCode" to null,
                                    "errorMessage" to null
                                )
                            )
                        }

                        override fun onAuthenticationError(code: Int, msg: CharSequence) {
                            replyOnce(
                                mapOf(
                                    "success" to false,
                                    "errorCode" to codeName(code),
                                    "errorMessage" to msg.toString()
                                )
                            )
                        }

                        override fun onAuthenticationFailed() {
                            // 单次指纹不匹配：**不要**回调，系统会自己让用户重试
                        }
                    }
                )

                val builder = BiometricPrompt.PromptInfo.Builder()
                    .setTitle(title)
                    .setAllowedAuthenticators(authenticators)
                if (subtitle.isNotEmpty()) builder.setSubtitle(subtitle)
                // 用 DEVICE_CREDENTIAL 时系统**不允许**再设 negativeButtonText，
                // 设了会直接抛 IllegalArgumentException。
                val usesDeviceCredential =
                    (authenticators and DEVICE_CREDENTIAL) != 0
                if (!usesDeviceCredential && negativeText.isNotEmpty()) {
                    builder.setNegativeButtonText(negativeText)
                }

                prompt.authenticate(builder.build())
            } catch (t: Throwable) {
                replyOnce(
                    mapOf(
                        "success" to false,
                        "errorCode" to "PLUGIN_ERROR",
                        "errorMessage" to (t.message ?: t.toString())
                    )
                )
            }
        }
    }

    private fun codeName(code: Int): String = when (code) {
        BiometricPrompt.ERROR_USER_CANCELED -> "USER_CANCELED"
        BiometricPrompt.ERROR_NEGATIVE_BUTTON -> "NEGATIVE_BUTTON"
        BiometricPrompt.ERROR_CANCELED -> "CANCELED"
        BiometricPrompt.ERROR_LOCKOUT -> "LOCKOUT"
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "LOCKOUT_PERMANENT"
        BiometricPrompt.ERROR_NO_BIOMETRICS -> "NO_BIOMETRICS"
        BiometricPrompt.ERROR_HW_NOT_PRESENT -> "HW_NOT_PRESENT"
        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "HW_UNAVAILABLE"
        BiometricPrompt.ERROR_TIMEOUT -> "TIMEOUT"
        BiometricPrompt.ERROR_UNABLE_TO_PROCESS -> "UNABLE_TO_PROCESS"
        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL -> "NO_DEVICE_CREDENTIAL"
        else -> "ERROR_$code"
    }

    private fun describe(code: Int): String = when (code) {
        BiometricManager.BIOMETRIC_SUCCESS -> "可用"
        BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "此设备不支持生物识别"
        BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "生物识别硬件暂时不可用"
        BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "尚未在系统中录入指纹"
        BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "需要安全更新后才能使用"
        BiometricManager.BIOMETRIC_ERROR_UNSUPPORTED -> "当前系统版本不支持该验证方式"
        BiometricManager.BIOMETRIC_STATUS_UNKNOWN -> "无法确定生物识别状态"
        else -> "生物识别不可用（code=$code）"
    }
}
