import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'finance_values.dart';

String financeTimestamp(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final d = parsed.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)} (UTC+7)';
}

class LedgerTotals extends StatelessWidget {
  const LedgerTotals({super.key, required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FarmSectionHeader(
        title: 'Tổng khoản hợp lệ trong kỳ',
        subtitle: 'Đơn vị VND · Tổng không bao gồm khoản đã hủy.',
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 900
              ? 3
              : c.maxWidth >= 650
              ? 2
              : 1;
          final width = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in {
                'income': 'Tổng thu',
                'expense': 'Tổng chi',
                'difference': 'Chênh lệch thu chi',
              }.entries)
                SizedBox(
                  width: width,
                  child: FarmInfoCard(
                    color: e.key == 'income'
                        ? FarmColors.mint
                        : e.key == 'expense'
                        ? FarmColors.peach
                        : FarmColors.lavender,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value),
                        const SizedBox(height: 8),
                        Text(
                          summary[e.key] == null
                              ? 'Chưa có dữ liệu'
                              : vnd(summary[e.key]),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      if (summary['salesRevenue'] != null)
        Text(
          'Trong Tổng thu: doanh thu bán vật nuôi ${vnd(summary['salesRevenue'])}.',
          style: const TextStyle(color: muted),
        ),
      const Text(
        'Chênh lệch thu chi chưa phải lợi nhuận kế toán.',
        style: TextStyle(color: muted),
      ),
    ],
  );
}

class LedgerEntrySummary extends StatelessWidget {
  const LedgerEntrySummary({super.key, required this.entry});
  final FarmRecord entry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: canvas,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${entry.text('kind') == 'IN' ? 'Thu' : 'Chi'} · ${vnd(entry.values['amount'])}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '${farmDate(entry.text('date'))} · ${financeCategory(entry.text('category'))}',
        ),
        const SizedBox(height: 8),
        Text(entry.text('content')),
        if (entry.text('actorName').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Người ghi: ${entry.text('actorName')}'),
        ],
      ],
    ),
  );
}

Future<void> showFinanceAudit(
  BuildContext context,
  FarmRepository repository,
  FarmRecord entry,
) => showDialog<void>(
  context: context,
  builder: (_) => FinanceAuditDialog(repository: repository, entry: entry),
);

class FinanceAuditDialog extends StatefulWidget {
  const FinanceAuditDialog({
    super.key,
    required this.repository,
    required this.entry,
  });
  final FarmRepository repository;
  final FarmRecord entry;
  @override
  State<FinanceAuditDialog> createState() => _FinanceAuditDialogState();
}

class _FinanceAuditDialogState extends State<FinanceAuditDialog> {
  List<FarmRecord> history = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.repository.get(
        '/finance/entries/${widget.entry.id}/history',
      );
      if (mounted) {
        setState(() => history = FarmRepository.records(data, 'history'));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget snapshot(Object? value, String heading) {
    if (value is! Map) return Text('$heading: không có bản chụp dữ liệu.');
    final data = Map<String, dynamic>.from(value);
    final cancelled = data['cancelled_at'] ?? data['cancelledAt'];
    final hasStatus =
        data.containsKey('cancelled_at') || data.containsKey('cancelledAt');
    final values = <String, String>{
      if (data['date'] != null)
        'Ngày ghi nhận': farmDate(data['date'].toString()),
      if (data['kind'] != null)
        'Loại': data['kind'] == 'IN'
            ? 'Thu'
            : data['kind'] == 'OUT'
            ? 'Chi'
            : data['kind'].toString(),
      if (data['category'] != null)
        'Nhóm': financeCategory(data['category'].toString()),
      if (data['amount'] != null) 'Số tiền (VND)': vnd(data['amount']),
      if (data['content'] != null) 'Nội dung': data['content'].toString(),
      if (hasStatus) 'Trạng thái': cancelled == null ? 'Hợp lệ' : 'Đã hủy',
      if (cancelled != null)
        'Thời điểm hủy': financeTimestamp(cancelled.toString()),
      if ((data['cancel_reason'] ?? data['cancelReason']) != null)
        'Lý do hủy': (data['cancel_reason'] ?? data['cancelReason']).toString(),
      if ((data['sale_id'] ?? data['saleId']) != null)
        'Nguồn': 'Liên kết giao dịch bán',
      if ((data['stock_entry_id'] ?? data['stockEntryId']) != null)
        'Nguồn': 'Nhập kho thức ăn',
      if ((data['updated_at'] ?? data['updatedAt']) != null)
        'Cập nhật': financeTimestamp(
          (data['updated_at'] ?? data['updatedAt']).toString(),
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (values.isEmpty) const Text('Chưa có trường dữ liệu để hiển thị.'),
        for (final e in values.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: const TextStyle(color: muted)),
                Text(e.value),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => FarmFormLayout(
    title: 'Lịch sử thu chi',
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerEntrySummary(entry: widget.entry),
        const SizedBox(height: 20),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          FeedbackBox(error!),
          TextButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử tải lại lịch sử'),
          ),
        ],
        if (!loading && error == null && history.isEmpty)
          const Text('Chưa có lịch sử chỉnh sửa được trả về.'),
        for (final h in history) ...[
          FarmInfoCard(
            key: ValueKey('finance-audit-${h.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  {
                        'CREATE': 'Tạo khoản',
                        'EDIT': 'Sửa khoản',
                        'CANCEL': 'Hủy khoản',
                      }[h.text('action')] ??
                      h.text('action'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Người thực hiện: ${h.text('actorName')}'),
                Text(financeTimestamp(h.text('createdAt'))),
                if (h.text('reason').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Lý do: ${h.text('reason')}'),
                ],
                const Divider(height: 24),
                if (h.text('action') == 'CREATE' && h.values['before'] == null)
                  const Text('Tạo bản ghi mới.')
                else
                  snapshot(h.values['before'], 'Trước'),
                const SizedBox(height: 16),
                snapshot(h.values['after'], 'Sau'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    ),
  );
}
