// Local preview/test data only. Every HTTP response is supplied by MockClient.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/auth/auth_controller.dart';
import 'package:smart_farm/features/auth/auth_repository.dart';

class _PreviewStore implements TokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

class WorkspaceFixture {
  WorkspaceFixture(String role, {this.configured = true}) {
    api = ApiClient(client: MockClient(handle));
    auth = AuthController(AuthRepository(api, _PreviewStore()))
      ..initializing = false
      ..user = FarmUser(
        id: 'preview-user',
        email: 'preview@example.test',
        name: 'Nguyễn An Nhiên · tài khoản minh họa',
        role: role,
        active: true,
      );
  }
  bool configured;
  double latitude = 10.5, longitude = 106.5;
  final requests = <http.Request>[];
  late final ApiClient api;
  late final AuthController auth;

  static const animal = {
    'id': 'animal',
    'code': 'DE-001',
    'name': 'Mây',
    'speciesId': 'goat',
    'speciesName': 'Dê',
    'breedId': 'breed',
    'breedName': 'Boer',
    'gender': 'FEMALE',
    'arrivalDate': '2026-01-01',
    'penId': 'pen',
    'penName': 'Chuồng mẫu',
    'status': 'ACTIVE',
    'healthStatus': 'NORMAL',
  };
  static const catalogs = {
    'species': [
      {'id': 'goat', 'code': 'DE', 'name': 'Dê'},
    ],
    'breeds': [
      {'id': 'breed', 'code': 'BOER', 'name': 'Boer', 'speciesId': 'goat'},
    ],
    'areas': [
      {'id': 'area', 'code': 'KHU-A', 'name': 'Khu mẫu'},
    ],
    'pens': [
      {
        'id': 'pen',
        'code': 'A1',
        'name': 'Chuồng mẫu',
        'areaId': 'area',
        'active': true,
        'occupied': 1,
        'capacity': 10,
      },
    ],
  };

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    Object data = <String, dynamic>{};
    final path = request.url.path;
    if (path.endsWith('/species-settings')) {
      data = {
        'configured': configured,
        'speciesIds': ['goat'],
      };
    } else if (path.endsWith('/catalogs')) {
      data = catalogs;
    } else if (path.endsWith('/weather')) {
      data = {
        'temperature': 29,
        'location': 'Trang trại mẫu',
        'description': 'Mây nhẹ · dữ liệu minh họa',
        'humidity': 76,
        'windSpeed': 2,
        'condition': 801,
      };
    } else if (path.endsWith('/farm/location')) {
      if (request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        latitude = (body['latitude'] as num).toDouble();
        longitude = (body['longitude'] as num).toDouble();
      }
      data = {
        'location': {
          'name': 'Trang trại mẫu',
          'latitude': latitude,
          'longitude': longitude,
        },
      };
    } else if (path.endsWith('/feeds')) {
      data = {
        'feeds': [
          {
            'id': 'feed',
            'code': 'TA-01',
            'name': 'Thức ăn mẫu',
            'stock': 24,
            'lowStock': 10,
            'active': true,
          },
        ],
      };
    } else if (path.endsWith('/users')) {
      data = {'users': [], 'total': 0};
    } else if (path.endsWith('/animals')) {
      data = {
        'animals': [animal],
        'total': 1,
      };
    } else if (path.endsWith('/animals/animal')) {
      data = {
        'animal': animal,
        'weights': [],
        'transfers': [],
        'healthRecords': [],
        'careTasks': [],
      };
    } else if (path.endsWith('/farm/dashboard')) {
      data = {
        'today': '2026-10-24',
        'activeAnimals': 1,
        'activePens': 1,
        'needsCare': 0,
        'pens': catalogs['pens'],
        'tasks': [],
      };
    } else {
      data = {
        'animals': [],
        'tasks': [],
        'entries': [],
        'sales': [],
        'total': 0,
      };
    }
    return http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  void dispose() {
    auth.dispose();
    api.dispose();
  }
}
