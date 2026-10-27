import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/core/ui_components.dart';
import 'package:smart_farm/features/farm/animals_page.dart';
import 'package:smart_farm/features/farm/dashboard_page.dart';
import 'package:smart_farm/features/farm/inventory_page.dart';

import 'support/animals_fixture.dart';
import 'support/dashboard_weather_fixture.dart';
import 'support/inventory_fixture.dart';
import 'support/ui_preview.dart';

Future<GlobalKey> mountReview(
  WidgetTester t,
  Widget page, {
  double width = 412,
}) async {
  t.view.physicalSize = Size(width, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final boundary = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Scaffold(body: page),
    ),
  );
  await t.pump();
  return boundary;
}

AnimalsPage reviewAnimals(AnimalsFixture f, {String role = 'ADMIN'}) =>
    AnimalsPage(
      repository: f.repository,
      admin: role == 'ADMIN',
      canOperate: ['ADMIN', 'STAFF'].contains(role),
      canCare: role != 'ACCOUNTANT',
      canExamine: ['ADMIN', 'VET'].contains(role),
      canFinance: ['ADMIN', 'ACCOUNTANT'].contains(role),
      initialPenId: 'pen1',
    );

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final width in [360.0, 412.0, 1200.0]) {
    testWidgets(
      'states $width distinguish pending/error/empty and retry once with scope',
      (t) async {
        final f = AnimalsFixture()..repository.selectedSpeciesIds = ['cow'];
        addTearDown(f.dispose);
        var pending = Completer<http.Response>();
        f.listOverride = (_) => pending.future;
        final boundary = await mountReview(t, reviewAnimals(f), width: width);
        expect(find.byType(FarmLoadingState), findsOneWidget);
        expect(find.byType(FarmEmptyState), findsNothing);
        await t.pump(const Duration(milliseconds: 100));
        await exportUiPreview(t, boundary, 'loading-${width.toInt()}.png');
        pending.complete(
          animalsResponse({
            'error': {
              'message': 'Máy chủ tạm thời không phản hồi. Kiểm tra kết nối rồi thử lại; bộ lọc vẫn được giữ.',
            },
          }, 503),
        );
        await t.pumpAndSettle();
        expect(find.byType(FarmLoadError), findsOneWidget);
        expect(find.byType(FarmEmptyState), findsNothing);
        await exportUiPreview(t, boundary, 'error-${width.toInt()}.png');
        pending = Completer<http.Response>();
        final retry = find.widgetWithText(FilledButton, 'Thử lại');
        await t.ensureVisible(retry);
        await t.tap(retry);
        await t.tap(retry);
        await t.pump();
        expect(f.listRequests.length, 2);
        expect(
          f.listRequests.last.url.queryParameters,
          f.listRequests.first.url.queryParameters,
        );
        expect(f.listRequests.last.url.queryParameters['penId'], 'pen1');
        expect(f.listRequests.last.url.queryParameters['speciesIds'], 'cow');
        expect(find.byType(FarmEmptyState), findsNothing);
        pending.complete(animalsResponse({'animals': [], 'total': 0}));
        await t.pumpAndSettle();
        expect(find.byType(FarmLoadError), findsNothing);
        expect(find.byType(FarmEmptyState), findsOneWidget);
        await exportUiPreview(t, boundary, 'empty-${width.toInt()}.png');
        f.listOverride = null;
        await t.ensureVisible(find.byTooltip('Tải lại'));
        await t.tap(find.byTooltip('Tải lại'));
        await t.pumpAndSettle();
        expect(find.text('BO-001'), findsOneWidget);
        expect(find.byType(FarmEmptyState), findsNothing);
        expect(f.requests.every((r) => r.method == 'GET'), isTrue);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed refresh keeps old animals with warning and retry preserves search',
    (t) async {
      final f = AnimalsFixture();
      addTearDown(f.dispose);
      await mountReview(t, reviewAnimals(f));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Bông');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      f.failList = true;
      await t.tap(find.byTooltip('Tải lại'));
      await t.pumpAndSettle();
      expect(find.text('BO-001'), findsOneWidget);
      expect(
        find.textContaining('Danh sách bên dưới là kết quả lần tải trước.'),
        findsOneWidget,
      );
      expect(find.byType(FarmEmptyState), findsNothing);
      f.failList = false;
      await t.tap(find.widgetWithText(FilledButton, 'Thử lại'));
      await t.pumpAndSettle();
      expect(f.listRequests.last.url.queryParameters['search'], 'Bông');
      expect(find.text('BO-001'), findsOneWidget);
      expect(find.byType(FarmLoadError), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final role in ['ADMIN', 'STAFF', 'VET', 'ACCOUNTANT']) {
    testWidgets('empty state keeps animal actions for $role', (t) async {
      final f = AnimalsFixture()..animals.clear();
      addTearDown(f.dispose);
      await mountReview(t, reviewAnimals(f, role: role));
      await t.pumpAndSettle();
      expect(find.byType(FarmEmptyState), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Thêm vật nuôi'),
        ['ADMIN', 'STAFF'].contains(role) ? findsOneWidget : findsNothing,
      );
      expect(f.requests.every((r) => r.method == 'GET'), isTrue);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'feed failure is retryable for read-only VET without stock-entry requests',
    (t) async {
      final f = InventoryFixture('VET')..failFeeds = true;
      addTearDown(f.dispose);
      await mountReview(
        t,
        InventoryPage(
          repository: f.repository,
          admin: false,
          canOperate: false,
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(FarmLoadError), findsOneWidget);
      expect(find.byType(FarmEmptyState), findsNothing);
      f.failFeeds = false;
      await t.tap(find.widgetWithText(FilledButton, 'Thử lại'));
      await t.pumpAndSettle();
      expect(find.text('Thức ăn hỗn hợp có tên dài'), findsOneWidget);
      expect(
        f.requests.where((r) => r.url.path.endsWith('/stock-entries')),
        isEmpty,
      );
      expect(find.widgetWithText(FilledButton, 'Nhập kho'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'local weather error leaves dashboard usable; dashboard error retries independently',
    (t) async {
      final f = DashboardWeatherFixture(weatherState: 'WEATHER_NOT_CONFIGURED');
      addTearDown(f.api.dispose);
      final boundary = await mountReview(
        t,
        FarmDashboard(
          repository: f.repository,
          userName: 'Người kiểm thử',
          onAnimals: () {},
          onCare: () {},
        ),
        width: 360,
      );
      await t.pumpAndSettle();
      expect(find.byType(FarmLoadError), findsNothing);
      expect(
        find.byKey(const ValueKey('dashboard-activeAnimals')),
        findsOneWidget,
      );
      await exportUiPreview(t, boundary, 'dashboard-weather-local-360.png');
      f.dashboardFails = true;
      await t.tap(find.byTooltip('Tải lại'));
      await t.pumpAndSettle();
      expect(find.byType(FarmLoadError), findsOneWidget);
      expect(
        find.textContaining('Đang hiển thị dữ liệu từ lần tải trước.'),
        findsOneWidget,
      );
      f.dashboardFails = false;
      await t.tap(find.widgetWithText(FilledButton, 'Thử lại'));
      await t.pumpAndSettle();
      expect(find.byType(FarmLoadError), findsNothing);
      expect(
        find.byKey(const ValueKey('dashboard-activeAnimals')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
}
