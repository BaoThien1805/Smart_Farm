import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:smart_farm/features/farm/farm_pages.dart';

import 'farm_test.dart' show animal, catalogs;

http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'manual expense rejects fractional VND and retries with same request ID',
    (t) async {
      phone(t);
      final requests = <Map<String, dynamic>>[];
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            requests.add(jsonDecode(r.body) as Map<String, dynamic>);
            return requests.length == 1
                ? response({
                    'error': {'message': 'Thử lại cùng yêu cầu'},
                  }, 503)
                : response({
                    'entry': {'id': 'entry-1'},
                  });
          }
          return response({'entries': [], 'total': 0});
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(body: FinancePage(repository: FarmRepository(api))),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.widgetWithText(OutlinedButton, 'Ghi chi'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Số tiền (VND)'),
        '10.5',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nội dung'),
        'Mua thức ăn',
      );
      await tap(t, find.widgetWithText(FilledButton, 'Lưu giao dịch'));
      expect(requests, isEmpty);
      expect(find.text('Nhập số nguyên VND.'), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Số tiền (VND)'),
        '1000',
      );
      await tap(t, find.widgetWithText(FilledButton, 'Lưu giao dịch'));
      expect(find.text('Thử lại cùng yêu cầu'), findsOneWidget);
      await tap(t, find.widgetWithText(FilledButton, 'Lưu giao dịch'));
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(requests[0]['amount'], 1000);
      expect(requests[0]['kind'], 'OUT');
      expect(find.text('Ghi chi'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'sale receipts cannot be independently edited and report keeps large totals exact',
    (t) async {
      phone(t);
      final api = ApiClient(
        client: MockClient(
          (r) async => r.url.path.endsWith('/report')
              ? response({
                  'summary': {
                    'salesRevenue': '10000000',
                    'income': '9007199254740993123',
                    'expense': '1000',
                    'difference': '9007199254740992123',
                  },
                  'monthly': [
                    {
                      'month': '2026-10',
                      'income':
                          r.url.queryParameters['category'] == 'ANIMAL_SALE'
                          ? '10000000'
                          : '9007199254740993123',
                      'expense':
                          r.url.queryParameters['category'] == 'ANIMAL_SALE'
                          ? '0'
                          : '1000',
                    },
                  ],
                })
              : response({
                  'entries': [
                    {
                      'id': 'entry-1',
                      'date': '2026-10-02',
                      'kind': 'IN',
                      'category': 'ANIMAL_SALE',
                      'amount': '10000000',
                      'content': 'Bán GOAT-01',
                      'saleId': 'sale-1',
                    },
                  ],
                  'total': 1,
                }),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(body: FinancePage(repository: FarmRepository(api))),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Sửa'), findsNothing);
      expect(find.text('Hủy khoản'), findsNothing);
      expect(find.text('Liên kết giao dịch bán'), findsOneWidget);
      await tap(t, find.widgetWithText(ChoiceChip, 'Báo cáo'));
      expect(
        find.descendant(
          of: find.byType(FinanceTotals),
          matching: find.text('9.007.199.254.740.993.123 ₫'),
        ),
        findsOneWidget,
      );
      expect(find.text('Doanh thu bán vật nuôi'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FinanceTotals),
          matching: find.text('10.000.000 ₫'),
        ),
        findsOneWidget,
      );
      expect(find.text('Chênh lệch thu chi'), findsNWidgets(2));
      expect(find.byType(MonthlyFinanceChart), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'admin can sell then cancel from detail with refreshed sale history and free pens',
    (t) async {
      phone(t);
      var sold = false, cancelled = false;
      Map<String, dynamic>? cancelBody;
      var changed = 0;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            if (r.url.path.endsWith('/sell')) {
              sold = true;
            } else {
              cancelled = true;
              cancelBody = jsonDecode(r.body) as Map<String, dynamic>;
            }
            return response({'ok': true});
          }
          if (r.url.path.endsWith('/catalogs')) return response(catalogs);
          if (r.url.path.endsWith('/sales')) {
            changed++;
            return response({
              'sales': sold
                  ? [
                      {
                        'id': 'sale-1',
                        'animalId': animal['id'],
                        'animalCode': 'GOAT-01',
                        'date': farmToday(),
                        'amount': '10000000',
                        'cancelledAt': cancelled
                            ? '2026-10-02T10:00:00Z'
                            : null,
                        'cancelReason': cancelled ? 'Nhập nhầm' : '',
                      },
                    ]
                  : [],
              'total': sold ? 1 : 0,
            });
          }
          return response({
            'animal': {
              ...animal,
              'status': sold && !cancelled ? 'SOLD' : 'ACTIVE',
              'endedDate': sold && !cancelled ? farmToday() : null,
            },
            'weights': [],
            'transfers': [],
            'healthRecords': [],
            'careTasks': [],
          });
        }),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: AnimalDetailPage(
            repository: FarmRepository(api),
            admin: true,
            id: animal['id'] as String,
          ),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.widgetWithText(FilledButton, 'Bán vật nuôi'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Số tiền (VND)'),
        '10000000',
      );
      await tap(t, find.widgetWithText(FilledButton, 'Xác nhận bán'));
      expect(find.text('Bán vật nuôi'), findsNothing);
      expect(find.text('Hủy bán'), findsOneWidget);
      expect(changed, greaterThanOrEqualTo(2));
      await tap(t, find.text('Hủy bán'));
      await tap(
        t,
        find.widgetWithText(DropdownButtonFormField<String>, 'Chuồng nhận lại'),
      );
      await tap(t, find.text('P1 · Chuồng A (1/10)').last);
      await t.enterText(
        find.widgetWithText(TextFormField, 'Lý do hủy bán'),
        'Nhập nhầm',
      );
      await tap(t, find.widgetWithText(FilledButton, 'Xác nhận hủy'));
      expect(cancelBody!['penId'], animal['penId']);
      expect(cancelBody!['reason'], 'Nhập nhầm');
      expect(cancelBody!['requestId'], isNotEmpty);
      expect(find.text('Bán vật nuôi'), findsOneWidget);
      expect(find.text('Hủy bán'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets('staff detail never requests sales or shows financial actions', (
    t,
  ) async {
    phone(t);
    final calls = <String>[];
    final api = ApiClient(
      client: MockClient((r) async {
        calls.add(r.url.path);
        return r.url.path.endsWith('/catalogs')
            ? response(catalogs)
            : response({
                'animal': animal,
                'weights': [],
                'transfers': [],
                'healthRecords': [],
                'careTasks': [],
              });
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: AnimalDetailPage(
          repository: FarmRepository(api),
          admin: false,
          id: animal['id'] as String,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      calls.any((p) => p.endsWith('/sales') || p.contains('/finance')),
      false,
    );
    expect(find.text('Bán vật nuôi'), findsNothing);
    expect(find.byType(SalesHistory), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    api.dispose();
  });
}
