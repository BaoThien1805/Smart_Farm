import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'farm_repository.dart';
import 'farm_widgets.dart';

const financeCategories = {
  'FEED': 'Thức ăn',
  'MEDICINE': 'Thuốc / vaccine',
  'ANIMAL_PURCHASE': 'Mua vật nuôi',
  'OTHER': 'Khác',
};
String financeCategory(String key) =>
    key == 'ANIMAL_SALE' ? 'Bán vật nuôi' : financeCategories[key] ?? key;
String vnd(Object? value) {
  final digits = (value ?? '0').toString();
  final negative = digits.startsWith('-');
  final raw = negative ? digits.substring(1) : digits;
  return '${negative ? '-' : ''}${raw.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} ₫';
}

const moneyField = FarmField(
  'amount',
  'Số tiền (VND)',
  numeric: true,
  integer: true,
  maximum: 1000000000000,
);

Future<bool> sellAnimalForm(
  BuildContext context,
  FarmRepository repository,
  String animalId,
) async {
  final requestId = FarmRepository.requestId();
  return farmForm(
    context,
    title: 'Bán vật nuôi',
    fields: [
      FarmField('date', 'Ngày bán', initial: farmToday(), date: true),
      moneyField,
      const FarmField('buyer', 'Người mua', requiredValue: false),
      const FarmField('notes', 'Ghi chú', requiredValue: false),
    ],
    save: (b) => repository.save('POST', '/animals/$animalId/sell', {
      ...b,
      'requestId': requestId,
    }),
  );
}

Future<bool> cancelSaleForm(
  BuildContext context,
  FarmRepository repository,
  FarmRecord sale,
) async {
  final catalogs = await repository.get('/farm/catalogs');
  if (!context.mounted) return false;
  final pens = FarmRepository.records(catalogs, 'pens').where(
    (p) => p.flag('active') && p.integer('occupied') < p.integer('capacity'),
  );
  final requestId = FarmRepository.requestId();
  return farmForm(
    context,
    title: 'Hủy bán · ${sale.text('animalCode')}',
    fields: [
      FarmField(
        'penId',
        'Chuồng nhận lại',
        options: {
          for (final p in pens)
            p.id:
                '${p.text('code')} · ${p.text('name')} (${p.integer('occupied')}/${p.integer('capacity')})',
        },
      ),
      FarmField('date', 'Ngày nhận lại', initial: farmToday(), date: true),
      const FarmField('reason', 'Lý do hủy bán'),
    ],
    save: (b) => repository.save('POST', '/sales/${sale.id}/cancel', {
      ...b,
      'requestId': requestId,
    }),
  );
}

