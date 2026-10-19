import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/theme.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';
import 'package:smart_farm/features/farm/weather_card.dart';

void main() {
  testWidgets(
    'compact weather opens complete details and owner location controls',
    (t) async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'temperature': 28,
              'humidity': 70,
              'condition': 800,
              'windSpeed': 2,
              'description': 'trời quang',
              'location': 'Trang trại',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 130,
                child: WeatherCard(
                  repository: FarmRepository(api),
                  admin: true,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('28°C'), findsOneWidget);
      expect(find.text('Đặt vị trí trang trại'), findsNothing);
      await t.tap(find.text('Thời tiết'));
      await t.pumpAndSettle();
      expect(find.text('Độ ẩm 70%'), findsOneWidget);
      expect(find.text('Đặt vị trí trang trại'), findsOneWidget);
      await t.tap(find.text('Đóng'));
      await t.pumpAndSettle();
      expect(find.text('Độ ẩm 70%'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'missing server weather configuration is distinct from missing farm location',
    (t) async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'WEATHER_NOT_CONFIGURED',
                'message': 'Chưa cấu hình dịch vụ thời tiết.',
              },
            }),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: WeatherCard(repository: FarmRepository(api), admin: false),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('chưa được bật trên máy chủ'), findsOneWidget);
      expect(
        find.text('Chủ trang trại có thể đặt vị trí tại đây.'),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'weather shows actual data and fits narrow screen with large text',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'location': 'Trang trại gia đình',
              'temperature': 29.8,
              'humidity': 80,
              'windSpeed': 2.5,
              'condition': 500,
              'description': 'mưa nhẹ',
              'observedAt': '2026-10-05T03:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(api.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: farmTheme(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: WeatherCard(
                  repository: FarmRepository(api),
                  admin: true,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('30°C'), findsOneWidget);
      expect(find.text('mưa nhẹ'), findsOneWidget);
      expect(find.text('Độ ẩm 80%'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'owner sets farm coordinates; invalid values do not save; staff cannot edit',
    (t) async {
      Map<String, dynamic>? saved;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'PATCH') {
            saved = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('/farm/location')) {
            return http.Response(
              '{"location":{"name":"Farm","latitude":null,"longitude":null}}',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'error': {'message': 'Chưa đặt vị trí trang trại.'},
            }),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.dispose);
      Widget page(bool admin) => MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: WeatherCard(repository: FarmRepository(api), admin: admin),
        ),
      );
      await t.pumpWidget(page(true));
      await t.pumpAndSettle();
      await t.tap(find.text('Đặt vị trí trang trại'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(0), '91');
      await t.enterText(find.byType(TextFormField).at(1), '106.6');
      await t.tap(find.text('Lưu vị trí'));
      await t.pumpAndSettle();
      expect(saved, isNull);
      await t.enterText(find.byType(TextFormField).at(0), '10,8');
      await t.tap(find.text('Lưu vị trí'));
      await t.pumpAndSettle();
      expect(saved, {'latitude': 10.8, 'longitude': 106.6});
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(page(false));
      await t.pumpAndSettle();
      expect(find.text('Đặt vị trí trang trại'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
