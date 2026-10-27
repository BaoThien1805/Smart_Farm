import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';

enum AnimalEventKind {
  weights('Ghi cân nặng', 'Lưu cân nặng'),
  transfer('Chuyển chuồng', 'Xác nhận chuyển'),
  health('Ghi sức khỏe', 'Lưu ghi nhận'),
  exams('Khám thú y', 'Lưu kết quả khám'),
  death('Ghi nhận chết', 'Xác nhận ghi chết');

  const AnimalEventKind(this.title, this.action);
  final String title, action;
}

Future<bool> animalEventForm(
  BuildContext context, {
  required FarmRepository repository,
  required FarmRecord animal,
  required AnimalEventKind kind,
  required List<FarmRecord> pens,
  required List<FarmRecord> weights,
  required String requestId,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnimalEventForm(
        repository: repository,
        animal: animal,
        kind: kind,
        pens: pens,
        weights: weights,
        requestId: requestId,
      ),
    ) ??
    false;

class AnimalEventForm extends StatefulWidget {
  const AnimalEventForm({
    super.key,
    required this.repository,
    required this.animal,
    required this.kind,
    required this.pens,
    required this.weights,
    required this.requestId,
  });

  final FarmRepository repository;
  final FarmRecord animal;
  final AnimalEventKind kind;
  final List<FarmRecord> pens, weights;
  final String requestId;

  @override
  State<AnimalEventForm> createState() => _AnimalEventFormState();
}

class _AnimalEventFormState extends State<AnimalEventForm> {
  final form = GlobalKey<FormState>();
  final errorAnchor = GlobalKey();
  late final fields = <String, TextEditingController>{
    for (final key in [
      'date',
      'kg',
      'content',
      'diagnosis',
      'treatment',
      'notes',
    ])
      key: TextEditingController(
        text: key == 'date' ? farmDate(farmToday()) : '',
      ),
  };
  late String? status =
      const [
        'NORMAL',
        'NEEDS_CARE',
      ].contains(widget.animal.text('healthStatus'))
      ? widget.animal.text('healthStatus')
      : null;
  String? penId, error;
  bool busy = false;
  bool get isDeath => widget.kind == AnimalEventKind.death;
  bool get clinical => widget.kind == AnimalEventKind.exams;
  List<FarmRecord> get availablePens => widget.pens
      .where(
        (p) =>
            p.flag('active') &&
            p.id != widget.animal.text('penId') &&
            p.integer('occupied') < p.integer('capacity'),
      )
      .toList();

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // A comma is a decimal separator, never a grouping separator. Match the API's
  // thousandth-kg precision and bound before converting to an integer for delta.
  num? get enteredWeight =>
      num.tryParse(fields['kg']!.text.trim().replaceAll(',', '.'));
  int? grams(num? value) {
    if (value == null || !value.isFinite || value <= 0 || value > 100000) {
      return null;
    }
    final scaled = value * 1000;
    return (scaled - scaled.round()).abs() < 1e-7 ? scaled.round() : null;
  }

  String weightText(int grams) {
    final value = (grams / 1000)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return value.replaceAll('.', ',');
  }

  FarmRecord? get previousWeight {
    final date = farmIsoDate(fields['date']!.text);
    final valid =
        widget.weights
            .where(
              (w) =>
                  DateTime.tryParse(w.text('date')) != null &&
                  w.text('date').compareTo(date) < 0 &&
                  grams(w.values['kg'] is num ? w.values['kg'] as num : null) !=
                      null,
            )
            .toList()
          ..sort((a, b) => b.text('date').compareTo(a.text('date')));
    // Do not infer a baseline from ambiguous same-day records.
    if (valid.length > 1 && valid[0].text('date') == valid[1].text('date')) {
      return null;
    }
    return valid.firstOrNull;
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
      'date': farmIsoDate(fields['date']!.text),
      'notes': fields['notes']!.text.trim(),
      'requestId': widget.requestId,
      if (widget.kind == AnimalEventKind.weights) 'kg': enteredWeight!,
      if (widget.kind == AnimalEventKind.transfer) 'penId': penId,
      if (widget.kind == AnimalEventKind.health || clinical) ...{
        'content': fields['content']!.text.trim(),
        'status': status,
      },
      if (clinical) ...{
        'diagnosis': fields['diagnosis']!.text.trim(),
        'treatment': fields['treatment']!.text.trim(),
      },
    };
    try {
      await widget.repository.save(
        'POST',
        '/animals/${widget.animal.id}/${widget.kind.name}',
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

  Widget input(
    String key,
    String title, {
    bool requiredValue = false,
    int lines = 1,
    int limit = 2000,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy,
      maxLines: lines,
      maxLength: limit,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: farmInputDecoration(label: title, helperText: helper),
      validator: (value) => requiredValue && (value ?? '').trim().isEmpty
          ? 'Vui lòng nhập.'
          : null,
    ),
  );

  Widget animalHeader() {
    final a = widget.animal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDeath ? canvas : FarmColors.mint.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDeath) ...[
                FarmAnimalImage(
                  photoData: a.text('imageData'),
                  speciesName: a.text('speciesName'),
                  size: 64,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.text('code'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (a.text('name').isNotEmpty) Text(a.text('name')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            [
              a.text('speciesName'),
              a.text('breedName'),
              label(a.text('gender')),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            'Chuồng: ${a.text('penName').isEmpty ? 'Chưa có thông tin' : a.text('penName')}',
          ),
          const SizedBox(height: 10),
          if (isDeath)
            Text(
              'Vòng đời: ${label(a.text('status'))} · Sức khỏe: ${label(a.text('healthStatus'))}',
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FarmStatusBadge(
                label:
                    'Sức khỏe hiện tại: ${a.text('healthStatus').isEmpty ? 'Chưa có dữ liệu' : label(a.text('healthStatus'))}',
                tone: a.text('healthStatus') == 'NORMAL'
                    ? FarmBadgeTone.success
                    : a.text('healthStatus') == 'NEEDS_CARE'
                    ? FarmBadgeTone.warning
                    : FarmBadgeTone.neutral,
              ),
            ),
        ],
      ),
    );
  }

  Widget dateInput() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields['date'],
      enabled: !busy,
      readOnly: true,
      decoration: farmInputDecoration(
        label: isDeath ? 'Ngày chết' : 'Ngày thực hiện',
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: farmParseDate(fields['date']!.text) ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null && mounted) {
          setState(() {
            fields['date']!.text = farmDate(
              picked.toIso8601String().substring(0, 10),
            );
          });
        }
      },
      validator: (v) =>
          farmParseDate(v ?? '') == null ? 'Ngày không hợp lệ.' : null,
    ),
  );

  Widget weightInputs() {
    final previous = previousWeight;
    final baseline = previous == null
        ? null
        : grams(previous.values['kg'] as num);
    final current = grams(enteredWeight);
    final delta = baseline != null && current != null
        ? current - baseline
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FarmColors.sky,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (baseline == null)
                const Text('Chưa có bản ghi cân trước ngày đang chọn.')
              else ...[
                Text(
                  'Lần cân trước: ${weightText(baseline)} kg · ${farmDate(previous!.text('date'))}',
                ),
                if (delta != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Chênh lệch dự kiến: ${delta > 0 ? '+' : ''}${weightText(delta)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: fields['kg'],
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: farmInputDecoration(
            label: 'Cân nặng (kg)',
            helperText: 'Tối đa 3 số lẻ. Dùng dấu phẩy hoặc dấu chấm, không tách hàng nghìn.',
          ),
          onChanged: (_) => setState(() {}),
          validator: (_) {
            final n = enteredWeight;
            if (n == null || !n.isFinite || n <= 0) return 'Nhập số lớn hơn 0.';
            if (n > 100000) return 'Cân nặng tối đa 100000 kg.';
            if (grams(n) == null) return 'Tối đa ba chữ số thập phân.';
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget penInfo(FarmRecord pen, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FarmColors.peach.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('${pen.text('code')} · ${pen.text('name')}'),
          Text('${pen.integer('occupied')}/${pen.integer('capacity')} con'),
          if (penId == pen.id)
            Text(
              'Còn ${pen.integer('capacity') - pen.integer('occupied')} chỗ. Sức chứa được kiểm tra lại khi lưu.',
            ),
        ],
      ),
    ),
  );

  Widget transferInputs() {
    final current = widget.pens
        .where((p) => p.id == widget.animal.text('penId'))
        .firstOrNull;
    final selected = availablePens.where((p) => p.id == penId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) penInfo(current, 'Chuồng hiện tại'),
        if (availablePens.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Chưa có chuồng khác đang hoạt động và còn chỗ. Hãy liên hệ chủ trang trại.',
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: penId,
          isExpanded: true,
          decoration: farmInputDecoration(label: 'Chuồng mới'),
          items: [
            for (final p in availablePens)
              DropdownMenuItem(
                value: p.id,
                child: Text(
                  '${p.text('code')} · ${p.text('name')} (${p.integer('occupied')}/${p.integer('capacity')})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: busy ? null : (v) => setState(() => penId = v),
          validator: (v) =>
              availablePens.any((p) => p.id == v) ? null : 'Vui lòng chọn.',
        ),
        const SizedBox(height: 16),
        if (selected != null) penInfo(selected, 'Chuồng nhận'),
      ],
    );
  }

  Widget healthInputs() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          clinical ? 'Ghi nhận nội dung khám và chẩn đoán chuyên môn.' : 'Ghi nhận biểu hiện quan sát được. Nội dung này không phải chẩn đoán thú y.',
          style: const TextStyle(color: muted),
        ),
      ),
      input(
        'content',
        clinical ? 'Nội dung kiểm tra / điều trị' : 'Nội dung quan sát',
        requiredValue: true,
        lines: 3,
        limit: 100,
      ),
      DropdownButtonFormField<String>(
        initialValue: status,
        isExpanded: true,
        decoration: farmInputDecoration(label: 'Tình trạng'),
        items: const [
          DropdownMenuItem(value: 'NORMAL', child: Text('Bình thường')),
          DropdownMenuItem(value: 'NEEDS_CARE', child: Text('Cần chăm sóc')),
        ],
        onChanged: busy ? null : (v) => setState(() => status = v),
        validator: (v) => v == null ? 'Vui lòng chọn.' : null,
      ),
      const SizedBox(height: 16),
      if (clinical) ...[
        input('diagnosis', 'Chẩn đoán', requiredValue: true, lines: 3),
        input('treatment', 'Hướng dẫn điều trị', lines: 3, helper: 'Tùy chọn.'),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FarmFormLayout(
      title: widget.kind.title,
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed:
              busy ||
                  (widget.kind == AnimalEventKind.transfer &&
                      availablePens.isEmpty)
              ? null
              : submit,
          style: isDeath
              ? FilledButton.styleFrom(
                  backgroundColor: FarmColors.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          child: FarmSubmitLabel(busy: busy, label: widget.kind.action),
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
            animalHeader(),
            const SizedBox(height: 20),
            if (isDeath) ...[
              const FeedbackBox(
                'Ghi nhận chết sẽ kết thúc nuôi, giải phóng chỗ chuồng và hủy các lịch đang chờ. Lịch sử được giữ lại.',
              ),
              const SizedBox(height: 20),
            ],
            dateInput(),
            if (widget.kind == AnimalEventKind.weights) weightInputs(),
            if (widget.kind == AnimalEventKind.transfer) transferInputs(),
            if (widget.kind == AnimalEventKind.health || clinical)
              healthInputs(),
            input('notes', 'Ghi chú', lines: 3, helper: 'Tùy chọn.'),
          ],
        ),
      ),
    ),
  );
}
