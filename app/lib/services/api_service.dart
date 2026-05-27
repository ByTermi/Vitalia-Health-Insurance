import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  String ip = '10.0.2.2';
  int port = 8000;
  static const _userId = 'demo_user_001';

  String get _base => 'http://$ip:$port';

  Future<Map<String, dynamic>?> postActivity({
    required String activity,
    required int durationSeconds,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/events/activity'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id_hash': _userId,
              'activity': activity,
              'duration_s': durationSeconds,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<String?> postFall({
    required int stage,
    required double svmPeak,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base/events/fall'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id_hash': _userId,
              'stage': stage,
              'svm_peak': svmPeak,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['fall_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> ackFall(String fallId) async {
    try {
      await http
          .post(Uri.parse('$_base/events/fall/$fallId/ack'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
