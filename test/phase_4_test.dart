import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/animal_editor.dart';
import 'package:smart_farm/features/farm/species_chooser.dart';
import 'package:smart_farm/features/farm/inventory_page.dart';

http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
const s1 = '11111111-1111-4111-8111-111111111111';
const s2 = '22222222-2222-4222-8222-222222222222';
const b1 = '33333333-3333-4333-8333-333333333333';
void size(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'animal form fetches new species and can create breed without closing parent',
    (t) async {
      size(t);
      var requests = 0;
      final breeds = <Map<String, dynamic>>[];
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/code-suggestion')) {
            return response({'code': 'TEST_01'});
          }
          if (r.method == 'POST') {
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            expect(body['speciesId'], s2);
            breeds.add({'id': b1, 'name': body['name'], 'speciesId': s2});
            return response({
              'item': {'id': b1},
            });
          }
          requests++;
          return response({
            'species': [
              {'id': s1, 'name': 'Bò'},
              {'id': s2, 'name': 'Dê mới'},
            ],
            'breeds': breeds,
            'pens': [],
            'areas': [],
          });
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => animalForm(
                  context,
                  FarmRepository(api),
                  {'species': []},
                  null,
                  true,
                ),
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Mở form'));
      await t.pumpAndSettle();
      expect(requests, 1);
      await t.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Loài'));
      await t.pumpAndSettle();
      await t.tap(find.text('Dê mới').last);
      await t.pumpAndSettle();
      expect(
        find.text(
          'Loài này chưa có giống. Chủ trang trại cần tạo giống trước khi thêm vật nuôi.',
        ),
        findsOneWidget,
      );
      await t.ensureVisible(find.text('Thêm giống cho loài này'));
      await t.tap(find.text('Thêm giống cho loài này'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Tên giống'),
        'Boer mới',
      );
      await t.tap(find.widgetWithText(FilledButton, 'Lưu').last);
      await t.pumpAndSettle();
      expect(requests, 2);
      await t.ensureVisible(
        find.widgetWithText(DropdownButtonFormField<String>, 'Giống'),
      );
      await t.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Giống'),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Boer mới').last);
      await t.pumpAndSettle();
      expect(find.text('Boer mới'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'species chooser persists multiple choices and repository applies selected scope',
    (t) async {
      size(t);
      Map<String, dynamic>? saved;
      List<String>? selected;
      String? scope;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            saved = jsonDecode(r.body) as Map<String, dynamic>;
            return response({'ok': true});
          }
          if (r.url.path.endsWith('/preferences')) {
            return response({'speciesIds': []});
          }
          if (r.url.path.endsWith('/animals')) {
            scope = r.url.queryParameters['speciesIds'];
            return response({'animals': []});
          }
          return response({
            'species': [
              {'id': s1, 'name': 'Bò'},
              {'id': s2, 'name': 'Dê'},
            ],
          });
        }),
      );
      final repo = FarmRepository(api);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: SpeciesChooser(
            repository: repo,
            admin: false,
            userName: 'Nhân viên',
            onLogout: () {},
            onContinue: (ids) => selected = ids,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Bò'), findsOneWidget);
      await t.tap(find.text('Chọn theo nhóm'));
      await t.pumpAndSettle();
      expect(find.text('Gia súc'), findsOneWidget);
      await t.tap(find.text('Bò'));
      await t.ensureVisible(find.text('Dê'));
      await t.tap(find.text('Dê'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Tiếp tục (2 loài)'));
      await t.tap(find.text('Tiếp tục (2 loài)'));
      await t.pumpAndSettle();
      expect(saved!['speciesIds'], containsAll([s1, s2]));
      repo.selectedSpeciesIds = selected!;
      await repo.get('/animals?status=ACTIVE');
      expect(scope!.split(','), containsAll([s1, s2]));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'inventory accepts zero threshold and displays low stock; staff cannot cancel',
    (t) async {
      size(t);
      Map<String, dynamic>? created;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            created = jsonDecode(r.body) as Map<String, dynamic>;
            return response({
              'feed': {'id': b1},
            });
          }
          if (r.url.path.endsWith('/feeds')) {
            return response({
              'feeds': [
                {
                  'id': b1,
                  'code': 'F1',
                  'name': 'Cám',
                  'stock': 10,
                  'lowStock': 20,
                  'active': true,
                  'notes': '',
                },
              ],
            });
          }
          if (r.url.path.endsWith('/stock-entries')) {
            return response({
              'entries': [
                {
                  'id': s1,
                  'kind': 'OUT',
                  'quantity': 5,
                  'feedName': 'Cám',
                  'date': '2026-10-01',
                  'actorName': 'Admin',
                },
              ],
              'total': 1,
            });
          }
          return response({'pens': []});
        }),
      );
      final repo = FarmRepository(api);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(body: InventoryPage(repository: repo, admin: true)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tồn thấp'), findsOneWidget);
      await t.tap(find.text('Thêm thức ăn'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, 'Mã thức ăn'), 'F2');
      await t.enterText(
        find.widgetWithText(TextFormField, 'Tên thức ăn'),
        'Cỏ',
      );
      await t.ensureVisible(find.widgetWithText(FilledButton, 'Lưu thức ăn'));
      await t.tap(find.widgetWithText(FilledButton, 'Lưu thức ăn'));
      await t.pumpAndSettle();
      expect(created!['lowStock'], 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(body: InventoryPage(repository: repo, admin: false)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Thêm thức ăn'), findsNothing);
      await t.tap(find.text('Lịch sử nhập / xuất'));
      await t.pumpAndSettle();
      expect(find.text('Hủy phiếu'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
