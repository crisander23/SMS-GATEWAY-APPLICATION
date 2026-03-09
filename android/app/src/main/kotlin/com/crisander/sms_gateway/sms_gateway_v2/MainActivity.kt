package com.crisander.sms_gateway.sms_gateway_v2

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.crisander.sms_gateway/sms"
    private val NOTIFICATION_CHANNEL_ID = "sms_gateway_service"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "SMS Gateway Service"
            val descriptionText = "Notifications for SMS Gateway background service"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "sendSMS") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                if (phone != null && message != null) {
                    sendSMS(phone, message, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone or message is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendSMS(phone: String, message: String, result: MethodChannel.Result) {
        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                this.getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }
            smsManager.sendTextMessage(phone, null, message, null, null)
            result.success("SMS Sent")
        } catch (e: Exception) {
            result.error("FAILED", "Failed to send SMS: ${e.message}", null)
        }
    }
}
