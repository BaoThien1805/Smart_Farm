import 'dart:convert';
import 'dart:async';

import 'package:smart_farm/features/farm/farm_refresh.dart';
import 'package:smart_farm/features/farm/finance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/home/workspace_page.dart';
import 'package:smart_farm/features/farm/animals_page.dart';

import 'support/workspace_fixture.dart';

class FreshnessFixture extends WorkspaceFixture {
  FreshnessFixture() : super('ADMIN');
  bool sold = false;
  int occupied = 1;
  int income = 18500000;
  http.Response response(Object data) => http.Response(
    jsonEncode(data),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  @override
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/sales/sale/cancel')) {
      requests.add(request);
      sold = false;
      return response({'id': 'sale'});
    }
    if (request.method == 'GET' && path.endsWith('/animals')) {
      requests.add(request);
      final matches =
          !sold &&
          WorkspaceFixture.animal['code']!.contains(
            request.url.queryParameters['search'] ?? '',
          );
      return response({
        'animals': matches ? [WorkspaceFixture.animal] : [],
        'total': matches ? 1 : 0,
      });
    }
    if (request.method == 'POST' && path.endsWith('/animals')) {
      requests.add(request);
      occupied++;
      return response({'id': 'created-local-review'});
    }
    if (request.method == 'POST' && path.endsWith('/animals/animal/sell')) {
      requests.add(request);
      income = 20500000;
      return response({'id': 'sale-local-review'});
    }
    if (path.endsWith('/catalogs')) {
      requests.add(request);
      final data = jsonDecode(
        jsonEncode(WorkspaceFixture.catalogs),
      ) as Map<String, dynamic>;
      (data['pens'] as List).first['occupied'] = occupied;
      return response(data);
    }
    if (path.endsWith('/finance/entries')) {
      requests.add(request);
      return response({
        'total': 1,
        'entries': [
          {
            'id': 'income',
            'date': '2026-10-25',
            'kind': 'IN',
            'category': 'OTHER',
            'amount': '$income',
            'content': 'Khoản thu kiểm tra local',
            'actorName': 'Chủ trại',
          },
        ],
      });
    }
    if (path.endsWith('/finance/report')) {
      requests.add(request);
      return response({
        'summary': {
          'income': '$income',
          'expense': '0',
          'difference': '$income',
          'salesRevenue': '0',
        },
        'monthly': [],
      });
    }
    return super.handle(request);
  }
}

Future<void> mountReview(WidgetTester t, FreshnessFixture fixture) async {
  t.view.physicalSize = const Size(1200, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(fixture.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      home: WorkspacePage(auth: fixture.auth),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> openDestination(WidgetTester t, String destination) async {
  final finder = find.byKey(ValueKey('nav-$destination'));
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  test(
    'reactivation during an in-flight load queues one fresh serial pass',
    () async {
      final refresh = FarmRefresh();
      final pending = Completer<void>();
      var calls = 0, active = 0, peak = 0;
      Future<void> load() async {
        calls++;
        active++;
        if (active > peak) peak = active;
        if (calls == 1) await pending.future;
        active--;
      }

      final first = refresh.run(load);
      await Future<void>.delayed(Duration.zero);
      final second = refresh.run(load);
      final third = refresh.run(load);
      pending.complete();
      await Future.wait([first, second, third]);
      expect(calls, 2);
      expect(peak, 1);
      refresh.dispose();
      await refresh.run(load);
      expect(calls, 2);
    },
  );

  testWidgets(
    'cancelling a sale restores the cached ACTIVE list and keeps search',
    (t) async {
      final fixture = FreshnessFixture()..sold = true;
      await mountReview(t, fixture);
      await openDestination(t, 'animals');
      await t.enterText(find.byType(TextField), 'DE-001');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('animal-animal')), findsNothing);
      await openDestination(t, 'finance');
      final repository = t
          .widget<FinancePage>(find.byType(FinancePage))
          .repository;
      await repository.save('POST', '/sales/sale/cancel', {
        'reason': 'Nhận lại',
      });
      final before = fixture.requests
          .where((r) => r.url.path.endsWith('/animals'))
          .length;
      await openDestination(t, 'animals');
      expect(find.byKey(const ValueKey('animal-animal')), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'DE-001',
      );
      final last = fixture.requests.lastWhere(
        (r) => r.url.path.endsWith('/animals'),
      );
      expect(last.url.queryParameters['status'], 'ACTIVE');
      expect(last.url.queryParameters['search'], 'DE-001');
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/animals')).length,
        before + 1,
      );
      await openDestination(t, 'animals');
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/animals')).length,
        before + 1,
      );
    },
  );

  testWidgets(
    'Review: pen occupancy should refresh after creating an animal in another tab',
    (t) async {
      final fixture = FreshnessFixture();
      await mountReview(t, fixture);
      await openDestination(t, 'pens');
      expect(find.text('1/10 con'), findsOneWidget);
      await openDestination(t, 'animals');
      final repository = t
          .widget<AnimalsPage>(find.byType(AnimalsPage))
          .repository;
      await repository.save('POST', '/animals', {'code': 'review-local'});
      final before = fixture.requests
          .where((r) => r.url.path.endsWith('/catalogs'))
          .length;
      await openDestination(t, 'pens');
      final after = fixture.requests
          .where((r) => r.url.path.endsWith('/catalogs'))
          .length;
      expect(after - before, 1);
      expect(
        find.text('2/10 con'),
        findsOneWidget,
        reason: 'Returning to Pens after a successful animal write must not retain old occupancy.',
      );
    },
  );

  testWidgets('Review: finance should refresh after a sale in animal profile', (
    t,
  ) async {
    final fixture = FreshnessFixture();
    await mountReview(t, fixture);
    await openDestination(t, 'finance');
    expect(find.textContaining('18.500.000'), findsWidgets);
    await openDestination(t, 'animals');
    final repository = t
        .widget<AnimalsPage>(find.byType(AnimalsPage))
        .repository;
    await repository.save('POST', '/animals/animal/sell', {'amount': 2000000});
    final before = fixture.requests
        .where((r) => r.url.path.endsWith('/finance/report'))
        .length;
    await openDestination(t, 'finance');
    final after = fixture.requests
        .where((r) => r.url.path.endsWith('/finance/report'))
        .length;
    expect(after - before, 1);
    expect(
      find.textContaining('20.500.000'),
      findsWidgets,
      reason: 'Finance totals should include a successful sale when returning from Animals.',
    );
  });
}
