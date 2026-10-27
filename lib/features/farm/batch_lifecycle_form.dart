import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_selection_summary.dart';
import 'farm_repository.dart';
import 'finance_values.dart';

Future<bool> batchLifecycleForm(
  BuildContext context, {
  required FarmRepository repository,
  required List<FarmRecord> animals,
  required bool selling,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchLifecycleEditor(
        repository: repository,
        animals: animals,
        selling: selling,
      ),
    ) ??
    false;

class BatchLifecycleEditor extends StatefulWidget {
  const BatchLifecycleEditor({
    super.key,
    required this.repository,
    required this.animals,
    required this.selling,
  });
  final FarmRepository repository;
  final List<FarmRecord> animals;
  final bool selling;

  @override
  State<BatchLifecycleEditor> createState() => _BatchLifecycleEditorState();
}

class _BatchLifecycleEditorState extends State<BatchLifecycleEditor> {
  final form = GlobalKey<FormState>(), errorAnchor = GlobalKey();
  final date = TextEditingController(text: farmDate(farmToday()));
  final amount = TextEditingController(),
      buyer = TextEditingController(),
      notes = TextEditingController();
  late final requestId = FarmRepository.requestId();
  bool busy = false, confirmed = false;
  String? error;
  int? get unitPrice => int.tryParse(amount.text.trim());

  @override
  void dispose() {
    for (final c in [date, amount, buyer, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || widget.animals.isEmpty || (!widget.selling && !confirmed)) {
      return;
    }
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
    final ids = widget.animals.map((a) => a.id).toSet().toList()..sort();
    try {
      await widget.repository.save(
        'POST',
        '/animals/batch/${widget.selling ? 'sell' : 'death'}',
        {
          'requestId': requestId,
          'date': farmIsoDate(date.text),
          'notes': notes.text.trim(),
          if (widget.selling) ...{
            'items': [
              for (final id in ids) {'animalId': id, 'amount': unitPrice!},
            ],
            'buyer': buyer.text.trim(),
          } else
            'animalIds': ids,
        },
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FarmFormLayout(
      title: widget.selling ? 'Bán nhiều vật nuôi' : 'Ghi nhận đã chết',
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed:
              busy || widget.animals.isEmpty || (!widget.selling && !confirmed)
              ? null
              : submit,
          style: widget.selling
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: FarmColors.danger,
                  foregroundColor: Colors.white,
                ),
          child: FarmSubmitLabel(
            busy: busy,
            label: widget.selling ? 'Xác nhận bán' : 'Xác nhận đã chết',
          ),
        ),
      ],
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimalSelectionSummary(animals: widget.animals),
            const SizedBox(height: 16),
            if (error != null) ...[
              FeedbackBox(error!, key: errorAnchor),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: date,
              enabled: !busy,
              readOnly: true,
              decoration: farmInputDecoration(
                label: widget.selling ? 'Ngày bán' : 'Ngày chết',
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      farmParseDate(date.text) ?? DateTime.parse(farmToday()),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.parse(farmToday()),
                );
                if (picked != null && mounted) {
                  setState(
                    () => date.text = farmDate(
                      picked.toIso8601String().substring(0, 10),
                    ),
                  );
                }
              },
              validator: (value) {
                if (farmParseDate(value ?? '') == null) {
                  return 'Ngày không hợp lệ.';
                }
                final iso = farmIsoDate(value!);
                if (iso.compareTo(farmToday()) > 0 ||
                    widget.animals.any(
                      (a) =>
                          a.text('arrivalDate').isNotEmpty &&
                          iso.compareTo(a.text('arrivalDate')) < 0,
                    )) {
                  return 'Ngày phải từ ngày nhập đàn của các con đến hôm nay.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (widget.selling) ...[
              TextFormField(
                controller: amount,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: farmInputDecoration(
                  label: 'Giá bán mỗi con (VND)',
                  helperText: 'Áp dụng cùng giá cho các con đã chọn. Nhập số nguyên, không dùng dấu phân cách.',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Nhập số nguyên VND lớn hơn 0.';
                  }
                  if (parsed > 1000000000000) {
                    return 'Giá tối đa 1000000000000 VND mỗi con.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Tổng tiền ${widget.animals.length} con: ${vnd((unitPrice ?? 0) * widget.animals.length)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: buyer,
                enabled: !busy,
                maxLength: 200,
                decoration: farmInputDecoration(label: 'Người mua (tùy chọn)'),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: notes,
              enabled: !busy,
              maxLength: 2000,
              maxLines: 3,
              decoration: farmInputDecoration(
                label: widget.selling
                    ? 'Ghi chú (tùy chọn)'
                    : 'Ghi chú / nguyên nhân (tùy chọn)',
              ),
            ),
            const SizedBox(height: 12),
            FeedbackBox(
              widget.selling
                  ? 'Mỗi con có giao dịch bán và khoản thu riêng. Lịch chăm sóc đang chờ của các con này sẽ được hủy.'
                  : 'Hồ sơ và lịch sử được giữ lại. Lịch chăm sóc đang chờ sẽ được hủy. Không thể hoàn tác ghi nhận chết trong ứng dụng.',
              isError: false,
            ),
            if (!widget.selling) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                key: const ValueKey('batch-death-confirm'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmed,
                title: Text(
                  'Tôi xác nhận ${widget.animals.length} vật nuôi đã chọn đã chết.',
                ),
                onChanged: busy
                    ? null
                    : (value) => setState(() => confirmed = value ?? false),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
