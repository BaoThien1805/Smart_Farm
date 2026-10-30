import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/care_forms.dart';
import 'package:smart_farm/features/farm/care_page.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/home/workspace_page.dart';

import 'support/care_fixture.dart';
import 'support/ui_preview.dart';

Finder inCare(Finder f) =>
    find.descendant(of: find.byType(CareEditor), matching: f);
Finder task(String id) => find.byKey(ValueKey('care-task-$id'));
Finder taskButton(String id, String text) =>
    find.descendant(of: task(id), matching: find.text(text));
Finder careField(String label) =>
    inCare(find.widgetWithText(TextFormField, label));
Future<void> tapCare(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> fillCare(WidgetTester t, String label, String text) async {
  await t.ensureVisible(careField(label));
  await t.enterText(careField(label), text);
}

Future<GlobalKey> mountCare(
  WidgetTester t,
  CareFixture fixture, {
  double width = 412,
  bool workspace = false,
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  addTearDown(fixture.dispose);
  final boundary = GlobalKey();
  final user = fixture.auth.user!;
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: workspace
          ? WorkspacePage(auth: fixture.auth)
          : Scaffold(
              body: CarePage(
                repository: fixture.repository,
                admin: user.isAdmin,
                canOperate: user.canOperate,
                canCare: user.canCare,
                canExamine: user.canExamine,
                canFinance: user.canFinance,
              ),
            ),
    ),
  );
  await t.pumpAndSettle();
  return boundary;
}

