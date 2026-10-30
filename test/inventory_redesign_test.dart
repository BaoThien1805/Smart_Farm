import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/inventory_page.dart';
import 'package:smart_farm/features/farm/inventory_forms.dart';

import 'support/inventory_fixture.dart';
import 'support/ui_preview.dart';

Finder inInventory(Finder f) =>
    find.descendant(of: find.byType(InventoryEditor), matching: f);
Finder feedCard(String id) => find.byKey(ValueKey('feed-$id'));
Finder entryCard(String id) => find.byKey(ValueKey('stock-entry-$id'));
Finder inEntry(String id, String text) =>
    find.descendant(of: entryCard(id), matching: find.text(text));
Finder input(String label) =>
    inInventory(find.widgetWithText(TextFormField, label));
Finder save(String label) =>
    inInventory(find.widgetWithText(FilledButton, label));
Future<void> tapInventory(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> fillInventory(WidgetTester t, String label, String text) async {
  await t.ensureVisible(input(label));
  await t.enterText(input(label), text);
  await t.pump();
}

Future<GlobalKey> mountInventory(
  WidgetTester t,
  InventoryFixture fixture, {
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
        body: InventoryPage(
          repository: fixture.repository,
          admin: user.isAdmin,
          canOperate: user.canOperate,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return boundary;
}

Future<void> history(WidgetTester t) =>
    tapInventory(t, find.widgetWithText(ChoiceChip, 'Lịch sử nhập / xuất'));
Future<void> chooseFeed(WidgetTester t) async {
  await tapInventory(
    t,
    inInventory(
      find.widgetWithText(DropdownButtonFormField<String>, 'Thức ăn'),
    ),
  );
  await tapInventory(t, find.text('TA-01 · Thức ăn hỗn hợp có tên dài').last);
}

String action(InventoryFormKind kind) => switch (kind) {
  InventoryFormKind.feed => 'Lưu thức ăn',
  InventoryFormKind.incoming => 'Lưu phiếu nhập',
  InventoryFormKind.outgoing => 'Lưu phiếu xuất',
  InventoryFormKind.cancel => 'Hủy phiếu',
};
Future<void> openInventory(WidgetTester t, InventoryFormKind kind) async {
  if (kind == InventoryFormKind.cancel) {
    await history(t);
    await tapInventory(t, inEntry('e1', 'Hủy phiếu'));
  } else {
    await tapInventory(
      t,
      find.text(switch (kind) {
        InventoryFormKind.feed => 'Thêm thức ăn',
        InventoryFormKind.incoming => 'Nhập kho',
        _ => 'Xuất kho',
      }),
    );
  }
  if (kind == InventoryFormKind.feed) {
    await fillInventory(t, 'Mã thức ăn', 'MANUAL-FEED');
    await fillInventory(t, 'Tên thức ăn', 'Thức ăn mới');
  } else if (kind == InventoryFormKind.cancel) {
    await fillInventory(t, 'Lý do hủy', 'Lý do hủy hợp lệ');
  } else {
    await chooseFeed(t);
    await fillInventory(t, 'Số lượng (kg)', '0,125');
    if (kind == InventoryFormKind.incoming) {
      await fillInventory(t, 'Tổng tiền mua (VND)', '250000');
    }
  }
}

Future<void> captureInventory(
  WidgetTester t,
  GlobalKey boundary,
  String name,
) async {
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, boundary, '$name.png');
}

Future<void> filterSelect(WidgetTester t, String label, String value) async {
  await tapInventory(
    t,
    find.widgetWithText(DropdownButtonFormField<String>, label),
  );
  await tapInventory(t, find.text(value).last);
}

Future<void> filterDate(WidgetTester t, String label, String day) async {
  await tapInventory(t, find.widgetWithText(TextField, label));
  await tapInventory(t, find.text(day).last);
  await tapInventory(t, find.text('OK'));
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  testWidgets(
    'intake requires whole VND and retains the amount after a server error',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture, width: 360);
      await openInventory(t, InventoryFormKind.incoming);
      for (final value in [
        '',
        '0',
        '-1',
        '1.5',
        '1,5',
        '1.000',
        'NaN',
        '1000000000001',
      ]) {
        await fillInventory(t, 'Tổng tiền mua (VND)', value);
        await tapInventory(t, save('Lưu phiếu nhập'));
        expect(fixture.writes, isEmpty);
      }
      fixture.writeError = 'Chưa lưu được phiếu nhập.';
      await fillInventory(t, 'Tổng tiền mua (VND)', '125000');
      await tapInventory(t, save('Lưu phiếu nhập'));
      expect(find.text('Chưa lưu được phiếu nhập.'), findsOneWidget);
      expect(
        t.widget<TextFormField>(input('Tổng tiền mua (VND)')).controller!.text,
        '125000',
      );
      final requestId = fixture.bodies.last!['requestId'];
      fixture.writeError = null;
      await tapInventory(t, save('Lưu phiếu nhập'));
      expect(fixture.bodies.last!['amount'], 125000);
      expect(fixture.bodies.last!['requestId'], requestId);
      expect(t.takeException(), isNull);
    },
  );

  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('$role retains inventory read/write/history permissions', (
      t,
    ) async {
      final fixture = InventoryFixture(role);
      await mountInventory(t, fixture);
      final operates = ['ADMIN', 'STAFF'].contains(role);
      expect(find.text('Nhập kho'), operates ? findsOneWidget : findsNothing);
      expect(find.text('Xuất kho'), operates ? findsOneWidget : findsNothing);
      expect(
        find.text('Thêm thức ăn'),
        role == 'ADMIN' ? findsOneWidget : findsNothing,
      );
      expect(fixture.entryRequests.isNotEmpty, operates);
      if (operates) {
        await history(t);
        expect(
          inEntry('e1', 'Hủy phiếu'),
          role == 'ADMIN' ? findsOneWidget : findsNothing,
        );
      } else {
        expect(find.text('Lịch sử nhập / xuất'), findsNothing);
      }
      expect(fixture.writes, isEmpty);
    });
  }
  testWidgets(
    'zero, equality, decimals and inactive feeds use exact low-stock rule',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      expect(find.text('Tồn thấp'), findsNWidgets(2));
      expect(
        find.descendant(of: feedCard('f2'), matching: find.text('0 kg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: feedCard('f3'), matching: find.text('12,345 kg')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: feedCard('f4'), matching: find.text('Tồn thấp')),
        findsNothing,
      );
      fixture.feeds[2].remove('stock');
      await tapInventory(t, find.byTooltip('Tải lại'));
      expect(find.text('Tồn thấp'), findsOneWidget);
      expect(
        find.descendant(of: feedCard('f3'), matching: find.text('— kg')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'feed creation keeps manual code, zero threshold, optional notes and exact payload',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await openInventory(t, InventoryFormKind.feed);
      await tapInventory(t, save('Lưu thức ăn'));
      expect(fixture.bodies.single, {
        'code': 'MANUAL-FEED',
        'name': 'Thức ăn mới',
        'lowStock': 0,
        'active': true,
        'notes': '',
      });
      expect(fixture.feedLoads, 2);
    },
  );
  testWidgets(
    'feed edit retains code, validates precision and keeps server rejection when disabling stock',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await tapInventory(
        t,
        find.descendant(of: feedCard('f1'), matching: find.text('Sửa')),
      );
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/code-suggestion')),
        isEmpty,
      );
      await fillInventory(t, 'Ngưỡng tồn thấp (kg)', '0,0001');
      await tapInventory(t, save('Lưu thức ăn'));
      expect(fixture.writes, isEmpty);
      await fillInventory(t, 'Ngưỡng tồn thấp (kg)', '0,125');
      await tapInventory(t, inInventory(find.byType(SwitchListTile)));
      await tapInventory(t, save('Lưu thức ăn'));
      expect(
        find.text('Thức ăn còn tồn kho; chưa thể ngừng sử dụng.').hitTestable(),
        findsOneWidget,
      );
      expect(
        t.widget<TextFormField>(input('Mã thức ăn')).controller!.text,
        'TA-01',
      );
      await tapInventory(t, inInventory(find.byType(SwitchListTile)));
      await tapInventory(t, save('Lưu thức ăn'));
      expect(fixture.bodies.last!['lowStock'], 0.125);
      expect(fixture.writes.last.method, 'PATCH');
    },
  );
  testWidgets(
    'deleting a linked feed keeps confirmation and server error without losing stock',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      final remove = find.descendant(
        of: feedCard('f1'),
        matching: find.text('Xóa'),
      );
      await tapInventory(t, remove);
      await tapInventory(t, find.widgetWithText(TextButton, 'Hủy'));
      expect(fixture.writes, isEmpty);
      await tapInventory(t, remove);
      await tapInventory(t, find.widgetWithText(FilledButton, 'Xác nhận'));
      expect(
        find.text('Thức ăn đã có phiếu kho; không thể xóa.'),
        findsOneWidget,
      );
      expect(fixture.feeds.first['stock'], 120.125);
    },
  );
  for (final kind in [InventoryFormKind.incoming, InventoryFormKind.outgoing]) {
    testWidgets(
      '${kind.name} parses decimal comma, keeps optional pen and reloads balances',
      (t) async {
        final fixture = InventoryFixture('STAFF');
        await mountInventory(t, fixture);
        await openInventory(t, kind);
        await tapInventory(t, save(action(kind)));
        final body = fixture.bodies.single!;
        expect(body['quantity'], 0.125);
        if (kind == InventoryFormKind.incoming) {
          expect(body['amount'], 250000);
          expect(body['amount'], isA<int>());
          await history(t);
          expect(inEntry('created', 'Tiền mua: 250.000 ₫'), findsOneWidget);
        } else {
          expect(body.containsKey('amount'), isFalse);
        }
        expect(body['requestId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(body.containsKey('penId'), kind == InventoryFormKind.outgoing);
        if (kind == InventoryFormKind.outgoing) expect(body['penId'], isNull);
        expect(
          fixture.feeds.first['stock'],
          kind == InventoryFormKind.outgoing ? 120 : 120.25,
        );
        expect(fixture.feedLoads, 2);
      },
    );
  }
  testWidgets(
    'quantity rejects invalid nonfinite precision and thousands separators',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await openInventory(t, InventoryFormKind.incoming);
      for (final value in [
        '',
        '0',
        '-1',
        'NaN',
        'Infinity',
        '0.0001',
        '100000001',
        '1.234,5',
      ]) {
        await fillInventory(t, 'Số lượng (kg)', value);
        await tapInventory(t, save('Lưu phiếu nhập'));
        expect(fixture.writes, isEmpty);
      }
      await fillInventory(t, 'Số lượng (kg)', '100000000');
      await tapInventory(t, save('Lưu phiếu nhập'));
      expect(fixture.bodies.single!['quantity'], 100000000);
    },
  );
  testWidgets(
    'negative estimated stock never becomes success; server refusal keeps id and draft',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await openInventory(t, InventoryFormKind.outgoing);
      await fillInventory(t, 'Số lượng (kg)', '121');
      expect(find.text('Dự kiến sau xuất: -0,875 kg'), findsOneWidget);
      await tapInventory(t, save('Lưu phiếu xuất'));
      expect(
        find.text('Số lượng xuất vượt tồn kho hiện tại.').hitTestable(),
        findsOneWidget,
      );
      expect(fixture.feeds.first['stock'], 120.125);
      await fillInventory(t, 'Số lượng (kg)', '120,125');
      expect(find.text('Dự kiến sau xuất: 0 kg'), findsOneWidget);
      await tapInventory(t, save('Lưu phiếu xuất'));
      expect(
        fixture.bodies.first!['requestId'],
        fixture.bodies.last!['requestId'],
      );
      expect(fixture.feeds.first['stock'], 0);
    },
  );
  testWidgets(
    'outgoing pens are optional, active only and selection is sent unchanged',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await openInventory(t, InventoryFormKind.outgoing);
      final selector = inInventory(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Chuồng (không bắt buộc)',
        ),
      );
      final button = find.descendant(
        of: selector,
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        t.widget<DropdownButton<String>>(button).items!.map((i) => i.value),
        [null, 'pen'],
      );
      await tapInventory(t, selector);
      await tapInventory(t, find.text('Chuồng mẫu').last);
      await tapInventory(t, save('Lưu phiếu xuất'));
      expect(fixture.bodies.single!['penId'], 'pen');
    },
  );
  testWidgets(
    'history labels cancellation truthfully and preserves reason, actor and notes',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await history(t);
      expect(inEntry('e1', 'Hợp lệ'), findsOneWidget);
      expect(inEntry('e2', 'Đã hủy'), findsOneWidget);
      expect(inEntry('e2', 'Hủy phiếu'), findsNothing);
      expect(inEntry('e2', 'Lý do hủy: Nhập sai số lượng'), findsOneWidget);
      expect(inEntry('e2', 'Người hủy: Chủ trại'), findsOneWidget);
      expect(
        inEntry('e2', 'Thời điểm hủy: 23/10/2026 17:00 (UTC+7)'),
        findsOneWidget,
      );
      expect(
        inEntry('e2', 'Phiếu không còn tính vào tồn kho.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'cancel requires reason and server rejects reversal that would make stock negative',
    (t) async {
      final fixture = InventoryFixture();
      fixture.feeds.first['stock'] = 1;
      await mountInventory(t, fixture);
      await openInventory(t, InventoryFormKind.cancel);
      await fillInventory(t, 'Lý do hủy', ' ');
      await tapInventory(t, save('Hủy phiếu'));
      expect(fixture.writes, isEmpty);
      final reason = List.filled(12, 'Lý do chi tiết được giữ. ').join();
      await fillInventory(t, 'Lý do hủy', reason);
      await tapInventory(t, save('Hủy phiếu'));
      expect(
        find
            .text('Không thể hủy phiếu nhập vì sẽ làm âm tồn kho.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(fixture.entries.first['cancelledAt'], isNull);
      expect(fixture.feeds.first['stock'], 1);
      fixture.feeds.first['stock'] = 120.125;
      await tapInventory(t, save('Hủy phiếu'));
      expect(fixture.bodies.first, fixture.bodies.last);
      expect(fixture.bodies.last!['reason'], reason.trim());
      expect(fixture.feeds.first['stock'], 70);
      expect(inEntry('e1', 'Đã hủy'), findsOneWidget);
    },
  );
  testWidgets(
    'canceling outgoing restores stock and keeps original entry in history',
    (t) async {
      final fixture = InventoryFixture();
      fixture.entries[1]['cancelledAt'] = null;
      await mountInventory(t, fixture);
      await history(t);
      await tapInventory(t, inEntry('e2', 'Hủy phiếu'));
      await fillInventory(t, 'Lý do hủy', 'Trả lại lượng xuất nhầm');
      await tapInventory(t, save('Hủy phiếu'));
      expect(fixture.feeds.first['stock'], 120.126);
      expect(inEntry('e2', 'Đã hủy'), findsOneWidget);
      expect(
        fixture.writes.single.url.path,
        endsWith('/stock-entries/e2/cancel'),
      );
      expect(fixture.bodies.single!.keys.toSet(), {'reason', 'requestId'});
    },
  );
  testWidgets(
    'removed feed stays identifiable in current filter and can be cleared',
    (t) async {
      final fixture = InventoryFixture();
      await mountInventory(t, fixture);
      await history(t);
      await tapInventory(t, find.byKey(const ValueKey('inventory-filters')));
      await filterSelect(t, 'Thức ăn', 'Cỏ khô');
      fixture.feeds.removeWhere((f) => f['id'] == 'f3');
      await tapInventory(t, find.byTooltip('Tải lại'));
      expect(find.text('Thức ăn không còn trong danh mục'), findsOneWidget);
      expect(fixture.entryRequests.last.url.queryParameters['feedId'], 'f3');
      await filterSelect(t, 'Thức ăn', 'Tất cả');
      expect(
        fixture.entryRequests.last.url.queryParameters.containsKey('feedId'),
        isFalse,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final kind in InventoryFormKind.values) {
    testWidgets(
      '${kind.name} retry preserves body/id and blocks same-frame duplicate save, cancel, Back',
      (t) async {
        final fixture = InventoryFixture()
          ..writeError = 'Không lưu được dữ liệu. Nháp vẫn được giữ.';
        await mountInventory(t, fixture);
        await openInventory(t, kind);
        await tapInventory(t, save(action(kind)));
        expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
        final pending = Completer<void>();
        fixture
          ..writeError = null
          ..pending = pending.future;
        final submit = save(action(kind));
        await t.tap(submit);
        await t.tap(submit);
        await t.pump();
        expect(fixture.writes.length, 2);
        expect(fixture.bodies.first, fixture.bodies.last);
        final cancel = inInventory(
          find.widgetWithText(
            TextButton,
            kind == InventoryFormKind.cancel ? 'Giữ phiếu' : 'Hủy',
          ),
        );
        expect(t.widget<TextButton>(cancel).onPressed, isNull);
        await t.binding.handlePopRoute();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(InventoryEditor), findsOneWidget);
        pending.complete();
        await t.pumpAndSettle();
        expect(find.byType(InventoryEditor), findsNothing);
        expect(fixture.feedLoads, 2);
      },
    );
  }
  testWidgets(
    'all five filters, date clear and pagination retain queries across tabs and resize',
    (t) async {
      final fixture = InventoryFixture();
      final base = Map<String, dynamic>.from(fixture.entries.first);
      fixture.entries
        ..clear()
        ..addAll(List.generate(25, (i) => {...base, 'id': 'p$i'}));
      await mountInventory(t, fixture);
      await history(t);
      await tapInventory(t, find.byTooltip('Trang sau'));
      expect(fixture.entryRequests.last.url.queryParameters['page'], '2');
      await tapInventory(t, find.byKey(const ValueKey('inventory-filters')));
      await filterSelect(t, 'Thức ăn', 'Thức ăn hỗn hợp có tên dài');
      await filterSelect(t, 'Loại phiếu', 'Nhập');
      await filterSelect(t, 'Trạng thái', 'Hợp lệ');
      await filterDate(t, 'Từ ngày', '22');
      await filterDate(t, 'Đến ngày', '24');
      expect(fixture.entryRequests.last.url.queryParameters, {
        'page': '1',
        'feedId': 'f1',
        'kind': 'IN',
        'status': 'VALID',
        'from': '2026-10-22',
        'to': '2026-10-24',
      });
      await tapInventory(t, find.widgetWithText(ChoiceChip, 'Tồn kho'));
      await history(t);
      await tapInventory(t, find.byKey(const ValueKey('inventory-filters')));
      t.view.physicalSize = const Size(1200, 1100);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.widgetWithText(TextField, 'Từ ngày'))
            .controller!
            .text,
        '22/10/2026',
      );
      await tapInventory(
        t,
        find.descendant(
          of: find.widgetWithText(TextField, 'Từ ngày'),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        fixture.entryRequests.last.url.queryParameters.containsKey('from'),
        isFalse,
      );
      expect(
        fixture.entryRequests.last.url.queryParameters['to'],
        '2026-10-24',
      );
    },
  );
  testWidgets(
    'cancel last valid item on page 2 returns to existing page without losing filters',
    (t) async {
      final fixture = InventoryFixture();
      final base = Map<String, dynamic>.from(fixture.entries.first);
      fixture.entries
        ..clear()
        ..addAll(
          List.generate(21, (i) => {...base, 'id': 'p$i', 'quantity': 0.125}),
        );
      await mountInventory(t, fixture);
      await history(t);
      await tapInventory(t, find.byKey(const ValueKey('inventory-filters')));
      await filterSelect(t, 'Trạng thái', 'Hợp lệ');
      await tapInventory(t, find.byTooltip('Trang sau'));
      await tapInventory(t, inEntry('p20', 'Hủy phiếu'));
      await fillInventory(t, 'Lý do hủy', 'Sai phiếu');
      await tapInventory(t, save('Hủy phiếu'));
      expect(find.text('Trang 1 · 20 phiếu'), findsOneWidget);
      expect(fixture.entryRequests.last.url.queryParameters['status'], 'VALID');
    },
  );
  testWidgets(
    'initial and stale failures do not fabricate empty or allow stock writes',
    (t) async {
      final fixture = InventoryFixture()..failFeeds = true;
      await mountInventory(t, fixture);
      expect(
        find.text('Chưa có thức ăn. ADMIN tạo thức ăn trước khi nhập kho.'),
        findsNothing,
      );
      fixture.failFeeds = false;
      await tapInventory(t, find.byTooltip('Tải lại'));
      fixture.failEntries = true;
      await tapInventory(t, find.byTooltip('Tải lại'));
      expect(
        find.textContaining('Đang hiển thị dữ liệu từ lần tải trước.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Nhập kho'))
            .onPressed,
        isNull,
      );
      await history(t);
      expect(find.text('Không có phiếu phù hợp.'), findsNothing);
      fixture
        ..failEntries = false
        ..entries.clear();
      await tapInventory(t, find.byTooltip('Tải lại'));
      expect(find.text('Không có phiếu phù hợp.'), findsOneWidget);
    },
  );
  for (final width in [360.0, 412.0, 1200.0]) {
    for (final tab in ['stock', 'history']) {
      testWidgets(
        '$tab $width supports long names, zero, precision and canceled records at scale 1.3',
        (t) async {
          final fixture = InventoryFixture();
          final boundary = await mountInventory(t, fixture, width: width);
          if (tab == 'history') await history(t);
          await t.ensureVisible(find.text('Kho thức ăn'));
          await captureInventory(t, boundary, '$tab-${width.toInt()}-top');
          await t.ensureVisible(
            tab == 'stock' ? feedCard('f4') : entryCard('e2'),
          );
          await captureInventory(t, boundary, '$tab-${width.toInt()}-bottom');
        },
      );
    }
    for (final kind in InventoryFormKind.values) {
      testWidgets(
        '${kind.name} $width keeps draft, error and CTA above keyboard',
        (t) async {
          final fixture = InventoryFixture()
            ..writeError =
                'Máy chủ từ chối giao dịch này. Bản nháp được giữ để kiểm tra và thử lại.';
          final boundary = await mountInventory(t, fixture, width: width);
          await openInventory(t, kind);
          final name = '${kind.name}-${width.toInt()}';
          await t.ensureVisible(inInventory(find.byType(Form)));
          await captureInventory(t, boundary, '$name-top');
          final field = kind == InventoryFormKind.cancel
              ? 'Lý do hủy'
              : 'Ghi chú';
          await fillInventory(
            t,
            field,
            'Nội dung nhiều dòng cần được giữ.\nKhông mất nháp khi cuộn hoặc đổi kích thước.',
          );
          await captureInventory(t, boundary, '$name-bottom');
          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          await t.ensureVisible(input(field));
          await t.pumpAndSettle();
          expect(
            t.getBottomRight(save(action(kind))).dy,
            lessThanOrEqualTo(800),
          );
          expect(save(action(kind)).hitTestable(), findsOneWidget);
          await captureInventory(t, boundary, '$name-keyboard');
          await tapInventory(t, save(action(kind)));
          expect(find.text(fixture.writeError!).hitTestable(), findsOneWidget);
          await captureInventory(t, boundary, '$name-error');
          t.view.viewInsets = const FakeViewPadding();
          t.view.physicalSize = Size(width < 600 ? 1200 : 360, 1100);
          await t.pumpAndSettle();
          expect(
            t.widget<TextFormField>(input(field)).controller!.text,
            contains('Không mất nháp'),
          );
          await tapInventory(
            t,
            inInventory(
              find.widgetWithText(
                TextButton,
                kind == InventoryFormKind.cancel ? 'Giữ phiếu' : 'Hủy',
              ),
            ),
          );
          expect(fixture.writes.length, 1);
        },
      );
    }
  }
}
