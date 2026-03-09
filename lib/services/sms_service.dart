import 'package:flutter/services.dart';
import 'logging_service.dart';

class SmsService {
  static const MethodChannel _channel = MethodChannel('com.crisander.sms_gateway/sms');

  static Future<bool> sendSms(String phone, String message) async {
    try {
      final String result = await _channel.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
      await LoggingService.addLog('SMS sent to $phone: $message');
      return true;
    } on PlatformException catch (e) {
      await LoggingService.addLog('Failed to send SMS to $phone: ${e.message}', isError: true);
      return false;
    } catch (e) {
      await LoggingService.addLog('Error sending SMS to $phone: $e', isError: true);
      return false;
    }
  }
}
