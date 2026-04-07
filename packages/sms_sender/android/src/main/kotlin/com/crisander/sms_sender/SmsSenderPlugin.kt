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
        val SENT = "SMS_SENT_${System.currentTimeMillis()}"
        val sentPI = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            android.app.PendingIntent.getBroadcast(context, 0, android.content.Intent(SENT), android.app.PendingIntent.FLAG_IMMUTABLE)
        } else {
            android.app.PendingIntent.getBroadcast(context, 0, android.content.Intent(SENT), 0)
        }

        val smsStatusReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(arg0: android.content.Context?, arg1: android.content.Intent?) {
                context?.unregisterReceiver(this)
                when (resultCode) {
                    android.app.Activity.RESULT_OK -> {
                        result.success("SMS Sent")
                    }
                    android.telephony.SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                        result.error("FAILED", "Carrier Error: Generic Failure (Check Balance/SIM)", null)
                    }
                    android.telephony.SmsManager.RESULT_ERROR_NO_SERVICE -> {
                        result.error("FAILED", "Carrier Error: No Service", null)
                    }
                    android.telephony.SmsManager.RESULT_ERROR_RADIO_OFF -> {
                        result.error("FAILED", "Carrier Error: Radio Off", null)
                    }
                    else -> {
                        result.error("FAILED", "Carrier Error: Code $resultCode", null)
                    }
                }
            }
        }
        
        context?.registerReceiver(smsStatusReceiver, android.content.IntentFilter(SENT))

        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                context?.getSystemService(SmsManager::class.java)!!
            } else {
                SmsManager.getDefault()
            }

            if (message.length > 160) {
                val parts = smsManager.divideMessage(message)
                val sentIntents = java.util.ArrayList<android.app.PendingIntent>()
                for (i in parts.indices) {
                    sentIntents.add(sentPI)
                }
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, sentPI, null)
            }
        } catch (e: Exception) {
            try {
                context?.unregisterReceiver(smsStatusReceiver)
            } catch (ignore: Exception) {}
            result.error("FAILED", "Plugin Error: ${e.message}", null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
