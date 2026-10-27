// Isolated report/sale data. No request reaches a real backend.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'finance_ledger_fixture.dart';
import 'workspace_fixture.dart';

class ReportsSalesFixture extends FinanceLedgerFixture {
  ReportsSalesFixture([super.role]);
  bool failSales = false, failSaleReport = false, missingSaleMonth = false;
  bool failPens = false;
  bool inconsistentSaleReport = false;
  Future<void>? pendingReport;
  String animalStatus = 'ACTIVE';
  List<Map<String, dynamic>> pens = [
    ...(WorkspaceFixture.catalogs['pens'] as List<Map<String, dynamic>>),
    {
      'id': 'full',
      'code': 'FULL',
      'name': 'Chuồng đầy',
      'active': true,
      'occupied': 10,
      'capacity': 10,
    },
    {
      'id': 'inactive',
      'code': 'OFF',
      'name': 'Chuồng ngừng dùng',
      'active': false,
      'occupied': 0,
      'capacity': 10,
    },
  ];
  final sales = <Map<String, dynamic>>[
    {
      'id': 'sale',
      'animalId': 'old',
      'animalCode': 'BO-008',
      'date': '2026-10-22',
      'amount': '10000000',
      'buyer': 'Người mua minh họa có tên dài',
      'notes':
          'Giao dịch liên kết với khoản thu, nội dung dài vẫn cần đọc đầy đủ.',
      'actorName': 'Chủ trại',
      'cancelledAt': null,
    },
    {
      'id': 'cancelled-sale',
      'animalId': 'old-pig',
      'animalCode': 'HEO-010',
      'date': '2026-10-20',
      'amount': '2500000',
      'buyer': 'Người mua cũ',
      'notes': 'Ghi chú giao dịch cũ',
      'actorName': 'Chủ trại',
      'cancelledAt': '2026-10-24T08:00:00Z',
      'cancelReason': 'Nhập nhầm, vật nuôi đã nhận lại đúng quy trình.',
      'restoreDate': '2026-10-24',
      'restorePenName': 'Chuồng mẫu',
      'cancelledByName': 'Chủ trại',
    },
  ];
  List<http.Request> get salesRequests => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/sales'))
      .toList();
  @override
  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path, q = r.url.queryParameters;
    if (path.endsWith('/finance/report')) {
      requests.add(r);
      await pendingReport;
      if (failSummary || (failSaleReport && q['category'] == 'ANIMAL_SALE')) {
        return ledgerResponse({
          'error': {'message': 'Không tải được báo cáo.'},
        }, 503);
      }
      final filtered = entries
          .where((e) => matches(e, q) && e['cancelledAt'] == null)
          .toList();
      Map<String, String> totals(Iterable<Map<String, dynamic>> rows) {
        var income = BigInt.zero, expense = BigInt.zero, sold = BigInt.zero;
        for (final e in rows) {
          final a = BigInt.parse(e['amount'].toString());
          if (e['kind'] == 'IN') {
            income += a;
          } else {
            expense += a;
          }
          if (e['category'] == 'ANIMAL_SALE') sold += a;
        }
        return {
          'income': '$income',
          'expense': '$expense',
          'salesRevenue': '$sold',
          'difference': '${income - expense}',
        };
      }

      final start = DateTime.parse(q['from'] ?? '2026-10-01');
      final end = DateTime.parse(q['to'] ?? '2026-10-24');
      final monthly = <Map<String, String>>[];
      for (
        var m = DateTime(start.year, start.month);
        !m.isAfter(end);
        m = DateTime(m.year, m.month + 1)
      ) {
        final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
        final total = totals(
          filtered.where((e) => (e['date'] as String).startsWith(key)),
        );
        monthly.add({
          'month': key,
          'income': total['income']!,
          'expense': total['expense']!,
        });
      }
      if (missingSaleMonth && q['category'] == 'ANIMAL_SALE') monthly.clear();
      if (inconsistentSaleReport &&
          q['category'] == 'ANIMAL_SALE' &&
          monthly.isNotEmpty) {
        monthly.first['income'] =
            '${BigInt.parse(monthly.first['income']!) + BigInt.one}';
      }
      return ledgerResponse({
        'summary': totals(filtered),
        'monthly': monthly,
        'from': q['from'],
        'to': q['to'],
      });
    }
    if (path.endsWith('/catalogs')) {
      requests.add(r);
      if (failPens) {
        return ledgerResponse({
          'error': {'message': 'Không tải được chuồng.'},
        }, 503);
      }
      return ledgerResponse({...WorkspaceFixture.catalogs, 'pens': pens});
    }
    if (path.endsWith('/sales') && r.method == 'GET') {
      requests.add(r);
      if (failSales) {
        return ledgerResponse({
          'error': {'message': 'Không tải được giao dịch bán.'},
        }, 503);
      }
      final rows = sales
          .where(
            (s) =>
                (q['animalId'] == null || s['animalId'] == q['animalId']) &&
                (q['status'] == 'ALL' ||
                    (q['status'] == 'CANCELLED'
                        ? s['cancelledAt'] != null
                        : s['cancelledAt'] == null)),
          )
          .toList();
      final page = int.parse(q['page'] ?? '1');
      return ledgerResponse({
        'sales': rows.skip((page - 1) * 20).take(20).toList(),
        'total': rows.length,
      });
    }
    if ((path.endsWith('/sell') ||
            path.contains('/sales/') && path.endsWith('/cancel')) &&
        r.method == 'POST') {
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
      if (path.endsWith('/sell')) {
        animalStatus = 'SOLD';
        sales.insert(0, {
          'id': 'new-sale',
          'animalId': 'animal',
          'animalCode': 'DE-001',
          ...b,
          'amount': b['amount'].toString(),
          'actorName': 'Chủ trại',
          'cancelledAt': null,
        });
        entries.add({
          'id': 'new-receipt',
          ...b,
          'amount': b['amount'].toString(),
          'kind': 'IN',
          'category': 'ANIMAL_SALE',
          'content': 'Bán DE-001',
          'saleId': 'new-sale',
          'cancelledAt': null,
        });
      } else {
        final id = path.split('/')[path.split('/').length - 2];
        sales.firstWhere((s) => s['id'] == id).addAll({
          'cancelledAt': '2026-10-24T09:00:00Z',
          'cancelReason': b['reason'],
          'restoreDate': b['date'],
          'restorePenName': 'Chuồng mẫu',
          'cancelledByName': 'Chủ trại',
        });
        for (final entry in entries.where((e) => e['saleId'] == id)) {
          entry['cancelledAt'] = '2026-10-24T09:00:00Z';
        }
        animalStatus = 'ACTIVE';
      }
      return ledgerResponse({'ok': true});
    }
    if (path.endsWith('/animals/animal')) {
      requests.add(r);
      return ledgerResponse({
        'animal': {...WorkspaceFixture.animal, 'status': animalStatus},
        'weights': [],
        'transfers': [],
        'healthRecords': [],
        'careTasks': [],
      });
    }
    return super.handle(r);
  }
}
