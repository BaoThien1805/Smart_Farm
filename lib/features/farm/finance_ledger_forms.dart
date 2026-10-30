import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'finance_values.dart';
import 'finance_ledger_widgets.dart';

Future<bool> financeLedgerForm(
  BuildContext context,
  FarmRepository repository, {
  String kind = 'IN',
  FarmRecord? entry,
  bool cancelling = false,
}) async {
  if (cancelling && entry == null) return false;
  if (entry != null &&
      (isLinkedFinanceEntry(entry) || entry.text('cancelledAt').isNotEmpty)) {
    return false;
  }
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => FinanceLedgerEditor(
          repository: repository,
          initialKind: kind,
          entry: entry,
          cancelling: cancelling,
        ),
      ) ??
      false;
}

class FinanceLedgerEditor extends StatefulWidget {
  const FinanceLedgerEditor({
    super.key,
    required this.repository,
    this.initialKind = 'IN',
    this.entry,
    this.cancelling = false,
  });
  final FarmRepository repository;
  final String initialKind;
  final FarmRecord? entry;
  final bool cancelling;
  @override
  State<FinanceLedgerEditor> createState() => _FinanceLedgerEditorState();
}

class _FinanceLedgerEditorState extends State<FinanceLedgerEditor> {
  final form = GlobalKey<FormState>(), errorAnchor = GlobalKey();
  late final requestId = FarmRepository.requestId();
  late final date = TextEditingController(
    text: farmDate(widget.entry?.text('date') ?? farmToday()),
  );
  late final amount = TextEditingController(
    text: widget.entry?.text('amount') ?? '',
  );
  late final content = TextEditingController(
    text: widget.entry?.text('content') ?? '',
  );
  final reason = TextEditingController();
  late String kind = widget.entry?.text('kind') ?? widget.initialKind;
  late String category = widget.entry?.text('category') ?? 'OTHER';
  bool busy = false;
  String? error;
  bool get editing => widget.entry != null;
  @override
  void dispose() {
    date.dispose();
    amount.dispose();
    content.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            invalid.first.context,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, dynamic>{
      'requestId': requestId,
      if (editing) 'reason': reason.text.trim(),
      if (!widget.cancelling) ...{
        'date': farmIsoDate(date.text),
        'kind': kind,
        'category': category,
        'amount': int.parse(amount.text.trim()),
        'content': content.text.trim(),
      },
    };
    final path =
        '/finance/entries${editing ? '/${widget.entry!.id}' : ''}${widget.cancelling ? '/cancel' : ''}';
    try {
      await widget.repository.save(
        editing && !widget.cancelling ? 'PATCH' : 'POST',
        path,
        body,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = errorAnchor.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(
              target,
              duration: const Duration(milliseconds: 200),
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget selector(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: farmInputDecoration(label: label),
      isExpanded: true,
      items: [
        for (final e in choices.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: busy ? null : changed,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cancelling = widget.cancelling;
    final parsed = int.tryParse(amount.text.trim());
    return PopScope(
      canPop: !busy,
      child: FarmFormLayout(
        title: cancelling
            ? 'Hủy khoản thu chi'
            : editing
            ? 'Sửa khoản thu chi'
            : kind == 'IN'
            ? 'Ghi thu'
            : 'Ghi chi',
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: Text(cancelling ? 'Giữ khoản' : 'Hủy'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            style: cancelling
                ? FilledButton.styleFrom(
                    backgroundColor: FarmColors.danger,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: FarmSubmitLabel(
              busy: busy,
              label: cancelling ? 'Xác nhận hủy' : 'Lưu giao dịch',
            ),
          ),
        ],
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                FeedbackBox(error!, key: errorAnchor),
                const SizedBox(height: 16),
              ],
              if (editing) ...[
                LedgerEntrySummary(entry: widget.entry!),
                const SizedBox(height: 20),
              ],
              if (cancelling) ...[
                const FeedbackBox(
                  'Khi xác nhận, khoản này được đánh dấu đã hủy và không còn tính vào tổng thu chi hợp lệ. Bản ghi và lịch sử vẫn được giữ.',
                ),
                const SizedBox(height: 20),
              ] else ...[
                selector('Loại', kind, const {
                  'IN': 'Thu',
                  'OUT': 'Chi',
                }, (v) => setState(() => kind = v!)),
                selector(
                  'Nhóm',
                  category,
                  financeCategories,
                  (v) => setState(() => category = v!),
                ),
                TextFormField(
                  controller: date,
                  enabled: !busy,
                  readOnly: true,
                  decoration: farmInputDecoration(
                    label: 'Ngày ghi nhận',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: farmParseDate(date.text) ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null && mounted) {
                      date.text = farmDate(
                        selected.toIso8601String().substring(0, 10),
                      );
                    }
                  },
                  validator: (v) => farmParseDate(v ?? '') == null
                      ? 'Ngày không hợp lệ.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amount,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: farmInputDecoration(
                    label: 'Số tiền (VND)',
                    helperText: parsed != null && parsed > 0
                        ? vnd(parsed)
                        : 'Nhập số nguyên VND, không dùng dấu phân cách.',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = num.tryParse((v ?? '').trim());
                    if (n == null || !n.isFinite || n <= 0) {
                      return 'Nhập số lớn hơn 0.';
                    }
                    final integer = int.tryParse((v ?? '').trim());
                    if (integer == null) return 'Nhập số nguyên VND.';
                    if (integer > 1000000000000) {
                      return 'Giá trị tối đa 1000000000000 VND.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: content,
                  enabled: !busy,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: farmInputDecoration(label: 'Nội dung'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Vui lòng nhập.' : null,
                ),
                const SizedBox(height: 16),
              ],
              if (editing)
                TextFormField(
                  controller: reason,
                  enabled: !busy,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: farmInputDecoration(
                    label: cancelling ? 'Lý do hủy' : 'Lý do sửa',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Vui lòng nhập.' : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
