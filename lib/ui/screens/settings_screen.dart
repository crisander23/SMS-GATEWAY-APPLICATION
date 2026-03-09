import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../core/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiUrlController;
  late TextEditingController _gatewayIdController;
  late TextEditingController _apiKeyController;
  late TextEditingController _pollIntervalController;
  late TextEditingController _rateLimitController;
  bool _autoStart = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = await StorageService.init();
    setState(() {
      _apiUrlController = TextEditingController(text: storage.apiUrl);
      _gatewayIdController = TextEditingController(text: storage.gatewayId);
      _apiKeyController = TextEditingController(text: storage.apiKey);
      _pollIntervalController = TextEditingController(text: storage.pollInterval.toString());
      _rateLimitController = TextEditingController(text: storage.rateLimitDelay.toString());
      _autoStart = storage.autoStart;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final storage = await StorageService.init();
      await storage.saveConfig(
        apiUrl: _apiUrlController.text,
        gatewayId: _gatewayIdController.text,
        apiKey: _apiKeyController.text,
        pollInterval: int.parse(_pollIntervalController.text),
        rateLimitDelay: int.parse(_rateLimitController.text),
      );
      await storage.setAutoStart(_autoStart);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully')),
        );
      }
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _gatewayIdController.dispose();
    _apiKeyController.dispose();
    _pollIntervalController.dispose();
    _rateLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GATEWAY SETTINGS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Connection Settings'),
              const SizedBox(height: 16),
              _buildTextField(_apiUrlController, 'Backend API URL', 'https://api.example.com', Icons.link),
              const SizedBox(height: 16),
              _buildTextField(_gatewayIdController, 'Gateway ID', 'phone-01', Icons.phone_android),
              const SizedBox(height: 16),
              _buildTextField(_apiKeyController, 'API Key', '********', Icons.vpn_key, isPassword: true),
              const SizedBox(height: 32),
              _buildSectionTitle('Behavior Settings'),
              const SizedBox(height: 16),
              _buildTextField(_pollIntervalController, 'Poll Interval (seconds)', '5', Icons.timer, isNumber: true),
              const SizedBox(height: 16),
              _buildTextField(_rateLimitController, 'Rate Limit Delay (seconds)', '7', Icons.speed, isNumber: true),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto-start Gateway'),
                subtitle: const Text('Start gateway automatically on app launch'),
                value: _autoStart,
                onChanged: (val) => setState(() => _autoStart = val),
                activeColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('SAVE CONFIGURATION', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isPassword = false,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (isNumber && int.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }
}
