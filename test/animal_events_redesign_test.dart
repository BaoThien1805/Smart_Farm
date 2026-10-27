import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_detail_page.dart';
import 'package:smart_farm/features/farm/animal_event_form.dart';

import 'support/animal_events_fixture.dart';
import 'support/ui_preview.dart';

Future<GlobalKey> mountEvents(
  WidgetTester t,
  AnimalEventsFixture fixture, {
  String role = 'ADMIN',
  double width = 412,
}) async {
  t.view.physicalSize = Size(width, 1100);
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
      home: AnimalDetailPage(
        repository: fixture.repository,
        id: 'profile',
        admin: role == 'ADMIN',
        canOperate: ['ADMIN', 'STAFF'].contains(role),
        canCare: role != 'ACCOUNTANT',
        canExamine: ['ADMIN', 'VET'].contains(role),
      ),
    ),
  );
  await t.pumpAndSettle();
  return boundary;
}

Finder eventField(String text) => find.widgetWithText(TextFormField, text);
Finder inEvent(Finder finder) =>
    find.descendant(of: find.byType(AnimalEventForm), matching: finder);
Finder eventSave(AnimalEventKind kind) =>
    find.widgetWithText(FilledButton, kind.action);
Future<void> tapEvent(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> fillEvent(WidgetTester t, String label, String value) async {
  await t.ensureVisible(eventField(label));
  await t.enterText(eventField(label), value);
  await t.pump();
}

Future<void> openEvent(WidgetTester t, AnimalEventKind kind) async {
  await tapEvent(t, find.text(kind.title));
  if (kind == AnimalEventKind.death) {
    expect(find.textContaining('giải phóng chỗ chuồng'), findsOneWidget);
    await tapEvent(t, find.widgetWithText(FilledButton, 'Xác nhận'));
  }
  expect(find.byType(AnimalEventForm), findsOneWidget);
}

Future<void> chooseStatus(WidgetTester t, String label) async {
  await tapEvent(
    t,
    find.widgetWithText(DropdownButtonFormField<String>, 'Tình trạng'),
  );
  await tapEvent(t, find.text(label).last);
}

Future<void> readyEvent(WidgetTester t, AnimalEventKind kind) async {
  switch (kind) {
    case AnimalEventKind.weights:
      await fillEvent(t, 'Cân nặng (kg)', '215,500');
    case AnimalEventKind.transfer:
      await tapEvent(
        t,
        find.widgetWithText(DropdownButtonFormField<String>, 'Chuồng mới'),
      );
      await tapEvent(t, find.text('B1 · Chuồng B (0/10)').last);
    case AnimalEventKind.health:
      await fillEvent(t, 'Nội dung quan sát', 'Quan sát ăn uống');
    case AnimalEventKind.exams:
      await fillEvent(t, 'Nội dung kiểm tra / điều trị', 'Khám định kỳ');
      await fillEvent(t, 'Chẩn đoán', 'Chẩn đoán có đủ nội dung chuyên môn.');
    case AnimalEventKind.death:
      break;
  }
}

Future<void> captureEvent(
  WidgetTester t,
  GlobalKey boundary,
  String name,
) async {
  final context = t.element(find.byType(AnimalEventForm));
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
  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role keeps only authorized events', (t) async {
      final fixture = AnimalEventsFixture();
      await mountEvents(t, fixture, role: role);
      final allowed = {
        AnimalEventKind.weights: ['ADMIN', 'STAFF'].contains(role),
        AnimalEventKind.transfer: ['ADMIN', 'STAFF'].contains(role),
        AnimalEventKind.health: role != 'ACCOUNTANT',
        AnimalEventKind.exams: ['ADMIN', 'VET'].contains(role),
        AnimalEventKind.death: role == 'ADMIN',
      };
      for (final entry in allowed.entries) {
        expect(
          find.text(entry.key.title),
          entry.value ? findsOneWidget : findsNothing,
        );
        if (entry.value) {
          await openEvent(t, entry.key);
          expect(inEvent(find.text('BO-001')), findsOneWidget);
          if (entry.key == AnimalEventKind.health) {
            expect(eventField('Chẩn đoán'), findsNothing);
          }
          await tapEvent(t, find.widgetWithText(TextButton, 'Hủy'));
        }
      }
      expect(fixture.bodies, isEmpty);
    });
  }
  for (final lifecycle in ['SOLD', 'DEAD']) {
    testWidgets('$lifecycle has no writable event entry', (t) async {
      final fixture = AnimalEventsFixture()..animal['status'] = lifecycle;
      await mountEvents(t, fixture);
      for (final kind in AnimalEventKind.values) {
        expect(find.text(kind.title), findsNothing);
      }
      expect(fixture.bodies, isEmpty);
    });
  }
  for (final value in ['215,500', '215.001', '100000']) {
    testWidgets('weight $value preserves numeric value and refreshes profile', (
      t,
    ) async {
      final fixture = AnimalEventsFixture();
      await mountEvents(t, fixture, role: 'STAFF');
      await openEvent(t, AnimalEventKind.weights);
      await fillEvent(t, 'Cân nặng (kg)', value);
      await t.tap(eventSave(AnimalEventKind.weights));
      await t.pumpAndSettle();
      expect(
        fixture.bodies.single['kg'],
        num.parse(value.replaceAll(',', '.')),
      );
      expect(fixture.bodies.single.keys.toSet(), {
        'kg',
        'date',
        'notes',
        'requestId',
      });
      expect(
        fixture.bodies.single['requestId'],
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
      expect(fixture.detailLoads, 2);
      expect(find.byType(AnimalEventForm), findsNothing);
    });
  }
  testWidgets(
    'weight rejects invalid, nonfinite, excess precision and grouping without saving',
    (t) async {
      final fixture = AnimalEventsFixture();
      await mountEvents(t, fixture);
      await openEvent(t, AnimalEventKind.weights);
      for (final input in [
        '',
        '0',
        '-1',
        'NaN',
        'Infinity',
        '215.0001',
        '100000.001',
        '1.234,5',
      ]) {
        await fillEvent(t, 'Cân nặng (kg)', input);
        await t.tap(eventSave(AnimalEventKind.weights));
        await t.pumpAndSettle();
        expect(fixture.bodies, isEmpty);
        expect(t.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'weight delta uses exact thousandths and latest record before selected date only',
    (t) async {
      final fixture = AnimalEventsFixture();
      fixture.weights
        ..clear()
        ..addAll([
          {'date': '2026-02-01', 'kg': 215.001},
          {'date': '2026-01-01', 'kg': 210.5},
          {'date': '2099-01-01', 'kg': 999},
        ]);
      await mountEvents(t, fixture);
      await openEvent(t, AnimalEventKind.weights);
      await fillEvent(t, 'Cân nặng (kg)', '215,5');
      expect(find.text('Chênh lệch dự kiến: +0,499 kg'), findsOneWidget);
      await fillEvent(t, 'Cân nặng (kg)', '215.000');
      expect(find.text('Chênh lệch dự kiến: -0,001 kg'), findsOneWidget);
      t.widget<TextFormField>(eventField('Ngày thực hiện')).controller!.text =
          '2026-01-15';
      await fillEvent(t, 'Cân nặng (kg)', '210.5');
      expect(find.text('Chênh lệch dự kiến: 0 kg'), findsOneWidget);
      t.widget<TextFormField>(eventField('Ngày thực hiện')).controller!.text =
          '2025-01-01';
      await fillEvent(t, 'Cân nặng (kg)', '210.500');
      expect(inEvent(find.textContaining('Chênh lệch dự kiến:')), findsNothing);
      expect(
        find.text('Chưa có bản ghi cân trước ngày đang chọn.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'STAFF observation requires content, offers exactly two states and sends no diagnosis',
    (t) async {
      final fixture = AnimalEventsFixture();
      await mountEvents(t, fixture, role: 'STAFF');
      await openEvent(t, AnimalEventKind.health);
      await t.tap(eventSave(AnimalEventKind.health));
      await t.pumpAndSettle();
      expect(fixture.bodies, isEmpty);
      await fillEvent(t, 'Nội dung quan sát', ' Quan sát vận động ');
      final dropdown = find.descendant(
        of: find.widgetWithText(DropdownButtonFormField<String>, 'Tình trạng'),
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        t.widget<DropdownButton<String>>(dropdown).items!.map((i) => i.value),
        ['NORMAL', 'NEEDS_CARE'],
      );
      await chooseStatus(t, 'Cần chăm sóc');
      await t.tap(eventSave(AnimalEventKind.health));
      await t.pumpAndSettle();
      expect(fixture.bodies.single['content'], 'Quan sát vận động');
      expect(fixture.bodies.single['status'], 'NEEDS_CARE');
      expect(fixture.bodies.single.containsKey('diagnosis'), isFalse);
      expect(fixture.detailLoads, 2);
    },
  );
  testWidgets(
    'VET diagnosis is required, treatment optional and long clinical text stays intact',
    (t) async {
      final fixture = AnimalEventsFixture();
      await mountEvents(t, fixture, role: 'VET');
      await openEvent(t, AnimalEventKind.exams);
      await fillEvent(t, 'Nội dung kiểm tra / điều trị', 'Khám');
      await t.tap(eventSave(AnimalEventKind.exams));
      await t.pumpAndSettle();
      expect(find.text('Vui lòng nhập.').hitTestable(), findsOneWidget);
      expect(fixture.bodies, isEmpty);
      final longDiagnosis = List.filled(20, 'Chẩn đoán chuyên môn. ').join();
      await fillEvent(t, 'Chẩn đoán', longDiagnosis);
      await t.tap(eventSave(AnimalEventKind.exams));
      await t.pumpAndSettle();
      expect(fixture.bodies.single['diagnosis'], longDiagnosis.trim());
      expect(fixture.bodies.single['treatment'], '');
      expect(fixture.requests.last.url.path, endsWith('/catalogs'));
      expect(fixture.healthRecords.last['recordType'], 'EXAM');
    },
  );
  testWidgets(
    'transfer excludes current, full and inactive pens, retains choice on rejection',
    (t) async {
      final fixture = AnimalEventsFixture()
        ..eventError = 'Chuồng vừa đầy. Hãy chọn chuồng khác.';
      await mountEvents(t, fixture, role: 'STAFF');
      await openEvent(t, AnimalEventKind.transfer);
      await readyEvent(t, AnimalEventKind.transfer);
      final dropdown = find.descendant(
        of: find.widgetWithText(DropdownButtonFormField<String>, 'Chuồng mới'),
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        t.widget<DropdownButton<String>>(dropdown).items!.map((i) => i.value),
        ['pen2'],
      );
      expect(find.textContaining('Còn 10 chỗ.'), findsOneWidget);
      await fillEvent(t, 'Ghi chú', 'Chuyển theo kế hoạch');
      await t.tap(eventSave(AnimalEventKind.transfer));
      await t.pumpAndSettle();
      expect(find.text(fixture.eventError!).hitTestable(), findsOneWidget);
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.widgetWithText(
                DropdownButtonFormField<String>,
                'Chuồng mới',
              ),
            )
            .initialValue,
        'pen2',
      );
      fixture.eventError = null;
      await t.tap(eventSave(AnimalEventKind.transfer));
      await t.pumpAndSettle();
      expect(fixture.bodies.first, fixture.bodies.last);
      expect(fixture.animal['penId'], 'pen2');
      expect(fixture.detailLoads, 2);
    },
  );
  testWidgets('no destination explains capacity and disables transfer save', (
    t,
  ) async {
    final fixture = AnimalEventsFixture()
      ..pens.removeWhere((p) => p['id'] == 'pen2');
    await mountEvents(t, fixture);
    await openEvent(t, AnimalEventKind.transfer);
    expect(find.textContaining('Chưa có chuồng khác'), findsOneWidget);
    expect(
      t.widget<FilledButton>(eventSave(AnimalEventKind.transfer)).onPressed,
      isNull,
    );
    expect(fixture.bodies, isEmpty);
  });
  testWidgets(
    'death retains confirmation, history, optional notes and reloads DEAD profile',
    (t) async {
      final fixture = AnimalEventsFixture();
      await mountEvents(t, fixture);
      await tapEvent(t, find.text('Ghi nhận chết'));
      await tapEvent(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.bodies, isEmpty);
      await openEvent(t, AnimalEventKind.death);
      expect(find.textContaining('Lịch sử được giữ lại.'), findsOneWidget);
      expect(inEvent(find.byType(Image)), findsNothing);
      await t.tap(eventSave(AnimalEventKind.death));
      await t.pumpAndSettle();
      expect(fixture.bodies.single.keys.toSet(), {
        'date',
        'notes',
        'requestId',
      });
      expect(fixture.bodies.single['notes'], '');
      expect(fixture.weights, isNotEmpty);
      expect(fixture.careTasks.where((t) => t['status'] == 'PENDING'), isEmpty);
      expect(fixture.animal['status'], 'DEAD');
      for (final kind in AnimalEventKind.values) {
        expect(find.text(kind.title), findsNothing);
      }
    },
  );
  for (final kind in AnimalEventKind.values) {
    testWidgets(
      '${kind.name} retry keeps payload/id and busy blocks duplicate, Back and cancel',
      (t) async {
        final fixture = AnimalEventsFixture()
          ..eventError = 'Lỗi lưu thử nghiệm. Nội dung vẫn được giữ.';
        await mountEvents(t, fixture);
        await openEvent(t, kind);
        await readyEvent(t, kind);
        await fillEvent(t, 'Ghi chú', ' Nháp cần giữ ');
        await t.tap(eventSave(kind));
        await t.pumpAndSettle();
        expect(find.text(fixture.eventError!).hitTestable(), findsOneWidget);
        expect(
          t.widget<TextFormField>(eventField('Ghi chú')).controller!.text,
          ' Nháp cần giữ ',
        );
        final pending = Completer<void>();
        fixture
          ..eventError = null
          ..pending = pending.future;
        final button = eventSave(kind);
        await t.tap(button);
        await t.tap(button);
        await t.pump();
        expect(fixture.bodies.length, 2);
        expect(fixture.bodies.first, fixture.bodies.last);
        expect(
          t
              .widget<TextButton>(find.widgetWithText(TextButton, 'Hủy'))
              .onPressed,
          isNull,
        );
        await t.binding.handlePopRoute();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(AnimalEventForm), findsOneWidget);
        pending.complete();
        await t.pumpAndSettle();
        expect(find.byType(AnimalEventForm), findsNothing);
        expect(fixture.detailLoads, 2);
      },
    );
  }
  for (final width in [360.0, 412.0, 1200.0]) {
    for (final kind in AnimalEventKind.values) {
      testWidgets(
        '${kind.name} $width with long text, scale 1.3, keyboard and resize',
        (t) async {
          final fixture = AnimalEventsFixture()
            ..eventError =
                'Không lưu được bản ghi. Hãy kiểm tra nội dung rồi thử lại; bản nháp vẫn được giữ.';
          final boundary = await mountEvents(t, fixture, width: width);
          await openEvent(t, kind);
          await readyEvent(t, kind);
          final name = '${kind.name}-${width.toInt()}';
          await tapEvent(t, inEvent(find.text(kind.title)));
          await captureEvent(t, boundary, '$name-top');
          await fillEvent(
            t,
            'Ghi chú',
            'Ghi chú nhiều dòng của vật nuôi.\nGiữ đầy đủ nội dung khi cuộn, đổi kích thước và có lỗi.',
          );
          await captureEvent(t, boundary, '$name-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(eventField('Ghi chú'));
          await t.pumpAndSettle();
          expect(t.getBottomRight(eventSave(kind)).dy, lessThanOrEqualTo(800));
          expect(eventSave(kind).hitTestable(), findsOneWidget);
          await captureEvent(t, boundary, '$name-keyboard');
          await t.tap(eventSave(kind));
          await t.pumpAndSettle();
          expect(find.text(fixture.eventError!).hitTestable(), findsOneWidget);
          await captureEvent(t, boundary, '$name-error');
          t.view.viewInsets = const FakeViewPadding();
          t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
          await t.pumpAndSettle();
          expect(
            t.widget<TextFormField>(eventField('Ghi chú')).controller!.text,
            contains('đầy đủ'),
          );
          await tapEvent(t, find.widgetWithText(TextButton, 'Hủy'));
          expect(fixture.bodies.length, 1);
          expect(fixture.detailLoads, 1);
        },
      );
    }
  }
}
