// Local inventory fixtures. No production service or database writes.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'workspace_fixture.dart';

http.Response inventoryResponse(Object data, [int status = 200]) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class InventoryFixture extends WorkspaceFixture {
  InventoryFixture([super.role = 'ADMIN']);
  late final repository = FarmRepository(api);
  bool failFeeds = false, failEntries = false;
  String? writeError;
  Future<void>? pending;
  final writes = <http.Request>[];
  final bodies = <Map<String, dynamic>?>[];
  final feeds = <Map<String, dynamic>>[
    {
      'id': 'f1',
      'code': 'TA-01',
      'name': 'Thức ăn hỗn hợp có tên dài',
      'stock': 120.125,
      'lowStock': 50,
      'active': true,
      'notes': 'Ghi chú nhiều dòng của thức ăn.\nGiữ nguyên nội dung khi sửa.',
    },
    {
      'id': 'f2',
      'code': 'TA-02',
      'name': 'Thức ăn tồn bằng không',
      'stock': 0,
      'lowStock': 0,
      'active': true,
      'notes': '',
    },
    {
      'id': 'f3',
      'code': 'TA-03',
      'name': 'Cỏ khô',
      'stock': 12.345,
      'lowStock': 20,
      'active': true,
      'notes': '',
    },
    {
      'id': 'f4',
      'code': 'TA-04',
      'name': 'Thức ăn ngừng sử dụng',
      'stock': 0,
      'lowStock': 20,
      'active': false,
      'notes': '',
    },
  ];
  final entries = <Map<String, dynamic>>[
    {
      'id': 'e1',
      'feedId': 'f1',
      'feedCode': 'TA-01',
      'feedName': 'Thức ăn hỗn hợp có tên dài',
      'kind': 'IN',
      'quantity': 50.125,
      'date': '2026-10-24',
      'actorName': 'Chủ trang trại',
      'notes': 'Phiếu nhập theo kế hoạch',
      'cancelledAt': null,
    },
    {
      'id': 'e2',
      'feedId': 'f1',
      'feedCode': 'TA-01',
      'feedName': 'Thức ăn hỗn hợp có tên dài',
      'kind': 'OUT',
      'quantity': 0.001,
      'date': '2026-10-22',
      'actorName': 'Nhân viên An',
      'penName': 'Chuồng mẫu',
      'notes': 'Ghi chú phiếu xuất dài',
      'cancelledAt': '2026-10-23T10:00:00Z',
      'cancelReason': 'Nhập sai số lượng',
      'cancelledByName': 'Chủ trại',
    },
  ];
  final pens = <Map<String, dynamic>>[
    {
      'id': 'pen',
      'name': 'Chuồng mẫu',
      'active': true,
      'capacity': 10,
      'occupied': 2,
    },
    {
      'id': 'closed',
      'name': 'Chuồng ngừng dùng',
      'active': false,
      'capacity': 10,
      'occupied': 0,
    },
  ];
  int get feedLoads => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/feeds'))
      .length;
  List<http.Request> get entryRequests => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/stock-entries'))
      .toList();
  @override
  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (path.endsWith('/code-suggestion')) {
      requests.add(r);
      return inventoryResponse({'code': 'TA-005'});
    }
    if (path.endsWith('/catalogs')) {
      requests.add(r);
      return inventoryResponse({...WorkspaceFixture.catalogs, 'pens': pens});
    }
    if (path.endsWith('/feeds') && r.method == 'GET') {
      requests.add(r);
      return failFeeds
          ? inventoryResponse({
              'error': {'message': 'Không tải được tồn kho.'},
            }, 503)
          : inventoryResponse({'feeds': feeds});
    }
    if (path.endsWith('/stock-entries') && r.method == 'GET') {
      requests.add(r);
      if (failEntries) {
        return inventoryResponse({
          'error': {'message': 'Không tải được lịch sử kho.'},
        }, 503);
      }
      final q = r.url.queryParameters;
      final rows = entries
          .where(
            (e) =>
                (q['feedId'] == null || e['feedId'] == q['feedId']) &&
                (q['kind'] == null || e['kind'] == q['kind']) &&
                (q['status'] == null ||
                    (q['status'] == 'VALID'
                        ? e['cancelledAt'] == null
                        : e['cancelledAt'] != null)) &&
                (q['from'] == null ||
                    (e['date'] as String).compareTo(q['from']!) >= 0) &&
                (q['to'] == null ||
                    (e['date'] as String).compareTo(q['to']!) <= 0),
          )
          .toList();
      final page = int.parse(q['page'] ?? '1');
      if (q['from'] != null &&
          q['to'] != null &&
          q['from']!.compareTo(q['to']!) > 0) {
        return inventoryResponse({
          'error': {'message': 'Ngày bắt đầu phải trước ngày kết thúc.'},
        }, 400);
      }
      return inventoryResponse({
        'entries': rows.skip((page - 1) * 20).take(20).toList(),
        'total': rows.length,
      });
    }
    if (r.method != 'GET' &&
        (path.contains('/feeds') || path.contains('/stock-entries'))) {
      requests.add(r);
      writes.add(r);
      final b = r.body.isEmpty
          ? null
          : jsonDecode(r.body) as Map<String, dynamic>;
      bodies.add(b);
      await pending;
      if (writeError != null) {
        return inventoryResponse({
          'error': {'message': writeError},
        }, 409);
      }
      if (path.contains('/feeds')) {
        if (r.method == 'POST') {
          feeds.add({'id': 'new-feed', ...b!, 'stock': 0});
        } else {
          final feed = feeds.firstWhere((f) => f['id'] == path.split('/').last);
          if (r.method == 'DELETE') {
            if (entries.any((e) => e['feedId'] == feed['id'])) {
              return inventoryResponse({
                'error': {'message': 'Thức ăn đã có phiếu kho; không thể xóa.'},
              }, 409);
            }
            feeds.remove(feed);
          } else {
            if (b!['active'] == false && (feed['stock'] as num) > 0) {
              return inventoryResponse({
                'error': {
                  'message': 'Thức ăn còn tồn kho; chưa thể ngừng sử dụng.',
                },
              }, 409);
            }
            feed.addAll(b);
          }
        }
      } else if (path.endsWith('/cancel')) {
        final id = path.split('/')[path.split('/').length - 2];
        final entry = entries.firstWhere((e) => e['id'] == id);
        final feed = feeds.firstWhere((f) => f['id'] == entry['feedId']);
        final after =
            (feed['stock'] as num) +
            (entry['kind'] == 'IN' ? -1 : 1) * (entry['quantity'] as num);
        if (after < 0) {
          return inventoryResponse({
            'error': {
              'message': 'Không thể hủy phiếu nhập vì sẽ làm âm tồn kho.',
            },
          }, 409);
        }
        feed['stock'] = (after * 1000).round() / 1000;
        entry.addAll({
          'cancelledAt': '2026-10-24T08:00:00Z',
          'cancelReason': b!['reason'],
          'cancelledByName': 'Chủ trại',
        });
      } else {
        final feed = feeds.firstWhere((f) => f['id'] == b!['feedId']);
        final after =
            (feed['stock'] as num) +
            (b!['kind'] == 'IN' ? 1 : -1) * (b['quantity'] as num);
        if (after < 0) {
          return inventoryResponse({
            'error': {'message': 'Số lượng xuất vượt tồn kho hiện tại.'},
          }, 409);
        }
        feed['stock'] = (after * 1000).round() / 1000;
        entries.insert(0, {
          'id': 'created',
          ...b,
          'feedName': feed['name'],
          'actorName': 'Người ghi',
          'cancelledAt': null,
        });
      }
      return inventoryResponse({'ok': true});
    }
    return super.handle(r);
  }
}
