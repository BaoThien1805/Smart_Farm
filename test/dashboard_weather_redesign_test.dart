import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/dashboard_page.dart';
import 'package:smart_farm/features/farm/farm_location_page.dart';
import 'package:smart_farm/features/farm/weather_card.dart';

import 'device_location_test.dart' show TestLocation;
import 'support/dashboard_weather_fixture.dart';
import 'support/ui_preview.dart';

Future<void> mount(
  WidgetTester t,
  DashboardWeatherFixture fixture, {
  double width = 412,
  double keyboard = 0,
  String screen = 'dashboard',
  bool admin = true,
  bool financeAccess = false,
  GlobalKey? boundary,
  VoidCallback? onPens,
  VoidCallback? onStock,
  VoidCallback? onCare,
}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  addTearDown(fixture.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: farmTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: RepaintBoundary(key: boundary, child: child!),
      ),
      home: Scaffold(
        body: screen == 'location'
            ? FarmLocationPage(repository: fixture.repository, admin: admin)
            : FarmDashboard(
                repository: fixture.repository,
                userName: 'Chủ trang trại',
                admin: admin,
                financeAccess: financeAccess,
                onAnimals: () {},
                onCare: onCare ?? () {},
                onStock: onStock,
                onPens: onPens,
                onFinance: () {},
              ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, GlobalKey boundary, String name) async {
  final context = t.element(find.byType(Scaffold).first);
  final images = t.widgetList<Image>(find.byType(Image)).toList();
  await t.runAsync(
    () =>
        Future.wait(images.map((image) => precacheImage(image.image, context))),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  await exportUiPreview(t, boundary, '$name.png');
}

Future<void> tapText(WidgetTester t, String text) async {
  final target = find.text(text).last;
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  if (exportUiPreviews) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(loadUiPreviewFonts);
  }
  for (final weatherState in [
    'WEATHER_NOT_CONFIGURED',
    'FARM_LOCATION_REQUIRED',
    'PROVIDER_ERROR',
  ]) {
    testWidgets(
      'weather $weatherState leaves dashboard and independent data usable',
      (t) async {
        final boundary = GlobalKey();
        await mount(
          t,
          DashboardWeatherFixture(weatherState: weatherState),
          boundary: boundary,
          width: 360,
        );
        expect(find.text('18'), findsOneWidget);
        expect(
          find.textContaining('Trang trại mẫu An Nhiên có tên dài'),
          findsOneWidget,
        );
        expect(find.textContaining('DE-001 · Kiểm tra'), findsOneWidget);
        expect(find.text('29°C'), findsNothing);
        await capture(t, boundary, 'dashboard-$weatherState');
        await t.tap(find.byType(WeatherCard));
        await t.pumpAndSettle();
        expect(find.byType(WeatherCard), findsNWidgets(2));
        expect(
          find.textContaining(
            weatherState == 'WEATHER_NOT_CONFIGURED'
                ? 'chưa được bật trên máy chủ'
                : weatherState == 'FARM_LOCATION_REQUIRED'
                ? 'Chưa đặt vị trí trang trại.'
                : 'Không tải được thời tiết.',
          ),
          findsWidgets,
        );
        await capture(t, boundary, 'weather-$weatherState');
      },
    );
  }

  testWidgets(
    'weather retry cannot replace farm data; dashboard errors do not hide weather',
    (t) async {
      final fixture = DashboardWeatherFixture(dashboardFails: true);
      await mount(t, fixture);
      expect(find.text('Không tải được Tổng quan.'), findsOneWidget);
      expect(find.text('29°C'), findsOneWidget);
      expect(find.text('18'), findsNothing);
      fixture.dashboardFails = false;
      await t.tap(find.byTooltip('Tải lại'));
      await t.pumpAndSettle();
      expect(find.text('18'), findsOneWidget);
      fixture.dashboardFails = true;
      await t.tap(find.byTooltip('Tải lại'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Đang hiển thị dữ liệu từ lần tải trước'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'pen cards, real overdue task and low stock open their intended function; full pens are not alerts',
    (t) async {
      var pens = 0, stock = 0, care = 0;
      await mount(
        t,
        DashboardWeatherFixture(),
        onPens: () => pens++,
        onStock: () => stock++,
        onCare: () => care++,
      );
      final penCard = find.byKey(const ValueKey('dashboard-activePens'));
      await t.ensureVisible(penCard);
      await t.tap(penCard);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('dashboard-pens')));
      await t.tap(find.byKey(const ValueKey('dashboard-pens')));
      await t.pumpAndSettle();
      expect(pens, 2);
      await tapText(t, 'DE-001 · Kiểm tra sức khỏe theo lịch');
      expect(care, 1);
      await tapText(t, 'Cảnh báo');
      await tapText(t, 'Thức ăn hỗn hợp');
      expect(stock, 1);
      expect(pens, 2);
      expect(find.text('A1 · Chuồng hỗn hợp'), findsNothing);
      expect(find.text('Chuồng đầy · 10/10 con'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final finance in [false, true]) {
    testWidgets(
      'financial payload is ${finance ? 'available to accountant' : 'hidden from vet'}',
      (t) async {
        await mount(
          t,
          DashboardWeatherFixture(),
          admin: false,
          financeAccess: finance,
        );
        final tab = find.widgetWithText(ChoiceChip, 'Tài chính');
        expect(tab, finance ? findsOneWidget : findsNothing);
        if (finance) {
          await t.ensureVisible(tab);
          await t.tap(tab);
          await t.pumpAndSettle();
          expect(find.text('Biểu đồ doanh thu'), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'read-only location shows API coordinates with no GPS or edit controls',
    (t) async {
      await mount(
        t,
        DashboardWeatherFixture(),
        screen: 'location',
        admin: false,
      );
      expect(find.text('Vĩ độ: 10.8'), findsOneWidget);
      expect(find.text('Kinh độ: 106.6'), findsOneWidget);
      expect(find.text('Đặt vị trí trang trại'), findsNothing);
      expect(find.text('Lấy vị trí thiết bị'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'denied GPS keeps manual input usable and never auto-saves coordinates',
    (t) async {
      final previous = GeolocatorPlatform.instance;
      final platform = TestLocation()
        ..permission = LocationPermission.deniedForever;
      GeolocatorPlatform.instance = platform;
      addTearDown(() {
        GeolocatorPlatform.instance = previous;
      });
      final saved = <Map<String, dynamic>>[];
      final fixture = DashboardWeatherFixture(
        responder: (r) async {
          if (r.method == 'PATCH') {
            saved.add(jsonDecode(r.body) as Map<String, dynamic>);
            return dashboardResponse({});
          }
          return r.url.path.endsWith('/weather')
              ? dashboardResponse(DashboardWeatherFixture.weather)
              : dashboardResponse({
                  'location': {'latitude': 10.8, 'longitude': 106.6},
                });
        },
      );
      await mount(t, fixture, screen: 'location');
      await tapText(t, 'Đặt vị trí trang trại');
      expect(platform.settings, isEmpty);
      await tapText(t, 'Lấy vị trí thiết bị');
      expect(saved, isEmpty);
      expect(find.textContaining('Quyền vị trí đã bị chặn'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '10,7');
      await t.enterText(find.widgetWithText(TextFormField, 'Kinh độ'), '106,5');
      await tapText(t, 'Lưu vị trí');
      expect(saved.single, {'latitude': 10.7, 'longitude': 106.5});
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'location save validates, guards busy and Back, keeps draft for retry',
    (t) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final fixture = DashboardWeatherFixture(
        responder: (r) async {
          if (r.method == 'PATCH') {
            calls++;
            expectSync(jsonDecode(r.body), {
              'latitude': -90.0,
              'longitude': 180.0,
            });
            return calls == 1 ? pending.future : dashboardResponse({});
          }
          return r.url.path.endsWith('/weather')
              ? dashboardResponse(DashboardWeatherFixture.weather)
              : dashboardResponse({
                  'location': {'latitude': 10.8, 'longitude': 106.6},
                });
        },
      );
      await mount(t, fixture, screen: 'location', keyboard: 300, width: 360);
      await tapText(t, 'Đặt vị trí trang trại');
      await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '91');
      await tapText(t, 'Lưu vị trí');
      expect(calls, 0);
      await t.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '-90');
      await t.enterText(find.widgetWithText(TextFormField, 'Kinh độ'), '180');
      final save = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu vị trí'))
          .onPressed!;
      save();
      save();
      await t.pump();
      expect(calls, 1);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(FarmLocationDialog), findsOneWidget);
      pending.complete(
        dashboardResponse({
          'error': {'message': 'Lưu chưa thành công. Giữ tọa độ và thử lại.'},
        }, 503),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Lưu chưa thành công.'), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Vĩ độ'))
            .controller!
            .text,
        '-90',
      );
      await tapText(t, 'Lưu vị trí');
      expect(calls, 2);
      expect(find.byType(FarmLocationDialog), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [360.0, 412.0, 1200.0]) {
    for (final screen in ['dashboard', 'location', 'editor']) {
      testWidgets('$screen fits $width with scale 1.3', (t) async {
        final boundary = GlobalKey();
        await mount(
          t,
          DashboardWeatherFixture(),
          width: width,
          boundary: boundary,
          screen: screen == 'dashboard' ? 'dashboard' : 'location',
          keyboard: screen == 'editor' ? 300 : 0,
        );
        if (screen == 'editor') {
          await tapText(t, 'Đặt vị trí trang trại');
          final longitude = find.widgetWithText(TextFormField, 'Kinh độ');
          await t.ensureVisible(longitude);
          await t.pumpAndSettle();
          expect(
            t
                .getBottomRight(find.widgetWithText(FilledButton, 'Lưu vị trí'))
                .dy,
            lessThanOrEqualTo(700),
          );
        }
        await capture(t, boundary, '$screen-${width.toInt()}');
        if (screen == 'dashboard') {
          await t.ensureVisible(find.byKey(const ValueKey('dashboard-pens')));
          await t.pumpAndSettle();
          await capture(t, boundary, 'dashboard-details-${width.toInt()}');
        }
      });
    }
  }
}
