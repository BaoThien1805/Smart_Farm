import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/finance_ledger_forms.dart';
import 'package:smart_farm/features/farm/finance_ledger_widgets.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'support/finance_ledger_fixture.dart';
import 'support/ui_preview.dart';

Finder ledgerRow(String id) => find.byKey(ValueKey('ledger-entry-$id'));
Finder ledgerAction(String id, String text) =>
    find.descendant(of: ledgerRow(id), matching: find.text(text));
Finder inLedger(Finder f) =>
    find.descendant(of: find.byType(FinanceLedgerEditor), matching: f);
Finder ledgerField(String label) =>
    inLedger(find.widgetWithText(TextFormField, label));
Finder inAudit(Finder f) =>
    find.descendant(of: find.byType(FinanceAuditDialog), matching: f);
Finder totalText(String text) =>
    find.descendant(of: find.byType(LedgerTotals), matching: find.text(text));
Future<void> tapLedger(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> fillLedger(WidgetTester t, String label, String value) async {
  await t.ensureVisible(ledgerField(label));
  await t.enterText(ledgerField(label), value);
  await t.pump();
}

Future<GlobalKey> mountLedger(
  WidgetTester t,
  FinanceLedgerFixture fixture, {
  double width = 412,
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
      home: Scaffold(
        body: FinancePage(
          repository: fixture.repository,
          admin: user.isAdmin,
          canFinance: user.canFinance,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return boundary;
}

Future<void> pickLedger(
  WidgetTester t,
  String label,
  String value, {
  bool form = true,
}) async {
  final target = find.widgetWithText(DropdownButtonFormField<String>, label);
  await tapLedger(t, form ? inLedger(target) : target.last);
  await tapLedger(t, find.text(value).last);
}

Future<void> allLedger(WidgetTester t) async {
  await tapLedger(t, find.text('Bộ lọc'));
  await pickLedger(t, 'Trạng thái sổ', 'Tất cả', form: false);
  await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
}

Future<void> openLedger(WidgetTester t, String mode) async {
  if (mode == 'create') {
    await tapLedger(t, find.widgetWithText(OutlinedButton, 'Ghi chi'));
    await fillLedger(t, 'Số tiền (VND)', '1000');
    await fillLedger(t, 'Nội dung', 'Khoản ghi mới có nội dung dài');
  } else if (mode == 'edit') {
    await tapLedger(t, ledgerAction('manual', 'Sửa'));
    await fillLedger(t, 'Lý do sửa', 'Điều chỉnh theo chứng từ');
  } else if (mode == 'cancel') {
    await tapLedger(t, ledgerAction('manual', 'Hủy khoản'));
    await fillLedger(t, 'Lý do hủy', 'Khoản ghi nhầm');
  }
}

Finder ledgerSave(String mode) => inLedger(
  find.widgetWithText(
    FilledButton,
    mode == 'cancel' ? 'Xác nhận hủy' : 'Lưu giao dịch',
  ),
);
Future<void> captureLedger(
  WidgetTester t,
  GlobalKey boundary,
  String name,
) async {
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, boundary, '$name.png');
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final role in ['ADMIN', 'ACCOUNTANT', 'STAFF', 'VET']) {
    testWidgets('$role gets only authorized financial access and operations', (
      t,
    ) async {
      final fixture = FinanceLedgerFixture(role);
      await mountLedger(t, fixture);
      if (['STAFF', 'VET'].contains(role)) {
        expect(
          find.text('Bạn không có quyền truy cập tài chính.'),
          findsOneWidget,
        );
        expect(fixture.requests, isEmpty);
        expect(find.text('Ghi thu'), findsNothing);
      } else {
        expect(find.text('Ghi thu'), findsOneWidget);
        expect(ledgerAction('manual', 'Sửa'), findsOneWidget);
        expect(ledgerAction('manual', 'Hủy khoản'), findsOneWidget);
        expect(ledgerAction('linked', 'Sửa'), findsNothing);
        expect(ledgerAction('linked', 'Hủy khoản'), findsNothing);
        expect(ledgerAction('linked', 'Lịch sử'), findsOneWidget);
      }
    });
  }
  testWidgets(
    'totals come from valid report, include sale only once and preserve strings beyond double precision',
    (t) async {
      final fixture = FinanceLedgerFixture();
      await mountLedger(t, fixture);
      expect(totalText('10.005.000 ₫'), findsOneWidget);
      expect(totalText('1.000 ₫'), findsOneWidget);
      expect(totalText('10.004.000 ₫'), findsOneWidget);
      expect(
        fixture.reports.single.url.queryParameters.containsKey('status'),
        isFalse,
      );
      fixture.summaryOverride = {
        'income': '9007199254740993123',
        'expense': '1000',
        'difference': '9007199254740992123',
        'salesRevenue': '10000000',
      };
      await tapLedger(t, find.byTooltip('Tải lại'));
      expect(totalText('9.007.199.254.740.993.123 ₫'), findsOneWidget);
      expect(totalText('9.007.199.254.740.992.123 ₫'), findsOneWidget);
      expect(
        find.textContaining(
          'Trong Tổng thu: doanh thu bán vật nuôi 10.000.000 ₫.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'manual categories exclude sale, integer amount and exact payload remain intact',
    (t) async {
      final fixture = FinanceLedgerFixture('ACCOUNTANT');
      await mountLedger(t, fixture);
      await openLedger(t, 'create');
      final choices = find.descendant(
        of: inLedger(
          find.widgetWithText(DropdownButtonFormField<String>, 'Nhóm'),
        ),
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        t.widget<DropdownButton<String>>(choices).items!.map((i) => i.value),
        financeCategories.keys,
      );
      await pickLedger(t, 'Nhóm', 'Thức ăn');
      await tapLedger(t, ledgerSave('create'));
      final body = fixture.bodies.single;
      expect(body.keys.toSet(), {
        'date',
        'kind',
        'category',
        'amount',
        'content',
        'requestId',
      });
      expect(body['kind'], 'OUT');
      expect(body['category'], 'FEED');
      expect(body['amount'], 1000);
      expect(body['requestId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(fixture.lists.length, 2);
      expect(fixture.reports.length, 2);
      expect(totalText('2.000 ₫'), findsOneWidget);
    },
  );
  testWidgets(
    'money rejects fraction grouping nonfinite and overflow without converting to another amount',
    (t) async {
      final fixture = FinanceLedgerFixture();
      await mountLedger(t, fixture);
      await openLedger(t, 'create');
      for (final value in [
        '',
        '0',
        '-1',
        'NaN',
        'Infinity',
        '10.5',
        '1,5',
        '1.000',
        '1e3',
        '1000000000001',
      ]) {
        await fillLedger(t, 'Số tiền (VND)', value);
        await tapLedger(t, ledgerSave('create'));
        expect(fixture.writes, isEmpty);
      }
      await fillLedger(t, 'Số tiền (VND)', '1000000000000');
      await tapLedger(t, ledgerSave('create'));
      expect(fixture.bodies.single['amount'], 1000000000000);
    },
  );
  testWidgets(
    'edit requires reason, keeps full content and preserves request body across retry',
    (t) async {
      final fixture = FinanceLedgerFixture()
        ..writeError = 'Khoản vừa thay đổi. Hãy kiểm tra rồi thử lại.';
      await mountLedger(t, fixture);
      await openLedger(t, 'edit');
      await fillLedger(t, 'Lý do sửa', ' ');
      await tapLedger(t, ledgerSave('edit'));
      expect(fixture.writes, isEmpty);
      final reason = List.filled(12, 'Lý do sửa đầy đủ. ').join();
      final content = List.filled(12, 'Nội dung chi tiết. ').join();
      await fillLedger(t, 'Lý do sửa', reason);
      await fillLedger(t, 'Nội dung', content);
      await fillLedger(t, 'Số tiền (VND)', '5500');
      await tapLedger(t, ledgerSave('edit'));
      expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
      fixture.writeError = null;
      await tapLedger(t, ledgerSave('edit'));
      expect(fixture.writes.last.method, 'PATCH');
      expect(fixture.bodies.first, fixture.bodies.last);
      expect(fixture.bodies.last['reason'], reason.trim());
      expect(fixture.bodies.last['content'], content.trim());
      expect(totalText('10.005.500 ₫'), findsOneWidget);
    },
  );
  testWidgets(
    'linked and canceled entries cannot enter manual edit/cancel even through wrapper',
    (t) async {
      final fixture = FinanceLedgerFixture();
      await mountLedger(t, fixture);
      await allLedger(t);
      for (final id in ['linked', 'cancelled']) {
        expect(ledgerAction(id, 'Sửa'), findsNothing);
        expect(ledgerAction(id, 'Hủy khoản'), findsNothing);
        final entry = FarmRecord(
          fixture.entries.firstWhere((e) => e['id'] == id),
        );
        final context = t.element(find.byType(FinancePage));
        expect(
          await financeLedgerForm(context, fixture.repository, entry: entry),
          isFalse,
        );
        expect(
          await financeLedgerForm(
            context,
            fixture.repository,
            entry: entry,
            cancelling: true,
          ),
          isFalse,
        );
      }
      expect(fixture.writes, isEmpty);
    },
  );
  testWidgets(
    'stock purchase expense shows its source and blocks manual changes',
    (t) async {
      final fixture = FinanceLedgerFixture('ACCOUNTANT');
      fixture.entries.add({
        'id': 'stock-purchase',
        'date': '2026-10-24',
        'kind': 'OUT',
        'category': 'FEED',
        'amount': '250000',
        'content': 'Mua thức ăn nhập kho: Cám',
        'actorName': 'Nhân viên kho',
        'stockEntryId': 'stock-1',
        'cancelledAt': null,
      });
      await mountLedger(t, fixture);
      expect(ledgerAction('stock-purchase', 'Sửa'), findsNothing);
      expect(ledgerAction('stock-purchase', 'Hủy khoản'), findsNothing);
      expect(ledgerAction('stock-purchase', 'Lịch sử'), findsOneWidget);
      expect(
        ledgerAction(
          'stock-purchase',
          'Từ nhập kho thức ăn. Hủy khoản chi qua phiếu nhập kho.',
        ),
        findsOneWidget,
      );
      final entry = FarmRecord(fixture.entries.last);
      final context = t.element(find.byType(FinancePage));
      expect(
        await financeLedgerForm(context, fixture.repository, entry: entry),
        isFalse,
      );
      expect(
        await financeLedgerForm(
          context,
          fixture.repository,
          entry: entry,
          cancelling: true,
        ),
        isFalse,
      );
      expect(fixture.writes, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'cancel requires reason, keeps history, refreshes totals and last valid page',
    (t) async {
      final fixture = FinanceLedgerFixture();
      final base = Map<String, dynamic>.from(fixture.entries.first);
      fixture.entries
        ..clear()
        ..addAll(
          List.generate(21, (i) => {...base, 'id': 'entry-$i', 'amount': '1'}),
        );
      await mountLedger(t, fixture);
      await tapLedger(t, find.byTooltip('Trang sau'));
      await tapLedger(t, ledgerAction('entry-20', 'Hủy khoản'));
      await tapLedger(t, ledgerSave('cancel'));
      expect(fixture.writes, isEmpty);
      await fillLedger(t, 'Lý do hủy', 'Nhập nhầm có lý do');
      await tapLedger(t, ledgerSave('cancel'));
      expect(fixture.bodies.single.keys.toSet(), {'reason', 'requestId'});
      expect(find.text('Trang 1 · 20 bản ghi'), findsOneWidget);
      expect(totalText('20 ₫'), findsNWidgets(2));
      expect(fixture.entries.last['cancelledAt'], isNotNull);
      expect(fixture.newAudit['entry-20']!.last['action'], 'CANCEL');
    },
  );
  for (final mode in ['create', 'edit', 'cancel']) {
    testWidgets(
      '$mode retry keeps id/body, blocks double save and Back, cancel does not write',
      (t) async {
        final fixture = FinanceLedgerFixture()
          ..writeError = 'Không ghi được giao dịch. Nháp được giữ.';
        await mountLedger(t, fixture);
        await openLedger(t, mode);
        await tapLedger(t, ledgerSave(mode));
        expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
        final pending = Completer<void>();
        fixture
          ..writeError = null
          ..pending = pending.future;
        final submit = ledgerSave(mode);
        await t.tap(submit);
        await t.tap(submit);
        await t.pump();
        expect(fixture.writes.length, 2);
        expect(fixture.bodies.first, fixture.bodies.last);
        final cancel = inLedger(
          find.widgetWithText(
            TextButton,
            mode == 'cancel' ? 'Giữ khoản' : 'Hủy',
          ),
        );
        expect(t.widget<TextButton>(cancel).onPressed, isNull);
        await t.binding.handlePopRoute();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(FinanceLedgerEditor), findsOneWidget);
        pending.complete();
        await t.pumpAndSettle();
        expect(find.byType(FinanceLedgerEditor), findsNothing);
        final calls = fixture.writes.length;
        await openLedger(t, 'create');
        await tapLedger(t, inLedger(find.widgetWithText(TextButton, 'Hủy')));
        expect(fixture.writes.length, calls);
      },
    );
  }
  testWidgets(
    'filters use range kind category status correctly; summary ignores canceled status and cancel keeps filters',
    (t) async {
      final fixture = FinanceLedgerFixture();
      await mountLedger(t, fixture);
      await tapLedger(t, find.text('Bộ lọc'));
      await pickLedger(t, 'Thu / chi', 'Chi', form: false);
      await pickLedger(t, 'Nhóm', 'Thức ăn', form: false);
      await pickLedger(t, 'Trạng thái sổ', 'Đã hủy', form: false);
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      final query = fixture.lists.last.url.queryParameters;
      expect(query, {
        'from': '2026-10-01',
        'to': farmToday(),
        'kind': 'OUT',
        'category': 'FEED',
        'status': 'CANCELLED',
        'page': '1',
      });
      expect(fixture.reports.last.url.queryParameters, {
        'from': '2026-10-01',
        'to': farmToday(),
        'kind': 'OUT',
        'category': 'FEED',
      });
      expect(totalText('-1.000 ₫'), findsOneWidget);
      expect(find.text('Tổng khoản hợp lệ trong kỳ'), findsOneWidget);
      expect(find.text('Trạng thái danh sách: Đã hủy'), findsOneWidget);
      final calls = fixture.lists.length;
      await tapLedger(t, find.text('Bộ lọc'));
      await tapLedger(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.lists.length, calls);
    },
  );
  testWidgets(
    'range validates order and 730 days without losing filter draft',
    (t) async {
      final fixture = FinanceLedgerFixture();
      await mountLedger(t, fixture);
      await tapLedger(t, find.text('Bộ lọc'));
      final from = find.widgetWithText(TextFormField, 'Từ ngày');
      final to = find.widgetWithText(TextFormField, 'Đến ngày');
      t.widget<TextFormField>(from).controller!.text = '2026-10-24';
      t.widget<TextFormField>(to).controller!.text = '2026-10-01';
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(
        find.text('Khoảng ngày phải đúng thứ tự và tối đa 730 ngày.'),
        findsOneWidget,
      );
      t.widget<TextFormField>(from).controller!.text = '2020-01-01';
      await tapLedger(t, find.widgetWithText(FilledButton, 'Lưu'));
      expect(fixture.lists.length, 1);
      expect(t.widget<TextFormField>(from).controller!.text, '2020-01-01');
    },
  );
  testWidgets(
    'audit shows actual before/after all fields, actor reason and local timestamp, no invoice fields',
    (t) async {
      final fixture = FinanceLedgerFixture();
      await mountLedger(t, fixture);
      await allLedger(t);
      await tapLedger(t, ledgerAction('cancelled', 'Lịch sử'));
      final edit = find.byKey(const ValueKey('finance-audit-h2'));
      expect(
        find.descendant(of: edit, matching: find.text('Kế toán sửa')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: edit,
          matching: find.text('Người thực hiện: Kế toán sửa'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: edit,
          matching: find.text('22/10/2026 09:00 (UTC+7)'),
        ),
        findsNWidgets(2), // Action time and the saved snapshot's update time.
      );
      expect(
        find.descendant(of: edit, matching: find.text('4.000 ₫')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: edit, matching: find.text('2.000 ₫')),
        findsOneWidget,
      );
      expect(
        inAudit(find.text('Lý do: Điều chỉnh theo chứng từ')),
        findsOneWidget,
      );
      expect(inAudit(find.text('Trước')), findsNWidgets(2));
      expect(inAudit(find.text('Sau')), findsNWidgets(3));
      expect(inAudit(find.text('Nội dung trước khi sửa')), findsNWidgets(2));
      for (final field in ['Nhà cung cấp', 'Đơn giá', 'Số lượng']) {
        expect(inAudit(find.text(field)), findsNothing);
      }
    },
  );
  testWidgets(
    'audit retry, empty and malformed snapshots remain safe without inventing zero amounts',
    (t) async {
      final fixture = FinanceLedgerFixture()..failHistory = true;
      await mountLedger(t, fixture);
      await tapLedger(t, ledgerAction('manual', 'Lịch sử'));
      expect(
        inAudit(find.text('Không tải được lịch sử thu chi.')),
        findsOneWidget,
      );
      fixture
        ..failHistory = false
        ..historyOverride = [];
      await tapLedger(t, inAudit(find.text('Thử tải lại lịch sử')));
      expect(
        inAudit(find.text('Chưa có lịch sử chỉnh sửa được trả về.')),
        findsOneWidget,
      );
      await tapLedger(t, inAudit(find.text('Đóng')));
      fixture.historyOverride = [
        {
          'id': 'unknown',
          'action': 'EDIT',
          'actorName': 'Người ghi',
          'createdAt': '2026-10-24T00:00:00Z',
          'before': null,
          'after': null,
        },
      ];
      await tapLedger(t, ledgerAction('manual', 'Lịch sử'));
      expect(
        inAudit(find.text('Trước: không có bản chụp dữ liệu.')),
        findsOneWidget,
      );
      expect(
        inAudit(find.text('Sau: không có bản chụp dữ liệu.')),
        findsOneWidget,
      );
      expect(inAudit(find.text('0 ₫')), findsNothing);
    },
  );
  testWidgets(
    'independent summary errors do not fabricate totals; stale ledger blocks writes until retry',
    (t) async {
      final fixture = FinanceLedgerFixture()..failSummary = true;
      await mountLedger(t, fixture);
      expect(find.text('Không tải được tổng thu chi.'), findsOneWidget);
      expect(find.byType(LedgerTotals), findsNothing);
      expect(ledgerRow('manual'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Ghi thu'))
            .onPressed,
        isNotNull,
      );
      fixture
        ..failSummary = false
        ..failList = true;
      await tapLedger(t, find.byTooltip('Tải lại'));
      expect(
        find.textContaining('Đang hiển thị sổ từ lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Ghi thu'))
            .onPressed,
        isNull,
      );
      fixture
        ..failList = false
        ..entries.clear();
      await tapLedger(t, find.byTooltip('Tải lại'));
      expect(
        find.text('Chưa có khoản thu chi trong khoảng ngày này.'),
        findsOneWidget,
      );
      expect(totalText('0 ₫'), findsNWidgets(3));
    },
  );
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'ledger $width keeps totals and long canceled/linked records readable at scale 1.3',
      (t) async {
        final fixture = FinanceLedgerFixture();
        final boundary = await mountLedger(t, fixture, width: width);
        await allLedger(t);
        await t.ensureVisible(find.text('Thu chi trang trại'));
        await captureLedger(t, boundary, 'ledger-${width.toInt()}-top');
        await t.ensureVisible(ledgerRow('cancelled'));
        await captureLedger(t, boundary, 'ledger-${width.toInt()}-bottom');
      },
    );
    for (final mode in ['create', 'edit', 'cancel']) {
      testWidgets(
        '$mode $width keeps CTA above keyboard, errors and drafts through resize',
        (t) async {
          final fixture = FinanceLedgerFixture()
            ..writeError =
                'Không lưu được khoản thu chi này. Dữ liệu nháp được giữ để kiểm tra và thử lại.';
          final boundary = await mountLedger(t, fixture, width: width);
          await openLedger(t, mode);
          await t.ensureVisible(inLedger(find.byType(Form)));
          await captureLedger(t, boundary, '$mode-${width.toInt()}-top');
          final label = mode == 'cancel'
              ? 'Lý do hủy'
              : mode == 'edit'
              ? 'Lý do sửa'
              : 'Nội dung';
          await fillLedger(
            t,
            label,
            'Nội dung nhiều dòng cần giữ.\nKhông mất nháp khi mở bàn phím hoặc đổi kích thước.',
          );
          await captureLedger(t, boundary, '$mode-${width.toInt()}-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(ledgerField(label));
          await t.pumpAndSettle();
          expect(t.getBottomRight(ledgerSave(mode)).dy, lessThanOrEqualTo(800));
          expect(ledgerSave(mode).hitTestable(), findsOneWidget);
          await captureLedger(t, boundary, '$mode-${width.toInt()}-keyboard');
          await tapLedger(t, ledgerSave(mode));
          expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
          await captureLedger(t, boundary, '$mode-${width.toInt()}-error');
          t.view.viewInsets = const FakeViewPadding();
          t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
          await t.pumpAndSettle();
          expect(
            t.widget<TextFormField>(ledgerField(label)).controller!.text,
            contains('Không mất nháp'),
          );
          await tapLedger(
            t,
            inLedger(
              find.widgetWithText(
                TextButton,
                mode == 'cancel' ? 'Giữ khoản' : 'Hủy',
              ),
            ),
          );
          expect(fixture.writes.length, 1);
        },
      );
    }
    testWidgets(
      'audit $width displays long before after timeline and scrolls to cancellation',
      (t) async {
        final fixture = FinanceLedgerFixture();
        final boundary = await mountLedger(t, fixture, width: width);
        await allLedger(t);
        await tapLedger(t, ledgerAction('cancelled', 'Lịch sử'));
        await captureLedger(t, boundary, 'audit-${width.toInt()}-top');
        await t.ensureVisible(find.byKey(const ValueKey('finance-audit-h3')));
        await captureLedger(t, boundary, 'audit-${width.toInt()}-bottom');
      },
    );
  }
}
