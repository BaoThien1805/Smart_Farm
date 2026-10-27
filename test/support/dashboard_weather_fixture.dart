// Isolated fixture data. Never imported by lib/ or sent to a real backend.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

http.Response dashboardResponse(Object data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class DashboardWeatherFixture {
  DashboardWeatherFixture({
    this.weatherState = 'ready',
    this.dashboardFails = false,
    Future<http.Response> Function(http.Request)? responder,
  }) {
    api = ApiClient(
      client: MockClient((r) async {
        requests.add(r);
        if (responder != null) return responder(r);
        if (r.url.path.endsWith('/weather')) {
          if (weatherState != 'ready') {
            return dashboardResponse({
              'error': {
                'code': weatherState,
                'message': weatherState == 'FARM_LOCATION_REQUIRED'
                    ? 'Chưa đặt vị trí trang trại.'
                    : 'Không tải được thời tiết. Thử lại sau.',
              },
            }, 503);
          }
          return dashboardResponse(weather);
        }
        if (r.url.path.endsWith('/farm/location')) {
          return dashboardResponse({
            'location': {
              'name':
                  'Trang trại mẫu An Nhiên có tên dài để kiểm tra giao diện',
              'latitude': weatherState == 'FARM_LOCATION_REQUIRED'
                  ? null
                  : latitude,
              'longitude': weatherState == 'FARM_LOCATION_REQUIRED'
                  ? null
                  : longitude,
            },
          });
        }
        if (r.url.path.endsWith('/farm/dashboard')) {
          return dashboardFails
              ? dashboardResponse({
                  'error': {'message': 'Không tải được Tổng quan.'},
                }, 503)
              : dashboardResponse(dashboard);
        }
        return dashboardResponse({});
      }),
    );
    repository = FarmRepository(api);
  }
  String weatherState;
  bool dashboardFails;
  double latitude = 10.8, longitude = 106.6;
  late final ApiClient api;
  late final FarmRepository repository;
  final requests = <http.Request>[];

  static const weather = {
    'temperature': 28.6,
    'humidity': 78,
    'windSpeed': 2.3,
    'description': 'Mây nhẹ · dữ liệu minh họa',
    'condition': 801,
    'location': 'Trang trại mẫu An Nhiên',
    'region': 'Thành phố Hồ Chí Minh',
    'observedAt': '2026-10-24T02:15:00Z',
  };
  static const dashboard = {
    'today': '2026-10-24',
    'activeAnimals': 18,
    'activePens': 4,
    'needsCare': 2,
    'due': 1,
    'overdue': 1,
    'tasks': [
      {
        'id': 'task',
        'animalCode': 'DE-001',
        'title': 'Kiểm tra sức khỏe theo lịch',
        'kind': 'CHECKUP',
        'dueDate': '2026-10-22',
      },
      {
        'id': 'task2',
        'animalCode': 'BO-002',
        'title': 'Tiêm phòng định kỳ',
        'kind': 'VACCINATION',
        'dueDate': '2026-10-24',
      },
    ],
    'lowStockFeeds': [
      {'name': 'Thức ăn hỗn hợp', 'stock': 25.5, 'lowStock': 50},
    ],
    'fullPens': [
      {'code': 'A1', 'name': 'Chuồng hỗn hợp', 'occupied': 10, 'capacity': 10},
    ],
    'finance': {
      'salesRevenue': '10000000',
      'income': '12000000',
      'expense': '3000000',
      'difference': '9000000',
    },
    'financeMonthly': [
      {
        'month': '2026-09',
        'salesRevenue': '3000000',
        'income': '4000000',
        'expense': '2000000',
        'difference': '2000000',
      },
      {
        'month': '2026-10',
        'salesRevenue': '10000000',
        'income': '12000000',
        'expense': '3000000',
        'difference': '9000000',
      },
    ],
  };
  void dispose() => api.dispose();
}
