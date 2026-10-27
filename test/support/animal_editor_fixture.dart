// Isolated editor data and HTTP. Never writes to a real service.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'animals_fixture.dart' show AnimalsFixture;

http.Response editorResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class AnimalEditorFixture {
  AnimalEditorFixture() {
    api = ApiClient(client: MockClient(handle));
    repository = FarmRepository(api);
  }
  late final ApiClient api;
  late final FarmRepository repository;
  final requests = <http.Request>[];
  final bodies = <Map<String, dynamic>>[];
  bool failCatalogs = false, failSave = false;
  int saveErrorStatus = 409;
  String? saveErrorMessage;
  Future<void>? pendingSave;
  final catalogs = <String, dynamic>{
    'species': [
      {'id': 'cow', 'name': 'Bò', 'code': 'BO'},
      {'id': 'goat', 'name': 'Dê', 'code': 'DE'},
    ],
    'breeds': <Map<String, dynamic>>[
      {'id': 'holstein', 'name': 'Holstein', 'speciesId': 'cow'},
      {'id': 'boer', 'name': 'Boer', 'speciesId': 'goat'},
    ],
    'areas': [
      {'id': 'a', 'name': 'Khu A'},
      {'id': 'b', 'name': 'Khu B có tên dài để kiểm tra xuống dòng'},
    ],
    'pens': [
      {
        'id': 'p1',
        'code': 'A1',
        'name': 'Chuồng A',
        'areaId': 'a',
        'active': true,
        'occupied': 2,
        'capacity': 10,
      },
      {
        'id': 'p2',
        'code': 'B1',
        'name': 'Chuồng B',
        'areaId': 'b',
        'active': true,
        'occupied': 0,
        'capacity': 5,
      },
      {
        'id': 'full',
        'code': 'FULL',
        'name': 'Đã đầy',
        'areaId': 'a',
        'active': true,
        'occupied': 5,
        'capacity': 5,
      },
      {
        'id': 'inactive',
        'code': 'CLOSED',
        'name': 'Ngừng dùng',
        'areaId': 'a',
        'active': false,
        'occupied': 0,
        'capacity': 5,
      },
    ],
  };
  final animal = <String, dynamic>{
    'id': 'animal1',
    'code': 'BO-001',
    'name': 'Bông có tên dài để kiểm tra tiếng Việt',
    'speciesId': 'cow',
    'speciesName': 'Bò',
    'breedId': 'holstein',
    'gender': 'UNKNOWN',
    'birthDate': '2025-10-01',
    'arrivalDate': '2026-01-01',
    'penId': 'p1',
    'penName': 'Chuồng A',
    'origin': 'Nguồn gốc có nội dung dài được giữ khi sửa hồ sơ.',
    'notes': 'Ghi chú nhiều dòng.\nGiữ nguyên nội dung đã nhập.',
    'imageData': AnimalsFixture.photo,
  };

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (request.url.path.endsWith('/code-suggestion')) {
      final name = request.url.queryParameters['name'];
      return editorResponse({
        'code': '${name == null || name.isEmpty ? 'VT' : name}_01',
      });
    }
    if (request.method == 'GET') {
      return failCatalogs
          ? editorResponse({
              'error': {'message': 'Không tải được danh mục. Hãy thử lại.'},
            }, 503)
          : editorResponse(catalogs);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.endsWith('/breeds')) {
      (catalogs['breeds'] as List).add({'id': 'new-breed', ...body});
      return editorResponse({
        'item': {'id': 'new-breed'},
      });
    }
    bodies.add(body);
    await pendingSave;
    if (failSave) {
      return editorResponse({
        'error': {
          'message': saveErrorMessage ?? 'Mã vật nuôi đã tồn tại. Hãy đổi mã rồi lưu lại; nội dung và ảnh vẫn được giữ.',
        },
      }, saveErrorStatus);
    }
    return editorResponse({'ok': true});
  }

  void dispose() => api.dispose();
}
