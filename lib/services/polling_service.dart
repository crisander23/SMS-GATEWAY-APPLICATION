import 'dart:async';
import 'dart:ui';
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

      final jobs = await apiClient.fetchJobs();
      int pollInterval = storage.pollInterval; // default 10

      if (jobs.isNotEmpty) {
        pollInterval = 2; // Active mode
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "SMS Gateway Active",
            content: "Processing ${jobs.length} jobs",
          );
        }

        for (var job in jobs) {
          await LoggingService.addLog('Processing job ${job.id} for ${job.phone}');
          
          final success = await SmsService.sendSms(job.phone, job.message);
          
          if (success) {
            await apiClient.reportComplete(job.id);
          } else {
            await apiClient.reportFailure(job.id, 'sms_failed');
          }

          // Rate limiting
          await Future.delayed(Duration(seconds: rateLimitDelay));
        }
      } else {
        pollInterval = 10; // Idle mode
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "SMS Gateway Online",
            content: "Waiting for jobs...",
          );
        }
      }

      await Future.delayed(Duration(seconds: pollInterval));
    }
  }
}
