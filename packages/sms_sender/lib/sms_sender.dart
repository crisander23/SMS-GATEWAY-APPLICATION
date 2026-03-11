import 'dart:async';
import 'package:flutter/services.dart';

class SmsSender {
  static const MethodChannel _channel = MethodChannel('com.crisander.sms_gateway/sms');

  static Future<String?> sendSms(String phone, String message) async {
    try {
      final String? result = await _channel.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
      return result;
    } on PlatformException catch (e) {
      return 'Failed: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
