import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/animal_detail_page.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/revenue_chart.dart';
import 'package:smart_farm/features/farm/sales_forms.dart';

import 'finance_ledger_redesign_test.dart'
    show mountLedger, tapLedger, pickLedger;
import 'support/reports_sales_fixture.dart';
import 'support/animals_fixture.dart';
import 'support/ui_preview.dart';
import 'support/workspace_fixture.dart';

Finder inSale(Finder f) =>
    find.descendant(of: find.byType(SaleEditor), matching: f);
Finder saleField(String label) =>
    inSale(find.widgetWithText(TextFormField, label));
Finder saleAction(bool cancel) => inSale(
  find.widgetWithText(FilledButton, cancel ? 'Xác nhận hủy' : 'Xác nhận bán'),
);
Finder saleCard(String id) => find.byKey(ValueKey('sale-$id'));
Finder cancelAction(String id) =>
    find.descendant(of: saleCard(id), matching: find.text('Hủy bán'));
Future<void> fillSale(WidgetTester t, String label, String value) async {
  await t.ensureVisible(saleField(label));
  await t.enterText(saleField(label), value);
  await t.pump();
}

Future<void> pickPen(WidgetTester t) async {
  await tapLedger(t, inSale(find.byType(DropdownButtonFormField<String>)));
  await tapLedger(t, find.text('A1 · Chuồng mẫu (1/10)').last);
}

Future<GlobalKey> mountSale(
  WidgetTester t,
  ReportsSalesFixture f, {
  bool cancel = false,
  double width = 412,
  String imageData = '',
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  addTearDown(f.dispose);
  final boundary = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              if (cancel) {
                cancelSaleForm(
                  context,
                  f.repository,
                  FarmRecord(f.sales.first),
                  admin: f.auth.user!.isAdmin,
                );
              } else {
                sellAnimalForm(
                  context,
                  f.repository,
                  FarmRecord({
                    ...WorkspaceFixture.animal,
                    'status': f.animalStatus,
                    'imageData': imageData,
                  }),
                  admin: f.auth.user!.isAdmin,
                );
              }
            },
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tapLedger(t, find.text('Mở'));
  return boundary;
}

Future<void> captureSales(WidgetTester t, GlobalKey b, String name) async {
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, b, '$name.png');
}

Future<void> reportTab(WidgetTester t) =>
    tapLedger(t, find.widgetWithText(ChoiceChip, 'Báo cáo'));
Future<void> salesTab(WidgetTester t) =>
    tapLedger(t, find.widgetWithText(ChoiceChip, 'Giao dịch bán'));
Future<void> filterSales(WidgetTester t, String label) async {
  await tapLedger(
    t,
    find.widgetWithText(
      DropdownButtonFormField<String>,
      'Trạng thái giao dịch bán',
    ),
  );
  await tapLedger(t, find.text(label).last);
}

