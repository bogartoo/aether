import 'dart:convert';

import 'package:aether/auth/grok_oauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requestDeviceCode parses xAI payload', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), kGrokDeviceCodeUrl);
      expect(request.bodyFields['client_id'], kGrokOAuthClientId);
      return http.Response(
        jsonEncode({
          'device_code': 'dev-1',
          'user_code': 'ABCD-EFGH',
          'verification_uri': 'https://accounts.x.ai/oauth2/device',
          'verification_uri_complete':
              'https://accounts.x.ai/oauth2/device?user_code=ABCD-EFGH',
          'expires_in': 1800,
          'interval': 5,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final oauth = GrokOAuth(client: client);
    final device = await oauth.requestDeviceCode();
    expect(device.userCode, 'ABCD-EFGH');
    expect(device.browserUrl, contains('user_code=ABCD-EFGH'));
  });

  test('pollForTokens returns after authorization_pending', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (calls == 1) {
        return http.Response(
          jsonEncode({'error': 'authorization_pending'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'access_token': 'access-xyz',
          'refresh_token': 'refresh-xyz',
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final oauth = GrokOAuth(client: client);
    final device = GrokDeviceCode(
      deviceCode: 'dev',
      userCode: 'CODE',
      verificationUri: 'https://accounts.x.ai/oauth2/device',
      expiresIn: 30,
      interval: 1,
    );

    final tokens = await oauth.pollForTokens(device);
    expect(tokens.accessToken, 'access-xyz');
    expect(tokens.refreshToken, 'refresh-xyz');
    expect(calls, 2);
  });

  test('GrokTokens round-trip JSON', () {
    final original = GrokTokens(
      accessToken: 'a',
      refreshToken: 'r',
      expiresAt: DateTime.utc(2030, 1, 1),
    );
    final restored = GrokTokens.fromJson(original.toJson());
    expect(restored.accessToken, 'a');
    expect(restored.refreshToken, 'r');
    expect(restored.expiresAt.toUtc(), DateTime.utc(2030, 1, 1));
  });
}
