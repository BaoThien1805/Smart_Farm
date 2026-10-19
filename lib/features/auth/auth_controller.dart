import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import 'auth_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository repository;
  FarmUser? user;
  bool initializing = true;
  bool busy = false;
  String? error;
  String? notice;
  AuthController(this.repository) {
    repository.api.onUnauthorized = () {
      unawaited(expire());
    };
  }

  Future<void> initialize() async {
    initializing = true;
    error = null;
    notifyListeners();
    try {
      user = await repository.restore();
    } on ApiException catch (e) {
      if (e.status != 401) error = e.message;
    } catch (_) {
      error = 'Không thể đọc phiên đăng nhập an toàn. Vui lòng thử lại.';
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> expire() async {
    user = null;
    notice = 'Phiên đã hết hạn hoặc tài khoản bị khóa. Vui lòng đăng nhập lại.';
    try {
      await repository.forget();
    } catch (_) {
      error = 'Không thể xóa phiên đã lưu. Vui lòng thử lại.';
    }
    notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) => run(() async {
    user = await repository.login(email, password);
  });
  Future<bool> register(
    String name,
    String farmName,
    String email,
    String password,
  ) => run(() async {
    user = await repository.register(name, farmName, email, password);
  });
  Future<bool> logout() => run(() async {
    try {
      final revoked = await repository.logout();
      notice = revoked ? 'Đã đăng xuất.' : 'Đã đăng xuất trên thiết bị này. Chưa thể xác nhận thu hồi phiên trên máy chủ do lỗi kết nối; phiên đó sẽ hết hạn theo cấu hình.';
    } finally {
      user = null;
    }
  });
  Future<bool> changePassword(String current, String next) => run(() async {
    await repository.changePassword(current, next);
    user = null;
    notice = 'Đã đổi mật khẩu. Vui lòng đăng nhập bằng mật khẩu mới.';
  });
  Future<bool> refresh() => run(() async {
    user = await repository.profile();
  });

  @override
  void dispose() {
    repository.api.onUnauthorized = null;
    super.dispose();
  }
}
