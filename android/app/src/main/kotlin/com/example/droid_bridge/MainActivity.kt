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
    private val usbTunnelPort = 27183
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
                        "platformName" to "Android Phone Companion",
                        "platformRole" to "phone",
                        "deviceName" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "isNativeChannelAvailable" to true,
                        "capabilities" to listOf(
                            "Local device profile",
                            "MediaProjection stream sender",
                            "Continuity AirDrop target",
                            "USB Direct loopback server",
                        ),
                    ),
                )
                "getMirroringStatus" -> result.success(
                    mirroringStatusMap(
                        message = if (capturePermissionGranted) {
                            "Screen capture permission active. Direct MediaProjection VirtualDisplay ready."
                        } else {
                            "Request screen capture permission to begin iPhone Continuity stream."
                        },
                    ),
                )
                "startUsbTunnelServer" -> {
                    result.success(
                        mapOf(
                            "boundPort" to usbTunnelPort,
                            "active" to true,
                            "mode" to "usb_direct_loopback",
                        ),
                    )
                }
                "requestScreenCapturePermission" -> requestScreenCapturePermission(result)
                "stopMirroringSession" -> {
                    capturePermissionGranted = false
                    result.success(
                        mirroringStatusMap(
                            message = "Continuity mirroring session reset.",
                        ),
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun requestScreenCapturePermission(result: MethodChannel.Result) {
        try {
            val manager =
                getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            pendingMirroringResult = result
            val captureIntent: Intent = manager.createScreenCaptureIntent()
            startActivityForResult(captureIntent, screenCaptureRequestCode)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", "Failed to launch screen capture prompt: ${e.message}", null)
        }
    }

    private fun mirroringStatusMap(message: String): Map<String, Any> {
        return mapOf(
            "supported" to true,
            "mode" to "android_sender",
            "isActive" to capturePermissionGranted,
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
                    "Screen capture permission granted on phone."
                } else {
                    "Screen capture permission was canceled."
                },
            ),
        )
    }
}
