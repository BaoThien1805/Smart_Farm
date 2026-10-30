import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/farm_illustrations.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/pen_icon_picker.dart';

import 'photo_workflow_test.dart' show ImagePicker;
import 'animal_editor_redesign_test.dart' show CancelPicker;
import 'support/animals_fixture.dart' show AnimalsFixture;

import 'support/catalog_fixture.dart';
import 'support/ui_preview.dart';

Future<CatalogFixture> mountCatalog(
  WidgetTester t, {
  CatalogFixture? fixture,
  String kind = 'pens',
  String role = 'ADMIN',
  double width = 412,
  GlobalKey? boundary,
  List<String> availableKinds = const ['pens', 'areas', 'species', 'breeds'],
}) async {
  final source = fixture ?? CatalogFixture();
  addTearDown(source.dispose);
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Scaffold(
        body: CatalogPage(
          repository: source.repository,
          admin: role == 'ADMIN',
          canOperate: role == 'STAFF',
          canCare: ['STAFF', 'VET'].contains(role),
          canExamine: role == 'VET',
          canFinance: role == 'ACCOUNTANT',
          initialKind: kind,
          availableKinds: availableKinds,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return source;
}

Future<void> tapCatalog(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> catalogAction(WidgetTester t, String label) async {
  await tapCatalog(t, find.byTooltip('Thao tác').first);
  await tapCatalog(t, find.widgetWithText(PopupMenuItem<String>, label));
}

Future<void> saveCatalog(WidgetTester t) =>
    tapCatalog(t, find.widgetWithText(FilledButton, 'Lưu'));
Future<void> choose(WidgetTester t, String label, String text) async {
  if (['Khu vực', 'Sử dụng'].contains(label) &&
      find
          .widgetWithText(DropdownButtonFormField<String>, label)
          .evaluate()
          .isEmpty) {
    await tapCatalog(t, find.text('Bộ lọc chuồng'));
  }
  await tapCatalog(
    t,
    find.widgetWithText(DropdownButtonFormField<String>, label).last,
  );
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

Future<void> captureCatalog(
  WidgetTester t,
  GlobalKey boundary,
  String name,
) async {
  final context = t.element(find.byType(Scaffold).first);
  final images = t.widgetList<Image>(find.byType(Image)).toList();
  await t.runAsync(
    () => Future.wait(images.map((i) => precacheImage(i.image, context))),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, boundary, '$name.png');
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final hasAreas in [false, true]) {
    testWidgets(
      'pen form creates and selects an area without losing input (existing: $hasAreas)',
      (t) async {
        final fixture = CatalogFixture();
        if (!hasAreas) {
          fixture.data['areas']!.clear();
          fixture.data['pens']!.clear();
        }
        await mountCatalog(
          t,
          fixture: fixture,
          availableKinds: const ['pens'],
          width: hasAreas ? 412 : 360,
        );
        await tapCatalog(t, find.widgetWithText(FilledButton, 'Thêm'));
        await t.enterText(
          find.widgetWithText(TextFormField, 'Tên'),
          'Chuồng mới',
        );
        await t.enterText(
          find.widgetWithText(TextFormField, 'Mã chuồng'),
          'CH-01',
        );
        await t.enterText(
          find.widgetWithText(TextFormField, 'Sức chứa (con)'),
          '25',
        );
        await tapCatalog(t, find.widgetWithText(TextButton, 'Thêm khu vực'));
        await t.enterText(
          find.widgetWithText(TextFormField, 'Tên khu vực'),
          'Khu mới',
        );
        await tapCatalog(t, find.widgetWithText(FilledButton, 'Lưu').last);
        final area = fixture.data['areas']!.last;
        expect(area['name'], 'Khu mới');
        expect(
          t
              .widget<DropdownButtonFormField<String>>(
                find
                    .widgetWithText(DropdownButtonFormField<String>, 'Khu vực')
                    .last,
              )
              .initialValue,
          area['id'],
        );
        expect(
          t
              .widget<TextFormField>(find.widgetWithText(TextFormField, 'Tên'))
              .controller!
              .text,
          'Chuồng mới',
        );
        await saveCatalog(t);
        expect(fixture.data['pens']!.last, containsPair('areaId', area['id']));
        expect(fixture.bodies.last, containsPair('code', 'CH-01'));
        expect(fixture.bodies.last, containsPair('capacity', 25));
        expect(find.text('Thêm chuồng trại'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('failed or cancelled area creation keeps the pen form usable', (
    t,
  ) async {
    final fixture = CatalogFixture();
    fixture.data['areas']!.clear();
    fixture.data['pens']!.clear();
    fixture.saveError = 'Tên khu vực đã tồn tại.';
    await mountCatalog(t, fixture: fixture, availableKinds: const ['pens']);
    await tapCatalog(t, find.widgetWithText(FilledButton, 'Thêm'));
    await t.enterText(
      find.widgetWithText(TextFormField, 'Tên'),
      'Chuồng giữ lại',
    );
    await tapCatalog(t, find.widgetWithText(TextButton, 'Thêm khu vực'));
    await t.enterText(
      find.widgetWithText(TextFormField, 'Tên khu vực'),
      'Khu A',
    );
    await tapCatalog(t, find.widgetWithText(FilledButton, 'Lưu').last);
    expect(find.text('Tên khu vực đã tồn tại.'), findsOneWidget);
    expect(fixture.data['areas'], isEmpty);
    await tapCatalog(t, find.widgetWithText(TextButton, 'Hủy').last);
    expect(
      t
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Tên'))
          .controller!
          .text,
      'Chuồng giữ lại',
    );
    final save = find.widgetWithText(FilledButton, 'Lưu');
    expect(t.widget<FilledButton>(save).onPressed, isNotNull);
    await saveCatalog(t);
    expect(find.text('Vui lòng chọn.'), findsOneWidget);
    expect(fixture.data['pens'], isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'pen icon preset persists independently of residents and resets to automatic',
    (t) async {
      final fixture = await mountCatalog(t);
      await catalogAction(t, 'Sửa');
      await tapCatalog(t, find.text('Chọn icon'));
      await tapCatalog(t, find.byKey(const ValueKey('pen-icon-fish')));
      await tapCatalog(t, find.text('Dùng icon này'));
      await saveCatalog(t);
      expect(fixture.bodies.single['iconKey'], 'fish');
      expect(fixture.bodies.single.containsKey('iconBase64'), isFalse);
      final card = find.byKey(const ValueKey('pen-mixed'));
      final art = find.descendant(
        of: card,
        matching: find.byType(FarmPenIllustration),
      );
      expect(t.widget<FarmPenIllustration>(art).iconKey, 'fish');
      expect(fixture.data['pens']![1].containsKey('iconKey'), isFalse);
      await catalogAction(t, 'Sửa');
      await tapCatalog(t, find.text('Chọn icon'));
      await tapCatalog(t, find.byKey(const ValueKey('pen-icon-auto')));
      await tapCatalog(t, find.text('Dùng icon này'));
      await saveCatalog(t);
      expect(fixture.bodies.last['iconKey'], 'auto');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel pen icon selection preserves saved custom icon without resending image',
    (t) async {
      final fixture = CatalogFixture();
      fixture.data['pens']!.first.addAll({
        'iconKey': 'custom',
        'iconData': 'data:image/png;base64,${AnimalsFixture.photo}',
      });
      await mountCatalog(t, fixture: fixture);
      await catalogAction(t, 'Sửa');
      await tapCatalog(t, find.text('Chọn icon'));
      expect(find.byKey(const ValueKey('pen-icon-custom')), findsOneWidget);
      await tapCatalog(t, find.byKey(const ValueKey('pen-icon-pig')));
      await tapCatalog(t, find.widgetWithText(TextButton, 'Hủy').last);
      await saveCatalog(t);
      expect(fixture.bodies.single.containsKey('iconKey'), isFalse);
      expect(fixture.data['pens']!.first['iconKey'], 'custom');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'uploaded pen icon previews before save and survives server-error retry',
    (t) async {
      final fixture = CatalogFixture()..saveError = 'Chưa lưu được chuồng.';
      final previous = FileSelectorPlatform.instance;
      addTearDown(() => FileSelectorPlatform.instance = previous);
      FileSelectorPlatform.instance = ImagePicker(
        base64Decode(AnimalsFixture.photo),
      );
      await mountCatalog(t, fixture: fixture);
      await catalogAction(t, 'Sửa');
      await tapCatalog(t, find.text('Chọn icon'));
      await t.ensureVisible(find.text('Tải icon từ thiết bị'));
      await t.runAsync(() async {
        await t.tap(find.text('Tải icon từ thiết bị'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pen-icon-custom')), findsOneWidget);
      await tapCatalog(t, find.text('Dùng icon này'));
      await saveCatalog(t);
      expect(find.text(fixture.saveError!), findsOneWidget);
      expect(fixture.bodies.single['iconKey'], 'custom');
      expect(
        base64Decode(fixture.bodies.single['iconBase64'] as String),
        isNotEmpty,
      );
      fixture.saveError = null;
      await saveCatalog(t);
      expect(fixture.bodies.first, fixture.bodies.last);
      expect(
        fixture.data['pens']!.first['iconData'],
        startsWith('data:image/png;base64,'),
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final action in ['cancel', 'invalid']) {
    testWidgets(
      'pen icon file $action keeps draft and does not upload invalid data',
      (t) async {
        final fixture = await mountCatalog(t);
        final previous = FileSelectorPlatform.instance;
        addTearDown(() => FileSelectorPlatform.instance = previous);
        FileSelectorPlatform.instance = action == 'cancel'
            ? CancelPicker()
            : ImagePicker(Uint8List.fromList([1, 2, 3]));
        await catalogAction(t, 'Sửa');
        await tapCatalog(t, find.text('Chọn icon'));
        await tapCatalog(t, find.byKey(const ValueKey('pen-icon-pig')));
        await t.ensureVisible(find.text('Tải icon từ thiết bị'));
        await t.runAsync(() async {
          await t.tap(find.text('Tải icon từ thiết bị'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await t.pumpAndSettle();
        if (action == 'invalid') {
          expect(find.textContaining('Ảnh phải là JPEG/PNG'), findsOneWidget);
        }
        await tapCatalog(t, find.text('Dùng icon này'));
        await saveCatalog(t);
        expect(fixture.bodies.single['iconKey'], 'pig');
        expect(fixture.bodies.single.containsKey('iconBase64'), isFalse);
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final width in [360.0, 1200.0]) {
    testWidgets('pen icon picker fits $width and retains form draft', (
      t,
    ) async {
      final fixture = CatalogFixture();
      final boundary = GlobalKey();
      await mountCatalog(t, fixture: fixture, width: width, boundary: boundary);
      await catalogAction(t, 'Sửa');
      await tapCatalog(t, find.text('Chọn icon'));
      await captureCatalog(t, boundary, 'pen-icon-picker-${width.toInt()}');
      await tapCatalog(t, find.byKey(const ValueKey('pen-icon-rabbit')));
      await captureCatalog(
        t,
        boundary,
        'pen-icon-picker-bottom-${width.toInt()}',
      );
      await tapCatalog(t, find.text('Dùng icon này'));
      expect(find.byType(PenIconDialog), findsNothing);
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mã chuồng'),
            )
            .controller!
            .text,
        'A1',
      );
      await saveCatalog(t);
      expect(fixture.bodies.single['iconKey'], 'rabbit');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'pens use real occupancy and neutral art without fetching animals',
    (t) async {
      final fixture = await mountCatalog(t);
      expect(fixture.requests.length, 1);
      expect(find.byType(FarmPenIllustration), findsNWidgets(4));
      expect(find.byType(FarmSpeciesIllustration), findsNothing);
      expect(find.text('8/10 con'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu sức chứa.'), findsOneWidget);
      expect(find.text('Bình thường'), findsNothing);
      final bars = t.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bars.map((bar) => bar.value), [0.8, 1.0, 0.0]);
    },
  );

  for (final role in ['STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets(
      '$role opens pen-filtered active animals without gaining permissions',
      (t) async {
        final fixture = await mountCatalog(t, role: role);
        expect(find.byTooltip('Sửa'), findsNothing);
        expect(find.byTooltip('Xóa'), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Thêm'), findsNothing);
        fixture.repository.selectedSpeciesIds = ['cow'];
        await t.enterText(find.byType(TextField), 'A1');
        await t.pumpAndSettle();
        await tapCatalog(t, find.byKey(const ValueKey('pen-mixed')));
        final page = t.widget<AnimalsPage>(find.byType(AnimalsPage));
        expect(page.initialPenId, 'mixed');
        expect(find.text('Chuồng & danh mục'), findsNothing);
        expect(page.canOperate, role == 'STAFF');
        expect(page.canCare, role != 'ACCOUNTANT');
        expect(page.canExamine, role == 'VET');
        expect(page.canFinance, role == 'ACCOUNTANT');
        final request = fixture.requests.lastWhere(
          (r) => r.url.path.endsWith('/animals'),
        );
        expect(request.url.queryParameters['penId'], 'mixed');
        expect(request.url.queryParameters['status'], 'ACTIVE');
        expect(request.url.queryParameters['speciesIds'], 'cow');
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text,
          'A1',
        );
        expect(find.byKey(const ValueKey('pen-mixed')), findsOneWidget);
        expect(find.byKey(const ValueKey('pen-full')), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'catalog search and relational filters stay local and use actual IDs',
    (t) async {
      final fixture = await mountCatalog(t);
      await choose(t, 'Khu vực', 'Khu B');
      expect(find.byKey(const ValueKey('pen-full')), findsOneWidget);
      expect(find.byKey(const ValueKey('pen-mixed')), findsNothing);
      await choose(t, 'Khu vực', 'Tất cả khu vực');
      await choose(t, 'Sử dụng', 'Ngừng sử dụng');
      expect(find.byKey(const ValueKey('pen-inactive')), findsOneWidget);
      expect(find.byKey(const ValueKey('pen-full')), findsNothing);
      await tapCatalog(t, find.widgetWithText(ChoiceChip, 'Loài'));
      await tapCatalog(t, find.text('Xem giống của loài').first);
      expect(find.text('Loài: Bò'), findsOneWidget);
      expect(find.text('Landrace'), findsNothing);
      await choose(t, 'Lọc loài', 'Tất cả loài');
      await t.enterText(find.byType(TextField), 'Heo');
      await t.pumpAndSettle();
      expect(find.text('Landrace'), findsOneWidget);
      expect(fixture.requests.length, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pen form keeps code required and capacity integer within server range',
    (t) async {
      final fixture = await mountCatalog(t);
      await tapCatalog(t, find.widgetWithText(FilledButton, 'Thêm'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Tên'),
        'Chuồng mới',
      );
      await choose(t, 'Khu vực', 'Khu B');
      final capacity = find.widgetWithText(TextFormField, 'Sức chứa (con)');
      for (final value in ['0', '1.5', '100001', 'NaN', 'Infinity']) {
        await t.enterText(capacity, value);
        await saveCatalog(t);
        expect(fixture.bodies, isEmpty);
      }
      await t.enterText(capacity, '100000');
      await t.enterText(find.widgetWithText(TextFormField, 'Mã chuồng'), '');
      await saveCatalog(t);
      expect(fixture.bodies, isEmpty);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Mã chuồng'),
        'NEW-PEN',
      );
      await tapCatalog(t, find.byType(SwitchListTile));
      await saveCatalog(t);
      expect(fixture.bodies.single, {
        'code': 'NEW-PEN',
        'name': 'Chuồng mới',
        'areaId': 'area-b',
        'capacity': 100000,
        'active': false,
      });
      expect(fixture.bodies.single['capacity'], isA<int>());
      expect(find.text('Thêm chuồng trại'), findsNothing);
      expect(
        fixture.requests.any(
          (r) => r.method == 'POST' && r.url.path.endsWith('/farm/pens'),
        ),
        isTrue,
      );
    },
  );

  for (final kind in ['species', 'breeds', 'areas']) {
    testWidgets(
      '$kind keeps optional code omitted and sends no invented notes',
      (t) async {
        final fixture = await mountCatalog(t, kind: kind);
        await tapCatalog(t, find.widgetWithText(FilledButton, 'Thêm'));
        expect(
          fixture.requests
              .lastWhere((r) => r.url.path.endsWith('/code-suggestion'))
              .url
              .queryParameters['kind'],
          kind,
        );
        await t.enterText(
          find.widgetWithText(TextFormField, 'Tên'),
          'Danh mục mới',
        );
        await t.pump(const Duration(milliseconds: 350));
        await t.pumpAndSettle();
        if (kind == 'breeds') {
          await saveCatalog(t);
          expect(fixture.bodies, isEmpty);
          await choose(t, 'Loài', 'Bò');
        }
        final label =
            'Mã ${kind == 'species'
                ? 'loài'
                : kind == 'breeds'
                ? 'giống'
                : 'khu vực'} (tùy chọn)';
        await t.enterText(find.widgetWithText(TextFormField, label), '');
        await saveCatalog(t);
        expect(fixture.bodies.single, {
          'name': 'Danh mục mới',
          if (kind == 'breeds') 'speciesId': 'cow',
        });
        expect(
          fixture.requests.any(
            (r) => r.method == 'POST' && r.url.path.endsWith('/farm/$kind'),
          ),
          isTrue,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'linked pen update error keeps draft for retry and existing code',
    (t) async {
      final fixture = CatalogFixture()
        ..saveError =
            'Sức chứa/trạng thái không phù hợp số vật nuôi đang ở chuồng.';
      await mountCatalog(t, fixture: fixture);
      await catalogAction(t, 'Sửa');
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/code-suggestion')),
        isEmpty,
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Sức chứa (con)'),
        '1',
      );
      await saveCatalog(t);
      expect(find.text(fixture.saveError!), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Mã chuồng'),
            )
            .controller!
            .text,
        'A1',
      );
      expect(
        t
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Sức chứa (con)'),
            )
            .controller!
            .text,
        '1',
      );
      fixture.saveError = null;
      await t.enterText(
        find.widgetWithText(TextFormField, 'Sức chứa (con)'),
        '12',
      );
      await saveCatalog(t);
      expect(
        fixture.requests.lastWhere((r) => r.method == 'PATCH').url.path,
        endsWith('/farm/pens/mixed'),
      );
      expect(find.text('8/12 con'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'linked breed species change is reported by server without discarding draft',
    (t) async {
      final fixture = CatalogFixture()
        ..saveError = 'Giống đã có vật nuôi, không thể đổi loài.';
      await mountCatalog(t, fixture: fixture, kind: 'breeds');
      await catalogAction(t, 'Sửa');
      await choose(t, 'Loài', 'Heo');
      await saveCatalog(t);
      expect(find.text(fixture.saveError!), findsOneWidget);
      expect(fixture.bodies.single['speciesId'], 'pig');
      expect(find.text('Sửa giống'), findsOneWidget);
      await tapCatalog(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(find.text('Loài: Bò'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final active in [true, false]) {
    testWidgets('delete empty pen with active=$active refreshes the list', (
      t,
    ) async {
      final fixture = CatalogFixture();
      fixture.data['pens']!.removeWhere((pen) => pen['id'] != 'inactive');
      fixture.data['pens']!.single['active'] = active;
      await mountCatalog(t, fixture: fixture);
      expect(find.text('0/6 con'), findsOneWidget);
      await catalogAction(t, 'Xóa');
      expect(
        find.textContaining('Lịch sử nuôi và chuyển chuồng vẫn được giữ lại.'),
        findsOneWidget,
      );
      await tapCatalog(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      expect(
        fixture.requests.singleWhere((r) => r.method == 'DELETE').url.path,
        '/api/farm/pens/inactive',
      );
      expect(find.byKey(const ValueKey('pen-inactive')), findsNothing);
      expect(fixture.data['pens'], isEmpty);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'delete confirmation preserves linked records and reloads only on success',
    (t) async {
      final fixture = CatalogFixture()
        ..deleteError = 'Danh mục đang được sử dụng, không thể xóa.';
      await mountCatalog(t, fixture: fixture, kind: 'areas');
      await catalogAction(t, 'Xóa');
      await tapCatalog(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await catalogAction(t, 'Xóa');
      await tapCatalog(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      expect(find.text(fixture.deleteError!), findsOneWidget);
      expect(fixture.data['areas']!.length, 2);
      fixture.deleteError = null;
      await catalogAction(t, 'Xóa');
      await tapCatalog(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      expect(fixture.data['areas']!.length, 1);
      expect(find.text('KHU-A'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'saving blocks duplicate submissions and Back until server responds',
    (t) async {
      final fixture = CatalogFixture()..pendingSave = Completer();
      await mountCatalog(t, fixture: fixture, kind: 'areas');
      await tapCatalog(t, find.widgetWithText(FilledButton, 'Thêm'));
      await t.enterText(find.widgetWithText(TextFormField, 'Tên'), 'Khu mới');
      final submit = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
          .onPressed!;
      submit();
      submit();
      await t.pump();
      expect(fixture.bodies.length, 1);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('Thêm khu vực'), findsOneWidget);
      fixture.pendingSave!.complete(
        catalogResponse({
          'error': {'message': 'Hãy thử lại sau.'},
        }, 503),
      );
      await t.pumpAndSettle();
      expect(find.text('Hãy thử lại sau.'), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Tên'))
            .controller!
            .text,
        'Khu mới',
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'load error supports retry and search empty is not an empty database',
    (t) async {
      final fixture = CatalogFixture()..loadError = true;
      await mountCatalog(t, fixture: fixture);
      expect(find.textContaining('Không tải được danh mục.'), findsOneWidget);
      expect(find.textContaining('Chưa có chuồng trại.'), findsNothing);
      fixture.loadError = false;
      await tapCatalog(t, find.byTooltip('Tải lại'));
      await t.enterText(find.byType(TextField), 'Không tồn tại');
      await t.pumpAndSettle();
      expect(
        find.textContaining('Không có chuồng trại phù hợp.'),
        findsOneWidget,
      );
      await tapCatalog(t, find.byTooltip('Xóa tìm kiếm'));
      expect(find.byKey(const ValueKey('pen-mixed')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0, 1200.0]) {
    for (final kind in ['pens', 'species', 'breeds', 'areas']) {
      testWidgets('$kind fits $width with long names and text scale 1.3', (
        t,
      ) async {
        final boundary = GlobalKey();
        await mountCatalog(
          t,
          width: width,
          kind: kind,
          boundary: boundary,
          availableKinds: kind == 'pens'
              ? const ['pens']
              : const ['species', 'breeds', 'areas'],
        );
        await captureCatalog(t, boundary, '$kind-${width.toInt()}');
        await t.ensureVisible(
          find.byType(FarmSpeciesIllustration).evaluate().isNotEmpty
              ? find.byType(FarmSpeciesIllustration).last
              : find.byTooltip('Thao tác').last,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
    for (final kind in ['pens', 'breeds']) {
      testWidgets('$kind form fits $width and saves above keyboard', (t) async {
        final boundary = GlobalKey();
        await mountCatalog(
          t,
          width: width,
          kind: kind,
          boundary: boundary,
          availableKinds: kind == 'pens'
              ? const ['pens']
              : const ['species', 'breeds', 'areas'],
        );
        await tapCatalog(t, find.widgetWithText(FilledButton, 'Thêm'));
        await captureCatalog(t, boundary, '$kind-form-${width.toInt()}');
        await t.enterText(
          find.widgetWithText(TextFormField, 'Tên'),
          'Bản nháp được giữ khi đổi kích thước và mở bàn phím',
        );
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        await t.ensureVisible(
          kind == 'pens'
              ? find.byType(SwitchListTile)
              : find.widgetWithText(DropdownButtonFormField<String>, 'Loài'),
        );
        await t.pumpAndSettle();
        expect(
          t.getBottomRight(find.widgetWithText(FilledButton, 'Lưu')).dy,
          lessThanOrEqualTo(700),
        );
        await captureCatalog(t, boundary, '$kind-keyboard-${width.toInt()}');
        t.view.physicalSize = const Size(1000, 1000);
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextFormField>(find.widgetWithText(TextFormField, 'Tên'))
              .controller!
              .text,
          'Bản nháp được giữ khi đổi kích thước và mở bàn phím',
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
