import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'farm_repository.dart';
import 'farm_refresh.dart';
import 'farm_widgets.dart';

export 'finance_values.dart';
import 'finance_values.dart';
import '../../core/ui_components.dart';
import 'finance_ledger_forms.dart';
import 'finance_ledger_widgets.dart';
import 'revenue_chart.dart';
import 'sales_history.dart';

export 'revenue_chart.dart' show FinanceTotals, MonthlyFinanceChart;
export 'sales_forms.dart' show sellAnimalForm, cancelSaleForm;
export 'sales_history.dart' show SalesHistory;

class FinancePage extends StatefulWidget {
  final FarmRepository repository;
  final int refreshRevision;
  final bool admin, canFinance;
  const FinancePage({
    super.key,
    required this.repository,
    this.refreshRevision = 0,
    this.admin = true,
    this.canFinance = true,
  });
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final refresh = FarmRefresh();
  late final controller = FarmController(widget.repository);
  late final sectionController = FarmController(widget.repository);
  int salesRevision = 0;
  int tab = 0, page = 1, loadRevision = 0;
  bool busy = false, summaryLoading = false;
  Map<String, dynamic>? ledgerSummary;
  String? summaryError;
  bool reportLoading = false;
  String? reportError;
  Map<String, dynamic>? reportData;
  String from = '${farmToday().substring(0, 7)}-01',
      to = farmToday(),
      kind = '',
      category = '',
      status = 'VALID';
  bool get canWrite =>
      widget.canFinance &&
      !busy &&
      !controller.loading &&
      controller.error == null;
  Map<String, String> get range => {
    'from': from,
    'to': to,
    if (kind.isNotEmpty) 'kind': kind,
    if (category.isNotEmpty) 'category': category,
  };
  String get entryPath =>
      '/finance/entries?${Uri(queryParameters: {...range, 'status': status, 'page': '$page'}).query}';
  Future<void> summary(String path, int revision) async {
    try {
      final response = await widget.repository.get(path);
      if (response['summary'] is! Map) {
        throw const ApiException(
          'Chưa có số tổng thu chi từ máy chủ. Hãy thử tải lại.',
        );
      }
      if (mounted && loadRevision == revision && tab == 0) {
        setState(
          () => ledgerSummary = Map<String, dynamic>.from(
            response['summary'] as Map,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted && loadRevision == revision && tab == 0) {
        setState(() => summaryError = e.message);
      }
    } finally {
      if (mounted && loadRevision == revision && tab == 0) {
        setState(() => summaryLoading = false);
      }
    }
  }

  Future<void> load() => refresh.run(loadData, supersede: true);

  Future<void> loadData() async {
    if (!widget.canFinance) return;
    final revision = ++loadRevision;
    if (tab == 2) {
      setState(() => salesRevision++);
      return;
    }
    final reportPath = '/finance/report?${Uri(queryParameters: range).query}';
    if (tab == 1) {
      await loadReport(revision);
      return;
    }
    setState(() {
      summaryLoading = true;
      ledgerSummary = null;
      summaryError = null;
    });
    await Future.wait([
      controller.load(entryPath),
      summary(reportPath, revision),
    ]);
    if (mounted &&
        revision == loadRevision &&
        tab == 0 &&
        controller.error == null &&
        controller.items('entries').isEmpty &&
        page > 1) {
      final total = (controller.data['total'] as num?)?.toInt() ?? 0;
      page = ((total - 1) ~/ 20 + 1).clamp(1, page - 1);
      await controller.load(entryPath);
    }
  }

  Future<void> loadReport(int revision) async {
    final query = Map<String, String>.from(range);
    final needsSales = !query.containsKey('category');
    setState(() {
      reportLoading = true;
      reportError = null;
      reportData = null;
    });
    try {
      final reports = await Future.wait([
        widget.repository.get(
          '/finance/report?${Uri(queryParameters: query).query}',
        ),
        if (needsSales)
          widget.repository.get(
            '/finance/report?${Uri(queryParameters: {...query, 'category': 'ANIMAL_SALE'}).query}',
          ),
      ]);
      final data = reports.first;
      if (data['summary'] is! Map || data['monthly'] is! List) {
        throw const ApiException(
          'Báo cáo chưa có đủ số liệu. Hãy thử tải lại.',
        );
      }
      final sales = needsSales
          ? FarmRepository.records(reports.last, 'monthly')
          : <FarmRecord>[];
      final salesByMonth = {for (final m in sales) m.text('month'): m};
      final months = <Map<String, dynamic>>[];
      for (final m in FarmRepository.records(data, 'monthly')) {
        final income = BigInt.tryParse(m.text('income'));
        final expense = BigInt.tryParse(m.text('expense'));
        final sold = query['category'] == 'ANIMAL_SALE'
            ? income
            : query.containsKey('category')
            ? BigInt.zero
            : BigInt.tryParse(
                salesByMonth[m.text('month')]?.text('income') ?? '',
              );
        if (income == null || expense == null || sold == null) {
          throw const ApiException(
            'Báo cáo tháng thiếu số liệu thu, chi hoặc doanh thu bán. Hãy thử tải lại.',
          );
        }
        months.add({
          ...m.values,
          'salesRevenue': '$sold',
          'difference': '${income - expense}',
        });
      }
      final summary = Map<String, dynamic>.from(data['summary'] as Map);
      final totalSales = months.fold<BigInt>(
        BigInt.zero,
        (sum, m) => sum + BigInt.parse(m['salesRevenue'] as String),
      );
      if (months.isEmpty ||
          [
            'salesRevenue',
            'income',
            'expense',
            'difference',
          ].any((key) => BigInt.tryParse('${summary[key]}') == null)) {
        throw const ApiException(
          'Báo cáo chưa có đủ số liệu. Hãy thử tải lại.',
        );
      }
      if (totalSales != BigInt.parse('${summary['salesRevenue']}')) {
        throw const ApiException(
          'Số liệu doanh thu bán thay đổi trong khi tải. Hãy tải lại báo cáo để lấy cùng số tổng.',
        );
      }
      if (mounted && revision == loadRevision && tab == 1) {
        setState(() => reportData = {...data, 'monthly': months});
      }
    } on ApiException catch (e) {
      if (mounted && revision == loadRevision && tab == 1) {
        setState(() => reportError = e.message);
      }
    } finally {
      if (mounted && revision == loadRevision && tab == 1) {
        setState(() => reportLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant FinancePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) {
      refresh.run(loadData);
    }
  }

  @override
  void dispose() {
    refresh.dispose();
    loadRevision++;
    controller.dispose();
    sectionController.dispose();
    super.dispose();
  }

  Future<void> filters() async {
    if (busy || controller.loading || reportLoading || !widget.canFinance) {
      return;
    }
    setState(() => busy = true);
    try {
      final saved = await farmForm(
        context,
        title: 'Lọc sổ và báo cáo',
        fields: [
          FarmField('from', 'Từ ngày', initial: from, date: true),
          FarmField('to', 'Đến ngày', initial: to, date: true),
          FarmField(
            'kind',
            'Thu / chi',
            initial: kind.isEmpty ? 'ALL' : kind,
            options: const {'ALL': 'Tất cả', 'IN': 'Thu', 'OUT': 'Chi'},
          ),
          FarmField(
            'category',
            'Nhóm',
            initial: category.isEmpty ? 'ALL' : category,
            options: const {
              'ALL': 'Tất cả',
              'ANIMAL_SALE': 'Bán vật nuôi',
              ...financeCategories,
            },
          ),
          FarmField(
            'status',
            'Trạng thái sổ',
            initial: status,
            options: const {
              'VALID': 'Hợp lệ',
              'CANCELLED': 'Đã hủy',
              'ALL': 'Tất cả',
            },
          ),
        ],
        save: (b) async {
          final first = b['from'] as String, last = b['to'] as String;
          if (first.compareTo(last) > 0 ||
              DateTime.parse(last).difference(DateTime.parse(first)).inDays >
                  730) {
            throw const ApiException(
              'Khoảng ngày phải đúng thứ tự và tối đa 730 ngày.',
            );
          }
          setState(() {
            from = first;
            to = last;
            kind = b['kind'] == 'ALL' ? '' : b['kind'] as String;
            category = b['category'] == 'ALL' ? '' : b['category'] as String;
            status = b['status'] as String;
            page = 1;
          });
        },
      );
      if (saved && mounted) await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(String type, [FarmRecord? entry]) async {
    if (!canWrite ||
        (entry != null &&
            (entry.text('saleId').isNotEmpty ||
                entry.text('category') == 'ANIMAL_SALE' ||
                entry.text('cancelledAt').isNotEmpty))) {
      return;
    }
    setState(() => busy = true);
    try {
      if (await financeLedgerForm(
            context,
            widget.repository,
            kind: type,
            entry: entry,
          ) &&
          mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel(FarmRecord entry) async {
    if (!canWrite ||
        entry.text('saleId').isNotEmpty ||
        entry.text('category') == 'ANIMAL_SALE' ||
        entry.text('cancelledAt').isNotEmpty) {
      return;
    }
    setState(() => busy = true);
    try {
      if (await financeLedgerForm(
            context,
            widget.repository,
            entry: entry,
            cancelling: true,
          ) &&
          mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> history(FarmRecord entry) async {
    if (busy || !widget.canFinance) return;
    setState(() => busy = true);
    try {
      await showFinanceAudit(context, widget.repository, entry);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget ledgerEntry(FarmRecord e) {
    final cancelled = e.text('cancelledAt').isNotEmpty;
    final linked =
        e.text('saleId').isNotEmpty || e.text('category') == 'ANIMAL_SALE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FarmInfoCard(
        key: ValueKey('ledger-entry-${e.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: e.text('kind') == 'IN'
                        ? FarmColors.mint
                        : FarmColors.peach,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    e.text('kind') == 'IN'
                        ? Icons.south_west
                        : Icons.north_east,
                    color: forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${e.text('kind') == 'IN' ? 'Thu' : 'Chi'} · ${vnd(e.values['amount'])}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              e.text('content'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${farmDate(e.text('date'))} · ${financeCategory(e.text('category'))}',
            ),
            Text('Người ghi: ${e.text('actorName')}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FarmStatusBadge(
                label: cancelled ? 'Đã hủy' : 'Hợp lệ',
                tone: cancelled ? FarmBadgeTone.neutral : FarmBadgeTone.success,
              ),
            ),
            if (cancelled) ...[
              const SizedBox(height: 12),
              Text('Lý do hủy: ${e.text('cancelReason')}'),
              if (e.text('cancelledByName').isNotEmpty)
                Text('Người hủy: ${e.text('cancelledByName')}'),
              Text('Thời điểm hủy: ${financeTimestamp(e.text('cancelledAt'))}'),
              const Text(
                'Khoản đã hủy không còn tính vào tổng hợp lệ.',
                style: TextStyle(color: muted),
              ),
            ],
            if (linked) ...[
              const SizedBox(height: 12),
              const Text('Liên kết giao dịch bán'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => history(e),
                  child: const Text('Lịch sử'),
                ),
                if (!linked && !cancelled) ...[
                  TextButton(
                    onPressed: canWrite ? () => edit(e.text('kind'), e) : null,
                    child: const Text('Sửa'),
                  ),
                  TextButton(
                    onPressed: canWrite ? () => cancel(e) : null,
                    child: const Text('Hủy khoản'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canFinance) {
      return const Center(
        child: Text('Bạn không có quyền truy cập tài chính.'),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => FarmBody(
        controller: tab == 0 ? controller : sectionController,
        title: tab == 1
            ? 'Báo cáo thu chi'
            : tab == 2
            ? 'Giao dịch bán'
            : 'Thu chi trang trại',
        refresh: () {
          if (!busy && !reportLoading) load();
        },
        actions: [
          if (tab == 0) ...[
            FilledButton.icon(
              onPressed: canWrite ? () => edit('IN') : null,
              icon: const Icon(Icons.add),
              label: const Text('Ghi thu'),
            ),
            OutlinedButton(
              onPressed: canWrite ? () => edit('OUT') : null,
              child: const Text('Ghi chi'),
            ),
          ],
          if (tab != 2)
            OutlinedButton.icon(
              onPressed: busy || controller.loading || reportLoading
                  ? null
                  : filters,
              icon: const Icon(Icons.filter_list),
              label: const Text('Bộ lọc'),
            ),
        ],
        children: [
          const Text(
            'VND · Bán vật nuôi từ hồ sơ sẽ tự tạo khoản thu. Nhập kho không tự ghi chi.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final e in {
                0: 'Sổ thu chi',
                1: 'Báo cáo',
                2: 'Giao dịch bán',
              }.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: tab == e.key,
                  onSelected: busy
                      ? null
                      : (_) {
                          setState(() {
                            tab = e.key;
                            page = 1;
                            reportLoading = false;
                          });
                          if (tab != 2) {
                            load();
                          } else {
                            loadRevision++;
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (tab != 2)
            Text(
              'Từ ${farmDate(from)} đến ${farmDate(to)} · ${kind.isEmpty
                  ? 'Thu và chi'
                  : kind == 'IN'
                  ? 'Thu'
                  : 'Chi'} · ${category.isEmpty ? 'Tất cả nhóm' : financeCategory(category)}',
            ),
          const SizedBox(height: 16),
          if (tab == 0) ...[
            if (summaryLoading) const LinearProgressIndicator(),
            if (summaryError != null) ...[
              FeedbackBox(summaryError!),
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Tải lại tổng thu chi'),
              ),
            ],
            if (ledgerSummary != null) ...[
              LedgerTotals(summary: ledgerSummary!),
              const SizedBox(height: 24),
            ],
            Text(
              'Trạng thái danh sách: ${{'VALID': 'Hợp lệ', 'CANCELLED': 'Đã hủy', 'ALL': 'Tất cả'}[status]}',
            ),
            const SizedBox(height: 12),
            if (controller.error != null && controller.data.isNotEmpty) ...[
              const Text(
                'Đang hiển thị sổ từ lần tải trước. Tải lại thành công để tiếp tục chỉnh sửa.',
              ),
              const SizedBox(height: 16),
            ],
            if (controller.items('entries').isEmpty &&
                !controller.loading &&
                controller.error == null)
              const FarmEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                message: 'Chưa có khoản thu chi trong khoảng ngày này.',
                description: 'Thử đổi khoảng ngày hoặc bộ lọc thu chi.',
              ),
            for (final e in controller.items('entries')) ledgerEntry(e),
            FinancePagination(
              page: page,
              total: (controller.data['total'] as num?)?.toInt() ?? 0,
              loading: controller.loading || busy,
              onPage: (p) {
                setState(() => page = p);
                load();
              },
            ),
          ],
          if (tab == 1) ...[
            if (reportLoading) const LinearProgressIndicator(),
            if (reportError != null) ...[
              FeedbackBox(reportError!),
              TextButton(
                onPressed: reportLoading ? null : load,
                child: const Text('Tải lại báo cáo'),
              ),
            ],
          ],
          if (tab == 1 && reportData != null) ...[
            FinanceTotals(
              summary: Map<String, dynamic>.from(reportData!['summary'] as Map),
            ),
            const SizedBox(height: 20),
            MonthlyFinanceChart(
              monthly: FarmRepository.records(reportData!, 'monthly'),
            ),
          ],
          if (tab == 2)
            SalesHistory(
              repository: widget.repository,
              admin: widget.admin,
              canFinance: widget.canFinance,
              revision: salesRevision,
              onChanged: () => setState(() {
                reportData = null;
                ledgerSummary = null;
              }),
            ),
        ],
      ),
    );
  }
}

class FinancePagination extends StatelessWidget {
  final int page, total;
  final bool loading;
  final ValueChanged<int> onPage;
  const FinancePagination({
    super.key,
    required this.page,
    required this.total,
    required this.loading,
    required this.onPage,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    children: [
      Text('Trang $page · $total bản ghi'),
      IconButton(
        tooltip: 'Trang trước',
        onPressed: loading || page <= 1 ? null : () => onPage(page - 1),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Trang sau',
        onPressed: loading || page * 20 >= total
            ? null
            : () => onPage(page + 1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
