import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_selection_summary.dart';
import 'farm_repository.dart';

Future<bool> batchTransferForm(
  BuildContext context, {
  required FarmRepository repository,
  required List<FarmRecord> animals,
  required List<FarmRecord> pens,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BatchTransferEditor(
        repository: repository,
        animals: animals,
        pens: pens,
      ),
    ) ??
    false;

class BatchTransferEditor extends StatefulWidget {
  const BatchTransferEditor({
    super.key,
    required this.repository,
    required this.animals,
    required this.pens,
  });
  final FarmRepository repository;
  final List<FarmRecord> animals, pens;

  @override
  State<BatchTransferEditor> createState() => _BatchTransferEditorState();
}

class _BatchTransferEditorState extends State<BatchTransferEditor> {
  final form = GlobalKey<FormState>();
  final errorAnchor = GlobalKey();
  final date = TextEditingController(text: farmDate(farmToday()));
  final notes = TextEditingController();
  late final requestId = FarmRepository.requestId();
  String? penId, error;
  bool busy = false;

  List<FarmRecord> get moving =>
      widget.animals.where((a) => a.text('penId') != penId).toList();
  List<FarmRecord> get available => widget.pens.where((p) {
    final count = widget.animals.where((a) => a.text('penId') != p.id).length;
    return p.flag('active') &&
        count > 0 &&
        p.integer('capacity') - p.integer('occupied') >= count;
  }).toList();
  FarmRecord? get destination =>
      available.where((p) => p.id == penId).firstOrNull;

  @override
  void dispose() {
    date.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || available.isEmpty || !form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save('POST', '/animals/batch/transfer', {
        'animalIds': widget.animals.map((a) => a.id).toSet().toList()..sort(),
        'penId': penId,
        'date': farmIsoDate(date.text),
        'notes': notes.text.trim(),
        'requestId': requestId,
      });
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
      title: 'Chuyển chuồng nhiều con',
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy || available.isEmpty || widget.animals.isEmpty
              ? null
              : submit,
          child: FarmSubmitLabel(busy: busy, label: 'Xác nhận chuyển'),
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
            if (available.isEmpty) ...[
              const FeedbackBox(
                'Chưa có chuồng đang hoạt động đủ chỗ cho đợt chuyển này. Hãy giảm số con hoặc bổ sung sức chứa.',
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: penId,
              isExpanded: true,
              decoration: farmInputDecoration(label: 'Chuồng đích'),
              items: [
                for (final p in available)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.text('code')} · ${p.text('name')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy ? null : (value) => setState(() => penId = value),
              validator: (value) => value == null || destination == null
                  ? 'Vui lòng chọn chuồng đích.'
                  : null,
            ),
            if (destination case final p?) ...[
              const SizedBox(height: 12),
              Text(
                '${moving.length} con sẽ chuyển · còn ${p.integer('capacity') - p.integer('occupied')} chỗ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (moving.length < widget.animals.length)
                Text(
                  '${widget.animals.length - moving.length} con đã ở chuồng đích, được giữ nguyên.',
                ),
              Text(
                'Sau chuyển: ${p.integer('occupied') + moving.length}/${p.integer('capacity')} con',
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: date,
              enabled: !busy,
              readOnly: true,
              decoration: farmInputDecoration(
                label: 'Ngày chuyển',
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: farmParseDate(date.text) ?? DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
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
                    moving.any(
                      (a) =>
                          a.text('arrivalDate').isNotEmpty &&
                          iso.compareTo(a.text('arrivalDate')) < 0,
                    )) {
                  return 'Ngày chuyển phải từ ngày nhập đàn của các con đến hôm nay.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: notes,
              enabled: !busy,
              maxLength: 2000,
              maxLines: 3,
              decoration: farmInputDecoration(
                label: 'Ghi chú',
                helperText: 'Tùy chọn.',
              ),
            ),
            const SizedBox(height: 8),
            const Text('Mỗi con chuyển chuồng được lưu lịch sử riêng.'),
          ],
        ),
      ),
    ),
  );
}
