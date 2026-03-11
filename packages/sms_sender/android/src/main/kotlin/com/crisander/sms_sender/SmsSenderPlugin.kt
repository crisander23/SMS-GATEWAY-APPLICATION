package com.crisander.sms_sender

import android.content.Context
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SmsSenderPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel : MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.crisander.sms_gateway/sms")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
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

    private fun sendSMS(phone: String, message: String, result: Result) {
        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                context?.getSystemService(SmsManager::class.java)!!
            } else {
                SmsManager.getDefault()
            }
            smsManager.sendTextMessage(phone, null, message, null, null)
            result.success("SMS Sent")
        } catch (e: Exception) {
            result.error("FAILED", "Failed to send SMS: ${e.message}", null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
