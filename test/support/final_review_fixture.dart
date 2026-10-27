// UI review only. No HTTP requests leave MockClient; never imported by lib/.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'animals_fixture.dart';
import 'dashboard_weather_fixture.dart';
import 'workspace_fixture.dart';

class FinalReviewFixture extends WorkspaceFixture {
  FinalReviewFixture(super.role, {this.scenario = 'ready'});
  final String scenario;
  final failed = <String>{};
  final animalSource = AnimalsFixture();

  @override
  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (scenario == 'slow') {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    final reviewed =
        path.endsWith('/animals') || path.endsWith('/farm/dashboard');
    if (scenario == 'error' && reviewed && failed.add(path)) {
      requests.add(request);
      return animalsResponse({
        'error': {
          'message': 'Không thể kết nối máy chủ thử nghiệm. Kiểm tra kết nối rồi thử lại; bộ lọc được giữ nguyên.',
        },
      }, 503);
    }
    if (path.endsWith('/weather') && scenario == 'weather') {
      requests.add(request);
      return animalsResponse({
        'error': {
          'code': 'WEATHER_NOT_CONFIGURED',
          'message': 'Chưa cấu hình dịch vụ thời tiết.',
        },
      }, 503);
    }
    if (path.endsWith('/species-settings')) {
      requests.add(request);
      return animalsResponse({
        'configured': true,
        'speciesIds': ['cow', 'pig', 'goat', 'duck'],
      });
    }
    if (path.endsWith('/catalogs') || path.contains('/animals')) {
      requests.add(request);
      if (scenario == 'empty' && path.endsWith('/animals')) {
        return animalsResponse({'animals': [], 'total': 0});
      }
      return animalSource.handle(request);
    }
    if (path.endsWith('/farm/dashboard')) {
      requests.add(request);
      return animalsResponse(DashboardWeatherFixture.dashboard);
    }
    if (path.endsWith('/finance/report')) {
      requests.add(request);
      return animalsResponse({
        'summary': {
          'income': '0',
          'expense': '0',
          'difference': '0',
          'salesRevenue': '0',
        },
        'monthly': [],
      });
    }
    if (path.endsWith('/auth/me')) {
      final user = auth.user!;
      return animalsResponse({
        'user': {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'role': user.role,
          'active': true,
        },
      });
    }
    // All other endpoints also stay in the inherited local MockClient.
    return super.handle(request);
  }

  @override
  void dispose() {
    animalSource.dispose();
    super.dispose();
  }

  String get summary => jsonEncode({
    'role': auth.user?.role,
    'scenario': scenario,
    'requests': requests.length,
  });
}
