import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../services/logging_service.dart';
import '../../services/storage_service.dart';
import '../../core/app_theme.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isRunning = false;
  String _lastSync = 'Never';
  int _smsSentToday = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkServiceStatus();
      _updateStats();
    });
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    if (mounted) {
      setState(() {
        _isRunning = isRunning;
      });
    }
  }

  void _updateStats() {
    final logs = LoggingService.logs;
    if (logs.isNotEmpty) {
      final lastLog = logs.first;
      if (mounted) {
        setState(() {
          _lastSync = lastLog.formattedTime;
          _smsSentToday = logs.where((l) => l.message.contains('SMS sent') && l.timestamp.day == DateTime.now().day).length;
        });
      }
    }
  }

  Future<void> _toggleGateway() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
    } else {
      final storage = await StorageService.init();
      if (storage.apiUrl.isEmpty || storage.gatewayId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please configure API settings first')),
        );
        return;
      }
      await service.startService();
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    _checkServiceStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS GATEWAY 2.0')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _toggleGateway,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? AppTheme.errorColor : AppTheme.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              child: Text(
                _isRunning ? 'STOP GATEWAY' : 'START GATEWAY',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
               onPressed: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Connection test initiated...')),
                 );
                 // In a real app, logic to test API reachability would go here
               },
               style: OutlinedButton.styleFrom(
                 foregroundColor: Colors.white,
                 side: const BorderSide(color: Colors.white24),
                 padding: const EdgeInsets.symmetric(vertical: 16),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               ),
               child: const Text('TEST CONNECTION'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (_isRunning ? AppTheme.accentColor : AppTheme.errorColor).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRunning ? Icons.check_circle : Icons.pause_circle_filled,
                size: 48,
                color: _isRunning ? AppTheme.accentColor : AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRunning ? 'Gateway Online' : 'Gateway Offline',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isRunning ? 'Polling for SMS jobs...' : 'Press Start to begin polling',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatItem('Last Sync', _lastSync, Icons.sync)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatItem('Sent Today', '$_smsSentToday', Icons.send)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
