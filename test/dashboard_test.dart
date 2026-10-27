import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/dashboard_page.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/revenue_chart.dart';

void main() {
  for (final size in [
    const Size(320, 844),
    const Size(390, 844),
    const Size(1300, 900),
  ]) {
    testWidgets('dashboard revenue table fits ${size.width}', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'activeAnimals': 20,
              'activePens': 3,
              'needsCare': 2,
              'due': 1,
              'overdue': 3,
              'finance': {
                'salesRevenue': '10000000',
                'income': '12000000',
                'expense': '3000000',
                'difference': '9000000',
              },
              'financeMonthly': [
                {
                  'month': '2026-10',
                  'salesRevenue': '10000000',
                  'income': '12000000',
                  'expense': '3000000',
                  'difference': '9000000',
                },
                {
                  'month': '2026-09',
                  'salesRevenue': '0',
                  'income': '0',
                  'expense': '0',
                  'difference': '0',
                },
              ],
              'tasks': [],
              'lowStockFeeds': [],
              'fullPens': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: FarmDashboard(
              repository: FarmRepository(api),
              userName: 'Chủ trang trại',
              admin: true,
              onAnimals: () {},
              onCare: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tổng quan trang trại'), findsNothing);
      expect(find.text('Chào Chủ trang trại'), findsOneWidget);
      expect(find.byType(RevenueChart), findsNothing);
      expect(find.byKey(const ValueKey('dashboard-due')), findsOneWidget);
      expect(find.text('3 việc chăm sóc quá hạn'), findsNothing);
      expect(find.text('Mở lịch để kiểm tra và xử lý.'), findsNothing);
      await t.ensureVisible(find.widgetWithText(ChoiceChip, 'Cảnh báo'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Cảnh báo'));
      await t.pumpAndSettle();
      expect(find.text('Cần lưu ý'), findsOneWidget);
      expect(find.text('Trang trại trong ngày'), findsNothing);
      await t.tap(find.widgetWithText(ChoiceChip, 'Tài chính'));
      await t.pumpAndSettle();
      expect(find.byType(RevenueChart), findsOneWidget);
      await t.ensureVisible(find.text('Xem bảng doanh thu chi tiết'));
      await t.tap(find.text('Xem bảng doanh thu chi tiết'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(RevenueTable));
      await t.pumpAndSettle();
      expect(find.text('Bảng thống kê doanh thu'), findsOneWidget);
      expect(find.text('10.000.000 ₫'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    });
  }

  testWidgets(
    'staff dashboard excludes financial widgets even if data is supplied',
    (t) async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'finance': {'salesRevenue': '10000000'},
              'financeMonthly': [
                {'month': '2026-10', 'salesRevenue': '10000000'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: FarmDashboard(
              repository: FarmRepository(api),
              userName: 'Nhân viên',
              onAnimals: () {},
              onCare: () {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(RevenueChart), findsNothing);
      expect(find.byType(RevenueTable), findsNothing);
      expect(find.byType(DashboardFinanceCards), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Tài chính'), findsNothing);
      await t.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
