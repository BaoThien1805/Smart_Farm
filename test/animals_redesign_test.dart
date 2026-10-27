import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_farm/core/farm_illustrations.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/core/ui_components.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';
import 'package:smart_farm/features/farm/batch_transfer_form.dart';
import 'package:smart_farm/features/farm/batch_lifecycle_form.dart';

import 'support/animals_fixture.dart';
import 'support/ui_preview.dart';

Future<AnimalsFixture> mountAnimals(
  WidgetTester t, {
  AnimalsFixture? fixture,
  String role = 'STAFF',
  double width = 412,
  double textScale = 1.3,
  GlobalKey? boundary,
  String? penId,
}) async {
  final source = fixture ?? AnimalsFixture();
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
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Scaffold(
        body: AnimalsPage(
          repository: source.repository,
          admin: role == 'ADMIN',
          canOperate: ['ADMIN', 'STAFF'].contains(role),
          canCare: role != 'ACCOUNTANT',
          canExamine: ['ADMIN', 'VET'].contains(role),
          canFinance: ['ADMIN', 'ACCOUNTANT'].contains(role),
          initialPenId: penId,
          initialPenName: penId == null ? null : 'Chuồng từ lối vào bước 06',
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return source;
}

Future<void> tapAnimals(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> openFilter(WidgetTester t) =>
    tapAnimals(t, find.byKey(const ValueKey('animal-filters')));
Future<void> selectMany(WidgetTester t) async {
  await tapAnimals(t, find.byKey(const ValueKey('animals-more')));
  await tapAnimals(t, find.text('Chọn nhiều'));
}

Future<void> applyFilter(WidgetTester t) =>
    tapAnimals(t, find.widgetWithText(FilledButton, 'Áp dụng'));
Future<void> chooseFilter(WidgetTester t, String label, String value) async {
  await tapAnimals(
    t,
    find.widgetWithText(DropdownButtonFormField<String>, label),
  );
  await t.tap(find.text(value).last);
  await t.pumpAndSettle();
}

Future<void> captureAnimals(
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
  testWidgets(
    'owner sells only selected animals with explicit per-animal price and total',
    (t) async {
      final fixture = await mountAnimals(t, role: 'ADMIN');
      await selectMany(t);
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow2')));
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-sell')));
      final price = find.widgetWithText(TextFormField, 'Giá bán mỗi con (VND)');
      await t.ensureVisible(price);
      await t.enterText(price, '1000000');
      await t.pumpAndSettle();
      expect(find.text('Tổng tiền 2 con: 2.000.000 ₫'), findsOneWidget);
      await tapAnimals(t, find.widgetWithText(FilledButton, 'Xác nhận bán'));
      expect(fixture.writes.single.url.path, '/api/animals/batch/sell');
      expect(fixture.bodies.single['items'], [
        {'animalId': 'cow1', 'amount': 1000000},
        {'animalId': 'cow2', 'amount': 1000000},
      ]);
      expect(
        fixture.animals.firstWhere((a) => a['id'] == 'cow1')['status'],
        'SOLD',
      );
      expect(
        fixture.animals.firstWhere((a) => a['id'] == 'goat')['status'],
        'ACTIVE',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'owner confirms selected deaths; cancel keeps all records and selection',
    (t) async {
      final fixture = await mountAnimals(t, role: 'ADMIN');
      await selectMany(t);
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow2')));
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-death')));
      final submit = find.widgetWithText(FilledButton, 'Xác nhận đã chết');
      expect(t.widget<FilledButton>(submit).onPressed, isNull);
      await tapAnimals(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.writes, isEmpty);
      expect(find.text('Đã chọn 2 con'), findsOneWidget);
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-death')));
      await tapAnimals(t, find.byKey(const ValueKey('batch-death-confirm')));
      await tapAnimals(t, submit);
      expect(fixture.bodies.single['animalIds'], ['cow1', 'cow2']);
      expect(fixture.writes.single.url.path, '/api/animals/batch/death');
      expect(
        fixture.animals.firstWhere((a) => a['id'] == 'cow2')['status'],
        'DEAD',
      );
      expect(
        fixture.animals.firstWhere((a) => a['id'] == 'goat')['status'],
        'ACTIVE',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'batch sale rejects invalid prices and retries without duplicate submissions',
    (t) async {
      final fixture = AnimalsFixture()
        ..writeError = 'Có vật nuôi không còn đang nuôi.';
      final pending = Completer<void>();
      fixture.pendingWrite = pending.future;
      await mountAnimals(t, fixture: fixture, role: 'ADMIN');
      await selectMany(t);
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-sell')));
      final price = find.widgetWithText(TextFormField, 'Giá bán mỗi con (VND)');
      for (final value in ['0', '-1', '1.5', 'NaN', '1000000000001', '1,000']) {
        await t.ensureVisible(price);
        await t.enterText(price, value);
        await tapAnimals(t, find.widgetWithText(FilledButton, 'Xác nhận bán'));
        expect(fixture.writes, isEmpty);
      }
      await t.ensureVisible(price);
      await t.enterText(price, '2000000');
      final submit = t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận bán'),
          )
          .onPressed!;
      submit();
      submit();
      await t.pump();
      expect(fixture.writes.length, 1);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(BatchLifecycleEditor), findsOneWidget);
      pending.complete();
      await t.pumpAndSettle();
      expect(find.text(fixture.writeError!), findsOneWidget);
      fixture.writeError = null;
      await tapAnimals(t, find.widgetWithText(FilledButton, 'Xác nhận bán'));
      expect(fixture.bodies[0], fixture.bodies[1]);
      expect(t.takeException(), isNull);
    },
  );
  for (final role in ['STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role cannot access bulk sale or death', (t) async {
      await mountAnimals(t, role: role);
      if (role != 'ACCOUNTANT') await selectMany(t);
      expect(find.byKey(const ValueKey('animals-batch-sell')), findsNothing);
      expect(find.byKey(const ValueKey('animals-batch-death')), findsNothing);
    });
  }
  for (final selling in [true, false]) {
    for (final width in [360.0, 1200.0]) {
      testWidgets(
        'batch ${selling ? 'sale' : 'death'} fits $width and keyboard',
        (t) async {
          final boundary = GlobalKey();
          await mountAnimals(
            t,
            role: 'ADMIN',
            width: width,
            boundary: boundary,
          );
          await selectMany(t);
          await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
          await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow2')));
          await tapAnimals(
            t,
            find.byKey(ValueKey('animals-batch-${selling ? 'sell' : 'death'}')),
          );
          await captureAnimals(
            t,
            boundary,
            'batch-${selling ? 'sell' : 'death'}-${width.toInt()}',
          );
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          final notes = find.widgetWithText(
            TextFormField,
            selling ? 'Ghi chú (tùy chọn)' : 'Ghi chú / nguyên nhân (tùy chọn)',
          );
          await t.ensureVisible(notes);
          await t.enterText(notes, 'Ghi chú cho đợt');
          final button = find.widgetWithText(
            FilledButton,
            selling ? 'Xác nhận bán' : 'Xác nhận đã chết',
          );
          expect(t.getBottomRight(button).dy, lessThanOrEqualTo(700));
          expect(button.hitTestable(), findsOneWidget);
          await captureAnimals(
            t,
            boundary,
            'batch-keyboard-${selling ? 'sell' : 'death'}-${width.toInt()}',
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'compact reference layout keeps statuses and opens profile at $width',
      (t) async {
        final fixture = AnimalsFixture();
        fixture.animals.first['name'] = 'Bông';
        fixture.animals.first['imageData'] = '';
        final boundary = GlobalKey();
        await mountAnimals(
          t,
          fixture: fixture,
          width: width,
          textScale: 1,
          boundary: boundary,
        );
        final firstCard = find.byKey(const ValueKey('animal-cow1'));
        expect(
          find.descendant(of: firstCard, matching: find.text('Đang nuôi')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: firstCard, matching: find.text('Bình thường')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await exportUiPreview(
          t,
          boundary,
          'reference-animals-${width.toInt()}.png',
        );
        await tapAnimals(t, firstCard);
        expect(find.byType(AnimalDetailPage), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role keeps create and detail capabilities correct', (
      t,
    ) async {
      final fixture = await mountAnimals(t, role: role);
      expect(
        find.widgetWithText(FilledButton, 'Thêm vật nuôi'),
        ['ADMIN', 'STAFF'].contains(role) ? findsOneWidget : findsNothing,
      );
      await tapAnimals(t, find.byKey(const ValueKey('animal-cow1')));
      final detail = t.widget<AnimalDetailPage>(find.byType(AnimalDetailPage));
      expect(detail.id, 'cow1');
      expect(detail.canOperate, ['ADMIN', 'STAFF'].contains(role));
      expect(detail.canExamine, ['ADMIN', 'VET'].contains(role));
      expect(detail.canFinance, ['ADMIN', 'ACCOUNTANT'].contains(role));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(fixture.listRequests.length, 2);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'ellipsis selection survives search and transfers only selected animals',
    (t) async {
      final fixture = await mountAnimals(t);
      await selectMany(t);
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
      expect(find.text('Đã chọn 1 con'), findsOneWidget);
      expect(find.byType(AnimalDetailPage), findsNothing);
      final search = find.widgetWithText(
        TextField,
        'Tìm theo mã / tên vật nuôi',
      );
      await t.enterText(search, 'DE-003');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-goat')));
      expect(find.text('Đã chọn 2 con'), findsOneWidget);
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-transfer')));
      await tapAnimals(
        t,
        find.widgetWithText(DropdownButtonFormField<String>, 'Chuồng đích'),
      );
      await tapAnimals(t, find.text('B1 · Chuồng B').last);
      expect(find.text('1 con sẽ chuyển · còn 9 chỗ'), findsOneWidget);
      expect(
        find.text('1 con đã ở chuồng đích, được giữ nguyên.'),
        findsOneWidget,
      );
      await tapAnimals(t, find.widgetWithText(FilledButton, 'Xác nhận chuyển'));
      expect(fixture.writes.single.url.path, '/api/animals/batch/transfer');
      expect(fixture.bodies.single['animalIds'], ['cow1', 'goat']);
      expect(fixture.bodies.single['penId'], 'pen2');
      expect(fixture.bodies.single['requestId'], isNotEmpty);
      expect(
        fixture.animals.firstWhere((a) => a['id'] == 'cow2')['penId'],
        'pen1',
      );
      expect(find.byType(BatchTransferEditor), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'selected animals open a fixed batch care form without reselecting',
    (t) async {
      final fixture = await mountAnimals(t);
      await selectMany(t);
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow2')));
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-care')));
      expect(find.byType(CareEditor), findsOneWidget);
      expect(find.text('Đã chọn 2 vật nuôi'), findsOneWidget);
      final title = find.widgetWithText(
        TextFormField,
        'Nội dung / tên vaccine',
      );
      await t.ensureVisible(title);
      await t.enterText(title, 'Đợt chăm sóc từ danh sách');
      await tapAnimals(t, find.widgetWithText(FilledButton, 'Tạo 2 lịch'));
      expect(fixture.writes.single.url.path, '/api/care-tasks/batch');
      expect(fixture.bodies.single['animalIds'], ['cow1', 'cow2']);
      expect(find.byType(CareEditor), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel retains selection, Back exits it, closed animals cannot be selected',
    (t) async {
      await mountAnimals(t);
      await openFilter(t);
      await tapAnimals(t, find.widgetWithText(OutlinedButton, 'Đặt lại'));
      await applyFilter(t);
      await selectMany(t);
      await tapAnimals(t, find.text('Chọn trang này'));
      expect(find.text('Đã chọn 4 con'), findsOneWidget);
      final sold = t.widget<Checkbox>(
        find.byKey(const ValueKey('animal-select-sold')),
      );
      expect(sold.onChanged, isNull);
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-transfer')));
      await tapAnimals(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(find.text('Đã chọn 4 con'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('animal-select-cow1')), findsNothing);
      await tapAnimals(t, find.byKey(const ValueKey('animal-cow1')));
      expect(find.byType(AnimalDetailPage), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'batch transfer guards duplicate saves and retains payload on retry',
    (t) async {
      final pending = Completer<void>();
      final fixture = AnimalsFixture()
        ..pendingWrite = pending.future
        ..writeError = 'Chuồng vừa hết chỗ.';
      await mountAnimals(t, fixture: fixture);
      await selectMany(t);
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
      await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow2')));
      await tapAnimals(t, find.byKey(const ValueKey('animals-batch-transfer')));
      await tapAnimals(
        t,
        find.widgetWithText(DropdownButtonFormField<String>, 'Chuồng đích'),
      );
      await tapAnimals(t, find.text('B1 · Chuồng B').last);
      final save = t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận chuyển'),
          )
          .onPressed!;
      save();
      save();
      await t.pump();
      expect(fixture.writes.length, 1);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(BatchTransferEditor), findsOneWidget);
      pending.complete();
      await t.pumpAndSettle();
      expect(find.text(fixture.writeError!), findsOneWidget);
      fixture.writeError = null;
      await tapAnimals(t, find.widgetWithText(FilledButton, 'Xác nhận chuyển'));
      expect(fixture.bodies[0], fixture.bodies[1]);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('batch transfer explains no capacity and prevents save', (
    t,
  ) async {
    final fixture = AnimalsFixture();
    fixture.pens[1]['capacity'] = 1;
    await mountAnimals(t, fixture: fixture);
    await selectMany(t);
    await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
    await tapAnimals(t, find.byKey(const ValueKey('animals-batch-transfer')));
    expect(
      find.textContaining('Chưa có chuồng đang hoạt động đủ chỗ'),
      findsOneWidget,
    );
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận chuyển'),
          )
          .onPressed,
      isNull,
    );
    expect(fixture.writes, isEmpty);
    expect(t.takeException(), isNull);
  });

  for (final role in ['VET', 'ACCOUNTANT']) {
    testWidgets('$role selection respects bulk permissions', (t) async {
      await mountAnimals(t, role: role);
      expect(
        find.byKey(const ValueKey('animals-more')),
        role == 'VET' ? findsOneWidget : findsNothing,
      );
      if (role == 'VET') {
        await selectMany(t);
        expect(
          find.byKey(const ValueKey('animals-batch-transfer')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('animals-batch-care')),
          findsOneWidget,
        );
      }
    });
  }

  for (final width in [360.0, 1200.0]) {
    testWidgets(
      'bulk toolbar and transfer fit $width with large text and keyboard',
      (t) async {
        final boundary = GlobalKey();
        await mountAnimals(t, width: width, boundary: boundary);
        await selectMany(t);
        await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow1')));
        await tapAnimals(t, find.byKey(const ValueKey('animal-select-cow2')));
        await t.ensureVisible(find.text('Đã chọn 2 con'));
        await captureAnimals(t, boundary, 'bulk-selection-${width.toInt()}');
        await tapAnimals(
          t,
          find.byKey(const ValueKey('animals-batch-transfer')),
        );
        await tapAnimals(
          t,
          find.widgetWithText(DropdownButtonFormField<String>, 'Chuồng đích'),
        );
        await tapAnimals(t, find.text('B1 · Chuồng B').last);
        await captureAnimals(t, boundary, 'bulk-transfer-${width.toInt()}');
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        final notes = find.widgetWithText(TextFormField, 'Ghi chú');
        await t.ensureVisible(notes);
        await t.enterText(notes, 'Chuyển đàn theo đợt');
        final save = find.widgetWithText(FilledButton, 'Xác nhận chuyển');
        expect(t.getBottomRight(save).dy, lessThanOrEqualTo(700));
        expect(save.hitTestable(), findsOneWidget);
        await captureAnimals(t, boundary, 'bulk-keyboard-${width.toInt()}');
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cards keep uploaded photo, species fallback, names and independent states',
    (t) async {
      await mountAnimals(t);
      final photo = find.descendant(
        of: find.byKey(const ValueKey('animal-cow1')),
        matching: find.byType(Image),
      );
      expect(t.widget<Image>(photo).image, isA<MemoryImage>());
      expect(
        find.text('Bông có tên dài để kiểm tra hiển thị tiếng Việt'),
        findsOneWidget,
      );
      final goat = find.descendant(
        of: find.byKey(const ValueKey('animal-goat')),
        matching: find.byType(FarmSpeciesIllustration),
      );
      expect(t.widget<FarmSpeciesIllustration>(goat).speciesName, 'Dê');
      final unknown = find.descendant(
        of: find.byKey(const ValueKey('animal-unknown')),
        matching: find.byType(FarmPenIllustration),
      );
      expect(unknown, findsWidgets);
      await openFilter(t);
      await tapAnimals(t, find.byKey(const ValueKey('Tình trạng vòng đời-')));
      await applyFilter(t);
      expect(find.text('Đã bán'), findsOneWidget);
      expect(find.text('Đã chết'), findsOneWidget);
      expect(find.text('Cần chăm sóc'), findsNWidgets(2));
      expect(find.text('Thứ tự: mã vật nuôi'), findsOneWidget);
      expect(find.text('Mới nhất'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'draft changes do not fetch; apply sends IDs once and restores selection',
    (t) async {
      final fixture = await mountAnimals(t);
      await openFilter(t);
      await chooseFilter(t, 'Loài', 'Bò');
      await chooseFilter(
        t,
        'Chuồng trại',
        'Chuồng A có tên dài để kiểm tra bố cục',
      );
      await tapAnimals(
        t,
        find.byKey(const ValueKey('Tình trạng sức khỏe-NEEDS_CARE')),
      );
      expect(fixture.listRequests.length, 1);
      await applyFilter(t);
      expect(fixture.listRequests.length, 2);
      expect(fixture.listRequests.last.url.queryParameters, {
        'page': '1',
        'search': '',
        'status': 'ACTIVE',
        'speciesId': 'cow',
        'penId': 'pen1',
        'healthStatus': 'NEEDS_CARE',
      });
      expect(find.text('BO-002'), findsOneWidget);
      expect(find.text('BO-001'), findsNothing);
      await openFilter(t);
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.widgetWithText(DropdownButtonFormField<String>, 'Loài'),
            )
            .initialValue,
        'cow',
      );
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('Tình trạng sức khỏe-NEEDS_CARE')),
            )
            .selected,
        isTrue,
      );
      await tapAnimals(t, find.widgetWithText(TextButton, 'Đóng'));
      expect(fixture.listRequests.length, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'reset is a draft; Cancel restores filters and Apply preserves farm species scope',
    (t) async {
      final fixture = AnimalsFixture()..repository.selectedSpeciesIds = ['cow'];
      await mountAnimals(t, fixture: fixture, penId: 'pen1');
      await openFilter(t);
      await tapAnimals(t, find.widgetWithText(OutlinedButton, 'Đặt lại'));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(fixture.listRequests.length, 1);
      expect(
        find.widgetWithText(
          FarmStatusBadge,
          'Chuồng: Chuồng A có tên dài để kiểm tra bố cục',
        ),
        findsOneWidget,
      );
      await openFilter(t);
      await tapAnimals(t, find.widgetWithText(OutlinedButton, 'Đặt lại'));
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('Tình trạng vòng đời-')),
            )
            .selected,
        isTrue,
      );
      await applyFilter(t);
      expect(fixture.listRequests.last.url.queryParameters, {
        'page': '1',
        'search': '',
        'speciesIds': 'cow',
      });
      expect(fixture.listRequests.length, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'search debounces 350ms and clear cancels pending duplicate requests',
    (t) async {
      final fixture = await mountAnimals(t);
      await t.enterText(find.byType(TextField), 'B');
      await t.pump(const Duration(milliseconds: 200));
      await t.enterText(find.byType(TextField), 'Bông');
      await t.pump(const Duration(milliseconds: 349));
      expect(fixture.listRequests.length, 1);
      await t.pump(const Duration(milliseconds: 1));
      await t.pumpAndSettle();
      expect(fixture.listRequests.length, 2);
      expect(fixture.listRequests.last.url.queryParameters['search'], 'Bông');
      expect(find.text('BO-001'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Mây');
      await tapAnimals(t, find.byTooltip('Xóa tìm kiếm'));
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(fixture.listRequests.length, 3);
      expect(fixture.listRequests.last.url.queryParameters['search'], '');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'opening filters cancels pending debounce and applies search exactly once on close',
    (t) async {
      final fixture = await mountAnimals(t);
      await t.enterText(find.byType(TextField), 'Nắng');
      await openFilter(t);
      await t.pump(const Duration(seconds: 1));
      expect(fixture.listRequests.length, 1);
      await applyFilter(t);
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(fixture.listRequests.length, 2);
      expect(find.text('DE-003'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'server pagination, detail Back and changed filters preserve correct page and query',
    (t) async {
      final fixture = AnimalsFixture();
      for (var i = 0; i < 21; i++) {
        fixture.animals.add({
          ...AnimalsFixture.base,
          'id': 'extra$i',
          'code': 'X-${i.toString().padLeft(2, '0')}',
          'name': 'Thêm $i',
        });
      }
      await mountAnimals(t, fixture: fixture);
      expect(find.byType(FarmAnimalImage), findsNWidgets(20));
      await tapAnimals(t, find.byTooltip('Trang sau'));
      expect(fixture.listRequests.last.url.queryParameters['page'], '2');
      expect(find.byType(FarmAnimalImage), findsNWidgets(5));
      await tapAnimals(t, find.byKey(const ValueKey('animal-extra20')));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(fixture.listRequests.last.url.queryParameters['page'], '2');
      expect(find.text('Trang 2 · 25 kết quả'), findsOneWidget);
      await openFilter(t);
      await chooseFilter(t, 'Loài', 'Dê');
      await applyFilter(t);
      expect(fixture.listRequests.last.url.queryParameters['page'], '1');
      expect(find.text('DE-003'), findsOneWidget);
      expect(find.text('X-20'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('late search response cannot replace newer results', (t) async {
    final fixture = await mountAnimals(t);
    final first = Completer<http.Response>(),
        second = Completer<http.Response>();
    fixture.listOverride = (r) => r.url.queryParameters['search'] == 'Bông'
        ? first.future
        : second.future;
    await t.enterText(find.byType(TextField), 'Bông');
    await t.pump(const Duration(milliseconds: 400));
    await t.enterText(find.byType(TextField), 'Mây');
    await t.pump(const Duration(milliseconds: 400));
    second.complete(
      animalsResponse(fixture.listData(fixture.listRequests.last)),
    );
    await t.pumpAndSettle();
    expect(find.text('BO-002'), findsOneWidget);
    expect(find.text('BO-001'), findsNothing);
    first.complete(animalsResponse(fixture.listData(fixture.listRequests[1])));
    await t.pumpAndSettle();
    expect(find.text('BO-002'), findsOneWidget);
    expect(find.text('BO-001'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'errors and stale data are explicit; retry and empty results remain usable',
    (t) async {
      final fixture = AnimalsFixture()..failList = true;
      final boundary = GlobalKey();
      await mountAnimals(t, fixture: fixture, width: 360, boundary: boundary);
      expect(find.text('Không có vật nuôi phù hợp.'), findsNothing);
      expect(find.text('0 vật nuôi'), findsNothing);
      await captureAnimals(t, boundary, 'list-error-360');
      fixture.failList = false;
      await tapAnimals(t, find.byTooltip('Tải lại'));
      fixture.failList = true;
      await tapAnimals(t, find.byTooltip('Tải lại'));
      expect(
        find.textContaining('Danh sách bên dưới là kết quả lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t.widget<InkWell>(find.byKey(const ValueKey('animal-cow1'))).onTap,
        isNull,
      );
      fixture.failList = false;
      await t.enterText(find.byType(TextField), 'Không có mã này');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('Không có vật nuôi phù hợp.'), findsOneWidget);
      await captureAnimals(t, boundary, 'list-empty-360');
      await tapAnimals(t, find.byTooltip('Xóa tìm kiếm'));
      expect(find.byKey(const ValueKey('animal-cow1')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'list fits $width with real photo, long names and all lifecycle states',
      (t) async {
        final boundary = GlobalKey();
        await mountAnimals(t, width: width, boundary: boundary);
        await openFilter(t);
        await tapAnimals(t, find.widgetWithText(OutlinedButton, 'Đặt lại'));
        await applyFilter(t);
        await t.ensureVisible(find.text('Đàn vật nuôi'));
        await t.pumpAndSettle();
        await captureAnimals(t, boundary, 'list-${width.toInt()}');
        await t.ensureVisible(find.byKey(const ValueKey('animal-unknown')));
        await t.pumpAndSettle();
        await captureAnimals(t, boundary, 'list-bottom-${width.toInt()}');
      },
    );
    for (final keyboard in [0.0, 300.0]) {
      testWidgets(
        'filter fits $width with keyboard $keyboard and retains draft through resize',
        (t) async {
          final boundary = GlobalKey();
          await mountAnimals(
            t,
            width: width,
            boundary: boundary,
            penId: 'pen1',
          );
          await openFilter(t);
          await chooseFilter(t, 'Loài', 'Vịt có tên loài dài');
          t.view.viewInsets = FakeViewPadding(bottom: keyboard);
          await t.pumpAndSettle();
          await captureAnimals(
            t,
            boundary,
            'filter-${width.toInt()}-${keyboard.toInt()}',
          );
          await t.ensureVisible(
            find.byKey(const ValueKey('Tình trạng sức khỏe-NEEDS_CARE')),
          );
          await t.pumpAndSettle();
          expect(
            t.getBottomRight(find.widgetWithText(FilledButton, 'Áp dụng')).dy,
            lessThanOrEqualTo(1000 - keyboard),
          );
          await captureAnimals(
            t,
            boundary,
            'filter-bottom-${width.toInt()}-${keyboard.toInt()}',
          );
          t.view.physicalSize = const Size(1000, 1000);
          await t.pumpAndSettle();
          expect(
            t
                .widget<DropdownButtonFormField<String>>(
                  find.widgetWithText(DropdownButtonFormField<String>, 'Loài'),
                )
                .initialValue,
            'duck',
          );
          await applyFilter(t);
          expect(find.text('Loài: Vịt có tên loài dài'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
