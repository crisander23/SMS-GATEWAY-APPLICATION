import 'package:sms_sender/sms_sender.dart';
import 'logging_service.dart';

class SmsService {
  static Future<String?> sendSms(String phone, String message) async {
    try {
      final result = await SmsSender.sendSms(phone, message);
      if (result == 'SMS Sent') {
        await LoggingService.addLog('SMS sent to $phone: $message');
        return null; // Success
      } else {
        await LoggingService.addLog('Native failure to $phone: $result', isError: true);
        return result; // Detailed error
      }
    } catch (e) {
      await LoggingService.addLog('Exceptions sending SMS to $phone: $e', isError: true);
      return e.toString();
    }
  }
}
