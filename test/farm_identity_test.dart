import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/auth/user_avatar.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/species_chooser.dart';
import 'package:smart_farm/features/home/workspace_page.dart';
import 'package:smart_farm/features/users/users_controller.dart';
import 'package:smart_farm/features/users/users_page.dart';

import 'farm_test.dart' as fixture;
import 'widget_test.dart' show MemoryStore;

void main() {
  testWidgets(
    'configured owner skips species setup on subsequent sessions and adds species from catalog',
    (t) async {
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var setups = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          if (r.url.path.endsWith('/species-settings')) {
            setups++;
            return fixture.response({
              'configured': true,
              'speciesIds': ['cow'],
            });
          }
          if (r.url.path.endsWith('/catalogs')) {
            return fixture.response({
              'species': [
                {'id': 'cow', 'name': 'Bò'},
              ],
              'breeds': [],
              'areas': [],
              'pens': [],
            });
          }
          if (r.url.path.endsWith('/weather')) {
            return fixture.response({
              'error': {'message': 'Chưa đặt vị trí'},
            }, 409);
          }
          return fixture.response({});
        }),
      );
      for (var i = 0; i < 2; i++) {
        final auth = AuthController(AuthRepository(api, MemoryStore()))
          ..user = const FarmUser(
            id: 'owner',
            email: 'owner@example.test',
            name: 'Chủ',
            role: 'ADMIN',
            active: true,
          )
          ..initializing = false;
        await t.pumpWidget(
          MaterialApp(
            theme: farmTheme(),
            home: WorkspacePage(auth: auth),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(SpeciesChooser), findsNothing);
        expect(find.textContaining('Chọn loài ·'), findsNothing);
        final add = find.text('Thêm loài').first;
        await t.ensureVisible(add);
        await t.tap(add);
        await t.pumpAndSettle();
        expect(find.byType(CatalogPage), findsOneWidget);
        expect(find.text('Bò'), findsOneWidget);
        expect(find.text('Dê'), findsNothing);
        await t.pumpWidget(const SizedBox());
        auth.dispose();
      }
      expect(setups, 2);
      api.dispose();
    },
  );

  for (final vet in [false, true]) {
    testWidgets(
      'care completion button is ${vet ? 'available to vet' : 'hidden from staff'}',
      (t) async {
        fixture.mobileSize(t);
        final api = ApiClient(
          client: MockClient(
            (_) async => fixture.response({
              'tasks': [
                {
                  'id': 'task',
                  'animalId': 'animal',
                  'animalCode': 'B01',
                  'title': 'Khám',
                  'kind': 'CHECKUP',
                  'dueDate': '2026-01-01',
                  'status': 'PENDING',
                  'notes': '',
                },
              ],
              'total': 1,
              'today': '2026-10-13',
            }),
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: farmTheme(),
            home: Scaffold(
              body: CarePage(
                repository: FarmRepository(api),
                admin: false,
                canExamine: vet,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Hoàn thành'), vet ? findsOneWidget : findsNothing);
        expect(find.text('Sửa lịch'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        api.dispose();
      },
    );
  }

  test(
    'avatar JSON and controller preserve role while updating image',
    () async {
      final user = FarmUser.fromJson({
        'id': 'staff',
        'email': 'staff@example.test',
        'name': 'Nhân viên',
        'role': 'STAFF',
        'active': true,
        'avatarData': 'data:image/jpeg;base64,AAAA',
      });
      expect(user.avatarData, isNotNull);
      expect(user.role, 'STAFF');
      Map<String, dynamic>? body;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            body = jsonDecode(r.body) as Map<String, dynamic>;
            expect(r.url.path, '/api/users/staff/avatar');
            return fixture.response({});
          }
          return fixture.response({'users': [], 'total': 0});
        }),
      );
      final controller = UsersController(api);
      expect(await controller.setAvatar(user, 'AAAA'), isTrue);
      expect(body, {'photoBase64': 'AAAA'});
      expect(await controller.setAvatar(user, null), isTrue);
      expect(body, {'photoBase64': null});
      controller.dispose();
      api.dispose();
    },
  );

  testWidgets('owner can remove avatar from personnel and list refreshes', (
    t,
  ) async {
    fixture.mobileSize(t);
    String? avatar = 'data:image/jpeg;base64,invalid-image';
    final api = ApiClient(
      client: MockClient((r) async {
        if (r.method == 'PATCH') {
          expect((jsonDecode(r.body) as Map)['photoBase64'], isNull);
          avatar = null;
          return fixture.response({});
        }
        return fixture.response({
          'users': [
            {
              'id': 'staff',
              'email': 'staff@example.test',
              'name': 'Nhân viên',
              'role': 'STAFF',
              'active': true,
              'avatarData': avatar,
            },
          ],
          'total': 1,
        });
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(body: UsersPage(api: api)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.text('Đổi ảnh đại diện'), findsNothing);
    await t.tap(find.byKey(const ValueKey('personnel-menu-staff')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Chỉnh sửa'));
    await t.pumpAndSettle();
    final remove = find.text('Bỏ ảnh');
    await t.ensureVisible(remove);
    await t.tap(remove);
    await t.pumpAndSettle();
    expect(avatar, isNotNull);
    await t.tap(find.text('Lưu thay đổi'));
    await t.pumpAndSettle();
    expect(avatar, isNull);
    expect(find.text('Xóa ảnh đại diện'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    api.dispose();
  });
}
