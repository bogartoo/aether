import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'grok_oauth.dart';

const _kTokensKey = 'aether_grok_tokens_v1';
const _kApiKeyKey = 'aether_xai_api_key_v1';

/// Persists Grok OAuth tokens. Uses secure storage on mobile/desktop;
/// falls back to SharedPreferences on web.
class AuthStore {
  AuthStore({
    FlutterSecureStorage? secureStorage,
  }) : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secure;

  Future<void> saveTokens(GrokTokens tokens) async {
    final encoded = jsonEncode(tokens.toJson());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTokensKey, encoded);
      return;
    }
    await _secure.write(key: _kTokensKey, value: encoded);
  }

  Future<GrokTokens?> loadTokens() async {
    String? raw;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_kTokensKey);
    } else {
      raw = await _secure.read(key: _kTokensKey);
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      return GrokTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokens() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kTokensKey);
      return;
    }
    await _secure.delete(key: _kTokensKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kApiKeyKey, apiKey);
      return;
    }
    await _secure.write(key: _kApiKeyKey, value: apiKey);
  }

  Future<String?> loadApiKey() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kApiKeyKey);
    }
    return _secure.read(key: _kApiKeyKey);
  }

  Future<void> clearApiKey() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kApiKeyKey);
      return;
    }
    await _secure.delete(key: _kApiKeyKey);
  }

  Future<void> clearAll() async {
    await clearTokens();
    await clearApiKey();
  }
}
