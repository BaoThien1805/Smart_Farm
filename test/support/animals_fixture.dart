// Isolated UI data. All HTTP is handled locally; never imported by lib/.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

http.Response animalsResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class AnimalsFixture {
  AnimalsFixture() {
    api = ApiClient(client: MockClient(handle));
    repository = FarmRepository(api);
  }
  late final ApiClient api;
  late final FarmRepository repository;
  final requests = <http.Request>[];
  List<http.Request> get listRequests =>
      requests.where((r) => r.url.path.endsWith('/animals')).toList();
  bool failList = false;
  Future<http.Response> Function(http.Request)? listOverride;
  final writes = <http.Request>[];
  final bodies = <Map<String, dynamic>>[];
  String? writeError;
  Future<void>? pendingWrite;
  final pens = (catalogs['pens'] as List)
      .map((p) => Map<String, dynamic>.from(p as Map))
      .toList();
  final animals = [
    {
      ...base,
      'id': 'cow1',
      'code': 'BO-001',
      'name': 'Bông có tên dài để kiểm tra hiển thị tiếng Việt',
      'imageData': photo,
    },
    {
      ...base,
      'id': 'cow2',
      'code': 'BO-002',
      'name': 'Mây',
      'healthStatus': 'NEEDS_CARE',
    },
    {
      ...base,
      'id': 'goat',
      'code': 'DE-003',
      'name': 'Nắng',
      'speciesId': 'goat',
      'speciesName': 'Dê',
      'breedName': 'Boer',
      'imageData': '%%%',
      'penId': 'pen2',
      'penName': 'Chuồng B',
    },
    {
      ...base,
      'id': 'unknown',
      'code': 'VT-004',
      'name': 'Vật nuôi ngoài bộ sticker',
      'speciesId': 'duck',
      'speciesName': 'Vịt có tên loài dài',
      'breedName': 'Giống địa phương',
      'gender': 'UNKNOWN',
    },
    {
      ...base,
      'id': 'sold',
      'code': 'HEO-005',
      'name': 'Heo đã bán',
      'speciesId': 'pig',
      'speciesName': 'Heo',
      'breedName': 'Landrace',
      'status': 'SOLD',
      'healthStatus': 'NEEDS_CARE',
    },
    {
      ...base,
      'id': 'dead',
      'code': 'DE-006',
      'name': 'Dê đã chết',
      'speciesId': 'goat',
      'speciesName': 'Dê',
      'breedName': 'Boer',
      'status': 'DEAD',
    },
  ];

  Map<String, dynamic> listData(http.Request request) {
    final q = request.url.queryParameters;
    final query = (q['search'] ?? '').toLowerCase();
    final rows = animals.where((animal) {
      if (!'${animal['code']} ${animal['name']}'.toLowerCase().contains(
        query,
      )) {
        return false;
      }
      for (final key in ['status', 'speciesId', 'penId', 'healthStatus']) {
        if (q[key] != null && q[key] != animal[key]) return false;
      }
      return q['speciesIds'] == null ||
          q['speciesIds']!.split(',').contains(animal['speciesId']);
    }).toList()..sort((a, b) => '${a['code']}'.compareTo('${b['code']}'));
    final page = int.tryParse(q['page'] ?? '') ?? 1;
    return {
      'animals': rows.skip((page - 1) * 20).take(20).toList(),
      'total': rows.length,
      'page': page,
      'pageSize': 20,
    };
  }

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (request.method == 'POST' &&
        (path.contains('/animals/batch/') ||
            path.endsWith('/care-tasks/batch'))) {
      writes.add(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      bodies.add(body);
      await pendingWrite;
      if (writeError != null) {
        return animalsResponse({
          'error': {'message': writeError},
        }, 409);
      }
      if (path.endsWith('/transfer')) {
        final pen = pens.firstWhere((p) => p['id'] == body['penId']);
        for (final animal in animals.where(
          (a) => (body['animalIds'] as List).contains(a['id']),
        )) {
          animal['penId'] = body['penId'];
          animal['penName'] = pen['name'];
        }
      } else if (path.endsWith('/sell') || path.endsWith('/death')) {
        final ids = path.endsWith('/sell')
            ? (body['items'] as List)
                  .map((item) => (item as Map)['animalId'])
                  .toList()
            : body['animalIds'] as List;
        for (final animal in animals.where((a) => ids.contains(a['id']))) {
          animal['status'] = path.endsWith('/sell') ? 'SOLD' : 'DEAD';
          animal['endedDate'] = body['date'];
        }
      }
      for (final p in pens) {
        p['occupied'] = animals
            .where((a) => a['penId'] == p['id'] && a['status'] == 'ACTIVE')
            .length;
      }
      return animalsResponse({'ok': true});
    }
    if (path.endsWith('/animals')) {
      if (listOverride != null) return listOverride!(request);
      if (failList) {
        return animalsResponse({
          'error': {'message': 'Không tải được đàn vật nuôi. Thử lại sau.'},
        }, 503);
      }
      return animalsResponse(listData(request));
    }
    if (path.endsWith('/catalogs')) {
      return animalsResponse({...catalogs, 'pens': pens});
    }
    if (path.contains('/animals/') && !path.endsWith('/sales')) {
      return animalsResponse({
        'animal': animals.firstWhere(
          (a) => a['id'] == request.url.pathSegments.last,
        ),
        'weights': [],
        'transfers': [],
        'healthRecords': [],
        'careTasks': [],
      });
    }
    return animalsResponse({'sales': [], 'total': 0});
  }

  void dispose() => api.dispose();

  static const photo =
      'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAIAAABvFaqvAAAAOklEQVR4nGOUKE5gIASO1rcTVMPEQCXANGoQQTBq0FA0iPHup+cEFVk3Vg5BrzGNGkQQjBpEGFDNIAAlrAbQS/mP3AAAAABJRU5ErkJggg==';
  static const base = <String, dynamic>{
    'speciesId': 'cow',
    'speciesName': 'Bò',
    'breedId': 'hf',
    'breedName': 'Holstein Friesian có tên giống dài',
    'penId': 'pen1',
    'penName': 'Chuồng A có tên dài để kiểm tra bố cục',
    'gender': 'FEMALE',
    'status': 'ACTIVE',
    'healthStatus': 'NORMAL',
    'arrivalDate': '2026-01-01',
  };
  static const catalogs = {
    'species': [
      {'id': 'cow', 'code': 'BO', 'name': 'Bò'},
      {'id': 'goat', 'code': 'DE', 'name': 'Dê'},
      {'id': 'pig', 'code': 'HEO', 'name': 'Heo'},
      {'id': 'duck', 'code': 'VIT', 'name': 'Vịt có tên loài dài'},
    ],
    'breeds': [
      {
        'id': 'hf',
        'name': 'Holstein Friesian có tên giống dài',
        'speciesId': 'cow',
      },
    ],
    'pens': [
      {
        'id': 'pen1',
        'code': 'A1',
        'name': 'Chuồng A có tên dài để kiểm tra bố cục',
        'capacity': 40,
        'occupied': 3,
        'active': true,
      },
      {
        'id': 'pen2',
        'code': 'B1',
        'name': 'Chuồng B',
        'capacity': 10,
        'occupied': 1,
        'active': true,
      },
    ],
    'areas': [],
  };
}
