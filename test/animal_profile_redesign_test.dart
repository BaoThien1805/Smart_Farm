import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_detail_page.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/farm_pages.dart' show WeightChart;

import 'photo_workflow_test.dart' show ImagePicker;
import 'support/animal_profile_fixture.dart';
import 'support/animals_fixture.dart' show AnimalsFixture;
import 'support/ui_preview.dart';

Future<AnimalProfileFixture> mountProfile(
  WidgetTester t, {
  AnimalProfileFixture? fixture,
  String role = 'ADMIN',
  double width = 412,
  GlobalKey? boundary,
}) async {
  final source = fixture ?? AnimalProfileFixture();
  addTearDown(source.dispose);
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: AnimalDetailPage(
        repository: source.repository,
        id: 'profile',
        admin: role == 'ADMIN',
        canOperate: ['ADMIN', 'STAFF'].contains(role),
        canCare: role != 'ACCOUNTANT',
        canExamine: ['ADMIN', 'VET'].contains(role),
        canFinance: ['ADMIN', 'ACCOUNTANT'].contains(role),
      ),
    ),
  );
  await t.pumpAndSettle();
  return source;
}

Future<void> tapProfile(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> profileTab(WidgetTester t, int index) =>
    tapProfile(t, find.byKey(ValueKey('profile-tab-$index')));
Future<void> captureProfile(
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
  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role gets only permitted profile and financial actions', (
      t,
    ) async {
      final fixture = await mountProfile(t, role: role);
      final operate = ['ADMIN', 'STAFF'].contains(role),
          care = role != 'ACCOUNTANT',
          examine = ['ADMIN', 'VET'].contains(role),
          finance = ['ADMIN', 'ACCOUNTANT'].contains(role);
      expect(
        find.text('Ghi cân nặng'),
        operate ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Chuyển chuồng'),
        operate ? findsOneWidget : findsNothing,
      );
      expect(find.text('Ghi sức khỏe'), care ? findsOneWidget : findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Khám thú y'),
        examine ? findsOneWidget : findsNothing,
      );
      expect(find.text('Sửa hồ sơ'), operate ? findsOneWidget : findsNothing);
      expect(
        find.byTooltip('Đổi ảnh qua chỉnh sửa hồ sơ'),
        operate ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Bán vật nuôi'),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byTooltip('Xóa hồ sơ nhập nhầm'),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      await profileTab(t, 3);
      expect(
        find.byType(SalesHistory),
        finance ? findsOneWidget : findsNothing,
      );
      expect(fixture.salesRequests.length, finance ? 1 : 0);
      if (finance) {
        expect(
          fixture.salesRequests.single.url.queryParameters['animalId'],
          'profile',
        );
        expect(
          find.textContaining('9.007.199.254.740.993.123 ₫'),
          findsOneWidget,
        );
        expect(find.textContaining('Nhập nhầm'), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }

  for (final status in ['SOLD', 'DEAD']) {
    testWidgets(
      '$status keeps all read data but hides active animal operations',
      (t) async {
        final fixture = AnimalProfileFixture()..animal['status'] = status;
        await mountProfile(t, fixture: fixture);
        for (final text in [
          'Ghi cân nặng',
          'Chuyển chuồng',
          'Ghi sức khỏe',
          'Sửa hồ sơ',
          'Bán vật nuôi',
          'Ghi nhận chết',
          'Đặt lịch chăm sóc',
        ]) {
          expect(find.text(text), findsNothing);
        }
        expect(find.byTooltip('Đổi ảnh qua chỉnh sửa hồ sơ'), findsNothing);
        expect(find.byTooltip('Xóa hồ sơ nhập nhầm'), findsNothing);
        await profileTab(t, 1);
        expect(find.byType(WeightChart), findsOneWidget);
        await profileTab(t, 2);
        expect(
          find.textContaining('Chẩn đoán có nội dung dài'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'timeline uses actual dates and actors and keeps creator distinct from performer',
    (t) async {
      await mountProfile(t, role: 'STAFF');
      await profileTab(t, 3);
      expect(find.text('Ghi cân: 20.5 kg'), findsOneWidget);
      expect(find.text('Ghi cân: 22.0 kg'), findsOneWidget);
      expect(find.textContaining('Từ Chuồng cũ đến Chuồng A'), findsOneWidget);
      expect(find.textContaining('Chẩn đoán có nội dung dài'), findsOneWidget);
      expect(find.text('Người thực hiện: Bác sĩ Mai'), findsOneWidget);
      expect(find.text('Người tạo lịch: Người lập lịch'), findsNWidgets(3));
      expect(find.text('Người thực hiện: Người lập lịch'), findsNothing);
      expect(find.textContaining('Thực hiện: 06/04/2026'), findsOneWidget);
      expect(find.text('Ngày của lịch: 2026-04-08'), findsOneWidget);
      expect(find.text('Nhập trại'), findsNothing);
      expect(
        t.getTopLeft(find.text('Lịch chăm sóc: Kiểm tra sắp tới')).dy,
        lessThan(t.getTopLeft(find.text('Ghi cân: 20.5 kg')).dy),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'tabs do not reload data; refresh preserves selected tab, image and sales page',
    (t) async {
      final fixture = AnimalProfileFixture();
      for (var i = 0; i < 20; i++) {
        fixture.sales.add({...fixture.sales.first, 'id': 'sale${i + 2}'});
      }
      await mountProfile(t, fixture: fixture);
      final initialSalesState = t.state(
        find.byType(SalesHistory, skipOffstage: false),
      );
      for (final index in [1, 2, 3, 0, 3]) {
        await profileTab(t, index);
      }
      expect(fixture.detailLoads, 1);
      expect(fixture.salesRequests.length, 1);
      await tapProfile(t, find.byTooltip('Trang sau'));
      expect(fixture.salesRequests.last.url.queryParameters['page'], '2');
      await tapProfile(t, find.byTooltip('Tải lại hồ sơ'));
      expect(
        t
            .widget<ChoiceChip>(find.byKey(const ValueKey('profile-tab-3')))
            .selected,
        isTrue,
      );
      expect(t.state(find.byType(SalesHistory)), same(initialSalesState));
      expect(fixture.detailLoads, 2);
      expect(fixture.salesRequests.length, 3);
      expect(fixture.salesRequests.last.url.queryParameters['page'], '2');
      final image = t.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'photo entry reuses editor; chosen image saves only through existing PATCH and survives refresh',
    (t) async {
      final fixture = AnimalProfileFixture()..animal['imageData'] = '%%%';
      await mountProfile(t, fixture: fixture, role: 'STAFF');
      final previousPicker = FileSelectorPlatform.instance;
      FileSelectorPlatform.instance = ImagePicker(
        base64Decode(AnimalsFixture.photo),
      );
      addTearDown(() => FileSelectorPlatform.instance = previousPicker);
      await tapProfile(t, find.byTooltip('Đổi ảnh qua chỉnh sửa hồ sơ'));
      final picker = find.text('Chọn ảnh từ thiết bị');
      await t.ensureVisible(picker);
      await t.runAsync(() async {
        await t.tap(picker);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pumpAndSettle();
      expect(fixture.bodies, isEmpty);
      await tapProfile(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(
        fixture.requests.lastWhere((r) => r.method == 'PATCH').url.path,
        '/api/animals/profile',
      );
      expect(fixture.bodies.single['photoBase64'], isNotEmpty);
      expect(fixture.bodies.single.containsKey('penId'), isFalse);
      expect(t.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
      await tapProfile(t, find.byTooltip('Tải lại hồ sơ'));
      expect(t.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'transfer entry keeps original available-pen rules and cancel does not save',
    (t) async {
      final fixture = await mountProfile(t, role: 'STAFF');
      await tapProfile(t, find.widgetWithText(OutlinedButton, 'Chuyển chuồng'));
      final field = t.widget<DropdownButton<String>>(
        find.descendant(
          of: find.widgetWithText(
            DropdownButtonFormField<String>,
            'Chuồng mới',
          ),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(field.items!.map((i) => i.value), ['pen2']);
      await tapProfile(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.bodies, isEmpty);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'death and delete retain confirmation; linked deletion error keeps profile intact',
    (t) async {
      final fixture = await mountProfile(t);
      await tapProfile(t, find.widgetWithText(OutlinedButton, 'Ghi nhận chết'));
      expect(find.textContaining('giải phóng chỗ chuồng'), findsOneWidget);
      await tapProfile(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.bodies, isEmpty);
      await tapProfile(t, find.byTooltip('Xóa hồ sơ nhập nhầm'));
      await tapProfile(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tapProfile(t, find.byTooltip('Xóa hồ sơ nhập nhầm'));
      await tapProfile(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      expect(find.text(fixture.deleteError!), findsOneWidget);
      expect(find.text('BO-001'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'empty histories stay truthful, load errors retry and stale profile disables writes',
    (t) async {
      final fixture = AnimalProfileFixture()
        ..clearHistory()
        ..failDetail = true;
      await mountProfile(t, fixture: fixture);
      expect(find.text('BO-001'), findsNothing);
      fixture.failDetail = false;
      await tapProfile(t, find.byTooltip('Tải lại hồ sơ'));
      await profileTab(t, 1);
      expect(find.text('Chưa ghi cân nặng.'), findsOneWidget);
      await profileTab(t, 2);
      expect(find.text('Chưa có lần kiểm tra / điều trị.'), findsOneWidget);
      await profileTab(t, 3);
      expect(find.textContaining('Chưa có bản ghi cân'), findsOneWidget);
      fixture.failDetail = true;
      await tapProfile(t, find.byTooltip('Tải lại hồ sơ'));
      expect(
        find.textContaining('Đang hiển thị hồ sơ từ lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Ghi cân nặng'),
            )
            .onPressed,
        isNull,
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0, 1200.0]) {
    for (final index in [0, 1, 2, 3]) {
      testWidgets(
        'profile tab $index fits $width with long names and scale 1.3',
        (t) async {
          final boundary = GlobalKey();
          await mountProfile(t, width: width, boundary: boundary);
          await profileTab(t, index);
          await t.ensureVisible(find.byTooltip('Tải lại hồ sơ'));
          await t.pumpAndSettle();
          await captureProfile(t, boundary, 'profile-$index-${width.toInt()}');
          final section = find.byKey(ValueKey('profile-section-$index'));
          final content = find
              .descendant(of: section, matching: find.byType(Text))
              .last;
          await t.ensureVisible(content);
          await t.pumpAndSettle();
          await captureProfile(
            t,
            boundary,
            'profile-$index-bottom-${width.toInt()}',
          );
        },
      );
    }
  }
}
