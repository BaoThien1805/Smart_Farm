import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../auth/auth_repository.dart';

class UsersController extends ChangeNotifier {
  final ApiClient api;
  List<FarmUser> users = [];
  int page = 1, total = 0;
  bool loading = false;
  bool saving = false;
  String? error;
  bool _disposed = false;
  UsersController(this.api);
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({int? targetPage}) async {
    if (loading) return;
    loading = true;
    error = null;
    changed();
    final nextPage = targetPage ?? page;
    try {
      final data = await api.request(
        'GET',
        '/users?page=$nextPage&pageSize=20',
      );
      users = (data['users'] as List)
          .map((value) => FarmUser.fromJson(value as Map<String, dynamic>))
          .toList();
      total = data['total'] as int;
      page = nextPage;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Không tải được danh sách tài khoản.';
    } finally {
      loading = false;
      changed();
    }
  }

  Future<bool> save(Future<void> Function() action) async {
    if (saving) return false;
    saving = true;
    error = null;
    changed();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Không thể lưu thay đổi. Vui lòng thử lại.';
      return false;
    } finally {
      saving = false;
      changed();
    }
  }

  Future<bool> create(
    String name,
    String email,
    String password, {
    String role = 'STAFF',
    String? code,
  }) => save(() async {
    await api.request(
      'POST',
      '/users',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      },
    );
    await load(targetPage: 1);
  });
  Future<bool> updateUser(FarmUser user, Map<String, dynamic> body) =>
      save(() async {
        try {
          await api.request('PATCH', '/users/${user.id}', body: body);
        } on ApiException catch (e) {
          if (e.status == 404 && e.code == 'NOT_FOUND') {
            throw const ApiException(
              'Máy chủ chưa hỗ trợ chỉnh sửa nhân sự. Cập nhật backend v10 lên Render rồi thử lại.',
              404,
              'BACKEND_UPDATE_REQUIRED',
            );
          }
          rethrow;
        }
        await load();
      });
  Future<bool> setAvatar(FarmUser user, String? photoBase64) => save(() async {
    await api.request(
      'PATCH',
      '/users/${user.id}/avatar',
      body: {'photoBase64': photoBase64},
    );
    await load();
  });
  Future<bool> setActive(FarmUser user, bool active) => save(() async {
    await api.request(
      'PATCH',
      '/users/${user.id}/status',
      body: {'active': active},
    );
    await load();
  });
  Future<bool> deleteUser(FarmUser user) => save(() async {
    try {
      await api.request('DELETE', '/users/${user.id}');
    } on ApiException catch (e) {
      if (e.status == 409 && e.code == 'DATA_CONFLICT') {
        throw const ApiException(
          'Máy chủ đang dùng cách xóa cũ nên chặn nhân viên có lịch sử. Cập nhật backend v11 trên Render để xóa tài khoản và giữ lịch sử.',
          409,
          'BACKEND_UPDATE_REQUIRED',
        );
      }
      rethrow;
    }
    final target = (users.length == 1 && page > 1) ? page - 1 : page;
    await load(targetPage: target);
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
