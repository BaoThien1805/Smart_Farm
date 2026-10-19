import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/main.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/users/users_page.dart';

http.Response testResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class MemoryStore implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

const staff = {
  'id': 'staff-id',
  'email': 'staff@test.local',
  'name': 'Nhân viên mẫu',
  'role': 'STAFF',
  'active': true,
};
const admin = {
  'id': 'admin-id',
  'email': 'admin@test.local',
  'name': 'Quản trị viên',
  'role': 'ADMIN',
  'active': true,
};

Future<void> enterWorkspace(WidgetTester tester) async {
  final start = find.text('Quản lý trang trại của tôi').evaluate().isNotEmpty
      ? find.text('Quản lý trang trại của tôi')
      : find.text('Vào trang trại làm việc');
  if (start.evaluate().isNotEmpty) {
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
  }
  final button = find.widgetWithText(OutlinedButton, 'Xem tất cả');
  if (button.evaluate().isNotEmpty) {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'owner registration validates confirmation and opens farm onboarding',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final store = MemoryStore();
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/register')) {
            calls++;
            final body = jsonDecode(request.body);
            expect(body['name'], 'Chủ trại');
            expect(body['farmName'], 'Trang trại A');
            expect(body.containsKey('role'), false);
            return testResponse(
              jsonEncode({'token': 'owner-token', 'user': admin}),
              201,
            );
          }
          return testResponse(
            jsonEncode({'species': [], 'speciesIds': []}),
            200,
          );
        }),
      );
      final auth = AuthController(AuthRepository(client, store));
      await tester.pumpWidget(SmartFarmApp(controller: auth));
      await tester.pumpAndSettle();
      final signup = find.text('Chưa có tài khoản? Đăng ký chủ trang trại');
      await tester.ensureVisible(signup);
      await tester.tap(signup);
      await tester.pumpAndSettle();
      Future<void> fill(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await fill('Họ và tên', 'Chủ trại');
      await fill('Tên trang trại', 'Trang trại A');
      await fill('Email', 'owner@test.local');
      await fill('Mật khẩu', 'Owner-password-42');
      await fill('Nhập lại mật khẩu', 'mismatch');
      final submit = find.widgetWithText(FilledButton, 'Tạo tài khoản');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Mật khẩu nhập lại chưa khớp.'), findsOneWidget);
      await fill('Nhập lại mật khẩu', 'Owner-password-42');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(store.token, 'owner-token');
      expect(find.text('Quản lý trang trại của tôi'), findsOneWidget);
      expect(find.text('Chọn vật nuôi trong trang trại'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      client.dispose();
    },
  );

  testWidgets('mobile login validates inputs and exposes server error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
      client: MockClient(
        (_) async => testResponse(
          jsonEncode({
            'error': {'message': 'Email hoặc mật khẩu không đúng.'},
          }),
          401,
        ),
      ),
    );
    final auth = AuthController(AuthRepository(client, MemoryStore()));
    await tester.pumpWidget(SmartFarmApp(controller: auth));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(find.text('Nhập địa chỉ email hợp lệ.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'staff@test.local',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'incorrect-password',
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    client.dispose();
  });

  testWidgets(
    'STAFF login has no personnel navigation and logout returns to login',
    (tester) async {
      final store = MemoryStore();
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return testResponse(
              jsonEncode({'token': 'test-token', 'user': staff}),
              200,
            );
          }
          if (request.url.path.endsWith('/logout')) {
            expect(request.headers.containsKey('content-type'), isFalse);
            expect(request.body, isEmpty);
            return testResponse('', 204);
          }
          return testResponse(jsonEncode({'user': staff}), 200);
        }),
      );
      final auth = AuthController(AuthRepository(client, store));
      await tester.pumpWidget(SmartFarmApp(controller: auth));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'staff@test.local',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'correct-password',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      expect(find.text('Vào trang trại làm việc'), findsNothing);
      expect(find.text('Thêm vật nuôi'), findsOneWidget);
      expect(find.text('Nhân sự'), findsNothing);
      expect(store.token, 'test-token');
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Đăng xuất'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      expect(find.text('Đăng nhập\ntrang trại của bạn.'), findsOneWidget);
      expect(store.token, isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      client.dispose();
    },
  );

  testWidgets(
    'desktop admin sees personnel and long names wrap without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..token = 'test-token';
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/users')) {
            return testResponse(
              jsonEncode({
                'users': [
                  admin,
                  {
                    ...staff,
                    'name': 'Nhân viên có họ và tên dài để kiểm tra bố cục trên các kích thước màn hình',
                  },
                ],
                'total': 2,
                'page': 1,
              }),
              200,
            );
          }
          return testResponse(jsonEncode({'user': admin}), 200);
        }),
      );
      final auth = AuthController(AuthRepository(client, store));
      await tester.pumpWidget(SmartFarmApp(controller: auth));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      await tester.tap(find.text('Nhân sự'));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      expect(find.text('Thêm nhân sự'), findsOneWidget);
      expect(find.text('2 tài khoản'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      client.dispose();
    },
  );

  testWidgets('login layout fits desktop and short landscape viewport', (
    tester,
  ) async {
    final client = ApiClient(
      client: MockClient((_) async => testResponse('{}', 200)),
    );
    final auth = AuthController(AuthRepository(client, MemoryStore()));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(1440, 900), const Size(932, 430)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(SmartFarmApp(controller: auth));
      await tester.pumpAndSettle();
      await enterWorkspace(tester);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    client.dispose();
  });

  test('authenticated 401 revokes local session', () async {
    final store = MemoryStore()..token = 'old-token';
    final client = ApiClient(
      client: MockClient(
        (_) async => testResponse(
          jsonEncode({
            'error': {'message': 'Hết phiên'},
          }),
          401,
        ),
      ),
    );
    final auth = AuthController(AuthRepository(client, store));
    await auth.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(auth.user, isNull);
    expect(store.token, isNull);
    expect(auth.notice, contains('Phiên đã hết hạn'));
    auth.dispose();
    client.dispose();
  });

  testWidgets('staff deletion requires confirmation and refreshes the list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var removed = false;
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          expect(request.url.path.endsWith('/staff-id'), isTrue);
          expect(request.headers.containsKey('content-type'), isFalse);
          removed = true;
          return testResponse('', 204);
        }
        final users = [admin, if (!removed) staff];
        return testResponse(
          jsonEncode({'users': users, 'total': users.length, 'page': 1}),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(body: UsersPage(api: client)),
      ),
    );
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(find.text('Xóa'), findsOneWidget);
    await tester.ensureVisible(find.text('Xóa'));
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(removed, isFalse);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(removed, isFalse);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    await tester.tap(find.text('Xóa tài khoản'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(removed, isTrue);
    expect(find.text('Nhân viên mẫu'), findsNothing);
    expect(find.text('1 tài khoản'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  test('offline logout removes local credentials and reports unconfirmed revocation', () async {
    final store = MemoryStore()..token = 'existing-token';
    final client = ApiClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    client.token = store.token;
    final auth = AuthController(AuthRepository(client, store));
    auth.user = FarmUser.fromJson(staff);
    expect(await auth.logout(), isTrue);
    expect(auth.user, isNull);
    expect(store.token, isNull);
    expect(client.token, isNull);
    expect(auth.notice, contains('Chưa thể xác nhận'));
    auth.dispose();
    client.dispose();
  });

  test('network failure is presented as a retryable message', () async {
    final client = ApiClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      client.request('GET', '/auth/me'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Không kết nối'),
        ),
      ),
    );
    client.dispose();
  });

  test(
    'logout clears local token and user even if backend request throws',
    () async {
      final store = MemoryStore()..token = 'existing-token';
      final client = ApiClient(
        client: MockClient(
          (_) async =>
              testResponse('{"error": {"message": "Server Error"}}', 500),
        ),
      );
      final auth = AuthController(AuthRepository(client, store))
        ..user = FarmUser.fromJson(staff);
      await auth.logout();
      expect(auth.user, isNull);
      expect(store.token, isNull);
      auth.dispose();
      client.dispose();
    },
  );

  testWidgets('admin can delete staff from personnel page', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore()..token = 'test-token';
    bool deleted = false;
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path.contains('/users/')) {
          deleted = true;
          return testResponse('', 204);
        }
        if (request.url.path.endsWith('/users')) {
          return testResponse(
            jsonEncode({
              'users': deleted ? [admin] : [admin, staff],
              'total': deleted ? 1 : 2,
              'page': 1,
            }),
            200,
          );
        }
        return testResponse(jsonEncode({'user': admin}), 200);
      }),
    );
    final auth = AuthController(AuthRepository(client, store));
    await tester.pumpWidget(SmartFarmApp(controller: auth));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    await tester.tap(find.text('Nhân sự'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(find.text('2 tài khoản'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Xóa'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(find.textContaining('Xóa tài khoản'), findsAtLeast(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa tài khoản'));
    await tester.pumpAndSettle();
    await enterWorkspace(tester);
    expect(deleted, isTrue);
    expect(find.text('1 tài khoản'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    client.dispose();
  });
}
