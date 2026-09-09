import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Public Grok-CLI OAuth client used by OpenCode / Hermes / peer agents.
/// Not a secret — xAI allowlists this client for the device-code flow.
const kGrokOAuthClientId = 'b1a00492-073a-47ea-816f-4c329264a828';

const kGrokDeviceCodeUrl = 'https://auth.x.ai/oauth2/device/code';
const kGrokTokenUrl = 'https://auth.x.ai/oauth2/token';
const kGrokOAuthScope =
    'openid profile email offline_access grok-cli:access api:access';
const kGrokDeviceCodeGrantType =
    'urn:ietf:params:oauth:grant-type:device_code';

/// Optional CORS proxy base for Flutter web (see tool/oauth_cors_proxy.py).
/// Pass with: --dart-define=AETHER_OAUTH_PROXY=http://127.0.0.1:8787
const String kOAuthProxyBase = String.fromEnvironment('AETHER_OAUTH_PROXY');

String get grokDeviceCodeUrl {
  if (kOAuthProxyBase.isNotEmpty) {
    return '$kOAuthProxyBase/oauth2/device/code';
  }
  // Sensible web default when running the bundled local proxy.
  if (kIsWeb) return 'http://127.0.0.1:8787/oauth2/device/code';
  return kGrokDeviceCodeUrl;
}

String get grokTokenUrl {
  if (kOAuthProxyBase.isNotEmpty) {
    return '$kOAuthProxyBase/oauth2/token';
  }
  if (kIsWeb) return 'http://127.0.0.1:8787/oauth2/token';
  return kGrokTokenUrl;
}

class GrokDeviceCode {
  GrokDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String? verificationUriComplete;
  final int expiresIn;
  final int interval;

  String get browserUrl => verificationUriComplete ?? verificationUri;
}

class GrokTokens {
  GrokTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.idToken,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String? idToken;

  bool get isExpiringSoon {
    final skew = const Duration(minutes: 2);
    if (expiresAt.isBefore(DateTime.now().add(skew))) return true;
    return _jwtExpiringSoon(accessToken, skew);
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
        if (idToken != null) 'id_token': idToken,
      };

  factory GrokTokens.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expires_at'];
    DateTime expiresAt;
    if (expiresAtRaw is String) {
      expiresAt = DateTime.parse(expiresAtRaw);
    } else if (json['expires_in'] is num) {
      expiresAt = DateTime.now().add(
        Duration(seconds: (json['expires_in'] as num).toInt()),
      );
    } else {
      expiresAt = DateTime.now().add(const Duration(hours: 1));
    }
    return GrokTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: expiresAt,
      idToken: json['id_token'] as String?,
    );
  }

  factory GrokTokens.fromTokenResponse(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    return GrokTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      idToken: json['id_token'] as String?,
    );
  }
}

bool _jwtExpiringSoon(String token, Duration skew) {
  final parts = token.split('.');
  if (parts.length < 2) return false;
  try {
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final claims = jsonDecode(utf8.decode(base64.decode(payload)));
    final exp = claims['exp'];
    if (exp is! num) return false;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
        .isBefore(DateTime.now().add(skew));
  } catch (_) {
    return false;
  }
}

class GrokOAuthException implements Exception {
  GrokOAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GrokOAuth {
  GrokOAuth({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GrokDeviceCode> requestDeviceCode() async {
    final response = await _client.post(
      Uri.parse(grokDeviceCodeUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        'User-Agent': 'aether/1.0',
      },
      body: {
        'client_id': kGrokOAuthClientId,
        'scope': kGrokOAuthScope,
        'referrer': 'aether',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GrokOAuthException(
        'Device code request failed (${response.statusCode}): ${response.body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final deviceCode = json['device_code'] as String?;
    final userCode = json['user_code'] as String?;
    final verificationUri = json['verification_uri'] as String?;
    if (deviceCode == null || userCode == null || verificationUri == null) {
      throw GrokOAuthException('Incomplete device-code response from xAI');
    }
    return GrokDeviceCode(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: verificationUri,
      verificationUriComplete: json['verification_uri_complete'] as String?,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 1800,
      interval: (json['interval'] as num?)?.toInt() ?? 5,
    );
  }

  /// Polls until the user approves the device code in the browser.
  Future<GrokTokens> pollForTokens(
    GrokDeviceCode device, {
    void Function(String status)? onStatus,
    bool Function()? shouldCancel,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: device.expiresIn));
    var intervalMs = (device.interval.clamp(1, 60)) * 1000;

    while (DateTime.now().isBefore(deadline)) {
      if (shouldCancel?.call() == true) {
        throw GrokOAuthException('Sign-in cancelled');
      }

      final response = await _client.post(
        Uri.parse(grokTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'User-Agent': 'aether/1.0',
        },
        body: {
          'grant_type': kGrokDeviceCodeGrantType,
          'client_id': kGrokOAuthClientId,
          'device_code': device.deviceCode,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return GrokTokens.fromTokenResponse(json);
      }

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      final error = body['error'] as String?;
      if (error == 'authorization_pending') {
        onStatus?.call('Waiting for approval…');
      } else if (error == 'slow_down') {
        intervalMs += 5000;
        onStatus?.call('Backing off — waiting…');
      } else if (error == 'access_denied' || error == 'authorization_denied') {
        throw GrokOAuthException('Authorization denied');
      } else if (error == 'expired_token') {
        throw GrokOAuthException('Device code expired — try again');
      } else {
        throw GrokOAuthException(
          'Token exchange failed (${response.statusCode}): ${response.body}',
        );
      }

      await Future<void>.delayed(Duration(milliseconds: intervalMs + 3000));
    }

    throw GrokOAuthException('Authorization timed out');
  }

  Future<GrokTokens> refresh(String refreshToken) async {
    final response = await _client.post(
      Uri.parse(grokTokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        'User-Agent': 'aether/1.0',
      },
      body: {
        'grant_type': 'refresh_token',
        'client_id': kGrokOAuthClientId,
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GrokOAuthException(
        'Token refresh failed (${response.statusCode}). Sign in again.',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final next = GrokTokens.fromTokenResponse(json);
    // Some servers omit a rotated refresh_token — keep the old one.
    if ((json['refresh_token'] as String?) == null ||
        (json['refresh_token'] as String).isEmpty) {
      return GrokTokens(
        accessToken: next.accessToken,
        refreshToken: refreshToken,
        expiresAt: next.expiresAt,
        idToken: next.idToken,
      );
    }
    return next;
  }
}
