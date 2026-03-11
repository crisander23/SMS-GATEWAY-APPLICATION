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
  bool _isFetching = false;
  StreamSubscription? _statSubscription;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _startRefreshTimer();
    _setupStatsListener();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statSubscription?.cancel();
    super.dispose();
  }

  void _setupStatsListener() {
    _statSubscription = FlutterBackgroundService().on('onStatsUpdated').listen((event) {
      if (event != null && mounted) {
        setState(() {
          if (event['sentToday'] != null) _smsSentToday = event['sentToday'];
          if (event['isFetching'] != null) _isFetching = event['isFetching'];
          if (event['lastSync'] != null) {
             final dt = DateTime.parse(event['lastSync']);
             _lastSync = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
          }
        });
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkServiceStatus();
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
    // Legacy method - logic moved to _setupStatsListener
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
            if (_isFetching)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor)),
                    SizedBox(width: 8),
                    Text('Fetching jobs...', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
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
