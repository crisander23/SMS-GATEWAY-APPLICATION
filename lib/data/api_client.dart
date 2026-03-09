import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sms_job.dart';
import '../services/logging_service.dart';

class ApiClient {
  final String baseUrl;
  final String apiKey;
  final String gatewayId;

  ApiClient({
    required this.baseUrl,
    required this.apiKey,
    required this.gatewayId,
  });

  Future<List<SmsJob>> fetchJobs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/gateway/jobs'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'X-Gateway-ID': gatewayId,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> jobsJson = data['jobs'] ?? [];
        return jobsJson.map((json) => SmsJob.fromJson(json)).toList();
      } else {
        await LoggingService.addLog('Failed to fetch jobs: ${response.statusCode}', isError: true);
        return [];
      }
    } catch (e) {
      await LoggingService.addLog('Error fetching jobs: $e', isError: true);
      return [];
    }
  }

  Future<void> reportComplete(int jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/gateway/job-complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'job_id': jobId,
          'gateway_id': gatewayId,
          'status': 'sent',
        }),
      );

      if (response.statusCode != 200) {
        await LoggingService.addLog('Failed to report completion for job $jobId: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      await LoggingService.addLog('Error reporting completion for job $jobId: $e', isError: true);
    }
  }

  Future<void> reportFailure(int jobId, String error) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/gateway/job-failed'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'job_id': jobId,
          'gateway_id': gatewayId,
          'error': error,
        }),
      );

      if (response.statusCode != 200) {
        await LoggingService.addLog('Failed to report failure for job $jobId: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      await LoggingService.addLog('Error reporting failure for job $jobId: $e', isError: true);
    }
  }
}
