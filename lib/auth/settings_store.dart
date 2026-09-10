import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/edge0_client.dart';

const _kBaseUrlKey = 'hrtbrkr_edge0_base_url_v1';
const _kModelKey = 'hrtbrkr_edge0_model_v1';
const _kConnectedKey = 'hrtbrkr_edge0_connected_v1';

/// Persists local Edge0 endpoint preferences.
class SettingsStore {
  SettingsStore({
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secure;

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    await _secure.write(key: key, value: value);
  }

  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _secure.read(key: key);
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _secure.delete(key: key);
  }

  Future<void> saveBaseUrl(String url) => _write(_kBaseUrlKey, url);

  Future<String> loadBaseUrl() async {
    final v = await _read(_kBaseUrlKey);
    if (v == null || v.trim().isEmpty) return kDefaultEdge0BaseUrl;
    return v.trim();
  }

  Future<void> saveModel(String model) => _write(_kModelKey, model);

  Future<String> loadModel() async {
    final v = await _read(_kModelKey);
    if (v == null || v.trim().isEmpty) return kDefaultEdge0Model;
    return v.trim();
  }

  Future<void> saveConnected(bool connected) =>
      _write(_kConnectedKey, connected ? '1' : '0');

  Future<bool> loadConnected() async {
    final v = await _read(_kConnectedKey);
    return v == '1';
  }

  Future<void> clearAll() async {
    await _delete(_kBaseUrlKey);
    await _delete(_kModelKey);
    await _delete(_kConnectedKey);
  }
}
