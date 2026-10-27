// Local UI fixtures only. No network requests or production writes.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

http.Response catalogResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class CatalogFixture {
  CatalogFixture() {
    data = (jsonDecode(jsonEncode(seed)) as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        (value as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      ),
    );
    api = ApiClient(client: MockClient(handle));
    repository = FarmRepository(api);
  }
  late final Map<String, List<Map<String, dynamic>>> data;
  late final ApiClient api;
  late final FarmRepository repository;
  final requests = <http.Request>[];
  bool loadError = false;
  String? saveError, deleteError;
  Completer<http.Response>? pendingSave;
  final bodies = <Map<String, dynamic>>[];

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/catalogs')) {
      return loadError
          ? catalogResponse({
              'error': {'message': 'Không tải được danh mục. Thử lại sau.'},
            }, 503)
          : catalogResponse(data);
    }
    if (path.endsWith('/code-suggestion')) {
      return catalogResponse({
        'code': '${request.url.queryParameters['kind']}-NEW',
      });
    }
    if (path.endsWith('/animals')) {
      return catalogResponse({'animals': [], 'total': 0});
    }
    final segments = request.url.pathSegments;
    final kind = segments.firstWhere(
      (s) => data.containsKey(s),
      orElse: () => '',
    );
    if (kind.isEmpty) return catalogResponse({});
    if (request.method == 'DELETE') {
      if (deleteError != null) {
        return catalogResponse({
          'error': {'message': deleteError},
        }, 409);
      }
      data[kind]!.removeWhere((item) => item['id'] == segments.last);
    } else {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      bodies.add(body);
      final stored = {...body};
      if (kind == 'pens' && body.containsKey('iconKey')) {
        if (body['iconKey'] != 'custom') stored['iconData'] = null;
        if (body['iconBase64'] is String) {
          stored['iconData'] = 'data:image/png;base64,${body['iconBase64']}';
        }
        stored.remove('iconBase64');
      }
      if (pendingSave != null) return pendingSave!.future;
      if (saveError != null) {
        return catalogResponse({
          'error': {'message': saveError},
        }, 409);
      }
      if (request.method == 'POST') {
        data[kind]!.add({
          'id': 'new-${data[kind]!.length}',
          if (kind == 'pens') 'occupied': 0,
          ...stored,
        });
      } else {
        data[kind]!
            .firstWhere((item) => item['id'] == segments.last)
            .addAll(stored);
      }
    }
    return catalogResponse({'ok': true});
  }

  void dispose() => api.dispose();
  static const seed = {
    'species': [
      {'id': 'cow', 'code': 'BO', 'name': 'Bò'},
      {'id': 'pig', 'code': 'HEO', 'name': 'Heo'},
      {
        'id': 'buffalo',
        'code': 'TRAU',
        'name': 'Trâu có tên dài để kiểm tra loài ngoài bộ sticker',
      },
    ],
    'breeds': [
      {
        'id': 'hf',
        'code': 'HF',
        'name': 'Holstein Friesian có tên giống dài để kiểm tra',
        'speciesId': 'cow',
      },
      {'id': 'landrace', 'code': 'LR', 'name': 'Landrace', 'speciesId': 'pig'},
    ],
    'areas': [
      {
        'id': 'area-a',
        'code': 'KHU-A',
        'name': 'Khu vực A có tên dài để kiểm tra bố cục tiếng Việt',
      },
      {'id': 'area-b', 'code': 'KHU-B', 'name': 'Khu B'},
    ],
    'pens': [
      {
        'id': 'mixed',
        'speciesNames': <String>[],
        'code': 'A1',
        'name': 'Chuồng hỗn hợp có tên dài để kiểm tra giao diện',
        'areaId': 'area-a',
        'capacity': 10,
        'occupied': 8,
        'active': true,
      },
      {
        'id': 'full',
        'speciesNames': <String>[],
        'code': 'B1',
        'name': 'Chuồng khu B',
        'areaId': 'area-b',
        'capacity': 10,
        'occupied': 10,
        'active': true,
      },
      {
        'id': 'inactive',
        'speciesNames': <String>[],
        'code': 'N1',
        'name': 'Chuồng nghỉ',
        'areaId': 'area-a',
        'capacity': 6,
        'occupied': 0,
        'active': false,
      },
      {
        'id': 'unknown',
        'speciesNames': <String>[],
        'code': 'X1',
        'name': 'Chuồng thiếu thông tin sức chứa',
      },
    ],
  };
}
