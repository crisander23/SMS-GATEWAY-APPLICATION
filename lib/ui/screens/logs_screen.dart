import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../services/logging_service.dart';
import '../../core/app_theme.dart';
import 'dart:async';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  StreamSubscription? _logSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _logSubscription = FlutterBackgroundService().on('onLogAdded').listen((event) {
      if (event != null) {
        LoggingService.loadLogs(); // Reload to get the new entry
        if (mounted) setState(() {});
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await LoggingService.loadLogs();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = LoggingService.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACTIVITY LOGS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await LoggingService.clearLogs();
              setState(() {});
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No logs available', style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: log.isError ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      log.isError ? Icons.error_outline : Icons.info_outline,
                      color: log.isError ? AppTheme.errorColor : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    log.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: log.isError ? AppTheme.errorColor : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    log.formattedTime,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                );
              },
            ),
    );
  }
}
