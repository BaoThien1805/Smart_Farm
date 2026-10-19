import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';
import 'package:smart_farm/features/home/workspace_page.dart';
import 'package:smart_farm/features/farm/animal_editor.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/species_chooser.dart';

import 'farm_test.dart' as fixture;
import 'widget_test.dart' show MemoryStore;

Future<void> tapText(WidgetTester t, String text) async {
  final target = find.text(text).last;
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> fill(WidgetTester t, String label, String value) async {
  final target = find.widgetWithText(TextFormField, label).last;
  await t.ensureVisible(target);
  await t.enterText(target, value);
}

void main() {
  for (final role in ['STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets(
      '$role enters its working page directly without species preferences',
      (t) async {
        fixture.mobileSize(t);
        final paths = <String>[];
        final api = ApiClient(
          client: MockClient((r) async {
            paths.add(r.url.path);
            expect(r.url.path.endsWith('/preferences'), isFalse);
            expect(r.url.queryParameters.containsKey('speciesIds'), isFalse);
            if (r.url.path.endsWith('/catalogs')) {
              return fixture.response(fixture.catalogs);
            }
            return fixture.response({
              'animals': [],
              'tasks': [],
              'entries': [],
              'total': 0,
            });
          }),
        );
        final auth = AuthController(AuthRepository(api, MemoryStore()))
          ..user = FarmUser(
            id: role,
            email: 'user@example.test',
            name: 'Người dùng',
            role: role,
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
        expect(find.byTooltip('Đổi loài đang theo dõi'), findsNothing);
        expect(
          find.byType(switch (role) {
            'STAFF' => AnimalsPage,
            'VET' => CarePage,
            _ => FinancePage,
          }),
          findsOneWidget,
        );
        expect(paths, isNotEmpty);
        await t.pumpWidget(const SizedBox());
        auth.dispose();
        api.dispose();
      },
    );
  }

  testWidgets(
    'creates area and pen inside animal form, preserves draft and selects new pen',
    (t) async {
      fixture.mobileSize(t);
      final areas = <Map<String, dynamic>>[], pens = <Map<String, dynamic>>[];
      Map<String, dynamic>? animalBody;
      var penAttempts = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return fixture.response({
              ...fixture.catalogs,
              'areas': areas,
              'pens': pens,
            });
          }
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          if (r.url.path.endsWith('/areas')) {
            areas.add({'id': 'area-new', 'name': body['name']});
            return fixture.response({
              'item': {'id': 'area-new'},
            });
          }
          if (r.url.path.endsWith('/pens')) {
            penAttempts++;
            expect(body['areaId'], 'area-new');
            expect(body['capacity'], 5);
            if (penAttempts == 1) {
              return fixture.response({
                'error': {'message': 'Mã chuồng đã tồn tại.'},
              }, 409);
            }
            pens.add({'id': 'pen-new', ...body, 'occupied': 0});
            return fixture.response({
              'item': {'id': 'pen-new'},
            });
          }
          animalBody = body;
          return fixture.response({'ok': true});
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    animalForm(context, FarmRepository(api), {}, null, true),
                child: const Text('Mở form'),
              ),
            ),
          ),
        ),
      );
      await tapText(t, 'Mở form');
      await fill(t, 'Mã vật nuôi', 'GOAT-DRAFT');
      await fill(t, 'Tên / số hiệu (tùy chọn)', 'Dê đang nhập');
      await tapText(t, 'Thêm chuồng');
      expect(find.text('Tên khu vực'), findsOneWidget);
      await fill(t, 'Tên khu vực', 'Khu mới');
      await tapText(t, 'Lưu');
      expect(find.text('Tên chuồng'), findsOneWidget);
      await fill(t, 'Mã chuồng', 'P-NEW');
      await fill(t, 'Tên chuồng', 'Chuồng mới');
      await fill(t, 'Sức chứa (con)', '2.5');
      await tapText(t, 'Lưu');
      expect(penAttempts, 0);
      await fill(t, 'Sức chứa (con)', '5');
      await tapText(t, 'Lưu');
      expect(find.text('Mã chuồng đã tồn tại.'), findsOneWidget);
      await tapText(t, 'Lưu');
      expect(penAttempts, 2);
      expect(find.text('P-NEW · Chuồng mới (0/5)'), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mã vật nuôi'),
            )
            .controller!
            .text,
        'GOAT-DRAFT',
      );
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Tên / số hiệu (tùy chọn)'),
            )
            .controller!
            .text,
        'Dê đang nhập',
      );
      final species = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Loài',
      );
      await t.ensureVisible(species);
      await t.tap(species);
      await t.pumpAndSettle();
      await tapText(t, 'Dê');
      final breed = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Giống',
      );
      await t.ensureVisible(breed);
      await t.tap(breed);
      await t.pumpAndSettle();
      await tapText(t, 'Boer');
      await tapText(t, 'Lưu');
      expect(animalBody!['penId'], 'pen-new');
      expect(animalBody!['code'], 'GOAT-DRAFT');
      expect(find.byType(AnimalEditor), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets(
    'canceling area creation leaves the animal draft intact and does not create a pen',
    (t) async {
      fixture.mobileSize(t);
      var writes = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method != 'GET') writes++;
          return fixture.response({
            ...fixture.catalogs,
            'areas': [],
            'pens': [],
          });
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: AnimalEditor(repository: FarmRepository(api), admin: true),
        ),
      );
      await t.pumpAndSettle();
      await fill(t, 'Mã vật nuôi', 'KEPT');
      await tapText(t, 'Thêm chuồng');
      await fill(t, 'Tên khu vực', 'Không lưu');
      await tapText(t, 'Hủy');
      expect(writes, 0);
      expect(find.text('Tên chuồng'), findsNothing);
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mã vật nuôi'),
            )
            .controller!
            .text,
        'KEPT',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets('staff cannot create area or pen through animal form', (t) async {
    fixture.mobileSize(t);
    final api = ApiClient(
      client: MockClient(
        (_) async => fixture.response({...fixture.catalogs, 'pens': []}),
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: AnimalEditor(repository: FarmRepository(api), admin: false),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Thêm khu vực'), findsNothing);
    expect(find.text('Thêm chuồng'), findsNothing);
    expect(
      find.text(
        'Chưa có chuồng còn chỗ. Hãy liên hệ chủ trang trại để bổ sung chuồng.',
      ),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    api.dispose();
  });
}
