// Fixture-only HTTP and token storage for isolated previews/tests.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

http.Response authFixtureResponse(Object value, [int status = 200]) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _PreviewTokenStore implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

class AuthOnboardingFixture {
  AuthOnboardingFixture({
    Future<http.Response> Function(http.Request)? responder,
  }) {
    api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (responder != null) return responder(request);
        if (request.method != 'GET') {
          return authFixtureResponse({
            'error': {'message': 'Bản xem thử không lưu dữ liệu.'},
          }, 409);
        }
        if (request.url.path.endsWith('/preferences')) {
          return authFixtureResponse({
            'speciesIds': ['goat'],
          });
        }
        return authFixtureResponse({'species': species});
      }),
    );
    auth = AuthController(AuthRepository(api, _PreviewTokenStore()))
      ..initializing = false;
    repository = FarmRepository(api);
  }
  static const species = [
    {'id': 'cow', 'code': 'BO', 'name': 'Bò'},
    {'id': 'pig', 'code': 'HEO', 'name': 'Heo'},
    {'id': 'goat', 'code': 'DE', 'name': 'Dê'},
    {'id': 'chicken', 'code': 'GA', 'name': 'Gà'},
    {'id': 'fish', 'code': 'CA', 'name': 'Cá rô phi nước ngọt có tên dài'},
  ];
  late final ApiClient api;
  late final AuthController auth;
  late final FarmRepository repository;
  final requests = <http.Request>[];
  void dispose() {
    auth.dispose();
    api.dispose();
  }
}
