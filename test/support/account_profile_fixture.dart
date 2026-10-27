// Isolated auth/profile service. Credentials and tokens below are test-only.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';

import 'animals_fixture.dart';

class ProfileTokenStore implements TokenStore {
  String? token = 'fixture-session';
  int clears = 0;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
    clears++;
  }
}

http.Response profileFixtureResponse(Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class AccountProfileFixture {
  AccountProfileFixture([String role = 'ADMIN']) {
    user['role'] = role;
    api = ApiClient(
      baseUrl: 'http://fixture.invalid/api',
      client: MockClient(handle),
    )..token = store.token;
    auth = AuthController(AuthRepository(api, store))
      ..initializing = false
      ..user = FarmUser.fromJson(user);
  }
  final store = ProfileTokenStore();
  late final ApiClient api;
  late final AuthController auth;
  final requests = <http.Request>[];
  final passwordBodies = <Map<String, dynamic>>[],
      avatarBodies = <Map<String, dynamic>>[];
  bool failFarm = false,
      failProfile = false,
      expirePassword = false,
      offlineLogout = false,
      sessionValid = true;
  String? passwordError, avatarError;
  String? farmName = 'Trang trại An Nhiên · tên trại mẫu có độ dài để kiểm tra';
  String credential = 'fixture-current-password';
  Future<void>? pendingPassword, pendingAvatar, pendingProfile, pendingLogout;
  final user = <String, dynamic>{
    'id': 'profile-user',
    'code': 'NV-016',
    'name': 'Nguyễn An Nhiên · tài khoản có họ tên dài',
    'email': 'account.profile.long@example.test',
    'role': 'ADMIN',
    'active': true,
    'avatarData': AnimalsFixture.photo,
  };
  List<http.Request> get profiles =>
      requests.where((r) => r.url.path.endsWith('/auth/me')).toList();
  List<http.Request> get farms =>
      requests.where((r) => r.url.path.endsWith('/farm/location')).toList();
  List<http.Request> get avatarWrites =>
      requests.where((r) => r.url.path.endsWith('/avatar')).toList();
  List<http.Request> get passwords =>
      requests.where((r) => r.url.path.endsWith('/auth/password')).toList();
  List<http.Request> get logouts =>
      requests.where((r) => r.url.path.endsWith('/auth/logout')).toList();
  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path;
    if (path.endsWith('/farm/location')) {
      if (failFarm) {
        return profileFixtureResponse({
          'error': {'message': 'Không tải được tên trang trại.'},
        }, 503);
      }
      return profileFixtureResponse({
        'location': {'name': farmName, 'latitude': 10.5, 'longitude': 106.5},
      });
    }
    if (path.endsWith('/auth/me')) {
      await pendingProfile;
      if (failProfile) {
        return profileFixtureResponse({
          'error': {'message': 'Chưa tải được thông tin tài khoản.'},
        }, 503);
      }
      return profileFixtureResponse({'user': user});
    }
    if (path.endsWith('/avatar')) {
      avatarBodies.add(jsonDecode(r.body) as Map<String, dynamic>);
      await pendingAvatar;
      if (user['role'] != 'ADMIN') {
        return profileFixtureResponse({
          'error': {'message': 'Không có quyền đổi ảnh.'},
        }, 403);
      }
      if (avatarError != null) {
        return profileFixtureResponse({
          'error': {'message': avatarError},
        }, 409);
      }
      user['avatarData'] = avatarBodies.last['photoBase64'];
      return profileFixtureResponse({'user': user});
    }
    if (path.endsWith('/auth/password')) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      passwordBodies.add(body);
      await pendingPassword;
      if (expirePassword) {
        return profileFixtureResponse({
          'error': {'message': 'Phiên không còn hợp lệ.'},
        }, 401);
      }
      if (passwordError != null) {
        return profileFixtureResponse({
          'error': {'message': passwordError},
        }, 503);
      }
      if (body['currentPassword'] != credential) {
        return profileFixtureResponse({
          'error': {
            'code': 'WRONG_PASSWORD',
            'message': 'Mật khẩu hiện tại không đúng.',
          },
        }, 400);
      }
      credential = body['newPassword'] as String;
      sessionValid = false;
      return profileFixtureResponse({}, 204);
    }
    if (path.endsWith('/auth/login')) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (body['password'] != credential) {
        return profileFixtureResponse({
          'error': {'message': 'Email hoặc mật khẩu không đúng.'},
        }, 401);
      }
      sessionValid = true;
      return profileFixtureResponse({
        'token': 'fixture-next-session',
        'user': user,
      });
    }
    if (path.endsWith('/auth/logout')) {
      await pendingLogout;
      if (offlineLogout) throw http.ClientException('fixture offline');
      sessionValid = false;
      return profileFixtureResponse({}, 204);
    }
    return profileFixtureResponse({});
  }

  void dispose() {
    auth.dispose();
    api.dispose();
  }
}