Finder reportMonth(String m) => find.byKey(ValueKey('report-month-$m'));
Finder monthText(String m, String text) =>
    find.descendant(of: reportMonth(m), matching: find.text(text));

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final role in ['ADMIN', 'ACCOUNTANT', 'STAFF', 'VET']) {
    testWidgets('$role report and sale access follow existing permissions', (
      t,
    ) async {
      final f = ReportsSalesFixture(role);
      await mountLedger(t, f);
      if (role == 'STAFF' || role == 'VET') {
        expect(f.requests, isEmpty);
        expect(find.byType(SalesHistory), findsNothing);
        return;
      }
      await reportTab(t);
      expect(find.byType(MonthlyFinanceChart), findsOneWidget);
      await salesTab(t);
      expect(
        cancelAction('sale'),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      expect(cancelAction('cancelled-sale'), findsNothing);
    });
  }
  for (final role in ['ACCOUNTANT', 'STAFF', 'VET']) {
    for (final cancel in [false, true]) {
      testWidgets(
        '$role cannot open ${cancel ? 'cancellation' : 'sale'} through wrapper',
        (t) async {
          final f = ReportsSalesFixture(role);
          await mountSale(t, f, cancel: cancel);
          expect(find.byType(SaleEditor), findsNothing);
          expect(f.writes, isEmpty);
        },
      );
    }
  }
  testWidgets('already canceled sale cannot open cancellation or load pens', (
    t,
  ) async {
    final f = ReportsSalesFixture();
    f.sales.removeAt(0);
    await mountSale(t, f, cancel: true);
    expect(find.byType(SaleEditor), findsNothing);
    expect(f.requests, isEmpty);
  });
  for (final status in ['SOLD', 'DEAD']) {
    testWidgets('$status animal cannot be sold', (t) async {
      final f = ReportsSalesFixture()..animalStatus = status;
      await mountSale(t, f);
      expect(find.byType(SaleEditor), findsNothing);
      expect(f.writes, isEmpty);
    });
  }
  testWidgets(
    'sale header prioritizes the actual animal photo over the species sticker',
    (t) async {
      final f = ReportsSalesFixture();
      await mountSale(t, f, imageData: AnimalsFixture.photo);
      expect(
        t.widget<Image>(inSale(find.byType(Image))).image,
        isA<MemoryImage>(),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'sale validates exact integer VND bounds, preserves optional fields and id across retry',
    (t) async {
      final f = ReportsSalesFixture()
        ..writeError = 'Ngày bán không thể trước lịch sử đã ghi.';
      await mountSale(t, f);
      for (final value in [
        '0',
        '-1',
        'NaN',
        'Infinity',
        '18.000.000',
        '10.5',
        '1000000000001',
      ]) {
        await fillSale(t, 'Số tiền (VND)', value);
        await tapLedger(t, saleAction(false));
        expect(f.writes, isEmpty);
      }
      await fillSale(t, 'Số tiền (VND)', '1000000000000');
      await fillSale(t, 'Người mua (tùy chọn)', 'Người mua có tên dài');
      await fillSale(t, 'Ghi chú (tùy chọn)', 'Ghi chú bán chính xác');
      await tapLedger(t, saleAction(false));
      expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(saleField('Người mua (tùy chọn)'))
            .controller!
            .text,
        'Người mua có tên dài',
      );
      final expected = {...f.bodies.single};
      expect(expected['amount'], 1000000000000);
      expect(expected['buyer'], 'Người mua có tên dài');
      expect(expected['notes'], 'Ghi chú bán chính xác');
      expect(expected['date'], farmToday());
      expect(expected['requestId'], isNotEmpty);
      f.writeError = null;
      await tapLedger(t, saleAction(false));
      expect(f.bodies.last, expected);
      expect(f.writes.last.url.path, endsWith('/animals/animal/sell'));
      expect(f.animalStatus, 'SOLD');
    },
  );
  testWidgets('sale allows empty buyer and notes without invented fields', (
    t,
  ) async {
    final f = ReportsSalesFixture();
    await mountSale(t, f);
    await fillSale(t, 'Số tiền (VND)', '1');
    await tapLedger(t, saleAction(false));
    expect(f.bodies.single.keys.toSet(), {
      'requestId',
      'date',
      'amount',
      'buyer',
      'notes',
    });
    expect(f.bodies.single['buyer'], '');
    expect(f.bodies.single['notes'], '');
  });
  for (final cancel in [false, true]) {
    testWidgets(
      '${cancel ? 'cancel sale' : 'sale'} locks back, input and same-frame double submit while saving',
      (t) async {
        final f = ReportsSalesFixture();
        final pending = Completer<void>();
        f.pending = pending.future;
        await mountSale(t, f, cancel: cancel);
        if (cancel) {
          await pickPen(t);
          await fillSale(t, 'Lý do hủy bán', 'Nhập nhầm');
        } else {
          await fillSale(t, 'Số tiền (VND)', '1000');
        }
        final callback = t.widget<FilledButton>(saleAction(cancel)).onPressed!;
        callback();
        callback();
        await t.pump();
        expect(f.writes.length, 1);
        expect(inSale(find.text('Đang lưu…')), findsOneWidget);
        expect(
          t
              .widget<TextButton>(
                inSale(
                  find.widgetWithText(
                    TextButton,
                    cancel ? 'Giữ giao dịch' : 'Hủy',
                  ),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          t
              .widget<TextFormField>(
                saleField(cancel ? 'Lý do hủy bán' : 'Số tiền (VND)'),
              )
              .enabled,
          isFalse,
        );
        await t.binding.handlePopRoute();
        await t.pump();
        expect(find.byType(SaleEditor), findsOneWidget);
        pending.complete();
        await t.pumpAndSettle();
        expect(find.byType(SaleEditor), findsNothing);
      },
    );
  }
  testWidgets(
    'cancel requires available pen, date and reason; retry keeps body and audit',
    (t) async {
      final f = ReportsSalesFixture()
        ..writeError = 'Chuồng đã đầy. Hãy chọn chuồng khác.';
      await mountSale(t, f, cancel: true);
      await tapLedger(t, saleAction(true));
      expect(f.writes, isEmpty);
      final dropdown = t.widget<DropdownButton<String>>(
        inSale(find.byType(DropdownButton<String>)),
      );
      expect(dropdown.items!.map((e) => e.value), ['pen']);
      await pickPen(t);
      await fillSale(t, 'Lý do hủy bán', 'Nhận lại theo biên bản');
      await tapLedger(t, saleAction(true));
      final body = f.bodies.single;
      expect(body.keys.toSet(), {'requestId', 'date', 'penId', 'reason'});
      expect(body['penId'], 'pen');
      expect(body['date'], farmToday());
      expect(body['reason'], 'Nhận lại theo biên bản');
      expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
      f.writeError = null;
      await tapLedger(t, saleAction(true));
      expect(f.bodies.last, body);
      expect(
        f.entries.firstWhere((e) => e['saleId'] == 'sale')['cancelledAt'],
        isNotNull,
      );
    },
  );
  testWidgets(
    'pen load error retry and no free pen block confirmation while retaining reason',
    (t) async {
      final f = ReportsSalesFixture()..failPens = true;
      await mountSale(t, f, cancel: true);
      expect(inSale(find.text('Không tải được chuồng.')), findsOneWidget);
      await fillSale(t, 'Lý do hủy bán', 'Giữ lý do qua tải lại');
      expect(t.widget<FilledButton>(saleAction(true)).onPressed, isNull);
      f.failPens = false;
      f.pens.removeWhere((p) => p['id'] == 'pen');
      await tapLedger(t, inSale(find.text('Tải lại chuồng')));
      expect(
        find.textContaining('Chưa có chuồng đang hoạt động còn chỗ'),
        findsOneWidget,
      );
      expect(t.widget<FilledButton>(saleAction(true)).onPressed, isNull);
      expect(
        t.widget<TextFormField>(saleField('Lý do hủy bán')).controller!.text,
        'Giữ lý do qua tải lại',
      );
    },
  );
  testWidgets(
    'report combines same-range filtered sale income, includes zero months and exact difference',
    (t) async {
      final f = ReportsSalesFixture();
      await mountLedger(t, f);
      await reportTab(t);
      expect(monthText('2026-10', '10.005.000 ₫'), findsOneWidget);
      expect(monthText('2026-10', '1.000 ₫'), findsOneWidget);
      expect(monthText('2026-10', '10.004.000 ₫'), findsOneWidget);
      expect(
        monthText('2026-10', 'Doanh thu bán: 10.000.000 ₫'),
        findsOneWidget,
      );
      final queries = f.reports
          .skip(1)
          .map((r) => r.url.queryParameters)
          .toList();
      expect(queries, [
        {'from': '2026-10-01', 'to': farmToday()},
        {'from': '2026-10-01', 'to': farmToday(), 'category': 'ANIMAL_SALE'},
      ]);
      await tapLedger(t, find.text('Bộ lọc'));
      t
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Từ ngày'),
              )
              .controller!
              .text =
          '2026-09-01';
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(monthText('2026-09', '0 ₫'), findsNWidgets(3));
      expect(monthText('2026-09', 'Doanh thu bán: 0 ₫'), findsOneWidget);
      expect(find.textContaining('lợi nhuận kế toán'), findsOneWidget);
    },
  );
  testWidgets(
    'manual category and OUT filters cannot leak unfiltered sales into report',
    (t) async {
      final f = ReportsSalesFixture();
      await mountLedger(t, f);
      await reportTab(t);
      await tapLedger(t, find.text('Bộ lọc'));
      await pickLedger(t, 'Nhóm', 'Thức ăn', form: false);
      await pickLedger(t, 'Thu / chi', 'Chi', form: false);
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(f.reports.last.url.queryParameters['category'], 'FEED');
      expect(monthText('2026-10', 'Doanh thu bán: 0 ₫'), findsOneWidget);
      expect(monthText('2026-10', '-1.000 ₫'), findsOneWidget);
      await tapLedger(t, find.text('Bộ lọc'));
      await pickLedger(t, 'Nhóm', 'Tất cả', form: false);
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(f.reports.last.url.queryParameters['kind'], 'OUT');
      expect(f.reports.last.url.queryParameters['category'], 'ANIMAL_SALE');
      expect(monthText('2026-10', 'Doanh thu bán: 0 ₫'), findsOneWidget);
    },
  );
  testWidgets(
    'sale-only report reuses monthly income and long totals remain exact',
    (t) async {
      final f = ReportsSalesFixture();
      f.entries.firstWhere((e) => e['saleId'] == 'sale')['amount'] =
          '9007199254740993123';
      await mountLedger(t, f);
      await reportTab(t);
      await tapLedger(t, find.text('Bộ lọc'));
      await pickLedger(t, 'Nhóm', 'Bán vật nuôi', form: false);
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(
        monthText('2026-10', 'Doanh thu bán: 9.007.199.254.740.993.123 ₫'),
        findsOneWidget,
      );
      expect(
        monthText('2026-10', '9.007.199.254.740.993.123 ₫'),
        findsNWidgets(2),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'failed or incomplete supplemental report does not fabricate zero; retry restores report',
    (t) async {
      final f = ReportsSalesFixture()..failSaleReport = true;
      await mountLedger(t, f);
      await reportTab(t);
      expect(find.byType(MonthlyFinanceChart), findsNothing);
      expect(find.text('Không tải được báo cáo.'), findsOneWidget);
      f.failSaleReport = false;
      f.missingSaleMonth = true;
      await tapLedger(t, find.text('Tải lại báo cáo'));
      expect(
        find.textContaining('Báo cáo tháng thiếu số liệu'),
        findsOneWidget,
      );
      f.missingSaleMonth = false;
      await tapLedger(t, find.text('Tải lại báo cáo'));
      expect(find.byType(MonthlyFinanceChart), findsOneWidget);
    },
  );
  testWidgets(
    'late report after leaving tab cannot replace ledger or block filters',
    (t) async {
      final f = ReportsSalesFixture();
      await mountLedger(t, f);
      final pending = Completer<void>();
      f.pendingReport = pending.future;
      await t.tap(find.widgetWithText(ChoiceChip, 'Báo cáo'));
      await t.pump();
      await t.tap(find.widgetWithText(ChoiceChip, 'Sổ thu chi'));
      await t.pump();
      f.pendingReport = null;
      pending.complete();
      await t.pumpAndSettle();
      expect(find.byType(MonthlyFinanceChart), findsNothing);
      expect(
        find.text('Khoản thu có nội dung dài để kiểm tra sổ tiếng Việt'),
        findsOneWidget,
      );
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Bộ lọc'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'two queries with different sales totals request retry instead of showing conflicting numbers',
    (t) async {
      final f = ReportsSalesFixture()..inconsistentSaleReport = true;
      await mountLedger(t, f);
      await reportTab(t);
      expect(
        find.textContaining('Số liệu doanh thu bán thay đổi trong khi tải.'),
        findsOneWidget,
      );
      expect(find.byType(MonthlyFinanceChart), findsNothing);
      f.inconsistentSaleReport = false;
      await tapLedger(t, find.text('Tải lại báo cáo'));
      expect(find.byType(MonthlyFinanceChart), findsOneWidget);
    },
  );
  testWidgets(
    'cancel refreshes list, receipt and report without double counting; canceled audit remains visible',
    (t) async {
      final f = ReportsSalesFixture();
      await mountLedger(t, f);
      await salesTab(t);
      await tapLedger(t, cancelAction('sale'));
      await pickPen(t);
      await fillSale(t, 'Lý do hủy bán', 'Nhận lại');
      await tapLedger(t, saleAction(true));
      expect(cancelAction('sale'), findsNothing);
      expect(
        find.descendant(of: saleCard('sale'), matching: find.text('Đã hủy')),
        findsOneWidget,
      );
      expect(
        find.text('Thời điểm hủy: 24/10/2026 16:00 (UTC+7)'),
        findsOneWidget,
      );
      await reportTab(t);
      expect(monthText('2026-10', 'Doanh thu bán: 0 ₫'), findsOneWidget);
      expect(monthText('2026-10', '5.000 ₫'), findsOneWidget);
      expect(monthText('2026-10', '4.000 ₫'), findsOneWidget);
      await tapLedger(t, find.widgetWithText(ChoiceChip, 'Sổ thu chi'));
      expect(find.text('Khoản thu liên kết bán vật nuôi'), findsNothing);
    },
  );
  testWidgets(
    'sales status pagination, last-page cancellation and stale errors remain actionable',
    (t) async {
      final f = ReportsSalesFixture();
      for (var i = 0; i < 20; i++) {
        f.sales.add({...f.sales.first, 'id': 'sale-$i'});
      }
      await mountLedger(t, f);
      await salesTab(t);
      await filterSales(t, 'Có hiệu lực');
      await tapLedger(t, find.byTooltip('Trang sau'));
      expect(f.salesRequests.last.url.queryParameters['page'], '2');
      final id = f.sales.last['id'] as String;
      await tapLedger(t, cancelAction(id));
      await pickPen(t);
      await fillSale(t, 'Lý do hủy bán', 'Nhận lại');
      await tapLedger(t, saleAction(true));
      expect(f.salesRequests.last.url.queryParameters, {
        'status': 'VALID',
        'page': '1',
      });
      f.failSales = true;
      await tapLedger(t, find.text('Tải giao dịch bán'));
      expect(
        find.textContaining('Đang hiển thị giao dịch từ lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<OutlinedButton>(
              find.ancestor(
                of: cancelAction('sale'),
                matching: find.byType(OutlinedButton),
              ),
            )
            .onPressed,
        isNull,
      );
      f.failSales = false;
      await filterSales(t, 'Đã hủy');
      expect(f.salesRequests.last.url.queryParameters['status'], 'CANCELLED');
      expect(find.text('Hủy bán'), findsNothing);
      f.sales.clear();
      await tapLedger(t, find.text('Tải giao dịch bán'));
      expect(
        find.text('Chưa có giao dịch bán theo bộ lọc này.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'selling and canceling in profile refresh animal lifecycle and keep animalId scope',
    (t) async {
      final f = ReportsSalesFixture();
      addTearDown(f.dispose);
      t.view.physicalSize = const Size(412, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: AnimalDetailPage(
            repository: f.repository,
            admin: true,
            id: 'animal',
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapLedger(t, find.widgetWithText(FilledButton, 'Bán vật nuôi'));
      await fillSale(t, 'Số tiền (VND)', '123456789');
      await tapLedger(t, saleAction(false));
      expect(f.animalStatus, 'SOLD');
      expect(f.salesRequests.last.url.queryParameters['animalId'], 'animal');
      await tapLedger(t, cancelAction('new-sale'));
      await pickPen(t);
      await fillSale(t, 'Lý do hủy bán', 'Nhận lại');
      await tapLedger(t, saleAction(true));
      expect(f.animalStatus, 'ACTIVE');
      expect(find.widgetWithText(FilledButton, 'Bán vật nuôi'), findsOneWidget);
    },
  );
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'report $width renders exact chart and monthly cards at text scale 1.3',
      (t) async {
        final f = ReportsSalesFixture();
        final b = await mountLedger(t, f, width: width);
        await reportTab(t);
        await t.ensureVisible(find.text('Báo cáo thu chi'));
        await captureSales(t, b, 'report-${width.toInt()}-top');
        await t.ensureVisible(find.byType(RevenueChart));
        await captureSales(t, b, 'report-${width.toInt()}-chart');
        await t.ensureVisible(reportMonth('2026-10'));
        await captureSales(t, b, 'report-${width.toInt()}-month');
      },
    );
    testWidgets(
      'sales $width renders effective and canceled transactions with long text',
      (t) async {
        final f = ReportsSalesFixture();
        final b = await mountLedger(t, f, width: width);
        await salesTab(t);
        await captureSales(t, b, 'sales-${width.toInt()}-top');
        await t.ensureVisible(saleCard('cancelled-sale'));
        await captureSales(t, b, 'sales-${width.toInt()}-bottom');
      },
    );
    for (final cancel in [false, true]) {
      final mode = cancel ? 'cancel-sale' : 'sell';
      testWidgets(
        '$mode $width retains draft through keyboard, server error and resize',
        (t) async {
          final f = ReportsSalesFixture()
            ..writeError =
                'Không thể xác nhận giao dịch này. Dữ liệu nháp được giữ để kiểm tra và thử lại.';
          final b = await mountSale(t, f, cancel: cancel, width: width);
          await captureSales(t, b, '$mode-${width.toInt()}-top');
          if (cancel) {
            await pickPen(t);
          } else {
            await fillSale(t, 'Số tiền (VND)', '18000000');
          }
          final label = cancel ? 'Lý do hủy bán' : 'Ghi chú (tùy chọn)';
          await fillSale(
            t,
            label,
            'Nội dung nhiều dòng.\nKhông mất nháp khi mở bàn phím hoặc thay đổi kích thước.',
          );
          await captureSales(t, b, '$mode-${width.toInt()}-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(saleField(label));
          await t.pumpAndSettle();
          expect(saleAction(cancel).hitTestable(), findsOneWidget);
          expect(
            t.getBottomRight(saleAction(cancel)).dy,
            lessThanOrEqualTo(800),
          );
          await captureSales(t, b, '$mode-${width.toInt()}-keyboard');
          await tapLedger(t, saleAction(cancel));
          expect(find.text(f.writeError!).hitTestable(), findsOneWidget);
          await captureSales(t, b, '$mode-${width.toInt()}-error');
          t.view.viewInsets = const FakeViewPadding();
          t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
          await t.pumpAndSettle();
          expect(
            t.widget<TextFormField>(saleField(label)).controller!.text,
            contains('Không mất nháp'),
          );
          await tapLedger(
            t,
            inSale(
              find.widgetWithText(TextButton, cancel ? 'Giữ giao dịch' : 'Hủy'),
            ),
          );
          expect(f.writes.length, 1);
        },
      );
    }
  }
}
