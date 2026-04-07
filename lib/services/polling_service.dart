import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter/material.dart';
import 'storage_service.dart';
import 'logging_service.dart';
import 'sms_service.dart';
import '../data/api_client.dart';
import '../models/sms_job.dart';

class PollingService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'sms_gateway_service',
        initialNotificationTitle: 'SMS Gateway Running',
        initialNotificationContent: 'Polling for jobs...',
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    final storage = await StorageService.init();
    DartPluginRegistrant.ensureInitialized();
    await LoggingService.loadLogs();
    
    await LoggingService.addLog('Gateway started');

    _runPollingLoop(service, storage);
  }

  static void _runPollingLoop(ServiceInstance service, StorageService storage) async {
    bool isProcessing = false;

    while (true) {
      // Refresh config in case it changed
      final apiUrl = storage.apiUrl;
      final apiKey = storage.apiKey;
      final gatewayId = storage.gatewayId;
      final rateLimitDelay = storage.rateLimitDelay;

      if (apiUrl.isEmpty || apiKey.isEmpty || gatewayId.isEmpty) {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "SMS Gateway Error",
            content: "Configuration missing",
          );
        }
        await Future.delayed(const Duration(seconds: 10));
        continue;
      }

      final apiClient = ApiClient(
        baseUrl: apiUrl,
        apiKey: apiKey,
        gatewayId: gatewayId,
      );

      // Initial broadcast
      await _broadcastStats(service);

      final jobs = await apiClient.fetchJobs();
      int pollInterval = storage.pollInterval; // default 10

      if (jobs.isNotEmpty) {
        pollInterval = 2; // Active mode
        service.invoke('onStatsUpdated', {'isFetching': true});
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "SMS Gateway Active",
            content: "Processing ${jobs.length} jobs",
          );
        }

        for (var job in jobs) {
          await LoggingService.addLog('Processing job ${job.id} for ${job.phone}');
          
          try {
            final error = await SmsService.sendSms(job.phone, job.message);
            if (error == null) {
              await apiClient.reportComplete(job.id);
              await _incrementSentCount();
              await _broadcastStats(service);
            } else {
              // Detailed failure reported to backend
              await apiClient.reportFailure(job.id, error);
            }
          } catch (e) {
            await LoggingService.addLog('Job ${job.id} threw exception: $e', isError: true);
            await apiClient.reportFailure(job.id, e.toString());
          }

          // Rate limiting (Enforced 6-8s minimum to prevent carrier bans)
          int effectiveDelay = rateLimitDelay < 7 ? 7 : rateLimitDelay;
          await Future.delayed(Duration(seconds: effectiveDelay));
        }
        
        service.invoke('onStatsUpdated', {'isFetching': false});
      } else {
        pollInterval = 10; // Idle mode
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "SMS Gateway Online",
            content: "Waiting for jobs...",
          );
        }
      }

      await _broadcastStats(service);
      await Future.delayed(Duration(seconds: pollInterval));
    }
  }
}

Future<void> _incrementSentCount() async {
  final prefs = await SharedPreferences.getInstance();
  final String today = DateTime.now().toIso8601String().split('T')[0];
  final int current = prefs.getInt('sent_$today') ?? 0;
  await prefs.setInt('sent_$today', current + 1);
}

Future<void> _broadcastStats(ServiceInstance service) async {
  final prefs = await SharedPreferences.getInstance();
  final String today = DateTime.now().toIso8601String().split('T')[0];
  final int sentToday = prefs.getInt('sent_$today') ?? 0;
  
  service.invoke('onStatsUpdated', {
    'sentToday': sentToday,
    'lastSync': DateTime.now().toIso8601String(),
  });
}
