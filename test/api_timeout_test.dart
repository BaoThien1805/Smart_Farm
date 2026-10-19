import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';

void main() {
  test(
    'default client reaches the online endpoint without build flags',
    () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'smart-farm-api-4n6x.onrender.com');
          expect(request.url.path, '/api/health');
          return http.Response('{"status":"ok"}', 200);
        }),
      );
      addTearDown(api.dispose);
      expect(api.requestTimeout, const Duration(seconds: 90));
      expect(await api.request('GET', '/health', authenticated: false), {
        'status': 'ok',
      });
    },
  );
  test('online API allows cold start; local API keeps the short timeout', () {
    final online = ApiClient(baseUrl: 'https://example.test/api');
    final local = ApiClient(baseUrl: 'http://127.0.0.1:3000/api');
    addTearDown(online.dispose);
    addTearDown(local.dispose);
    expect(online.requestTimeout, const Duration(seconds: 90));
    expect(local.requestTimeout, const Duration(seconds: 15));
  });

  test(
    'timeout is reported without retrying a login or other writes',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'https://example.test/api',
        requestTimeout: const Duration(milliseconds: 10),
        client: MockClient((_) {
          calls++;
          return response.future;
        }),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.request(
          'POST',
          '/auth/login',
          authenticated: false,
          body: {'email': 'test@example.test', 'password': 'example-password'},
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('khởi động'),
          ),
        ),
      );
      expect(calls, 1);
      response.complete(http.Response('{}', 200));
    },
  );
}
