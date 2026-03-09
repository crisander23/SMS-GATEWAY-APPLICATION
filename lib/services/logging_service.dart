import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final bool isError;

  LogEntry({required this.timestamp, required this.message, this.isError = false});

  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp);

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        'isError': isError,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        timestamp: DateTime.parse(json['timestamp']),
        message: json['message'],
        isError: json['isError'] ?? false,
      );
      
  @override
  String toString() => '$formattedTime: $message';
}

class LoggingService {
  static const String keyLogs = 'gateway_logs';
  static final List<LogEntry> _logs = [];
  
  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static Future<void> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? storedLogs = prefs.getStringList(keyLogs);
    if (storedLogs != null) {
      _logs.clear();
      for (var logJson in storedLogs) {
        // Simple string parsing or JSON
        try {
          // For simplicity, we just store as "timestamp|message|isError"
          final parts = logJson.split('|');
          if (parts.length >= 2) {
            _logs.add(LogEntry(
              timestamp: DateTime.parse(parts[0]),
              message: parts[1],
              isError: parts.length > 2 ? parts[2] == 'true' : false,
            ));
          }
        } catch (e) {
          // Ignore malformed logs
        }
      }
    }
  }

  static Future<void> addLog(String message, {bool isError = false}) async {
    final entry = LogEntry(timestamp: DateTime.now(), message: message, isError: isError);
    _logs.insert(0, entry);
    if (_logs.length > 500) _logs.removeLast(); // Keep last 500 logs

    final prefs = await SharedPreferences.getInstance();
    final List<String> logStrings = _logs.map((e) => '${e.timestamp.toIso8601String()}|${e.message}|${e.isError}').toList();
    await prefs.setStringList(keyLogs, logStrings);
  }

  static Future<void> clearLogs() async {
    _logs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLogs);
  }
}
