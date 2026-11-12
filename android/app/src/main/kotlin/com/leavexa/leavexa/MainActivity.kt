package com.leavexa.leavexa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val DEFAULT_NOTIFICATION_CHANNEL_ID = "leavexa_high_importance_channel"
        private const val DEFAULT_NOTIFICATION_CHANNEL_NAME = "LEAVEXA Leave Alerts"
        private const val DEFAULT_NOTIFICATION_CHANNEL_DESC =
            "Notifications for leave submissions, department reviews, approvals, and account updates."
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannel()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(DEFAULT_NOTIFICATION_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            DEFAULT_NOTIFICATION_CHANNEL_ID,
            DEFAULT_NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = DEFAULT_NOTIFICATION_CHANNEL_DESC
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.leavexa.leavexa/browser"
        ).setMethodCallHandler { call, result ->
            if (call.method == "openUrl") {
                val url = call.argument<String>("url")
                if (!url.isNullOrBlank()) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARG", "URL is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