class FinanceTotals extends StatelessWidget {
  final Map<String, dynamic> summary;
  const FinanceTotals({super.key, required this.summary});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final e in {
        'salesRevenue': 'Doanh thu bán vật nuôi',
        'income': 'Tổng thu',
        'expense': 'Tổng chi',
        'difference': 'Chênh lệch thu chi',
      }.entries)
        SizedBox(
          width: 260,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.value),
                  const SizedBox(height: 8),
                  Text(
                    vnd(summary[e.key]),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class FinancePage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  const FinancePage({super.key, required this.repository, this.admin = true});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late final controller = FarmController(widget.repository);
  int tab = 0, page = 1;
  String from = '${farmToday().substring(0, 7)}-01',
      to = farmToday(),
      kind = '',
      category = '',
      status = 'VALID';
  void load() {
    final query = Uri(
      queryParameters: {
        'from': from,
        'to': to,
        if (kind.isNotEmpty) 'kind': kind,
        if (category.isNotEmpty) 'category': category,
        'status': status,
        'page': '$page',
      },
    ).query;
    controller.load('/finance/${tab == 1 ? 'report' : 'entries'}?$query');
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> filters() async {
    await farmForm(
      context,
      title: 'Lọc sổ và báo cáo',
      fields: [
        FarmField('from', 'Từ ngày', initial: from, date: true),
        FarmField('to', 'Đến ngày', initial: to, date: true),
        FarmField(
          'kind',
          'Thu / chi',
          initial: kind.isEmpty ? 'ALL' : kind,
          options: {'ALL': 'Tất cả', 'IN': 'Thu', 'OUT': 'Chi'},
        ),
        FarmField(
          'category',
          'Nhóm',
          initial: category.isEmpty ? 'ALL' : category,
          options: {
            'ALL': 'Tất cả',
            'ANIMAL_SALE': 'Bán vật nuôi',
            ...financeCategories,
          },
        ),
        FarmField(
          'status',
          'Trạng thái sổ',
          initial: status,
          options: {'VALID': 'Hợp lệ', 'CANCELLED': 'Đã hủy', 'ALL': 'Tất cả'},
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
    if (mounted) load();
  }

  Future<void> edit(String type, [FarmRecord? entry]) async {
    final requestId = FarmRepository.requestId();
    final saved = await farmForm(
      context,
      title: entry == null
          ? 'Ghi ${type == 'IN' ? 'thu' : 'chi'}'
          : 'Sửa khoản thu chi',
      fields: [
        FarmField(
          'date',
          'Ngày ghi nhận',
          initial: entry?.text('date') ?? farmToday(),
          date: true,
        ),
        FarmField(
          'kind',
          'Loại',
          initial: entry?.text('kind') ?? type,
          options: {'IN': 'Thu', 'OUT': 'Chi'},
        ),
        FarmField(
          'category',
          'Nhóm',
          initial: entry?.text('category') ?? 'OTHER',
          options: financeCategories,
        ),
        FarmField(
          'amount',
          'Số tiền (VND)',
          initial: entry?.text('amount') ?? '',
          numeric: true,
          integer: true,
          maximum: 1000000000000,
        ),
        FarmField('content', 'Nội dung', initial: entry?.text('content') ?? ''),
        if (entry != null) const FarmField('reason', 'Lý do sửa'),
      ],
      save: (b) => widget.repository.save(
        entry == null ? 'POST' : 'PATCH',
        '/finance/entries${entry == null ? '' : '/${entry.id}'}',
        {...b, 'requestId': requestId},
      ),
    );
    if (saved && mounted) load();
  }

  Future<void> cancel(FarmRecord entry) async {
    final requestId = FarmRepository.requestId();
    final saved = await farmForm(
      context,
      title: 'Hủy khoản thu chi',
      fields: [const FarmField('reason', 'Lý do hủy')],
      save: (b) => widget.repository.save(
        'POST',
        '/finance/entries/${entry.id}/cancel',
        {...b, 'requestId': requestId},
      ),
    );
    if (saved && mounted) load();
  }

  Future<void> history(FarmRecord entry) async {
    try {
      final data = await widget.repository.get(
        '/finance/entries/${entry.id}/history',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lịch sử thu chi'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final h in FarmRepository.records(data, 'history'))
                    ListTile(
                      title: Text(
                        '${{'CREATE': 'Tạo', 'EDIT': 'Sửa', 'CANCEL': 'Hủy'}[h.text('action')]} · ${h.text('actorName')}',
                      ),
                      subtitle: Text(
                        '${h.text('createdAt')}\n${h.text('reason')}\n${h.values['before'] is Map ? 'Trước: ${vnd((h.values['before'] as Map)['amount'])} → ' : ''}Sau: ${vnd((h.values['after'] as Map)['amount'])}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: 'Thu chi trang trại',
      refresh: load,
      actions: [
        FilledButton.icon(
          onPressed: controller.loading ? null : () => edit('IN'),
          icon: const Icon(Icons.add),
          label: const Text('Ghi thu'),
        ),
        OutlinedButton(
          onPressed: controller.loading ? null : () => edit('OUT'),
          child: const Text('Ghi chi'),
        ),
        OutlinedButton.icon(
          onPressed: filters,
          icon: const Icon(Icons.filter_list),
          label: const Text('Bộ lọc'),
        ),
      ],
      children: [
        const Text(
          'VND · Bán vật nuôi từ hồ sơ sẽ tự tạo khoản thu. Nhập kho không tự ghi chi.',
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
                onSelected: (_) {
                  setState(() {
                    tab = e.key;
                    page = 1;
                  });
                  if (tab != 2) load();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (tab != 2)
          Text(
            '$from → $to · ${kind.isEmpty
                ? 'Thu và chi'
                : kind == 'IN'
                ? 'Thu'
                : 'Chi'} · ${category.isEmpty ? 'Tất cả nhóm' : financeCategory(category)}',
          ),
        const SizedBox(height: 16),
        if (tab == 0) ...[
          if (controller.items('entries').isEmpty && !controller.loading)
            const Text('Chưa có khoản thu chi trong khoảng ngày này.'),
          for (final e in controller.items('entries'))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.text('kind') == 'IN' ? 'Thu' : 'Chi'} · ${vnd(e.values['amount'])}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${e.text('date')} · ${financeCategory(e.text('category'))}',
                    ),
                    Text(e.text('content')),
                    Text('Người ghi: ${e.text('actorName')}'),
                    if (e.text('cancelledAt').isNotEmpty)
                      Text(
                        'Đã hủy · ${e.text('cancelReason')} · ${e.text('cancelledByName')}',
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => history(e),
                          child: const Text('Lịch sử'),
                        ),
                        if (e.text('saleId').isEmpty &&
                            e.text('cancelledAt').isEmpty) ...[
                          TextButton(
                            onPressed: () => edit(e.text('kind'), e),
                            child: const Text('Sửa'),
                          ),
                          TextButton(
                            onPressed: () => cancel(e),
                            child: const Text('Hủy khoản'),
                          ),
                        ] else if (e.text('saleId').isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Liên kết giao dịch bán'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          FinancePagination(
            page: page,
            total: (controller.data['total'] as num?)?.toInt() ?? 0,
            loading: controller.loading,
            onPage: (p) {
              setState(() => page = p);
              load();
            },
          ),
        ],
        if (tab == 1 && controller.data['summary'] is Map) ...[
          FinanceTotals(
            summary: Map<String, dynamic>.from(
              controller.data['summary'] as Map,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Thu / chi theo tháng · Chỉ tính khoản hợp lệ'),
          MonthlyFinanceChart(monthly: controller.items('monthly')),
        ],
        if (tab == 2)
          SalesHistory(repository: widget.repository, admin: widget.admin),
      ],
    ),
  );
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

class MonthlyFinanceChart extends StatelessWidget {
  final List<FarmRecord> monthly;
  const MonthlyFinanceChart({super.key, required this.monthly});
  @override
  Widget build(BuildContext context) {
    double maximum = 1;
    for (final m in monthly) {
      for (final k in ['income', 'expense']) {
        final v = double.tryParse(m.text(k)) ?? 0;
        if (v > maximum) maximum = v;
      }
    }
    return Column(
      children: [
        for (final m in monthly)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.text('month')),
                  for (final e in {
                    'income': 'Thu',
                    'expense': 'Chi',
                  }.entries) ...[
                    const SizedBox(height: 8),
                    Text('${e.value}: ${vnd(m.values[e.key])}'),
                    Semantics(
                      label:
                          '${e.value} tháng ${m.text('month')}: ${vnd(m.values[e.key])}',
                      child: LinearProgressIndicator(
                        value: (double.tryParse(m.text(e.key)) ?? 0) / maximum,
                        minHeight: 10,
                        color: e.key == 'income'
                            ? forest
                            : const Color(0xFF92502A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SalesHistory extends StatefulWidget {
  final FarmRepository repository;
  final String? animalId;
  final bool admin;
  final VoidCallback? onChanged;
  const SalesHistory({
    super.key,
    required this.repository,
    this.animalId,
    this.admin = true,
    this.onChanged,
  });
  @override
  State<SalesHistory> createState() => _SalesHistoryState();
}

class _SalesHistoryState extends State<SalesHistory> {
  late final controller = FarmController(widget.repository);
  bool preparing = false;
  String? error;
  int page = 1;
  void load() => controller.load(
    '/sales?status=ALL&page=$page${widget.animalId == null ? '' : '&animalId=${widget.animalId}'}',
  );
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> cancel(FarmRecord sale) async {
    setState(() {
      preparing = true;
      error = null;
    });
    try {
      if (await cancelSaleForm(context, widget.repository, sale) && mounted) {
        load();
        widget.onChanged?.call();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.admin
              ? 'Giao dịch bán · Hủy bán trả vật nuôi về chuồng còn chỗ và hủy khoản thu; lịch chăm sóc đã hủy được giữ nguyên.'
              : 'Giao dịch bán · Kế toán theo dõi khoản thu; chủ trang trại quyết định bán và hủy bán.',
        ),
        if (controller.loading) const LinearProgressIndicator(),
        if (preparing) const Text('Đang xử lý giao dịch…'),
        if (error != null) FeedbackBox(error!),
        if (controller.error != null) FeedbackBox(controller.error!),
        TextButton.icon(
          onPressed: controller.loading ? null : load,
          icon: const Icon(Icons.refresh),
          label: const Text('Tải giao dịch bán'),
        ),
        if (!controller.loading && controller.items('sales').isEmpty)
          const Text('Chưa có giao dịch bán.'),
        for (final s in controller.items('sales'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.text('animalCode')} · ${vnd(s.values['amount'])}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Ngày bán: ${s.text('date')} · ${s.text('actorName')}'),
                  if (s.text('buyer').isNotEmpty)
                    Text('Người mua: ${s.text('buyer')}'),
                  if (s.text('notes').isNotEmpty) Text(s.text('notes')),
                  if (s.text('cancelledAt').isNotEmpty)
                    Text(
                      'Đã hủy · ${s.text('cancelReason')}\n${s.text('restoreDate')} · ${s.text('restorePenName')} · ${s.text('cancelledByName')}',
                    )
                  else if (widget.admin)
                    TextButton(
                      onPressed: preparing ? null : () => cancel(s),
                      child: const Text('Hủy bán'),
                    ),
                ],
              ),
            ),
          ),
        FinancePagination(
          page: page,
          total: (controller.data['total'] as num?)?.toInt() ?? 0,
          loading: controller.loading || preparing,
          onPage: (p) {
            setState(() => page = p);
            load();
          },
        ),
      ],
    ),
  );
}
