import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'finance_page.dart' show FinancePagination;
import 'finance_ledger_widgets.dart' show financeTimestamp;
import 'finance_values.dart';
import 'sales_forms.dart';

class SalesHistory extends StatefulWidget {
  final FarmRepository repository;
  final String? animalId;
  final bool admin, canFinance;
  final VoidCallback? onChanged;
  final int revision;
  const SalesHistory({
    super.key,
    required this.repository,
    this.animalId,
    this.admin = true,
    this.canFinance = true,
    this.onChanged,
    this.revision = 0,
  });
  @override
  State<SalesHistory> createState() => _SalesHistoryState();
}

class _SalesHistoryState extends State<SalesHistory> {
  late final controller = FarmController(widget.repository);
  bool preparing = false;
  int page = 1, loadRevision = 0;
  String status = 'ALL';
  bool get locked => preparing || controller.loading;
  Future<void> load() async {
    if (!widget.canFinance) return;
    final revision = ++loadRevision;
    await controller.load(
      '/sales?${Uri(queryParameters: {'status': status, 'page': '$page', if (widget.animalId != null) 'animalId': widget.animalId!}).query}',
    );
    if (mounted &&
        revision == loadRevision &&
        controller.error == null &&
        controller.items('sales').isEmpty &&
        page > 1) {
      final total = (controller.data['total'] as num?)?.toInt() ?? 0;
      setState(() => page = ((total - 1) ~/ 20 + 1).clamp(1, page - 1));
      await load();
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant SalesHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animalId != widget.animalId) page = 1;
    if (oldWidget.revision != widget.revision ||
        oldWidget.animalId != widget.animalId ||
        oldWidget.canFinance != widget.canFinance) {
      load();
    }
  }

  @override
  void dispose() {
    loadRevision++;
    controller.dispose();
    super.dispose();
  }

  Future<void> cancel(FarmRecord sale) async {
    if (!widget.admin ||
        !widget.canFinance ||
        locked ||
        controller.error != null ||
        sale.text('cancelledAt').isNotEmpty) {
      return;
    }
    setState(() {
      preparing = true;
    });
    try {
      if (await cancelSaleForm(
            context,
            widget.repository,
            sale,
            admin: widget.admin,
          ) &&
          mounted) {
        await load();
        widget.onChanged?.call();
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Widget saleCard(FarmRecord s) {
    final cancelled = s.text('cancelledAt').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FarmInfoCard(
        key: ValueKey('sale-${s.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cancelled ? FarmColors.peach : FarmColors.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, color: forest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.text('animalCode'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FarmStatusBadge(
                label: cancelled ? 'Đã hủy' : 'Có hiệu lực',
                tone: cancelled ? FarmBadgeTone.danger : FarmBadgeTone.success,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              vnd(s.values['amount']),
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: forest),
            ),
            const SizedBox(height: 12),
            Text('Ngày bán: ${farmDate(s.text('date'))}'),
            Text('Người ghi: ${s.text('actorName')}'),
            Text(
              'Người mua: ${s.text('buyer').isEmpty ? 'Không ghi' : s.text('buyer')}',
            ),
            if (s.text('notes').isNotEmpty) Text('Ghi chú: ${s.text('notes')}'),
            if (cancelled) ...[
              const Divider(height: 32),
              Text('Lý do hủy: ${s.text('cancelReason')}'),
              if (s.text('restoreDate').isNotEmpty)
                Text('Ngày nhận lại: ${farmDate(s.text('restoreDate'))}'),
              if (s.text('restorePenName').isNotEmpty)
                Text('Chuồng nhận lại: ${s.text('restorePenName')}'),
              if (s.text('cancelledByName').isNotEmpty)
                Text('Người hủy: ${s.text('cancelledByName')}'),
              Text('Thời điểm hủy: ${financeTimestamp(s.text('cancelledAt'))}'),
              const SizedBox(height: 8),
              const Text(
                'Khoản thu liên kết đã hủy, không còn tính vào tổng hợp lệ.',
                style: TextStyle(color: muted),
              ),
            ] else if (widget.admin) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: locked || controller.error != null
                      ? null
                      : () => cancel(s),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Hủy bán'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canFinance) {
      return const Text('Bạn không có quyền xem giao dịch bán.');
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.admin
                ? 'Hủy bán trả vật nuôi về chuồng còn chỗ và hủy khoản thu liên kết; lịch chăm sóc đã hủy được giữ nguyên.'
                : 'Kế toán theo dõi khoản thu; chủ trang trại quyết định bán và hủy bán.',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: farmInputDecoration(label: 'Trạng thái giao dịch bán'),
            isExpanded: true,
            items: [
              for (final e in const {
                'ALL': 'Tất cả trạng thái',
                'VALID': 'Có hiệu lực',
                'CANCELLED': 'Đã hủy',
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: locked
                ? null
                : (v) {
                    setState(() {
                      status = v!;
                      page = 1;
                    });
                    // Discard the previous filter's records while loading this one.
                    controller.data = {};
                    load();
                  },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: locked ? null : load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải giao dịch bán'),
            ),
          ),
          if (controller.loading) const FarmLoadingState(),
          if (preparing) const Text('Đang xử lý giao dịch…'),
          if (controller.error != null) ...[
            FarmLoadError(
              message: controller.error!,
              onRetry: locked ? null : load,
            ),
            if (controller.data.isNotEmpty)
              const Text(
                'Đang hiển thị giao dịch từ lần tải trước. Tải lại thành công để tiếp tục hủy bán.',
              ),
          ],
          const SizedBox(height: 12),
          if (!controller.loading &&
              controller.error == null &&
              controller.items('sales').isEmpty)
            const FarmEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Chưa có giao dịch bán theo bộ lọc này.',
              description: 'Thử chọn trạng thái khác hoặc tải lại danh sách.',
            ),
          for (final s in controller.items('sales')) saleCard(s),
          FinancePagination(
            page: page,
            total: (controller.data['total'] as num?)?.toInt() ?? 0,
            loading: locked,
            onPage: (p) {
              setState(() => page = p);
              load();
            },
          ),
        ],
      ),
    );
  }
}
