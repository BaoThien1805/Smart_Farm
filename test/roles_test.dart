import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/users/users_controller.dart';

import 'farm_test.dart' as fixture;

void main() {
  test('roles grant only their intended capabilities', () {
    FarmUser user(String role) => FarmUser(
      id: 'id',
      email: 'a@test.local',
      name: 'User',
      role: role,
      active: true,
    );
    expect(user('VET').canExamine, isTrue);
    expect(user('VET').canCare, isTrue);
    expect(user('VET').canOperate, isFalse);
    expect(user('VET').canFinance, isFalse);
    expect(user('ACCOUNTANT').canFinance, isTrue);
    expect(user('ACCOUNTANT').canOperate, isFalse);
    expect(user('ACCOUNTANT').canCare, isFalse);
    expect(user('STAFF').canExamine, isFalse);
    expect(user('ADMIN').canFinance, isTrue);
  });

  test('personnel creation sends selected professional role', () async {
    Map<String, dynamic>? body;
    final api = ApiClient(
      client: MockClient((r) async {
        if (r.method == 'POST') {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return fixture.response({});
        }
        return fixture.response({'users': [], 'total': 0});
      }),
    );
    final controller = UsersController(api);
    expect(
      await controller.create(
        'Bác sĩ',
        'vet@test.local',
        'password-12-chars',
        role: 'VET',
      ),
      isTrue,
    );
    expect(body!['role'], 'VET');
    controller.dispose();
  });

  testWidgets(
    'vet sees clinical form, sends diagnosis and has no animal operation controls',
    (tester) async {
      fixture.mobileSize(tester);
      Map<String, dynamic>? body;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.path.endsWith('/exams'), isTrue);
            body = jsonDecode(r.body) as Map<String, dynamic>;
            return fixture.response({'ok': true});
          }
          if (r.url.path.endsWith('/catalogs')) {
            return fixture.response(fixture.catalogs);
          }
          return fixture.response({
            'animal': fixture.animal,
            'weights': [],
            'transfers': [],
            'healthRecords': [],
            'careTasks': [],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: AnimalDetailPage(
            repository: FarmRepository(api),
            admin: false,
            id: fixture.animal['id']!,
            canOperate: false,
            canCare: true,
            canExamine: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sửa hồ sơ'), findsNothing);
      expect(find.text('Ghi cân nặng'), findsNothing);
      expect(find.text('Bán vật nuôi'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('profile-tab-2')));
      await tester.tap(find.byKey(const ValueKey('profile-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('Khám thú y'), findsOneWidget);
      await tester.tap(find.text('Khám thú y'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nội dung kiểm tra / điều trị'),
        'Khám định kỳ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Chẩn đoán'),
        'Viêm da',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hướng dẫn điều trị'),
        'Tái khám',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu kết quả khám'));
      await tester.pumpAndSettle();
      expect(body!['diagnosis'], 'Viêm da');
      expect(body!['treatment'], 'Tái khám');
      expect(body!['requestId'], isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accountant reads clinical and sales history without write or cancel controls',
    (tester) async {
      fixture.mobileSize(tester);
      final api = ApiClient(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          if (r.url.path.endsWith('/catalogs')) {
            return fixture.response(fixture.catalogs);
          }
          if (r.url.path.endsWith('/sales')) {
            return fixture.response({
              'sales': [
                {
                  'id': 'sale',
                  'animalCode': 'GOAT-01',
                  'amount': '1000000',
                  'date': '2026-01-01',
                  'actorName': 'Chủ',
                  'cancelledAt': null,
                },
              ],
              'total': 1,
            });
          }
          return fixture.response({
            'animal': fixture.animal,
            'weights': [],
            'transfers': [],
            'healthRecords': [
              {
                'date': '2026-01-01',
                'content': 'Khám',
                'status': 'NORMAL',
                'recordType': 'EXAM',
                'diagnosis': 'Ổn định',
                'treatment': 'Theo dõi',
                'actorName': 'Bác sĩ',
              },
            ],
            'careTasks': [],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: AnimalDetailPage(
            repository: FarmRepository(api),
            admin: false,
            id: fixture.animal['id']!,
            canOperate: false,
            canCare: false,
            canFinance: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SalesHistory, skipOffstage: false), findsOneWidget);
      for (final text in [
        'Hủy bán',
        'Bán vật nuôi',
        'Khám thú y',
        'Đặt lịch chăm sóc',
        'Ghi sức khỏe',
        'Sửa hồ sơ',
        'Ghi cân nặng',
      ]) {
        expect(find.text(text), findsNothing);
      }
      await tester.ensureVisible(find.byKey(const ValueKey('profile-tab-2')));
      await tester.tap(find.byKey(const ValueKey('profile-tab-2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chẩn đoán: Ổn định'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
