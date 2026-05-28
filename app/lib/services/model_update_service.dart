import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ModelUpdateResult {
  final String? harPath;
  final String? fallPath;
  final bool updated;

  const ModelUpdateResult({this.harPath, this.fallPath, required this.updated});
}

class ModelUpdateService {
  static const _prefKeyVersion = 'ota_model_version';
  static const _prefKeyHarPath = 'ota_har_path';
  static const _prefKeyFallPath = 'ota_fall_path';

  static Future<ModelUpdateResult> checkAndUpdate(ApiService api) async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    final cachedHar = prefs.getString(_prefKeyHarPath);
    final cachedFall = prefs.getString(_prefKeyFallPath);

    final meta = await api.getLatestModel();
    if (meta == null) {
      return ModelUpdateResult(
        harPath: _existingPath(cachedHar),
        fallPath: _existingPath(cachedFall),
        updated: false,
      );
    }

    final storedVersion = prefs.getString(_prefKeyVersion) ?? '';
    if (meta.version == storedVersion) {
      return ModelUpdateResult(
        harPath: _existingPath(cachedHar),
        fallPath: _existingPath(cachedFall),
        updated: false,
      );
    }

    bool downloaded = false;
    String? newHar, newFall;

    if (meta.filename.contains('har')) {
      final path = '${dir.path}/${meta.filename}';
      if (await api.downloadModel(meta.filename, path)) {
        newHar = path;
        downloaded = true;
      }
    } else if (meta.filename.contains('fall')) {
      final path = '${dir.path}/${meta.filename}';
      if (await api.downloadModel(meta.filename, path)) {
        newFall = path;
        downloaded = true;
      }
    }

    if (downloaded) {
      await prefs.setString(_prefKeyVersion, meta.version);
      if (newHar != null) await prefs.setString(_prefKeyHarPath, newHar);
      if (newFall != null) await prefs.setString(_prefKeyFallPath, newFall);
    }

    return ModelUpdateResult(
      harPath: newHar ?? _existingPath(cachedHar),
      fallPath: newFall ?? _existingPath(cachedFall),
      updated: downloaded,
    );
  }

  static String? _existingPath(String? path) {
    if (path == null) return null;
    try {
      return File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }
}
