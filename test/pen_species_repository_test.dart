import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/features/farm/farm_repository.dart';

http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> resident(String id, String pen, String species) => {
  'id': id,
  'penId': pen,
  'speciesName': species,
  'status': 'ACTIVE',
};

void main() {
  test('form catalog reads never trigger a resident scan', () async {
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return jsonResponse({
          'pens': [
            {'id': 'pen', 'occupied': 2},
          ],
        });
      }),
    );
    addTearDown(api.dispose);
    await FarmRepository(api).get('/farm/catalogs');
    expect(paths, ['/api/farm/catalogs']);
  });

  test(
    'legacy pens resolve actual residents across all animal pages',
    () async {
      final animalRequests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/catalogs')) {
            return jsonResponse({
              'pens': [
                {
                  'id': 'a',
                  'name': 'Tên chuồng không chỉ loài',
                  'occupied': 100,
                },
                {'id': 'b', 'code': 'BO-C1', 'occupied': 1},
                {'id': 'empty', 'occupied': 0},
                {
                  'id': 'server',
                  'occupied': 1,
                  'speciesNames': ['Thỏ'],
                },
              ],
            });
          }
          animalRequests.add(request);
          final second = request.url.queryParameters['page'] == '2';
          return jsonResponse({
            'animals': second
                ? [resident('fish', 'b', 'Cá')]
                : [for (var i = 0; i < 100; i++) resident('cow-$i', 'a', 'Bò')],
            'total': 101,
          });
        }),
      );
      addTearDown(api.dispose);
      final repository = FarmRepository(api)..selectedSpeciesIds = ['cow'];
      final data = await repository.get('/farm/catalogs', withPenSpecies: true);
      final pens = data['pens'] as List;
      expect(pens.map((p) => p['speciesNames']), [
        ['Bò'],
        ['Cá'],
        [],
        ['Thỏ'],
      ]);
      expect(animalRequests.map((r) => r.url.queryParameters['page']), [
        '1',
        '2',
      ]);
      for (final request in animalRequests) {
        expect(request.url.queryParameters['status'], 'ACTIVE');
        expect(request.url.queryParameters['speciesIds'], isNull);
      }
    },
  );

  test('server metadata and empty pens need no extra animal request', () async {
    for (final pen in [
      {
        'id': 'known',
        'occupied': 2,
        'speciesNames': ['Heo'],
      },
      {'id': 'mixed', 'occupied': 2, 'speciesNames': <String>[]},
      {'id': 'empty', 'occupied': 0},
    ]) {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          calls++;
          return jsonResponse({
            'pens': [pen],
          });
        }),
      );
      addTearDown(api.dispose);
      await FarmRepository(api).get('/farm/catalogs', withPenSpecies: true);
      expect(calls, 1);
    }
  });

  test(
    'failed pagination keeps the catalog and retries on next refresh',
    () async {
      var fail = true;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/catalogs')) {
            return jsonResponse({
              'pens': [
                {'id': 'pen', 'occupied': 2},
              ],
            });
          }
          if (request.url.queryParameters['page'] == '2' && fail) {
            return jsonResponse({
              'error': {'message': 'Unavailable'},
            }, 503);
          }
          return jsonResponse({
            'animals': [
              resident(request.url.queryParameters['page']!, 'pen', 'Heo'),
            ],
            'total': 2,
          });
        }),
      );
      addTearDown(api.dispose);
      final repository = FarmRepository(api);
      final first = await repository.get(
        '/farm/catalogs',
        withPenSpecies: true,
      );
      expect((first['pens'] as List).single['speciesNames'], isNull);
      fail = false;
      final next = await repository.get('/farm/catalogs', withPenSpecies: true);
      expect((next['pens'] as List).single['speciesNames'], ['Heo']);
    },
  );

  test('catalog and dashboard share one in-flight resident read', () async {
    final response = Completer<http.Response>();
    var reads = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/animals')) {
          reads++;
          return response.future;
        }
        final key = request.url.path.endsWith('/dashboard')
            ? 'fullPens'
            : 'pens';
        return jsonResponse({
          key: [
            {'id': 'pen', 'occupied': 1},
          ],
        });
      }),
    );
    addTearDown(api.dispose);
    final repository = FarmRepository(api);
    final catalog = repository.get('/farm/catalogs', withPenSpecies: true);
    final dashboard = repository.get('/farm/dashboard', withPenSpecies: true);
    await Future<void>.delayed(Duration.zero);
    response.complete(
      jsonResponse({
        'animals': [resident('a', 'pen', 'Dê')],
        'total': 1,
      }),
    );
    expect(((await catalog)['pens'] as List).single['speciesNames'], ['Dê']);
    expect(((await dashboard)['fullPens'] as List).single['speciesNames'], [
      'Dê',
    ]);
    expect(reads, 1);
  });

  test(
    'a later refresh reflects changed residents instead of cached art',
    () async {
      var species = 'Bò';
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/catalogs')) {
            return jsonResponse({
              'pens': [
                {'id': 'pen', 'occupied': 1},
              ],
            });
          }
          return jsonResponse({
            'animals': [resident('a', 'pen', species)],
            'total': 1,
          });
        }),
      );
      addTearDown(api.dispose);
      final repository = FarmRepository(api);
      expect(
        ((await repository.get('/farm/catalogs', withPenSpecies: true))['pens']
                as List)
            .single['speciesNames'],
        ['Bò'],
      );
      species = 'Heo';
      expect(
        ((await repository.get('/farm/catalogs', withPenSpecies: true))['pens']
                as List)
            .single['speciesNames'],
        ['Heo'],
      );
    },
  );
}
