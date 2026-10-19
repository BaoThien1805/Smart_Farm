import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';

void main() {
  test(
    'plain text 404 exposes missing API instead of JSON format error',
    () async {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('Not Found\n', 404)),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.request('POST', '/auth/login', authenticated: false),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.message, 'message', contains('Primary URL')),
        ),
      );
    },
  );
  test(
    'HTML 503 identifies an unavailable server without exposing the page',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response('<html>loading</html>', 503),
        ),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.request('GET', '/health'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 503)
              .having((e) => e.message, 'message', contains('chưa sẵn sàng')),
        ),
      );
    },
  );
  test('non JSON 401 expires an authenticated session once', () async {
    var expired = 0;
    final api = ApiClient(
      client: MockClient((_) async => http.Response('Unauthorized', 401)),
    )..onUnauthorized = () => expired++;
    addTearDown(api.dispose);
    await expectLater(
      api.request('GET', '/auth/me'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, 1);
  });
  test('valid backend error message survives; malformed error shape is handled safely', () async {
    final api = ApiClient(
      client: MockClient(
        (request) async => request.url.path.endsWith('/login')
            ? http.Response(
                '{"error":{"message":"Email hoặc mật khẩu không đúng."}}',
                401,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )
            : http.Response('{"error":42}', 500),
      ),
    );
    addTearDown(api.dispose);
    await expectLater(
      api.request('POST', '/auth/login', authenticated: false),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Email hoặc mật khẩu không đúng.',
        ),
      ),
    );
    await expectLater(
      api.request('GET', '/health'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 500)),
    );
  });
  test(
    'successful response with wrong JSON shape is a controlled API error',
    () async {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.request('GET', '/health'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('JSON'),
          ),
        ),
      );
    },
  );
}
