import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/users/users_page.dart';
import 'package:smart_farm/features/users/users_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';

import 'farm_test.dart' as fixture;

void main() {
  test(
    'legacy deletion conflict explains upgrade and a retry refreshes personnel',
    () async {
      var legacy = true;
      const user = FarmUser(
        id: 'employee',
        email: 'employee@example.test',
        name: 'Nhân viên',
        role: 'STAFF',
        active: true,
      );
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'DELETE') {
            return legacy
                ? fixture.response({
                    'error': {
                      'code': 'DATA_CONFLICT',
                      'message': 'Dữ liệu đã được sử dụng trong lịch sử.',
                    },
                  }, 409)
                : fixture.response({}, 204);
          }
          return fixture.response({'users': [], 'total': 0});
        }),
      );
      addTearDown(api.dispose);
      final controller = UsersController(api)
        ..users = [user]
        ..total = 1;
      addTearDown(controller.dispose);
      expect(await controller.deleteUser(user), isFalse);
      expect(controller.error, contains('backend v11'));
      expect(controller.users.single.id, user.id);
      expect(controller.saving, isFalse);
      legacy = false;
      expect(await controller.deleteUser(user), isTrue);
      expect(controller.users, isEmpty);
      expect(controller.total, 0);
      expect(controller.error, isNull);
    },
  );
  testWidgets(
    'personnel edits remain a draft until save; validation blocks bad email',
    (t) async {
      fixture.mobileSize(t);
      var writes = 0, refreshes = 0;
      var user = <String, dynamic>{
        'id': 'staff',
        'code': 'NV-01',
        'name': 'Nhân viên cũ',
        'email': 'staff@example.test',
        'role': 'STAFF',
        'active': true,
      };
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            expect(r.url.path.endsWith('/users/staff'), isTrue);
            writes++;
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            expect(body.containsKey('photoBase64'), isFalse);
            user = {...user, ...body};
          }
          return fixture.response({
            'users': [user],
            'total': 1,
          });
        }),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: UsersPage(
              api: api,
              onProfileChanged: () async {
                refreshes++;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Đổi ảnh đại diện'), findsNothing);
      await t.tap(find.byKey(const ValueKey('personnel-menu-staff')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Chỉnh sửa'));
      await t.pumpAndSettle();
      final name = find.widgetWithText(TextFormField, 'Họ và tên');
      await t.ensureVisible(name);
      await t.enterText(name, 'Tên bị hủy');
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Nhân viên cũ'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('personnel-menu-staff')));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Chỉnh sửa'));
      await t.pumpAndSettle();
      await t.ensureVisible(name);
      await t.enterText(name, 'Nhân viên mới');
      final email = find.widgetWithText(TextFormField, 'Email');
      await t.ensureVisible(email);
      await t.enterText(email, 'bad-email');
      await t.tap(find.text('Lưu thay đổi'));
      await t.pumpAndSettle();
      expect(writes, 0);
      await t.enterText(email, 'new@example.test');
      await t.tap(find.text('Lưu thay đổi'));
      await t.pumpAndSettle();
      expect(writes, 1);
      expect(refreshes, 1);
      expect(find.text('Nhân viên mới'), findsOneWidget);
      expect(find.text('new@example.test'), findsOneWidget);
      expect(user['code'], 'NV-01');
      expect(t.takeException(), isNull);
    },
  );
}
