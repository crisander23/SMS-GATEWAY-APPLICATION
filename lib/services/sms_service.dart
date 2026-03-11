import 'package:sms_sender/sms_sender.dart';
import 'logging_service.dart';

class SmsService {
  static Future<bool> sendSms(String phone, String message) async {
    try {
      final result = await SmsSender.sendSms(phone, message);
      if (result == 'SMS Sent') {
        await LoggingService.addLog('SMS sent to $phone: $message');
        return true;
      } else {
        await LoggingService.addLog('Failed to send SMS to $phone: $result', isError: true);
        return false;
      }
    } catch (e) {
      await LoggingService.addLog('Error sending SMS to $phone: $e', isError: true);
      return false;
    }
  }
}
