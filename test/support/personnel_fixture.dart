// All personnel writes stay inside this MockClient fixture.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'animals_fixture.dart';
import 'workspace_fixture.dart';

http.Response personnelResponse(Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class PersonnelFixture extends WorkspaceFixture {
  PersonnelFixture([super.role = 'ADMIN']);
  bool failList = false, failListAfterWrite = false;
  String? writeError;
  String errorCode = 'VALIDATION_ERROR';
  Future<void>? pending;
  final writes = <http.Request>[];
  final bodies = <Map<String, dynamic>>[];
  final revoked = <String>[];
  final history = <String, String>{
    'staff': 'Lịch sử chăm sóc của nhân sự được giữ',
  };
  final users = <Map<String, dynamic>>[
    {
      'id': 'owner',
      'code': 'OWNER-001',
      'name': 'Nguyễn An · chủ trang trại',
      'email': 'owner@example.test',
      'role': 'ADMIN',
      'active': true,
    },
    {
      'id': 'staff',
      'code': 'NV-001',
      'name': 'Nguyễn Văn Nam · nhân sự có họ tên dài',
      'email': 'nhanvien.diachi.email.dai@example.test',
      'role': 'STAFF',
      'active': true,
      'avatarData': AnimalsFixture.photo,
    },
    {
      'id': 'vet',
      'code': 'VT-002',
      'name': 'Bác sĩ Lê Minh',
      'email': 'vet@example.test',
      'role': 'VET',
      'active': true,
      'avatarData': '%%% invalid avatar',
    },
    {
      'id': 'accountant',
      'code': 'KT-003',
      'name': 'Trần Hà',
      'email': 'accountant@example.test',
      'role': 'ACCOUNTANT',
      'active': false,
    },
  ];
  List<http.Request> get lists => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/users'))
      .toList();
  List<http.Request> get suggestions =>
      requests.where((r) => r.url.path.endsWith('/code-suggestion')).toList();
  @override
  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (path.endsWith('/code-suggestion')) {
      requests.add(r);
      return personnelResponse({'code': 'NV-004'});
    }
    if (path.endsWith('/users') && r.method == 'GET') {
      requests.add(r);
      if (failList) {
        return personnelResponse({
          'error': {'message': 'Không tải được nhân sự.'},
        }, 503);
      }
      final rows = users.where((u) => u['deletedAt'] == null).toList();
      final page = int.parse(r.url.queryParameters['page'] ?? '1');
      return personnelResponse({
        'users': rows.skip((page - 1) * 20).take(20).toList(),
        'total': rows.length,
        'page': page,
      });
    }
    if ((path.endsWith('/users') || path.contains('/users/')) &&
        r.method != 'GET') {
      requests.add(r);
      writes.add(r);
      final body = r.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(r.body) as Map<String, dynamic>;
      bodies.add(body);
      await pending;
      if (writeError != null) {
        return personnelResponse({
          'error': {'code': errorCode, 'message': writeError},
        }, 409);
      }
      if (path.endsWith('/users')) {
        users.insert(0, {
          'id': 'created',
          'name': body['name'],
          'email': body['email'],
          'role': body['role'],
          'code': body['code'] ?? 'NV-004',
          'active': true,
        });
      } else {
        final parts = path.split('/');
        final id = parts[parts.indexOf('users') + 1];
        final user = users.firstWhere((u) => u['id'] == id);
        if (r.method == 'DELETE') {
          revoked.add(id);
          if (history.containsKey(id)) {
            user.addAll({
              'active': false,
              'deletedAt': '2026-10-24T10:00:00Z',
              'email': 'deleted@example.invalid',
              'avatarData': null,
            });
          } else {
            users.remove(user);
          }
        } else if (path.endsWith('/status')) {
          user['active'] = body['active'];
          if (body['active'] == false) revoked.add(id);
        } else {
          if (body['role'] != null && body['role'] != user['role']) {
            revoked.add(id);
          }
          user.addAll({...body}..remove('photoBase64'));
          if (body.containsKey('photoBase64')) {
            user['avatarData'] = body['photoBase64'];
          }
        }
      }
      if (failListAfterWrite) failList = true;
      return personnelResponse({'ok': true});
    }
    return super.handle(r);
  }
}
