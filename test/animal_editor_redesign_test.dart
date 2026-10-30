import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_editor.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'photo_workflow_test.dart' show ImagePicker;
import 'support/animal_editor_fixture.dart';
import 'support/animals_fixture.dart' show AnimalsFixture;
import 'support/ui_preview.dart';

class CancelPicker extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => null;
}

Future<GlobalKey> mountEditor(
  WidgetTester t,
  AnimalEditorFixture fixture, {
  double width = 412,
  bool editing = false,
  bool admin = true,
  ValueChanged<bool>? result,
}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  addTearDown(fixture.dispose);
  final boundary = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final saved = await animalForm(
                context,
                fixture.repository,
                {},
                editing ? FarmRecord(fixture.animal) : null,
                admin,
              );
              result?.call(saved);
            },
            child: const Text('Mở editor'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Mở editor'));
  await t.pumpAndSettle();
  return boundary;
}

Finder field(String text) => find.widgetWithText(TextFormField, text).last;
Finder dropdown(String text) =>
    find.widgetWithText(DropdownButtonFormField<String>, text).last;
Finder get saveButton => find.widgetWithText(FilledButton, 'Lưu').last;

Future<void> fillEditor(WidgetTester t, String label, String value) async {
  await t.ensureVisible(field(label));
  await t.enterText(field(label), value);
}

