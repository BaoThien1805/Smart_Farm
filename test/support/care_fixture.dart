// Isolated care HTTP, shared with the preview and workspace refresh tests.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'animals_fixture.dart' show AnimalsFixture;
import 'workspace_fixture.dart';

http.Response careResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class CareFixture extends WorkspaceFixture {
  CareFixture([super.role = 'ADMIN']);
  late final repository = FarmRepository(api);
  bool failList = false, failAnimals = false;
  String? writeError;
  Future<void>? pending;
  final writes = <http.Request>[];
  final bodies = <Map<String, dynamic>?>[];
  String today = '2026-10-24';
  final animals = List.generate(
    105,
    (i) => <String, dynamic>{
      ...WorkspaceFixture.animal,
      'id': 'animal-$i',
      'code': 'DE-${i.toString().padLeft(3, '0')}',
      'name': 'Vật nuôi có tên dài để kiểm tra lựa chọn $i',
      if (i == 0) 'imageData': AnimalsFixture.photo,
    },
  );
  final tasks = <Map<String, dynamic>>[
    {
      'id': 'overdue',
      'animalId': 'animal-0',
      'animalCode': 'DE-000',
      'kind': 'CHECKUP',
      'title': 'Kiểm tra sức khỏe và vận động có nội dung dài',
      'dueDate': '2026-10-22',
      'status': 'PENDING',
      'actorName': 'Nhân viên tạo lịch',
      'notes': 'Ghi chú lịch nhiều dòng.\nTheo dõi ăn uống và vận động.',
    },
    {
      'id': 'today',
      'animalId': 'animal-1',
      'animalCode': 'DE-001',
      'kind': 'VACCINATION',
      'title': 'Tiêm phòng định kỳ',
      'dueDate': '2026-10-24',
      'status': 'PENDING',
      'actorName': 'Chủ trang trại',
      'notes': '',
    },
    {
      'id': 'done',
      'animalId': 'animal-0',
      'animalCode': 'DE-000',
      'kind': 'CHECKUP',
      'title': 'Công việc đã hoàn thành',
      'dueDate': '2026-10-24',
      'actualDate': '2026-10-23',
      'status': 'DONE',
      'actorName': 'Người tạo lịch ban đầu',
      'notes': '',
    },
    {
      'id': 'cancelled',
      'animalId': 'animal-1',
      'animalCode': 'DE-001',
      'kind': 'VACCINATION',
      'title': 'Lịch đã hủy',
      'dueDate': '2026-10-25',
      'status': 'CANCELLED',
      'actorName': 'Người tạo lịch',
      'notes': '',
    },
  ];
  final healthRecords = <Map<String, dynamic>>[];
  int get listLoads => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/care-tasks'))
      .length;
  int get dashboardLoads =>
      requests.where((r) => r.url.path.endsWith('/farm/dashboard')).length;

  @override
  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (path.endsWith('/care-tasks') && r.method == 'GET') {
      requests.add(r);
      if (failList) {
        return careResponse({
          'error': {'message': 'Không tải được lịch. Hãy thử lại.'},
        }, 503);
      }
      final rows =
          tasks
              .where(
                (t) =>
                    !r.url.queryParameters.containsKey('status') ||
                    t['status'] == r.url.queryParameters['status'],
              )
              .toList()
            ..sort(
              (a, b) =>
                  (a['dueDate'] as String).compareTo(b['dueDate'] as String),
            );
      final page = int.parse(r.url.queryParameters['page'] ?? '1');
      return careResponse({
        'tasks': rows.skip((page - 1) * 20).take(20).toList(),
        'total': rows.length,
        'today': today,
      });
    }
    if (path.endsWith('/animals')) {
      requests.add(r);
      if (failAnimals) {
        return careResponse({
          'error': {'message': 'Không tải được vật nuôi.'},
        }, 503);
      }
      final page = int.parse(r.url.queryParameters['page'] ?? '1');
      final size = int.parse(r.url.queryParameters['pageSize'] ?? '20');
      return careResponse({
        'animals': animals.skip((page - 1) * size).take(size).toList(),
        'total': animals.length,
      });
    }
    if (path.contains('/animals/')) {
      requests.add(r);
      final animal = animals.firstWhere((a) => a['id'] == path.split('/').last);
      return careResponse({
        'animal': animal,
        'healthRecords': healthRecords,
        'careTasks': tasks.where((t) => t['animalId'] == animal['id']).toList(),
        'weights': [],
        'transfers': [],
      });
    }
    if (path.endsWith('/farm/dashboard')) {
      requests.add(r);
      final active = tasks.where((t) => t['status'] == 'PENDING').toList();
      return careResponse({
        'today': today,
        'due': active.where((t) => t['dueDate'] == today).length,
        'overdue': active
            .where((t) => (t['dueDate'] as String).compareTo(today) < 0)
            .length,
        'activeAnimals': animals.length,
        'activePens': 1,
        'needsCare': 0,
        'tasks': active,
      });
    }
    if (path.contains('/care-tasks') && r.method != 'GET') {
      requests.add(r);
      writes.add(r);
      final body = r.body.isEmpty
          ? null
          : jsonDecode(r.body) as Map<String, dynamic>;
      bodies.add(body);
      await pending;
      if (writeError != null) {
        return careResponse({
          'error': {'message': writeError},
        }, 409);
      }
      if (path.endsWith('/care-tasks/batch')) {
        for (final id in body!['animalIds'] as List) {
          final animal = animals.firstWhere((a) => a['id'] == id);
          tasks.add({
            'id': 'batch-${writes.length}-$id',
            ...body,
            'animalId': id,
            'status': 'PENDING',
            'animalCode': animal['code'],
            'actorName': 'Người tạo mới',
          });
        }
      } else if (path.endsWith('/care-tasks')) {
        final animal = animals.firstWhere((a) => a['id'] == body!['animalId']);
        tasks.add({
          'id': 'created',
          ...body!,
          'status': 'PENDING',
          'animalCode': animal['code'],
          'actorName': 'Người tạo mới',
        });
      } else {
        final segments = path.split('/');
        final id = segments[segments.indexOf('care-tasks') + 1];
        final task = tasks.firstWhere((t) => t['id'] == id);
        if (path.endsWith('/complete')) {
          task['status'] = 'DONE';
          task['actualDate'] = body!['date'];
          healthRecords.add({
            'id': 'result',
            ...body,
            'content': task['title'],
            'actorName': 'Bác sĩ thực hiện',
            'recordType': 'OBSERVATION',
          });
          animals.firstWhere(
            (a) => a['id'] == task['animalId'],
          )['healthStatus'] = body['status'];
        } else if (path.endsWith('/cancel')) {
          task['status'] = 'CANCELLED';
        } else {
          task.addAll(body!);
        }
      }
      return careResponse({'ok': true});
    }
    return super.handle(r);
  }
}