Future<void> captureCare(
  WidgetTester t,
  GlobalKey boundary,
  String name,
) async {
  final context = t.element(find.byType(Scaffold).first);
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

Future<void> chooseAnimal(WidgetTester t, int index) async {
  final search = inCare(find.widgetWithText(TextField, 'Tìm vật nuôi'));
  await t.ensureVisible(search);
  await t.enterText(search, 'DE-${index.toString().padLeft(3, '0')}');
  await t.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  final checkbox = find.descendant(
    of: find.byKey(ValueKey('care-target-animal-$index')),
    matching: find.byType(Checkbox),
  );
  await t.ensureVisible(checkbox);
  await t.pumpAndSettle();
  await t.tap(checkbox);
  await t.pumpAndSettle();
  expect(t.widget<Checkbox>(checkbox).value, isTrue);
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  testWidgets(
    'due-date filter composes with status and cancels picker without changing dates',
    (t) async {
      final fixture = CareFixture();
      await mountCare(t, fixture);
      await tapCare(t, find.text('Hôm nay'));
      expect(task('today'), findsOneWidget);
      expect(task('overdue'), findsNothing);
      expect(
        fixture.requests.last.url.queryParameters,
        containsPair('from', fixture.today),
      );
      expect(
        fixture.requests.last.url.queryParameters,
        containsPair('to', fixture.today),
      );
      await tapCare(t, find.text('Lọc ngày'));
      expect(find.text('Lọc theo ngày hẹn'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(task('today'), findsOneWidget);
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Đã hoàn thành'));
      expect(task('done'), findsOneWidget);
      expect(fixture.requests.last.url.queryParameters['from'], fixture.today);
      await tapCare(t, find.text('Xóa lọc ngày'));
      expect(
        fixture.requests.last.url.queryParameters.containsKey('from'),
        isFalse,
      );
      expect(fixture.requests.last.url.queryParameters['status'], 'DONE');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'vet completes selected schedules in one request and preserves retry payload',
    (t) async {
      final fixture = CareFixture('VET')
        ..writeError = 'Có lịch đã thay đổi. Thử lại.';
      final boundary = await mountCare(t, fixture, width: 360);
      await tapCare(t, find.text('Chọn nhiều'));
      await tapCare(t, find.text('Chọn tất cả trang này'));
      expect(find.text('Đã chọn 2 lịch'), findsOneWidget);
      await t.ensureVisible(find.text('Lịch chăm sóc'));
      await captureCare(t, boundary, 'selected-care-360');
      await tapCare(t, find.text('Hoàn thành đã chọn'));
      expect(find.text('Hoàn thành 2 lịch'), findsOneWidget);
      await captureCare(t, boundary, 'complete-selected-care-360');
      await fillCare(t, 'Ghi chú kết quả', 'Đã kiểm tra cả nhóm');
      await tapCare(
        t,
        find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
      );
      expect(find.text('Có lịch đã thay đổi. Thử lại.'), findsOneWidget);
      final body = fixture.bodies.single!;
      expect(body['taskIds'], ['overdue', 'today']);
      expect(body['notes'], 'Đã kiểm tra cả nhóm');
      expect(
        fixture.writes.single.url.path,
        endsWith('/care-tasks/batch/complete'),
      );
      fixture.writeError = null;
      await tapCare(
        t,
        find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
      );
      expect(fixture.bodies.last, body);
      expect(find.text('Đã chọn 0 lịch'), findsOneWidget);
      expect(fixture.healthRecords, hasLength(2));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'staff selects across pages, clears on filter change and only cancels batches',
    (t) async {
      final fixture = CareFixture('STAFF');
      final seed = Map<String, dynamic>.from(fixture.tasks.first);
      fixture.tasks
        ..clear()
        ..addAll(
          List.generate(
            25,
            (i) => {...seed, 'id': 'page-$i', 'dueDate': fixture.today},
          ),
        );
      await mountCare(t, fixture);
      await tapCare(t, find.text('Chọn nhiều'));
      await tapCare(t, find.text('Chọn tất cả trang này'));
      expect(find.text('Đã chọn 20 lịch'), findsOneWidget);
      await tapCare(t, find.byTooltip('Trang sau'));
      await tapCare(t, find.byKey(const ValueKey('care-select-page-20')));
      expect(find.text('Đã chọn 21 lịch'), findsOneWidget);
      expect(find.text('Hoàn thành đã chọn'), findsNothing);
      await tapCare(t, find.text('Hôm nay'));
      expect(find.text('Đã chọn 0 lịch'), findsOneWidget);
      expect(fixture.requests.last.url.queryParameters['page'], '1');
      await tapCare(t, find.text('Chọn tất cả trang này'));
      await tapCare(t, find.text('Hủy lịch đã chọn'));
      await tapCare(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.writes, isEmpty);
      expect(find.text('Đã chọn 20 lịch'), findsOneWidget);
      await tapCare(t, find.text('Hủy lịch đã chọn'));
      await tapCare(t, find.widgetWithText(FilledButton, 'Xác nhận hủy'));
      expect(
        fixture.writes.single.url.path,
        endsWith('/care-tasks/batch/cancel'),
      );
      expect(fixture.bodies.single!['taskIds'], hasLength(20));
      expect(find.text('Đã chọn 0 lịch'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role has correct schedule and completion capabilities', (
      t,
    ) async {
      final fixture = CareFixture(role);
      await mountCare(t, fixture);
      final care = role != 'ACCOUNTANT',
          examine = ['ADMIN', 'VET'].contains(role);
      expect(find.text('Đặt lịch'), care ? findsOneWidget : findsNothing);
      expect(find.text('Chọn nhiều'), care ? findsOneWidget : findsNothing);
      expect(
        taskButton('overdue', 'Sửa lịch'),
        care ? findsOneWidget : findsNothing,
      );
      expect(
        taskButton('overdue', 'Hủy lịch'),
        care ? findsOneWidget : findsNothing,
      );
      expect(
        taskButton('overdue', 'Hoàn thành'),
        examine ? findsOneWidget : findsNothing,
      );
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Tất cả'));
      for (final id in ['done', 'cancelled']) {
        for (final action in ['Sửa lịch', 'Hủy lịch', 'Hoàn thành']) {
          expect(taskButton(id, action), findsNothing);
        }
      }
      expect(fixture.writes, isEmpty);
    });
  }
  testWidgets(
    'date groups use server today, keep status distinct from overdue, no invented time or actor',
    (t) async {
      final fixture = CareFixture()..today = '2026-10-30';
      await mountCare(t, fixture);
      expect(find.text('Quá hạn'), findsNWidgets(2));
      expect(
        find.text('Chờ thực hiện'),
        findsNWidgets(3),
      ); // chip and two cards
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Tất cả'));
      expect(find.text('Ngày hẹn 24/10/2026'), findsOneWidget);
      expect(find.text('Ngày thực hiện: 23/10/2026'), findsOneWidget);
      expect(
        find.text('Người tạo lịch: Người tạo lịch ban đầu'),
        findsOneWidget,
      );
      expect(find.textContaining('09:00'), findsNothing);
      expect(find.textContaining('Người thực hiện:'), findsNothing);
      expect(
        fixture.requests.where((r) => r.url.path.contains('/animals/')),
        isEmpty,
      );
    },
  );
  testWidgets(
    'create loads all animal pages and scope, keeps optional notes and two kinds',
    (t) async {
      final fixture = CareFixture('STAFF');
      fixture.repository.selectedSpeciesIds = ['goat'];
      await mountCare(t, fixture);
      await tapCare(t, find.text('Đặt lịch'));
      final requests = fixture.requests
          .where((r) => r.url.path.endsWith('/animals'))
          .toList();
      expect(requests.map((r) => r.url.queryParameters['page']), ['1', '2']);
      expect(
        requests.every((r) => r.url.queryParameters['speciesIds'] == 'goat'),
        isTrue,
      );
      final choice = find.descendant(
        of: inCare(
          find.widgetWithText(DropdownButtonFormField<String>, 'Loại việc'),
        ),
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        t.widget<DropdownButton<String>>(choice).items!.map((i) => i.value),
        ['CHECKUP', 'VACCINATION'],
      );
      await chooseAnimal(t, 104);
      expect(find.text('Một con'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Chọn con vật'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Chọn chuồng'), findsOneWidget);
      await fillCare(t, 'Nội dung / tên vaccine', ' Lịch cuối trang ');
      await tapCare(t, find.widgetWithText(FilledButton, 'Tạo 1 lịch'));
      expect(fixture.bodies.single, {
        'animalIds': ['animal-104'],
        'requestId': fixture.bodies.single!['requestId'],
        'kind': 'CHECKUP',
        'title': 'Lịch cuối trang',
        'dueDate': farmToday(),
        'notes': '',
      });
      expect(fixture.listLoads, 2);
    },
  );
  testWidgets(
    'animal load error retries without losing draft; empty animals prevent save',
    (t) async {
      final fixture = CareFixture()..failAnimals = true;
      await mountCare(t, fixture);
      await tapCare(t, find.text('Đặt lịch'));
      expect(find.text('Không tải được vật nuôi.'), findsOneWidget);
      await fillCare(t, 'Nội dung / tên vaccine', 'Nháp giữ khi tải lại');
      fixture.failAnimals = false;
      await tapCare(t, find.text('Thử tải lại vật nuôi'));
      expect(
        t
            .widget<TextFormField>(careField('Nội dung / tên vaccine'))
            .controller!
            .text,
        'Nháp giữ khi tải lại',
      );
      await tapCare(t, find.widgetWithText(TextButton, 'Hủy'));
      fixture.animals.clear();
      await tapCare(t, find.text('Đặt lịch'));
      expect(
        find.text('Chưa có vật nuôi đang nuôi để đặt lịch.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Tạo 0 lịch'),
            )
            .onPressed,
        isNull,
      );
      expect(fixture.writes, isEmpty);
    },
  );
  testWidgets(
    'batch selection searches across pages and keeps hidden selections',
    (t) async {
      final fixture = CareFixture('STAFF');
      await mountCare(t, fixture);
      await tapCare(t, find.text('Đặt lịch'));
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Chọn con vật'));
      final search = inCare(find.widgetWithText(TextField, 'Tìm vật nuôi'));
      await t.enterText(search, 'DE-104');
      await t.pumpAndSettle();
      await tapCare(t, find.byKey(const ValueKey('care-target-animal-104')));
      await t.enterText(search, 'DE-000');
      await t.pumpAndSettle();
      await tapCare(t, find.text('Chọn tất cả kết quả'));
      expect(find.text('Đã chọn 2 con'), findsOneWidget);
      await fillCare(t, 'Nội dung / tên vaccine', 'Đợt kiểm tra sức khỏe');
      await tapCare(t, find.widgetWithText(FilledButton, 'Tạo 2 lịch'));
      expect(fixture.writes.single.url.path, '/api/care-tasks/batch');
      expect(fixture.bodies.single!['animalIds'], ['animal-0', 'animal-104']);
      expect(fixture.bodies.single!['requestId'], isNotEmpty);
      expect(
        fixture.tasks
            .where((task) => task['title'] == 'Đợt kiểm tra sức khỏe')
            .length,
        2,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'multiple pens select each resident once and exclude other pens',
    (t) async {
      final fixture = CareFixture();
      for (var i = 0; i < fixture.animals.length; i++) {
        final group = i < 2
            ? 'a'
            : i == 2
            ? 'b'
            : 'c';
        fixture.animals[i]['penId'] = 'pen-$group';
        fixture.animals[i]['penName'] = 'Chuồng $group';
      }
      await mountCare(t, fixture);
      await tapCare(t, find.text('Đặt lịch'));
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Chọn chuồng'));
      await tapCare(t, find.byKey(const ValueKey('care-target-pen-a')));
      await tapCare(t, find.byKey(const ValueKey('care-target-pen-b')));
      expect(find.text('Đã chọn 2 chuồng · 3 con'), findsOneWidget);
      await fillCare(t, 'Nội dung / tên vaccine', 'Tiêm phòng theo đợt');
      await tapCare(t, find.widgetWithText(FilledButton, 'Tạo 3 lịch'));
      expect(fixture.bodies.single!['animalIds'], [
        'animal-0',
        'animal-1',
        'animal-2',
      ]);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'batch validation, busy guard and retry preserve selected targets and request ID',
    (t) async {
      final fixture = CareFixture()..writeError = 'Chưa lưu được đợt chăm sóc.';
      final pending = Completer<void>();
      fixture.pending = pending.future;
      await mountCare(t, fixture);
      await tapCare(t, find.text('Đặt lịch'));
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Chọn con vật'));
      await fillCare(t, 'Nội dung / tên vaccine', 'Đợt chăm sóc');
      await tapCare(t, find.widgetWithText(FilledButton, 'Tạo 0 lịch'));
      expect(find.text('Vui lòng chọn ít nhất một vật nuôi.'), findsOneWidget);
      expect(fixture.writes, isEmpty);
      await tapCare(t, find.byKey(const ValueKey('care-target-animal-0')));
      await tapCare(t, find.byKey(const ValueKey('care-target-animal-1')));
      final save = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Tạo 2 lịch'))
          .onPressed!;
      save();
      save();
      await t.pump();
      expect(fixture.writes.length, 1);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(CareEditor), findsOneWidget);
      pending.complete();
      await t.pumpAndSettle();
      expect(find.text(fixture.writeError!), findsOneWidget);
      expect(find.text('Đã chọn 2 con'), findsOneWidget);
      fixture.writeError = null;
      await tapCare(t, find.widgetWithText(FilledButton, 'Tạo 2 lịch'));
      expect(fixture.bodies[0], fixture.bodies[1]);
      expect(
        fixture.tasks.where((task) => task['title'] == 'Đợt chăm sóc').length,
        2,
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final mode in ['Chọn con vật', 'Chọn chuồng']) {
    for (final width in [360.0, 1200.0]) {
      testWidgets('$mode batch picker fits $width with keyboard and scale 1.3', (
        t,
      ) async {
        final fixture = CareFixture();
        final boundary = await mountCare(t, fixture, width: width);
        await tapCare(t, find.text('Đặt lịch'));
        await tapCare(t, find.widgetWithText(ChoiceChip, mode));
        final first = mode == 'Chọn con vật' ? 'animal-0' : 'pen';
        await tapCare(t, find.byKey(ValueKey('care-target-$first')));
        await captureCare(
          t,
          boundary,
          'batch-${mode == 'Chọn con vật' ? 'animals' : 'pens'}-${width.toInt()}',
        );
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        await fillCare(t, 'Ghi chú', 'Ghi chú cho đợt chăm sóc');
        final save = find.widgetWithText(
          FilledButton,
          mode == 'Chọn con vật' ? 'Tạo 1 lịch' : 'Tạo 105 lịch',
        );
        expect(t.getBottomRight(save).dy, lessThanOrEqualTo(800));
        expect(save.hitTestable(), findsOneWidget);
        await captureCare(
          t,
          boundary,
          'batch-keyboard-${mode == 'Chọn con vật' ? 'animals' : 'pens'}-${width.toInt()}',
        );
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'edit excludes immutable animalId, keeps notes and rejects closed task entry',
    (t) async {
      final fixture = CareFixture('STAFF');
      await mountCare(t, fixture);
      await tapCare(t, taskButton('overdue', 'Sửa lịch'));
      expect(
        inCare(
          find.widgetWithText(DropdownButtonFormField<String>, 'Vật nuôi'),
        ),
        findsNothing,
      );
      await fillCare(t, 'Nội dung / tên vaccine', ' Lịch đã sửa ');
      await fillCare(t, 'Ghi chú', ' Ghi chú mới ');
      await tapCare(t, find.widgetWithText(FilledButton, 'Lưu lịch'));
      expect(fixture.writes.single.method, 'PATCH');
      expect(fixture.bodies.single!.containsKey('animalId'), isFalse);
      expect(fixture.bodies.single!['title'], 'Lịch đã sửa');
      expect(fixture.bodies.single!['notes'], 'Ghi chú mới');
      final context = t.element(find.byType(CarePage));
      expect(
        await careForm(
          context,
          fixture.repository,
          task: FarmRecord(fixture.tasks[2]),
        ),
        isFalse,
      );
      expect(
        await completeCareForm(
          context,
          fixture.repository,
          FarmRecord(fixture.tasks[3]),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'completion keeps result optional, two health states and creator distinct; profile shows real record',
    (t) async {
      final fixture = CareFixture('VET');
      await mountCare(t, fixture);
      await tapCare(t, taskButton('overdue', 'Hoàn thành'));
      expect(
        inCare(find.text('Người tạo lịch: Nhân viên tạo lịch')),
        findsOneWidget,
      );
      expect(inCare(find.textContaining('Ghi chú lịch:')), findsOneWidget);
      final dropdown = inCare(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Tình trạng sau chăm sóc',
        ),
      );
      final button = find.descendant(
        of: dropdown,
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        t.widget<DropdownButton<String>>(button).items!.map((i) => i.value),
        ['NORMAL', 'NEEDS_CARE'],
      );
      await tapCare(t, dropdown);
      await tapCare(t, find.text('Cần chăm sóc').last);
      await tapCare(
        t,
        find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
      );
      expect(fixture.bodies.single!.keys.toSet(), {
        'date',
        'status',
        'notes',
        'requestId',
      });
      expect(fixture.bodies.single!['notes'], '');
      expect(fixture.bodies.single!['status'], 'NEEDS_CARE');
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Đã hoàn thành'));
      await tapCare(t, taskButton('overdue', 'Hồ sơ vật nuôi'));
      await tapCare(t, find.byKey(const ValueKey('profile-tab-2')));
      expect(find.textContaining('Bác sĩ thực hiện'), findsOneWidget);
      expect(fixture.tasks.first['actorName'], 'Nhân viên tạo lịch');
      expect(fixture.healthRecords.single.containsKey('diagnosis'), isFalse);
    },
  );
  for (final mode in ['create', 'edit', 'complete']) {
    testWidgets(
      '$mode validates, retries same draft and blocks duplicate submit and Back',
      (t) async {
        final fixture = CareFixture()
          ..writeError =
              'Ngày không hợp lệ hoặc lịch đã đóng. Kiểm tra rồi thử lại.';
        await mountCare(t, fixture);
        if (mode == 'create') {
          await tapCare(t, find.text('Đặt lịch'));
          await chooseAnimal(t, 0);
        } else {
          await tapCare(
            t,
            taskButton('overdue', mode == 'edit' ? 'Sửa lịch' : 'Hoàn thành'),
          );
        }
        final action = mode == 'complete'
            ? 'Xác nhận hoàn thành'
            : mode == 'create'
            ? 'Tạo 1 lịch'
            : 'Lưu lịch';
        if (mode != 'complete') {
          await fillCare(t, 'Nội dung / tên vaccine', '');
          await tapCare(t, find.widgetWithText(FilledButton, action));
          expect(fixture.writes, isEmpty);
          await fillCare(t, 'Nội dung / tên vaccine', 'Nháp còn nguyên');
        }
        final noteLabel = mode == 'complete' ? 'Ghi chú kết quả' : 'Ghi chú';
        await fillCare(t, noteLabel, 'Nháp có nhiều dòng\ncần được giữ');
        await tapCare(t, find.widgetWithText(FilledButton, action));
        expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
        final pending = Completer<void>();
        fixture
          ..writeError = null
          ..pending = pending.future;
        final save = find.widgetWithText(FilledButton, action);
        await t.tap(save);
        await t.tap(save);
        await t.pump();
        expect(fixture.writes.length, 2);
        expect(fixture.bodies.first, fixture.bodies.last);
        expect(
          t
              .widget<TextButton>(find.widgetWithText(TextButton, 'Hủy'))
              .onPressed,
          isNull,
        );
        await t.binding.handlePopRoute();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(CareEditor), findsOneWidget);
        pending.complete();
        await t.pumpAndSettle();
        expect(find.byType(CareEditor), findsNothing);
        expect(fixture.listLoads, 2);
      },
    );
  }
  testWidgets(
    'cancel confirmation never writes on cancel; successful cancel reloads statuses',
    (t) async {
      final fixture = CareFixture('STAFF');
      await mountCare(t, fixture);
      await tapCare(t, taskButton('overdue', 'Hủy lịch'));
      expect(
        find.textContaining('Lịch được giữ trong lịch sử'),
        findsOneWidget,
      );
      await tapCare(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.writes, isEmpty);
      await tapCare(t, taskButton('overdue', 'Hủy lịch'));
      await tapCare(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      expect(fixture.bodies.single, isNull);
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Đã hủy'));
      expect(task('overdue'), findsOneWidget);
    },
  );
  testWidgets(
    'pagination keeps scope; closing last item on page 2 returns to valid page',
    (t) async {
      final fixture = CareFixture();
      final base = Map<String, dynamic>.from(fixture.tasks.first);
      fixture.tasks
        ..clear()
        ..addAll(
          List.generate(
            21,
            (i) => {...base, 'id': 'task-$i', 'title': 'Lịch $i'},
          ),
        );
      fixture.repository.selectedSpeciesIds = ['goat'];
      await mountCare(t, fixture);
      await tapCare(t, find.byTooltip('Trang sau'));
      expect(find.text('Trang 2 · 21 kết quả'), findsOneWidget);
      await tapCare(t, taskButton('task-20', 'Hoàn thành'));
      await tapCare(
        t,
        find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
      );
      expect(find.text('Trang 1 · 20 kết quả'), findsOneWidget);
      expect(
        fixture.requests
            .where(
              (r) => r.url.path.endsWith('/care-tasks') && r.method == 'GET',
            )
            .every((r) => r.url.queryParameters['speciesIds'] == 'goat'),
        isTrue,
      );
    },
  );
  testWidgets(
    'initial/stale errors distinguish empty data and disable writes until retry',
    (t) async {
      final fixture = CareFixture()..failList = true;
      await mountCare(t, fixture);
      expect(find.text('Không có lịch chăm sóc.'), findsNothing);
      fixture.failList = false;
      await tapCare(t, find.byTooltip('Tải lại'));
      fixture.failList = true;
      await tapCare(t, find.byTooltip('Tải lại'));
      expect(
        find.textContaining('Đang hiển thị lịch từ lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.ancestor(
                of: taskButton('overdue', 'Hoàn thành'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      fixture
        ..failList = false
        ..tasks.clear();
      await tapCare(t, find.byTooltip('Tải lại'));
      expect(find.text('Không có lịch chăm sóc.'), findsOneWidget);
    },
  );
  testWidgets(
    'workspace dashboard refreshes after care write without remounting saved pages',
    (t) async {
      final fixture = CareFixture();
      await mountCare(t, fixture, workspace: true);
      expect(fixture.dashboardLoads, 1);
      await tapCare(t, find.byKey(const ValueKey('tab-care')));
      await tapCare(t, taskButton('overdue', 'Hoàn thành'));
      await tapCare(
        t,
        find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
      );
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Đã hoàn thành'));
      await tapCare(t, find.byKey(const ValueKey('tab-overview')));
      expect(fixture.dashboardLoads, 2);
      expect(
        find.text('1 việc hôm nay · 0 quá hạn · 7 ngày tới'),
        findsOneWidget,
      );
      await tapCare(t, find.byKey(const ValueKey('tab-care')));
      expect(task('overdue'), findsOneWidget);
      expect(
        t
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Đã hoàn thành'),
            )
            .selected,
        isTrue,
      );
      expect(fixture.listLoads, 4);
    },
  );
  testWidgets(
    'schedule from profile keeps selected animal and returns to refreshed history',
    (t) async {
      final fixture = CareFixture('STAFF');
      await mountCare(t, fixture);
      await tapCare(t, taskButton('overdue', 'Hồ sơ vật nuôi'));
      await tapCare(t, find.text('Đặt lịch chăm sóc'));
      expect(inCare(find.text('DE-000')), findsOneWidget);
      expect(
        inCare(
          find.widgetWithText(DropdownButtonFormField<String>, 'Vật nuôi'),
        ),
        findsNothing,
      );
      await fillCare(t, 'Nội dung / tên vaccine', 'Lịch từ hồ sơ');
      await tapCare(t, find.widgetWithText(FilledButton, 'Lưu lịch'));
      expect(fixture.bodies.single!['animalId'], 'animal-0');
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/animals')),
        isEmpty,
      );
      await tapCare(t, find.byKey(const ValueKey('profile-tab-3')));
      expect(find.textContaining('Lịch từ hồ sơ'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(task('created'), findsOneWidget);
    },
  );
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets('list $width groups long schedules at scale 1.3', (t) async {
      final fixture = CareFixture();
      final boundary = await mountCare(t, fixture, width: width);
      await tapCare(t, find.widgetWithText(ChoiceChip, 'Tất cả'));
      await t.ensureVisible(find.text('Lịch chăm sóc'));
      await captureCare(t, boundary, 'list-${width.toInt()}-top');
      await tapCare(
        t,
        taskButton('cancelled', 'Hồ sơ vật nuôi').first,
      ); // verify route remains available
      await t.pageBack();
      await t.pumpAndSettle();
      await t.ensureVisible(task('cancelled'));
      await captureCare(t, boundary, 'list-${width.toInt()}-bottom');
    });
    for (final mode in ['create', 'edit', 'complete']) {
      testWidgets(
        '$mode $width keeps CTA above keyboard, draft through resize and error',
        (t) async {
          final fixture = CareFixture()
            ..writeError =
                'Không lưu được lịch. Bản nháp và lựa chọn vẫn được giữ để thử lại.';
          final boundary = await mountCare(t, fixture, width: width);
          if (mode == 'create') {
            await tapCare(t, find.text('Đặt lịch'));
            await chooseAnimal(t, 0);
            await fillCare(
              t,
              'Nội dung / tên vaccine',
              'Lịch có tiêu đề dài để kiểm tra tiếng Việt',
            );
          } else {
            await tapCare(
              t,
              taskButton('overdue', mode == 'edit' ? 'Sửa lịch' : 'Hoàn thành'),
            );
          }
          await t.ensureVisible(inCare(find.byType(Form)));
          await captureCare(t, boundary, '$mode-${width.toInt()}-top');
          final label = mode == 'complete' ? 'Ghi chú kết quả' : 'Ghi chú';
          await fillCare(
            t,
            label,
            'Ghi chú nhiều dòng của lịch chăm sóc.\nKhông làm mất nội dung khi có bàn phím hoặc đổi kích thước.',
          );
          final action = mode == 'complete'
              ? 'Xác nhận hoàn thành'
              : mode == 'create'
              ? 'Tạo 1 lịch'
              : 'Lưu lịch';
          await captureCare(t, boundary, '$mode-${width.toInt()}-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(careField(label));
          await t.pumpAndSettle();
          final save = find.widgetWithText(FilledButton, action);
          expect(t.getBottomRight(save).dy, lessThanOrEqualTo(800));
          expect(save.hitTestable(), findsOneWidget);
          await captureCare(t, boundary, '$mode-${width.toInt()}-keyboard');
          await tapCare(t, save);
          expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
          await captureCare(t, boundary, '$mode-${width.toInt()}-error');
          t.view.viewInsets = const FakeViewPadding();
          t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
          await t.pumpAndSettle();
          expect(
            t.widget<TextFormField>(careField(label)).controller!.text,
            contains('Không làm mất'),
          );
          await tapCare(t, find.widgetWithText(TextButton, 'Hủy'));
          expect(fixture.writes.length, 1);
        },
      );
    }
  }
}
