import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists Grok / xAI credentials and agent prefs.
class SettingsStore {
  SettingsStore({
    FlutterSecureStorage? secureStorage,
    this._prefs,
  }) : _secure = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  static const _apiKeyKey = 'xai_api_key';
  static const _modelKey = 'grok_model';
  static const _imageModelKey = 'imagine_model';
  static const _providerKey = 'active_provider';

  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> getApiKey() => _secure.read(key: _apiKeyKey);

  Future<void> setApiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _secure.delete(key: _apiKeyKey);
      return;
    }
    await _secure.write(key: _apiKeyKey, value: value.trim());
  }

  Future<bool> get hasApiKey async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<String> getGrokModel() async {
    final p = await _p;
    return p.getString(_modelKey) ?? 'grok-4-1-fast-reasoning';
  }

  Future<void> setGrokModel(String model) async {
    final p = await _p;
    await p.setString(_modelKey, model);
  }

  Future<String> getImagineModel() async {
    final p = await _p;
    return p.getString(_imageModelKey) ?? 'grok-imagine-image-2.0';
  }

  Future<void> setImagineModel(String model) async {
    final p = await _p;
    await p.setString(_imageModelKey, model);
  }

  Future<String> getProvider() async {
    final p = await _p;
    return p.getString(_providerKey) ?? 'Grok';
  }

  Future<void> setProvider(String provider) async {
    final p = await _p;
    await p.setString(_providerKey, provider);
  }
}
