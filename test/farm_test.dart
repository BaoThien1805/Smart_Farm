import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
const animal = {
  'id': '11111111-1111-4111-8111-111111111111',
  'code': 'GOAT-01',
  'breedId': '22222222-2222-4222-8222-222222222222',
  'speciesId': '33333333-3333-4333-8333-333333333333',
  'speciesName': 'Dê',
  'breedName': 'Boer',
  'gender': 'FEMALE',
  'birthDate': null,
  'arrivalDate': '2026-01-01',
  'penId': '44444444-4444-4444-8444-444444444444',
  'penName': 'Chuồng A',
  'origin': '',
  'notes': '',
  'status': 'ACTIVE',
  'healthStatus': 'NEEDS_CARE',
};
const catalogs = {
  'species': [
    {'id': '33333333-3333-4333-8333-333333333333', 'name': 'Dê'},
  ],
  'breeds': [
    {
      'id': '22222222-2222-4222-8222-222222222222',
      'name': 'Boer',
      'speciesId': '33333333-3333-4333-8333-333333333333',
    },
  ],
  'areas': [],
  'pens': [
    {
      'id': '44444444-4444-4444-8444-444444444444',
      'code': 'P1',
      'name': 'Chuồng A',
      'active': true,
      'occupied': 1,
      'capacity': 10,
    },
  ],
};
void mobileSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'staff detail renders chart; invalid weight is blocked before API call',
    (tester) async {
      mobileSize(tester);
      var calls = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            calls++;
            return response({'ok': true});
          }
          if (r.url.path.endsWith('/catalogs')) return response(catalogs);
          return response({
            'animal': animal,
            'weights': [
              {
                'date': '2026-01-01',
                'kg': 20,
                'notes': '',
                'actorName': 'Admin',
              },
              {
                'date': '2026-01-15',
                'kg': 25,
                'notes': '',
                'actorName': 'Admin',
              },
            ],
            'healthRecords': [],
            'transfers': [],
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
            id: animal['id']!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GOAT-01'), findsOneWidget);
      expect(find.text('Ghi nhận chết'), findsNothing);
      expect(find.byType(WeightChart), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ghi cân nặng'));
      await tester.tap(find.text('Ghi cân nặng'));
      await tester.pumpAndSettle();
      final kg = find.widgetWithText(TextFormField, 'Cân nặng (kg)');
      await tester.enterText(kg, '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập số lớn hơn 0.'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(kg, '25.5');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'care completion retry reuses request id and keeps server error in form',
    (tester) async {
      mobileSize(tester);
      final bodies = <Map<String, dynamic>>[];
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
            if (bodies.length == 1) {
              return response({
                'error': {'message': 'Thử lại sau.'},
              }, 503);
            }
            return response({'ok': true});
          }
          return response({
            'tasks': [
              {
                'id': '55555555-5555-4555-8555-555555555555',
                'animalId': animal['id'],
                'animalCode': 'GOAT-01',
                'title': 'Kiểm tra lại',
                'kind': 'CHECKUP',
                'dueDate': '2026-01-10',
                'status': bodies.length > 1 ? 'DONE' : 'PENDING',
                'notes': '',
              },
            ],
            'total': 1,
            'today': '2026-10-01',
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: CarePage(
              repository: FarmRepository(api),
              admin: false,
              canExamine: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quá hạn'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hoàn thành'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại sau.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(bodies.length, 2);
      expect(bodies[0]['requestId'], bodies[1]['requestId']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Hoàn thành'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets('search query and read only staff catalog work on phone', (
    tester,
  ) async {
    mobileSize(tester);
    final searches = <String>[];
    final api = ApiClient(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/catalogs')) return response(catalogs);
        searches.add(r.url.queryParameters['search'] ?? '');
        return response({'animals': [], 'total': 0});
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: AnimalsPage(repository: FarmRepository(api), admin: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'GOAT-X');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(searches.last, 'GOAT-X');
    expect(find.text('Không có vật nuôi phù hợp.'), findsOneWidget);
    await tester.tap(find.text('Chuồng & danh mục'));
    await tester.pumpAndSettle();
    expect(find.text('1/10 con · Đang sử dụng'), findsOneWidget);
    expect(find.byTooltip('Sửa'), findsNothing);
    expect(find.byTooltip('Xóa'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
}
