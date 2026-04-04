package com.example.droid_bridge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "droid_bridge/platform"
    private val screenCaptureRequestCode = 3012
    private lateinit var channel: MethodChannel
    private var capturePermissionGranted = false
    private var pendingMirroringResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPlatformSnapshot" -> result.success(
                    mapOf(
                        "platformName" to "Android Companion",
                        "platformRole" to "phone",
                        "deviceName" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "isNativeChannelAvailable" to true,
                        "capabilities" to listOf(
                            "Local device profile",
                            "MediaProjection-ready shell",
                            "Share target integration",
                        ),
                    ),
                )
                "getMirroringStatus" -> result.success(
                    mirroringStatusMap(
                        message = if (capturePermissionGranted) {
                            "Android capture permission is ready. The transport layer is the next native step."
                        } else {
                            "Request Android screen capture permission to prepare for mirroring."
                        },
                    ),
                )
                "requestScreenCapturePermission" -> requestScreenCapturePermission(result)
                "stopMirroringSession" -> {
                    capturePermissionGranted = false
                    result.success(
                        mirroringStatusMap(
                            message = "Android mirroring state reset.",
                        ),
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun requestScreenCapturePermission(result: MethodChannel.Result) {
        val manager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        pendingMirroringResult = result
        val captureIntent: Intent = manager.createScreenCaptureIntent()
        startActivityForResult(captureIntent, screenCaptureRequestCode)
    }

    private fun mirroringStatusMap(message: String): Map<String, Any> {
        return mapOf(
            "supported" to true,
            "mode" to "android_sender",
            "isActive" to false,
            "permissionGranted" to capturePermissionGranted,
            "message" to message,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != screenCaptureRequestCode) {
            return
        }

        val granted = resultCode == Activity.RESULT_OK
        capturePermissionGranted = granted
        val result = pendingMirroringResult
        pendingMirroringResult = null
        result?.success(
            mirroringStatusMap(
                message = if (granted) {
                    "Screen capture permission granted on Android."
                } else {
                    "Screen capture permission was canceled."
                },
            ),
        )
    }
}
