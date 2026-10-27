import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/revenue_chart.dart';

void main() {
  final monthly = [
    FarmRecord({
      'month': '2026-10',
      'salesRevenue': '10000000',
      'income': '12000000',
      'expense': '3000000',
    }),
    FarmRecord({
      'month': '2026-09',
      'salesRevenue': '0',
      'income': '2000000',
      'expense': '5000000',
    }),
  ];

  testWidgets('columns show chronological months and switch exact values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: RevenueChart(monthly: monthly)),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('T09')).dx,
      lessThan(tester.getTopLeft(find.text('T10')).dx),
    );
    expect(find.text('10.000.000 ₫'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tổng chi'));
    await tester.pumpAndSettle();
    expect(find.text('8.000.000 ₫'), findsOneWidget);
    expect(find.text('3.000.000 ₫'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '09/2026'));
    await tester.pumpAndSettle();
    expect(find.text('5.000.000 ₫'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero revenue has guidance and retains month selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RevenueChart(monthly: [monthly.last])),
      ),
    );
    expect(
      find.text('Chưa phát sinh doanh thu bán trong khoảng thời gian này.'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('revenue-bar-2026-09'))).height,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty series gives a reload message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RevenueChart(monthly: [])),
      ),
    );
    expect(
      find.text('Chưa có số liệu. Hãy tải lại Tổng quan.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('large totals stay exact on a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = List.generate(
      6,
      (i) => FarmRecord({
        'month': '2026-${(i + 5).toString().padLeft(2, '0')}',
        'salesRevenue': '9007199254740993',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(child: RevenueChart(monthly: records)),
          ),
        ),
      ),
    );
    expect(find.text('54.043.195.528.445.958 ₫'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'two year report scrolls month bars and retains all three metrics and zero months',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = List.generate(25, (i) {
        final d = DateTime(2024, 10 + i);
        return FarmRecord({
          'month': '${d.year}-${d.month.toString().padLeft(2, '0')}',
          'salesRevenue': i == 24 ? '0' : '123456789',
          'income': '223456789',
          'expense': '300000000',
        });
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RevenueChart(monthly: records),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ChoiceChip), findsNWidgets(28));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('revenue-bar-2026-10')))
            .height,
        0,
      );
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(-1600, 0));
      await tester.pumpAndSettle();
      expect(find.text('T10').last.hitTestable(), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tổng thu'));
      await tester.pumpAndSettle();
      expect(find.text('5.586.419.725 ₫'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
