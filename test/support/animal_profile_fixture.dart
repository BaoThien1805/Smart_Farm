// Isolated profile fixtures: no real API, account, or database writes.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'animals_fixture.dart' show AnimalsFixture;

http.Response profileResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class AnimalProfileFixture {
  AnimalProfileFixture() {
    api = ApiClient(client: MockClient(handle));
    repository = FarmRepository(api);
  }
  late final ApiClient api;
  late final FarmRepository repository;
  final requests = <http.Request>[];
  final bodies = <Map<String, dynamic>>[];
  bool failDetail = false, failSales = false;
  String? deleteError = 'Hồ sơ đã có lịch sử, không thể xóa.';
  final animal = <String, dynamic>{
    ...AnimalsFixture.base,
    'id': 'profile',
    'code': 'BO-001',
    'name': 'Bông có tên dài để kiểm tra hồ sơ tiếng Việt',
    'imageData': AnimalsFixture.photo,
    'birthDate': '2025-11-01',
    'arrivalDate': '2026-01-01',
    'origin': 'Nguồn gốc có nội dung dài trong dữ liệu thực',
    'notes': 'Ghi chú nhiều dòng của cá thể.\nGiữ nguyên nội dung sau khi đổi tab và tải lại.',
  };
  final weights = <Map<String, dynamic>>[
    {
      'id': 'w1',
      'date': '2026-04-01',
      'kg': 20.5,
      'notes': 'Cân đầu kỳ',
      'actorName': 'Nhân viên An',
    },
    {
      'id': 'w2',
      'date': '2026-04-03',
      'kg': 22.0,
      'notes': 'Cân lại theo lịch',
      'actorName': 'Nhân viên Bình',
    },
  ];
  final transfers = <Map<String, dynamic>>[
    {
      'id': 't1',
      'date': '2026-04-02',
      'fromPenName': 'Chuồng cũ',
      'toPenName': 'Chuồng A',
      'notes': 'Chuyển theo sức chứa',
      'actorName': 'Nhân viên Bình',
    },
  ];
  final healthRecords = <Map<String, dynamic>>[
    {
      'id': 'h2',
      'date': '2026-04-05',
      'content': 'Khám da và thể trạng',
      'status': 'NEEDS_CARE',
      'recordType': 'EXAM',
      'diagnosis': 'Chẩn đoán có nội dung dài được ghi bởi bác sĩ thú y',
      'treatment': 'Theo dõi và tái khám theo hướng dẫn',
      'notes': 'Ghi chú của lần khám',
      'actorName': 'Bác sĩ Mai',
    },
    {
      'id': 'h1',
      'date': '2026-04-04',
      'content': 'Quan sát ăn uống',
      'status': 'NORMAL',
      'recordType': 'OBSERVATION',
      'notes': 'Ăn bình thường',
      'actorName': 'Nhân viên An',
    },
  ];
  final careTasks = <Map<String, dynamic>>[
    {
      'id': 'care3',
      'dueDate': '2026-04-08',
      'title': 'Kiểm tra sắp tới',
      'kind': 'CHECKUP',
      'status': 'PENDING',
      'notes': 'Ghi chú lịch',
      'actorName': 'Người lập lịch',
    },
    {
      'id': 'care2',
      'dueDate': '2026-04-07',
      'title': 'Lịch đã hủy',
      'kind': 'CHECKUP',
      'status': 'CANCELLED',
      'actorName': 'Người lập lịch',
    },
    {
      'id': 'care1',
      'dueDate': '2026-04-05',
      'actualDate': '2026-04-06',
      'title': 'Tiêm phòng định kỳ',
      'kind': 'VACCINATION',
      'status': 'DONE',
      'notes': 'Theo lịch tiêm',
      'actorName': 'Người lập lịch',
    },
  ];
  final sales = <Map<String, dynamic>>[
    {
      'id': 'sale1',
      'animalId': 'profile',
      'animalCode': 'BO-001',
      'date': '2026-04-07',
      'amount': '9007199254740993123',
      'buyer': 'Người mua từ dữ liệu thật',
      'actorName': 'Chủ trang trại',
      'notes': 'Giao dịch minh họa trong fixture',
      'cancelledAt': '2026-04-10T03:00:00Z',
      'cancelReason': 'Nhập nhầm',
      'restoreDate': '2026-04-09',
      'restorePenName': 'Chuồng A',
      'cancelledByName': 'Chủ trang trại',
    },
  ];
  int get detailLoads => requests
      .where(
        (r) => r.method == 'GET' && r.url.path.endsWith('/animals/profile'),
      )
      .length;
  List<http.Request> get salesRequests =>
      requests.where((r) => r.url.path.endsWith('/sales')).toList();
  Map<String, dynamic> get detail => {
    'animal': animal,
    'weights': weights,
    'transfers': transfers,
    'healthRecords': healthRecords,
    'careTasks': careTasks,
  };
  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/catalogs')) return profileResponse(catalogs);
    if (path.endsWith('/sales')) {
      if (failSales) {
        return profileResponse({
          'error': {'message': 'Không tải được giao dịch bán.'},
        }, 503);
      }
      final page = int.tryParse(request.url.queryParameters['page'] ?? '') ?? 1;
      return profileResponse({
        'sales': sales.skip((page - 1) * 20).take(20).toList(),
        'total': sales.length,
      });
    }
    if (request.method == 'GET') {
      return failDetail
          ? profileResponse({
              'error': {'message': 'Không tải được hồ sơ. Hãy thử lại.'},
            }, 503)
          : profileResponse(detail);
    }
    if (request.method == 'DELETE') {
      return deleteError == null
          ? profileResponse({})
          : profileResponse({
              'error': {'message': deleteError},
            }, 409);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    bodies.add(body);
    if (request.method == 'PATCH') {
      animal.addAll(body);
      if (body.containsKey('photoBase64')) {
        animal['imageData'] = body['photoBase64'] == null
            ? ''
            : 'data:image/png;base64,${body['photoBase64']}';
      }
    }
    return profileResponse({});
  }

  void clearHistory() {
    weights.clear();
    transfers.clear();
    healthRecords.clear();
    careTasks.clear();
    sales.clear();
  }

  void dispose() => api.dispose();
  static const catalogs = {
    'species': [
      {'id': 'cow', 'code': 'BO', 'name': 'Bò'},
    ],
    'breeds': [
      {
        'id': 'hf',
        'code': 'HF',
        'name': 'Holstein Friesian có tên giống dài',
        'speciesId': 'cow',
      },
    ],
    'areas': [
      {'id': 'area', 'code': 'A', 'name': 'Khu A'},
    ],
    'pens': [
      {
        'id': 'pen1',
        'code': 'A1',
        'name': 'Chuồng A có tên dài để kiểm tra bố cục',
        'areaId': 'area',
        'active': true,
        'capacity': 10,
        'occupied': 1,
      },
      {
        'id': 'pen2',
        'code': 'B1',
        'name': 'Chuồng B',
        'areaId': 'area',
        'active': true,
        'capacity': 10,
        'occupied': 0,
      },
      {
        'id': 'full',
        'code': 'F1',
        'name': 'Chuồng đầy',
        'active': true,
        'capacity': 1,
        'occupied': 1,
      },
      {
        'id': 'inactive',
        'code': 'N1',
        'name': 'Chuồng nghỉ',
        'active': false,
        'capacity': 10,
        'occupied': 0,
      },
    ],
  };
}