Future<void> tapEditor(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> selectEditor(WidgetTester t, String label, String option) async {
  await tapEditor(t, dropdown(label));
  await tapEditor(t, find.text(option).last);
}

Future<void> prepareCreate(
  WidgetTester t, {
  String penOption = 'A1 · Chuồng A (2/10)',
}) async {
  await selectEditor(t, 'Loài', 'Bò');
  await selectEditor(t, 'Giống', 'Holstein');
  await selectEditor(t, 'Chuồng', penOption);
  await fillEditor(t, 'Mã vật nuôi', 'MY-DRAFT');
}

Future<void> captureEditor(
  WidgetTester t,
  GlobalKey boundary,
  String name,
) async {
  final context = t.element(find.byType(AnimalEditor));
  await t.runAsync(
    () => Future.wait(
      t
          .widgetList<Image>(find.byType(Image))
          .map((i) => precacheImage(i.image, context)),
    ),
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
  for (final editing in [false, true]) {
    testWidgets(
      'profile weight is optional, atomic in payload and stable on retry (editing: $editing)',
      (t) async {
        final fixture = AnimalEditorFixture()..failSave = true;
        await mountEditor(t, fixture, editing: editing, width: 360);
        if (!editing) await prepareCreate(t);
        final weightLabel = editing
            ? 'Cân nặng mới (kg)'
            : 'Cân nặng ban đầu (kg)';
        await fillEditor(t, weightLabel, '25,125');
        await tapEditor(t, saveButton);
        expect(fixture.bodies, hasLength(1));
        final body = fixture.bodies.single;
        expect(body['weight'], {
          'kg': 25.125,
          'date': editing ? farmToday() : body['arrivalDate'],
        });
        expect(body['requestId'], matches(r'^[0-9a-f-]{36}$'));
        expect(
          t.widget<TextFormField>(field(weightLabel)).controller!.text,
          '25,125',
        );
        fixture.failSave = false;
        await tapEditor(t, saveButton);
        expect(fixture.bodies.last, body);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('initial weight validates precision and can be left blank', (
    t,
  ) async {
    final fixture = AnimalEditorFixture();
    await mountEditor(t, fixture);
    await prepareCreate(t);
    for (final value in ['0', '-1', 'NaN', 'Infinity', '100001', '1.0001']) {
      await fillEditor(t, 'Cân nặng ban đầu (kg)', value);
      await tapEditor(t, saveButton);
      expect(fixture.bodies, isEmpty);
    }
    await fillEditor(t, 'Cân nặng ban đầu (kg)', '');
    await tapEditor(t, saveButton);
    expect(fixture.bodies.single.containsKey('weight'), isFalse);
    expect(t.takeException(), isNull);
  });

  Future<void> prepareBatch(WidgetTester t, {bool largePen = true}) async {
    await prepareCreate(
      t,
      penOption: largePen ? 'A1 · Chuồng A (2/100)' : 'A1 · Chuồng A (2/10)',
    );
    await tapEditor(t, find.text('Theo số lượng'));
    await fillEditor(t, 'Số lượng (con)', '30');
    await fillEditor(t, 'Mã đầu tiên', 'GA-085');
    await t.pumpAndSettle();
  }

  testWidgets(
    'bulk intake previews consecutive codes and sends one atomic request for 30 profiles',
    (t) async {
      final fixture = AnimalEditorFixture();
      (fixture.catalogs['pens'] as List).first['capacity'] = 100;
      bool? saved;
      await mountEditor(t, fixture, result: (v) => saved = v);
      await prepareBatch(t);
      expect(find.text('Dãy mã: GA-085 → GA-114'), findsOneWidget);
      await fillEditor(t, 'Tên chung (tùy chọn)', 'Gà nhập theo đợt');
      await fillEditor(t, 'Nguồn gốc', 'Trại giống');
      await fillEditor(t, 'Ghi chú', 'Nhập cùng đợt');
      await t.tap(find.widgetWithText(FilledButton, 'Nhập 30 con'));
      await t.pumpAndSettle();
      expect(saved, isTrue);
      expect(fixture.bodies, hasLength(1));
      final body = fixture.bodies.single;
      expect(body['quantity'], 30);
      expect(body['firstCode'], 'GA-085');
      expect(body['penId'], 'p1');
      expect(body['breedId'], 'holstein');
      expect(body['gender'], 'UNKNOWN');
      expect(body['name'], 'Gà nhập theo đợt');
      expect(body['origin'], 'Trại giống');
      expect(body['notes'], 'Nhập cùng đợt');
      expect(body['requestId'], matches(r'^[0-9a-f-]{36}$'));
      expect(body.containsKey('code'), isFalse);
      expect(fixture.requests.last.url.path, '/api/animals/batch/create');
    },
  );

  testWidgets(
    'bulk intake blocks invalid quantities, code ranges and insufficient capacity without writes',
    (t) async {
      final fixture = AnimalEditorFixture();
      await mountEditor(t, fixture);
      await prepareBatch(t, largePen: false);
      await t.tap(find.widgetWithText(FilledButton, 'Nhập 30 con'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Chuồng không đủ chỗ cho 30 con.'),
        findsOneWidget,
      );
      expect(fixture.bodies, isEmpty);
      for (final value in ['0', '1001', '1.5', '']) {
        await fillEditor(t, 'Số lượng (con)', value);
        await t.pumpAndSettle();
        await t.tap(find.byType(FilledButton).last);
        await t.pumpAndSettle();
        expect(find.text('Nhập số nguyên từ 1 đến 1.000.'), findsOneWidget);
        expect(fixture.bodies, isEmpty);
      }
      await fillEditor(t, 'Số lượng (con)', '3');
      await fillEditor(t, 'Mã đầu tiên', 'NO-NUMBER');
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Nhập 3 con'));
      await t.pumpAndSettle();
      expect(find.textContaining('Mã cần kết thúc bằng số'), findsOneWidget);
      expect(fixture.bodies, isEmpty);
    },
  );

  testWidgets('bulk intake retains draft and request ID on retry', (t) async {
    final fixture = AnimalEditorFixture()..failSave = true;
    (fixture.catalogs['pens'] as List).first['capacity'] = 100;
    await mountEditor(t, fixture);
    await prepareBatch(t);
    await fillEditor(t, 'Ghi chú', 'Nháp nhập đàn');
    await t.tap(find.widgetWithText(FilledButton, 'Nhập 30 con'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Mã vật nuôi đã tồn tại.').hitTestable(),
      findsOneWidget,
    );
    await fillEditor(t, 'Mã đầu tiên', 'GA-115');
    fixture.failSave = false;
    await t.tap(find.widgetWithText(FilledButton, 'Nhập 30 con'));
    await t.pumpAndSettle();
    expect(fixture.bodies, hasLength(2));
    expect(fixture.bodies.last['requestId'], fixture.bodies.first['requestId']);
    expect(fixture.bodies.last['notes'], 'Nháp nhập đàn');
    expect(fixture.bodies.last['firstCode'], 'GA-115');
  });

  for (final message in [
    'Không tìm thấy đường dẫn.',
    'Không tìm thấy giống vật nuôi.',
  ]) {
    testWidgets(
      'bulk intake explains missing server support or catalog: $message',
      (t) async {
        final fixture = AnimalEditorFixture()
          ..failSave = true
          ..saveErrorStatus = 404
          ..saveErrorMessage = message;
        (fixture.catalogs['pens'] as List).first['capacity'] = 100;
        await mountEditor(t, fixture);
        await prepareBatch(t);
        await t.tap(find.widgetWithText(FilledButton, 'Nhập 30 con'));
        await t.pumpAndSettle();
        expect(
          find
              .textContaining(
                message == 'Không tìm thấy đường dẫn.'
                    ? 'Máy chủ chưa hỗ trợ nhập theo số lượng.'
                    : message,
              )
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          t.widget<TextFormField>(field('Mã đầu tiên')).controller!.text,
          'GA-085',
        );
      },
    );
  }

  testWidgets('bulk busy state prevents double submit, mode changes and back', (
    t,
  ) async {
    final pending = Completer<void>();
    final fixture = AnimalEditorFixture()..pendingSave = pending.future;
    (fixture.catalogs['pens'] as List).first['capacity'] = 100;
    await mountEditor(t, fixture);
    await prepareBatch(t);
    final save = find.widgetWithText(FilledButton, 'Nhập 30 con');
    await t.tap(save);
    await t.tap(save);
    await t.pump();
    expect(fixture.bodies, hasLength(1));
    expect(
      t
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Một con'))
          .onSelected,
      isNull,
    );
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(AnimalEditor), findsOneWidget);
    pending.complete();
    await t.pumpAndSettle();
    expect(find.byType(AnimalEditor), findsNothing);
  });

  testWidgets(
    'leaving bulk mode creates one animal and edit never offers bulk creation',
    (t) async {
      final fixture = AnimalEditorFixture();
      await mountEditor(t, fixture);
      await prepareBatch(t, largePen: false);
      await tapEditor(t, find.text('Một con'));
      expect(find.text('Số lượng (con)'), findsNothing);
      expect(find.text('Mã đầu tiên'), findsNothing);
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(fixture.bodies.single['code'], 'GA-085');
      expect(fixture.bodies.single.containsKey('quantity'), isFalse);
      expect(fixture.requests.last.url.path, '/api/animals');
    },
  );

  for (final width in [360.0, 1200.0]) {
    testWidgets('bulk intake layout at $width with large text', (t) async {
      final fixture = AnimalEditorFixture();
      (fixture.catalogs['pens'] as List).first['capacity'] = 100;
      final boundary = await mountEditor(t, fixture, width: width);
      await prepareBatch(t);
      await tapEditor(t, find.text('Theo số lượng'));
      Scrollable.of(t.element(find.widgetWithText(ChoiceChip, 'Theo số lượng')))
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      await captureEditor(t, boundary, 'bulk-intake-${width.toInt()}');
    });
  }

  testWidgets(
    'create keeps optional name, birth, origin, notes and UNKNOWN; only sends API fields',
    (t) async {
      final fixture = AnimalEditorFixture();
      bool? saved;
      await mountEditor(t, fixture, result: (value) => saved = value);
      await prepareCreate(t);
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(saved, isTrue);
      expect(fixture.bodies.single, {
        'code': 'MY-DRAFT',
        'name': '',
        'birthDate': null,
        'arrivalDate': matches(r'^\d{4}-\d{2}-\d{2}$'),
        'origin': '',
        'notes': '',
        'breedId': 'holstein',
        'gender': 'UNKNOWN',
        'penId': 'p1',
      });
    },
  );

  testWidgets(
    'edit keeps photo/species/arrival and excludes pen; edits all other text',
    (t) async {
      final fixture = AnimalEditorFixture();
      await mountEditor(t, fixture, editing: true);
      expect(find.text('Theo số lượng'), findsNothing);
      expect(
        t.widget<DropdownButtonFormField<String>>(dropdown('Loài')).onChanged,
        isNull,
      );
      expect(
        t
            .widget<TextField>(
              find.descendant(
                of: field('Ngày nhập đàn'),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(find.textContaining('dùng Chuyển chuồng'), findsOneWidget);
      await fillEditor(t, 'Tên / số hiệu (tùy chọn)', ' Tên sửa ');
      await fillEditor(t, 'Nguồn gốc', ' Nguồn mới ');
      await fillEditor(t, 'Ghi chú', ' Ghi chú\nđầy đủ ');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      final body = fixture.bodies.single;
      expect(body['name'], 'Tên sửa');
      expect(body['origin'], 'Nguồn mới');
      expect(body['notes'], 'Ghi chú\nđầy đủ');
      expect(body['arrivalDate'], '2026-01-01');
      expect(body.containsKey('penId'), isFalse);
      expect(body.containsKey('photoBase64'), isFalse);
      expect(fixture.requests.last.method, 'PATCH');
      expect(fixture.requests.last.url.path, endsWith('/animals/animal1'));
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/code-suggestion')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'client validation scrolls to first error; server error preserves draft for retry',
    (t) async {
      final fixture = AnimalEditorFixture()..failSave = true;
      await mountEditor(t, fixture);
      await tapEditor(t, field('Ghi chú'));
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(fixture.bodies, isEmpty);
      expect(find.text('Vui lòng chọn.').first.hitTestable(), findsOneWidget);
      await prepareCreate(t);
      await fillEditor(t, 'Ghi chú', 'Nháp cần giữ');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Mã vật nuôi đã tồn tại.').hitTestable(),
        findsOneWidget,
      );
      expect(
        t.widget<TextFormField>(field('Ghi chú')).controller!.text,
        'Nháp cần giữ',
      );
      fixture.failSave = false;
      await fillEditor(t, 'Mã vật nuôi', 'NEW-CODE');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(fixture.bodies.length, 2);
      expect(fixture.bodies.last['notes'], 'Nháp cần giữ');
      expect(fixture.bodies.last['code'], 'NEW-CODE');
      expect(find.byType(AnimalEditor), findsNothing);
    },
  );

  testWidgets('busy save blocks same-frame double submit, cancel and back', (
    t,
  ) async {
    final pending = Completer<void>();
    final fixture = AnimalEditorFixture()..pendingSave = pending.future;
    bool? saved;
    await mountEditor(t, fixture, editing: true, result: (v) => saved = v);
    final button = saveButton;
    await t.tap(button);
    await t.tap(button);
    await t.pump();
    expect(fixture.bodies.length, 1);
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, 'Hủy')).onPressed,
      isNull,
    );
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(AnimalEditor), findsOneWidget);
    expect(saved, isNull);
    pending.complete();
    await t.pumpAndSettle();
    expect(saved, isTrue);
  });

  testWidgets('catalog retry blocks save while retaining existing draft', (
    t,
  ) async {
    final fixture = AnimalEditorFixture();
    await mountEditor(t, fixture, editing: true);
    await fillEditor(t, 'Tên / số hiệu (tùy chọn)', 'Nháp lỗi mạng');
    fixture.failCatalogs = true;
    await tapEditor(t, find.text('Cập nhật danh mục'));
    expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
    expect(
      find.textContaining('Không tải được danh mục.').hitTestable(),
      findsOneWidget,
    );
    fixture.failCatalogs = false;
    await tapEditor(t, find.text('Thử tải lại danh mục'));
    expect(
      t
          .widget<TextFormField>(field('Tên / số hiệu (tùy chọn)'))
          .controller!
          .text,
      'Nháp lỗi mạng',
    );
    expect(t.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets(
    'STAFF cannot open catalog forms and pen filter respects area, active and capacity',
    (t) async {
      final fixture = AnimalEditorFixture();
      await mountEditor(t, fixture, admin: false);
      await prepareCreate(t);
      for (final text in [
        'Thêm loài',
        'Thêm giống cho loài này',
        'Thêm khu vực',
        'Thêm chuồng',
      ]) {
        expect(find.text(text), findsNothing);
      }
      await selectEditor(
        t,
        'Khu vực (lọc chuồng)',
        'Khu B có tên dài để kiểm tra xuống dòng',
      );
      expect(
        t
            .widget<DropdownButtonFormField<String>>(dropdown('Chuồng'))
            .initialValue,
        isNull,
      );
      await tapEditor(t, dropdown('Chuồng'));
      expect(find.textContaining('FULL'), findsNothing);
      expect(find.textContaining('CLOSED'), findsNothing);
      expect(find.text('A1 · Chuồng A (2/10)'), findsNothing);
      await tapEditor(t, find.text('B1 · Chuồng B (0/5)').last);
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(fixture.bodies.single['penId'], 'p2');
      expect(fixture.bodies.single.containsKey('areaId'), isFalse);
    },
  );

  testWidgets(
    'quick breed create and cancel keep complete draft, selected pen and photo',
    (t) async {
      final fixture = AnimalEditorFixture();
      await mountEditor(t, fixture, editing: true);
      await fillEditor(t, 'Mã vật nuôi', 'MANUAL');
      await fillEditor(t, 'Tên / số hiệu (tùy chọn)', 'Tên nháp');
      await fillEditor(t, 'Nguồn gốc', 'Nguồn nháp');
      await fillEditor(t, 'Ghi chú', 'Nháp còn nguyên');
      final original = FileSelectorPlatform.instance;
      addTearDown(() => FileSelectorPlatform.instance = original);
      FileSelectorPlatform.instance = ImagePicker(
        base64Decode(AnimalsFixture.photo),
      );
      await t.ensureVisible(find.text('Chọn ảnh từ thiết bị'));
      await t.runAsync(() async {
        await t.tap(find.text('Chọn ảnh từ thiết bị'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      await tapEditor(t, find.text('Thêm giống cho loài này'));
      await fillEditor(t, 'Tên giống', 'Giống mới');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(
        t.widget<TextFormField>(field('Mã vật nuôi')).controller!.text,
        'MANUAL',
      );
      expect(
        t.widget<TextFormField>(field('Ghi chú')).controller!.text,
        'Nháp còn nguyên',
      );
      expect(
        t
            .widget<DropdownButtonFormField<String>>(dropdown('Giống'))
            .initialValue,
        'holstein',
      );
      await tapEditor(t, find.text('Thêm giống cho loài này'));
      await tapEditor(t, find.widgetWithText(TextButton, 'Hủy').last);
      await selectEditor(t, 'Giống', 'Giống mới');
      await t.tap(saveButton);
      await t.pumpAndSettle();
      expect(fixture.bodies.single['breedId'], 'new-breed');
      expect(fixture.bodies.single['name'], 'Tên nháp');
      expect(fixture.bodies.single['origin'], 'Nguồn nháp');
      expect(fixture.bodies.single['notes'], 'Nháp còn nguyên');
      expect(fixture.bodies.single['birthDate'], '2025-10-01');
      expect(fixture.bodies.single['arrivalDate'], '2026-01-01');
      expect(fixture.bodies.single['gender'], 'UNKNOWN');
      expect(
        base64Decode(fixture.bodies.single['photoBase64'] as String),
        isNotEmpty,
      );
    },
  );

  for (final action in ['remove', 'replace', 'cancel', 'invalid']) {
    testWidgets('photo $action retains correct PATCH semantics', (t) async {
      final fixture = AnimalEditorFixture();
      await mountEditor(t, fixture, editing: true);
      final original = FileSelectorPlatform.instance;
      addTearDown(() => FileSelectorPlatform.instance = original);
      if (action == 'remove') {
        await tapEditor(t, find.text('Bỏ ảnh'));
      } else {
        FileSelectorPlatform.instance = action == 'cancel'
            ? CancelPicker()
            : ImagePicker(
                action == 'invalid'
                    ? Uint8List.fromList([1, 2, 3])
                    : base64Decode(AnimalsFixture.photo),
              );
        await t.runAsync(() async {
          await t.tap(find.text('Chọn ảnh từ thiết bị'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await t.pumpAndSettle();
        if (action == 'invalid') {
          expect(find.textContaining('Ảnh phải là JPEG/PNG'), findsOneWidget);
        }
      }
      await t.tap(saveButton);
      await t.pumpAndSettle();
      final body = fixture.bodies.single;
      if (action == 'remove') {
        expect(body.containsKey('photoBase64'), isTrue);
        expect(body['photoBase64'], isNull);
      } else if (action == 'replace') {
        expect(base64Decode(body['photoBase64'] as String), isNotEmpty);
      } else {
        expect(body.containsKey('photoBase64'), isFalse);
      }
    });
  }

  testWidgets(
    'cancel never writes; resizing and nested cancel keep draft and manual code',
    (t) async {
      final fixture = AnimalEditorFixture();
      bool? saved;
      await mountEditor(t, fixture, result: (value) => saved = value);
      await prepareCreate(t);
      await fillEditor(t, 'Tên / số hiệu (tùy chọn)', 'Tên đang nhập');
      t.view.physicalSize = const Size(1200, 1000);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(360, 1000);
      await t.pumpAndSettle();
      await tapEditor(t, find.text('Thêm khu vực'));
      await tapEditor(t, find.widgetWithText(TextButton, 'Hủy').last);
      expect(
        t.widget<TextFormField>(field('Mã vật nuôi')).controller!.text,
        'MY-DRAFT',
      );
      expect(
        t
            .widget<TextFormField>(field('Tên / số hiệu (tùy chọn)'))
            .controller!
            .text,
        'Tên đang nhập',
      );
      expect(
        t
            .widget<DropdownButtonFormField<String>>(dropdown('Chuồng'))
            .initialValue,
        'p1',
      );
      await tapEditor(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(saved, isFalse);
      expect(fixture.bodies, isEmpty);
    },
  );

  for (final width in [360.0, 412.0, 1200.0]) {
    for (final editing in [false, true]) {
      testWidgets(
        '${editing ? 'edit' : 'create'} $width layout and keyboard at scale 1.3',
        (t) async {
          final fixture = AnimalEditorFixture()..failSave = true;
          final boundary = await mountEditor(
            t,
            fixture,
            width: width,
            editing: editing,
          );
          final name = '${editing ? 'edit' : 'create'}-${width.toInt()}';
          await captureEditor(t, boundary, '$name-top');
          if (!editing) await prepareCreate(t);
          await tapEditor(t, field('Nguồn gốc'));
          await captureEditor(t, boundary, '$name-middle');
          await fillEditor(
            t,
            'Ghi chú',
            'Ghi chú nhiều dòng cần giữ.\nNội dung kiểm tra bàn phím và cuộn ở màn hình nhỏ.',
          );
          await captureEditor(t, boundary, '$name-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(field('Ghi chú'));
          await t.pumpAndSettle();
          expect(t.getBottomRight(saveButton).dy, lessThanOrEqualTo(700));
          expect(saveButton.hitTestable(), findsOneWidget);
          await captureEditor(t, boundary, '$name-keyboard');
          await t.tap(saveButton);
          await t.pumpAndSettle();
          expect(
            find.textContaining('Mã vật nuôi đã tồn tại.').hitTestable(),
            findsOneWidget,
          );
          expect(
            t.widget<TextFormField>(field('Ghi chú')).controller!.text,
            contains('nhiều dòng'),
          );
          await captureEditor(t, boundary, '$name-error');
        },
      );
    }
  }
}
