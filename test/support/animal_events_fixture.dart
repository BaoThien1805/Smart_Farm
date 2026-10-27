// Isolated event writes, layered on the profile fixture. No real API or DB.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'animal_profile_fixture.dart';

class AnimalEventsFixture extends AnimalProfileFixture {
  String? eventError;
  Future<void>? pending;
  final pens = (AnimalProfileFixture.catalogs['pens'] as List)
      .map((p) => Map<String, dynamic>.from(p as Map))
      .toList();

  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path.endsWith('/catalogs')) {
      requests.add(request);
      return profileResponse({...AnimalProfileFixture.catalogs, 'pens': pens});
    }
    final kind = request.url.path.split('/').last;
    if (request.method != 'POST' ||
        !['weights', 'transfer', 'health', 'exams', 'death'].contains(kind)) {
      return super.handle(request);
    }
    requests.add(request);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    bodies.add(body);
    await pending;
    if (eventError != null) {
      return profileResponse({
        'error': {'message': eventError},
      }, 409);
    }
    switch (kind) {
      case 'weights':
        weights.add({'id': 'new-weight', ...body, 'actorName': 'Người ghi'});
      case 'transfer':
        final target = pens.firstWhere((p) => p['id'] == body['penId']);
        animal['penId'] = target['id'];
        animal['penName'] = target['name'];
      case 'health':
      case 'exams':
        animal['healthStatus'] = body['status'];
        healthRecords.add({
          'id': 'new-health',
          ...body,
          'recordType': kind == 'exams' ? 'EXAM' : 'OBSERVATION',
          'actorName': 'Người ghi',
        });
      case 'death':
        animal['status'] = 'DEAD';
        animal['endedDate'] = body['date'];
        for (final task in careTasks) {
          if (task['status'] == 'PENDING') task['status'] = 'CANCELLED';
        }
    }
    return profileResponse({'ok': true});
  }
}
