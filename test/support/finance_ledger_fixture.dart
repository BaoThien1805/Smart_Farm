// Local ledger, summary and audit data. All HTTP writes stay in memory.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_farm/features/farm/farm_repository.dart';

import 'workspace_fixture.dart';

http.Response ledgerResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class FinanceLedgerFixture extends WorkspaceFixture {
  FinanceLedgerFixture([super.role = 'ADMIN']);
  late final repository = FarmRepository(api);
  bool failList = false, failSummary = false, failHistory = false;
  String? writeError;
  Future<void>? pending;
  Map<String, dynamic>? summaryOverride;
  List<Map<String, dynamic>>? historyOverride;
  final writes = <http.Request>[];
  final bodies = <Map<String, dynamic>>[];
  final entries = <Map<String, dynamic>>[
    {
      'id': 'manual',
      'date': '2026-10-24',
      'kind': 'IN',
      'category': 'OTHER',
      'amount': '5000',
      'content': 'Khoản thu có nội dung dài để kiểm tra sổ tiếng Việt',
      'actorName': 'Người ghi khoản',
      'saleId': null,
      'cancelledAt': null,
      'createdAt': '2026-10-24T06:00:00Z',
    },
    {
      'id': 'expense',
      'date': '2026-10-23',
      'kind': 'OUT',
      'category': 'FEED',
      'amount': '1000',
      'content': 'Mua thức ăn theo kế hoạch',
      'actorName': 'Kế toán An',
      'saleId': null,
      'cancelledAt': null,
    },
    {
      'id': 'linked',
      'date': '2026-10-22',
      'kind': 'IN',
      'category': 'ANIMAL_SALE',
      'amount': '10000000',
      'content': 'Khoản thu liên kết bán vật nuôi',
      'actorName': 'Chủ trại',
      'saleId': 'sale',
      'cancelledAt': null,
    },
    {
      'id': 'cancelled',
      'date': '2026-10-21',
      'kind': 'OUT',
      'category': 'MEDICINE',
      'amount': '2000',
      'content': 'Khoản đã hủy vẫn được giữ',
      'actorName': 'Người ghi ban đầu',
      'saleId': null,
      'cancelledAt': '2026-10-24T08:00:00Z',
      'cancelReason': 'Nhập nhầm khoản chi',
      'cancelledByName': 'Chủ trại',
    },
  ];
  final newAudit = <String, List<Map<String, dynamic>>>{};
  List<http.Request> get lists => requests
      .where(
        (r) => r.method == 'GET' && r.url.path.endsWith('/finance/entries'),
      )
      .toList();
  List<http.Request> get reports =>
      requests.where((r) => r.url.path.endsWith('/finance/report')).toList();
  Map<String, dynamic> snapshot(Map<String, dynamic> e) => {
    'date': e['date'],
    'kind': e['kind'],
    'category': e['category'],
    'amount': e['amount'].toString(),
    'content': e['content'],
    'sale_id': e['saleId'],
    'cancelled_at': e['cancelledAt'],
    'cancel_reason': e['cancelReason'],
    'updated_at': e['updatedAt'] ?? '2026-10-24T08:00:00Z',
  };
  bool matches(Map<String, dynamic> e, Map<String, String> q) =>
      (q['from'] == null || (e['date'] as String).compareTo(q['from']!) >= 0) &&
      (q['to'] == null || (e['date'] as String).compareTo(q['to']!) <= 0) &&
      (q['kind'] == null || e['kind'] == q['kind']) &&
      (q['category'] == null || e['category'] == q['category']);
  @override
  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path, q = r.url.queryParameters;
    if (path.endsWith('/finance/entries') && r.method == 'GET') {
      requests.add(r);
      if (failList) {
        return ledgerResponse({
          'error': {'message': 'Không tải được sổ thu chi.'},
        }, 503);
      }
      final rows = entries
          .where(
            (e) =>
                matches(e, q) &&
                (q['status'] == 'ALL' ||
                    (q['status'] == 'CANCELLED'
                        ? e['cancelledAt'] != null
                        : e['cancelledAt'] == null)),
          )
          .toList();
      final page = int.parse(q['page'] ?? '1');
      return ledgerResponse({
        'entries': rows.skip((page - 1) * 20).take(20).toList(),
        'total': rows.length,
      });
    }
    if (path.endsWith('/finance/report')) {
      requests.add(r);
      if (failSummary) {
        return ledgerResponse({
          'error': {'message': 'Không tải được tổng thu chi.'},
        }, 503);
      }
      var income = BigInt.zero, expense = BigInt.zero, sales = BigInt.zero;
      for (final e in entries.where(
        (e) => matches(e, q) && e['cancelledAt'] == null,
      )) {
        final amount = BigInt.parse(e['amount'].toString());
        if (e['kind'] == 'IN') {
          income += amount;
        } else {
          expense += amount;
        }
        if (e['category'] == 'ANIMAL_SALE') sales += amount;
      }
      return ledgerResponse({
        'summary':
            summaryOverride ??
            {
              'income': '$income',
              'expense': '$expense',
              'difference': '${income - expense}',
              'salesRevenue': '$sales',
            },
        'monthly': [
          {'month': '2026-10', 'income': '$income', 'expense': '$expense'},
        ],
      });
    }
    if (path.endsWith('/history') && path.contains('/finance/entries/')) {
      requests.add(r);
      if (failHistory) {
        return ledgerResponse({
          'error': {'message': 'Không tải được lịch sử thu chi.'},
        }, 503);
      }
      final id = path.split('/')[path.split('/').length - 2];
      final current = entries.firstWhere((e) => e['id'] == id);
      final initial = {
        ...current,
        'amount': '4000',
        'date': '2026-10-21',
        'cancelledAt': null,
        'cancelReason': null,
        'updatedAt': '2026-10-21T01:00:00Z',
        'content': 'Nội dung trước khi sửa',
      };
      final edited = {
        ...current,
        'date': '2026-10-21',
        'cancelledAt': null,
        'cancelReason': null,
        'updatedAt': '2026-10-22T02:00:00Z',
      };
      return ledgerResponse({
        'history':
            historyOverride ??
            [
              {
                'id': 'h1',
                'action': 'CREATE',
                'actorName': 'Người tạo khoản',
                'createdAt': '2026-10-21T01:00:00Z',
                'reason': 'Ghi thu chi',
                'before': null,
                'after': snapshot(initial),
              },
              {
                'id': 'h2',
                'action': 'EDIT',
                'actorName': 'Kế toán sửa',
                'createdAt': '2026-10-22T02:00:00Z',
                'reason': 'Điều chỉnh theo chứng từ',
                'before': snapshot(initial),
                'after': snapshot(edited),
              },
              if (current['cancelledAt'] != null && newAudit[id] == null)
                {
                  'id': 'h3',
                  'action': 'CANCEL',
                  'actorName': 'Người xác nhận hủy',
                  'createdAt': current['cancelledAt'],
                  'reason': current['cancelReason'],
                  'before': snapshot(edited),
                  'after': snapshot(current),
                },
              ...?newAudit[id],
            ],
      });
    }
    if (path.contains('/finance/entries') && r.method != 'GET') {
      requests.add(r);
      writes.add(r);
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      bodies.add(b);
      await pending;
      if (writeError != null) {
        return ledgerResponse({
          'error': {'message': writeError},
        }, 409);
      }
      if (path.endsWith('/finance/entries')) {
        entries.insert(0, {
          'id': 'created',
          ...b,
          'amount': b['amount'].toString(),
          'actorName': 'Người ghi mới',
          'saleId': null,
          'cancelledAt': null,
        });
      } else {
        final id = path.endsWith('/cancel')
            ? path.split('/')[path.split('/').length - 2]
            : path.split('/').last;
        final entry = entries.firstWhere((e) => e['id'] == id);
        if (entry['saleId'] != null) {
          return ledgerResponse({
            'error': {
              'message':
                  'Khoản thu bán vật nuôi chỉ thay đổi qua thao tác hủy bán.',
            },
          }, 409);
        }
        if (entry['cancelledAt'] != null) {
          return ledgerResponse({
            'error': {'message': 'Khoản thu chi đã hủy.'},
          }, 409);
        }
        final before = snapshot(entry);
        if (path.endsWith('/cancel')) {
          entry.addAll({
            'cancelledAt': '2026-10-24T09:00:00Z',
            'cancelReason': b['reason'],
            'cancelledByName': 'Người xác nhận',
          });
        } else {
          entry.addAll({...b, 'amount': b['amount'].toString()});
        }
        newAudit.putIfAbsent(id, () => []).add({
          'id': 'new-audit',
          'action': path.endsWith('/cancel') ? 'CANCEL' : 'EDIT',
          'actorName': 'Người thực hiện mới',
          'createdAt': '2026-10-24T09:00:00Z',
          'reason': b['reason'],
          'before': before,
          'after': snapshot(entry),
        });
      }
      return ledgerResponse({'ok': true});
    }
    return super.handle(r);
  }
}
