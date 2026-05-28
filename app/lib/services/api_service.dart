import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VitaPointsState {
  final double total;
  final double thisWeek;
  final int streakDays;
  final String level;

  const VitaPointsState({
    required this.total,
    required this.thisWeek,
    required this.streakDays,
    required this.level,
  });

  factory VitaPointsState.fromJson(Map<String, dynamic> j) => VitaPointsState(
        total: (j['total'] as num).toDouble(),
        thisWeek: (j['this_week'] as num).toDouble(),
        streakDays: j['streak_days'] as int,
        level: j['level'] as String,
      );
}

class ModelMeta {
  final String name;
  final String version;
  final int sizeKb;
  final String filename;

  const ModelMeta({
    required this.name,
    required this.version,
    required this.sizeKb,
    required this.filename,
  });

  factory ModelMeta.fromJson(Map<String, dynamic> j) => ModelMeta(
        name: j['name'] as String,
        version: j['version'] as String,
        sizeKb: j['size_kb'] as int,
        filename: j['filename'] as String,
      );
}

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

  Future<VitaPointsState?> getVitaPoints() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/users/$_userId/vitapoints'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return VitaPointsState.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<ModelMeta?> getLatestModel() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/models/latest'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return ModelMeta.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> downloadModel(String filename, String localPath) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/models/$filename'))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        await File(localPath).writeAsBytes(res.bodyBytes);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteUserData() async {
    try {
      final res = await http
          .delete(Uri.parse('$_base/users/$_userId/data'))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
