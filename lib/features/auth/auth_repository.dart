import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';

class FarmUser {
  final String id, email, name, role;
  final bool active;
  final String? avatarData;
  final String? code;
  const FarmUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    this.avatarData,
    this.code,
  });
  bool get isAdmin => role == 'ADMIN';
  bool get canOperate => isAdmin || role == 'STAFF';
  bool get canCare => canOperate || role == 'VET';
  bool get canExamine => isAdmin || role == 'VET';
  bool get canFinance => isAdmin || role == 'ACCOUNTANT';
  String get roleLabel => switch (role) {
    'ADMIN' => 'Quản trị viên',
    'STAFF' => 'Nhân viên',
    'VET' => 'Bác sĩ thú y',
    'ACCOUNTANT' => 'Kế toán',
    _ => 'Chưa xác định',
  };
  factory FarmUser.fromJson(Map<String, dynamic> data) => FarmUser(
    id: data['id'] as String,
    email: data['email'] as String,
    name: data['name'] as String,
    role: data['role'] as String,
    active: data['active'] as bool,
    avatarData: data['avatarData'] as String?,
    code: data['code'] as String?,
  );
}

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? _webToken;
  // Web uses memory only. Reloading the page requires login; no bearer token is persisted in localStorage.
  @override
  Future<String?> read() async =>
      kIsWeb ? _webToken : storage.read(key: 'smartfarm_session');
  @override
  Future<void> write(String token) async {
    if (kIsWeb) {
      _webToken = token;
    } else {
      await storage.write(key: 'smartfarm_session', value: token);
    }
  }

  @override
  Future<void> clear() async {
    _webToken = null;
    if (!kIsWeb) await storage.delete(key: 'smartfarm_session');
  }
}

class AuthRepository {
  final ApiClient api;
  final TokenStore store;
  AuthRepository(this.api, this.store);

  Future<FarmUser?> restore() async {
    api.token = await store.read();
    if (api.token == null) return null;
    return profile();
  }

  Future<FarmUser> profile() async => FarmUser.fromJson(
    (await api.request('GET', '/auth/me'))['user'] as Map<String, dynamic>,
  );
  Future<FarmUser> login(String email, String password) async {
    final data = await api.request(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    return saveSession(data);
  }

  Future<FarmUser> register(
    String name,
    String farmName,
    String email,
    String password,
  ) async {
    final data = await api.request(
      'POST',
      '/auth/register',
      body: {
        'name': name.trim(),
        'farmName': farmName.trim(),
        'email': email.trim(),
        'password': password,
      },
      authenticated: false,
    );
    return saveSession(data);
  }

  Future<FarmUser> saveSession(Map<String, dynamic> data) async {
    api.token = data['token'] as String;
    try {
      await store.write(api.token!);
    } catch (_) {
      api.token = null;
      throw const ApiException(
        'Không thể lưu phiên an toàn. Vui lòng thử lại.',
      );
    }
    return FarmUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> forget() async {
    api.token = null;
    await store.clear();
  }

  Future<bool> logout() async {
    var revoked = false;
    try {
      await api.request('POST', '/auth/logout');
      revoked = true;
    } on ApiException catch (error) {
      // An expired session is already invalid; connection failures must be disclosed.
      revoked = error.status == 401;
    } finally {
      await forget();
    }
    return revoked;
  }

  Future<void> changePassword(String current, String next) async {
    await api.request(
      'POST',
      '/auth/password',
      body: {'currentPassword': current, 'newPassword': next},
    );
    await forget();
  }
}
