import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyApiUrl = 'api_url';
  static const String keyGatewayId = 'gateway_id';
  static const String keyApiKey = 'api_key';
  static const String keyPollInterval = 'poll_interval';
  static const String keyRateLimitDelay = 'rate_limit_delay';
  static const String keyAutoStart = 'auto_start';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String get apiUrl => _prefs.getString(keyApiUrl) ?? '';
  String get gatewayId => _prefs.getString(keyGatewayId) ?? '';
  String get apiKey => _prefs.getString(keyApiKey) ?? '';
  int get pollInterval => _prefs.getInt(keyPollInterval) ?? 10;
  int get rateLimitDelay => _prefs.getInt(keyRateLimitDelay) ?? 7;
  bool get autoStart => _prefs.getBool(keyAutoStart) ?? false;

  Future<void> setApiUrl(String value) => _prefs.setString(keyApiUrl, value);
  Future<void> setGatewayId(String value) => _prefs.setString(keyGatewayId, value);
  Future<void> setApiKey(String value) => _prefs.setString(keyApiKey, value);
  Future<void> setPollInterval(int value) => _prefs.setInt(keyPollInterval, value);
  Future<void> setRateLimitDelay(int value) => _prefs.setInt(keyRateLimitDelay, value);
  Future<void> setAutoStart(bool value) => _prefs.setBool(keyAutoStart, value);

  Future<void> saveConfig({
    required String apiUrl,
    required String gatewayId,
    required String apiKey,
    required int pollInterval,
    required int rateLimitDelay,
  }) async {
    await setApiUrl(apiUrl);
    await setGatewayId(gatewayId);
    await setApiKey(apiKey);
    await setPollInterval(pollInterval);
    await setRateLimitDelay(rateLimitDelay);
  }
}
