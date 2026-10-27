import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'care_target_picker.dart';
import 'animal_selection_summary.dart';

Future<bool> careForm(
  BuildContext context,
  FarmRepository repo, {
  FarmRecord? animal,
  FarmRecord? task,
  List<FarmRecord>? selectedAnimals,
}) async {
  if (task != null && task.text('status') != 'PENDING') return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CareEditor(
          repository: repo,
          animal: animal,
          task: task,
          initialAnimals: selectedAnimals,
        ),
      ) ??
      false;
}

Future<bool> completeCareForm(
  BuildContext context,
  FarmRepository repo,
  FarmRecord task,
) async {
  if (task.text('status') != 'PENDING') return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            CareEditor(repository: repo, task: task, completing: true),
      ) ??
      false;
}

class CareTaskSummary extends StatelessWidget {
  const CareTaskSummary({super.key, required this.task});
  final FarmRecord task;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: FarmColors.mint.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          task.text('animalCode'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          task.text('title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${label(task.text('kind'))} · Hẹn ${farmDate(task.text('dueDate'))}',
        ),
        if (task.text('actorName').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Người tạo lịch: ${task.text('actorName')}'),
        ],
        if (task.text('notes').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Ghi chú lịch: ${task.text('notes')}'),
        ],
      ],
    ),
  );
}

class CareEditor extends StatefulWidget {
  const CareEditor({
    super.key,
    required this.repository,
    this.animal,
    this.task,
    this.completing = false,
    this.initialAnimals,
  });
  final FarmRepository repository;
  final FarmRecord? animal, task;
  final bool completing;
  final List<FarmRecord>? initialAnimals;
  @override
  State<CareEditor> createState() => _CareEditorState();
}

class _CareEditorState extends State<CareEditor> {
  final form = GlobalKey<FormState>();
  final errorAnchor = GlobalKey();
  late final requestId = FarmRepository.requestId();
  late final title = TextEditingController(
    text: widget.task?.text('title') ?? '',
  );
  late final notes = TextEditingController(
    text: widget.completing ? '' : widget.task?.text('notes') ?? '',
  );
  late final date = TextEditingController(
    text: farmDate(
      widget.completing
          ? farmToday()
          : widget.task?.text('dueDate') ?? farmToday(),
    ),
  );
  late String kind = widget.task?.text('kind') ?? 'CHECKUP';
  String status = 'NORMAL';
  String? error;
  String targetMode = 'animals';
  Set<String> selectedAnimals = {}, selectedPens = {};
  List<FarmRecord> animals = [];
  bool busy = false, loading = false, loadFailed = false;
  bool get choosingAnimal =>
      widget.animal == null &&
      widget.task == null &&
      widget.initialAnimals == null;
  bool get batch => widget.initialAnimals != null || choosingAnimal;
  List<String> get targetAnimalIds =>
      animals
          .where(
            (a) => targetMode == 'pens'
                ? selectedPens.contains(a.text('penId'))
                : selectedAnimals.contains(a.id),
          )
          .map((a) => a.id)
          .toSet()
          .toList()
        ..sort();
  List<FarmRecord> get penOptions {
    final grouped = <String, List<FarmRecord>>{};
    for (final a in animals) {
      if (a.text('penId').isNotEmpty) {
        grouped.putIfAbsent(a.text('penId'), () => []).add(a);
      }
    }
    return [
      for (final e in grouped.entries)
        FarmRecord({
          'id': e.key,
          'name': e.value.first.text('penName').isEmpty
              ? 'Chuồng chưa có tên'
              : e.value.first.text('penName'),
          'count': e.value.length,
        }),
    ]..sort((a, b) => a.text('name').compareTo(b.text('name')));
  }

  FarmRecord? get selectedAnimal => widget.animal;

  @override
  void initState() {
    super.initState();
    if (widget.initialAnimals != null) {
      animals = List.of(widget.initialAnimals!);
      selectedAnimals = animals.map((a) => a.id).toSet();
      targetMode = 'animals';
    }
    if (choosingAnimal) loadAnimals();
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> loadAnimals() async {
    if (busy || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = <FarmRecord>[];
      var page = 1, total = 0;
      do {
        final data = await widget.repository.get(
          '/animals?status=ACTIVE&pageSize=100&page=$page',
        );
        final batch = FarmRepository.records(data, 'animals');
        total = (data['total'] as num?)?.toInt() ?? 0;
        if (batch.isEmpty) {
          if (result.length < total) {
            throw const ApiException(
              'Chưa tải đủ danh sách vật nuôi. Hãy thử lại.',
            );
          }
          break;
        }
        result.addAll(batch);
        page++;
      } while (result.length < total);
      if (mounted) {
        setState(() {
          animals = result;
          loadFailed = false;
          selectedAnimals.retainAll(animals.map((a) => a.id));
          selectedPens.retainAll(penOptions.map((p) => p.id));
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loadFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (busy ||
        loading ||
        loadFailed ||
        (widget.task != null && widget.task!.text('status') != 'PENDING')) {
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
    final body = widget.completing
        ? <String, dynamic>{
            'date': farmIsoDate(date.text),
            'status': status,
            'notes': notes.text.trim(),
            'requestId': requestId,
          }
        : <String, dynamic>{
            if (widget.task == null && !batch) 'animalId': widget.animal!.id,
            if (batch) ...{
              'animalIds': targetAnimalIds,
              'requestId': requestId,
            },
            'kind': kind,
            'title': title.text.trim(),
            'dueDate': farmIsoDate(date.text),
            'notes': notes.text.trim(),
          };
    final path = batch
        ? '/care-tasks/batch'
        : '/care-tasks${widget.task == null ? '' : '/${widget.task!.id}'}${widget.completing ? '/complete' : ''}';
    try {
      await widget.repository.save(
        widget.task != null && !widget.completing ? 'PATCH' : 'POST',
        path,
        body,
      );
      if (mounted) {
        if (batch) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tạo ${targetAnimalIds.length} lịch chăm sóc.'),
            ),
          );
        }
        Navigator.pop(context, true);
      }
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

  Widget dropdown(
    String label,
    String? value,
    Map<String, String> options,
    ValueChanged<String?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${options.keys.join()}'),
      initialValue: value,
      isExpanded: true,
      decoration: farmInputDecoration(label: label),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: busy || loading ? null : changed,
      validator: (v) =>
          v == null || !options.containsKey(v) ? 'Vui lòng chọn.' : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = selectedAnimal;
    final submitLabel = widget.completing
        ? 'Xác nhận hoàn thành'
        : batch
        ? 'Tạo ${targetAnimalIds.length} lịch'
        : 'Lưu lịch';
    return PopScope(
      canPop: !busy,
      child: FarmFormLayout(
        title: widget.completing
            ? 'Hoàn thành chăm sóc'
            : widget.task == null
            ? 'Đặt lịch chăm sóc'
            : 'Sửa lịch chăm sóc',
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed:
                busy ||
                    loading ||
                    loadFailed ||
                    (choosingAnimal && animals.isEmpty)
                ? null
                : submit,
            child: FarmSubmitLabel(busy: busy, label: submitLabel),
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
              if (loading) const LinearProgressIndicator(),
              if (widget.initialAnimals != null) ...[
                AnimalSelectionSummary(animals: widget.initialAnimals!),
                const SizedBox(height: 20),
              ],
              if (loadFailed)
                TextButton.icon(
                  onPressed: loading ? null : loadAnimals,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử tải lại vật nuôi'),
                ),
              if (choosingAnimal) ...[
                if (!loading && !loadFailed && animals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Chưa có vật nuôi đang nuôi để đặt lịch.'),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in {
                      'animals': 'Chọn con vật',
                      'pens': 'Chọn chuồng',
                    }.entries)
                      ChoiceChip(
                        label: Text(mode.value),
                        selected: targetMode == mode.key,
                        onSelected: busy || loading
                            ? null
                            : (_) => setState(() => targetMode = mode.key),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (batch) ...[
                  if (widget.repository.selectedSpeciesIds.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Danh sách chỉ gồm các loài đang được chọn.'),
                    ),
                  if (targetMode == 'pens')
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Chọn chuồng để đặt lịch cho toàn bộ vật nuôi đang nuôi trong danh sách của chuồng đó.',
                      ),
                    ),
                  FormField<int>(
                    key: ValueKey('care-targets-$targetMode'),
                    validator: (_) => targetAnimalIds.isEmpty
                        ? 'Vui lòng chọn ít nhất một ${targetMode == 'pens' ? 'chuồng' : 'vật nuôi'}.'
                        : targetAnimalIds.length > 1000
                        ? 'Mỗi đợt tối đa 1.000 vật nuôi. Hãy chia thành các đợt nhỏ hơn.'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CareTargetPicker(
                          key: ValueKey(targetMode),
                          options: targetMode == 'pens' ? penOptions : animals,
                          selected: targetMode == 'pens'
                              ? selectedPens
                              : selectedAnimals,
                          pens: targetMode == 'pens',
                          enabled: !busy && !loading && !loadFailed,
                          onChanged: (selected) {
                            setState(() {
                              if (targetMode == 'pens') {
                                selectedPens = selected;
                              } else {
                                selectedAnimals = selected;
                              }
                            });
                            field.didChange(targetAnimalIds.length);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          targetMode == 'pens'
                              ? 'Đã chọn ${selectedPens.length} chuồng · ${targetAnimalIds.length} con'
                              : 'Đã chọn ${targetAnimalIds.length} con',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (field.hasError)
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mỗi con được tạo một lịch riêng để theo dõi và xác nhận kết quả.',
                  ),
                  const SizedBox(height: 20),
                ],
              ],
              if (a != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FarmColors.mint.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FarmAnimalImage(
                        photoData: a.text('imageData'),
                        speciesName: a.text('speciesName'),
                        size: 64,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.text('code'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (a.text('name').isNotEmpty) Text(a.text('name')),
                            if (a.text('speciesName').isNotEmpty)
                              Text(a.text('speciesName')),
                            if (a.text('penName').isNotEmpty)
                              Text('Chuồng: ${a.text('penName')}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (widget.task != null) ...[
                CareTaskSummary(task: widget.task!),
                const SizedBox(height: 20),
              ],
              if (!widget.completing) ...[
                dropdown('Loại việc', kind, const {
                  'CHECKUP': 'Kiểm tra sức khỏe',
                  'VACCINATION': 'Tiêm phòng',
                }, (v) => setState(() => kind = v!)),
                TextFormField(
                  controller: title,
                  enabled: !busy,
                  maxLength: 100,
                  maxLines: 2,
                  decoration: farmInputDecoration(
                    label: 'Nội dung / tên vaccine',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Vui lòng nhập.' : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: date,
                enabled: !busy,
                readOnly: true,
                decoration: farmInputDecoration(
                  label: widget.completing ? 'Ngày thực hiện' : 'Ngày hẹn',
                  helperText: widget.completing
                      ? 'Ngày thực tế đã thực hiện chăm sóc.'
                      : 'Chọn ngày chăm sóc.',
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: farmParseDate(date.text) ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
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
              if (widget.completing) ...[
                dropdown('Tình trạng sau chăm sóc', status, const {
                  'NORMAL': 'Bình thường',
                  'NEEDS_CARE': 'Cần chăm sóc',
                }, (v) => setState(() => status = v!)),
              ],
              TextFormField(
                controller: notes,
                enabled: !busy,
                maxLength: 2000,
                maxLines: 4,
                decoration: farmInputDecoration(
                  label: widget.completing ? 'Ghi chú kết quả' : 'Ghi chú',
                  helperText: 'Tùy chọn.',
                ),
              ),
              if (widget.completing) ...[
                const SizedBox(height: 8),
                const FeedbackBox(
                  'Khi xác nhận, lịch được hoàn thành và kết quả được lưu vào hồ sơ sức khỏe. Lịch đã hoàn thành không thể sửa.',
                  isError: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
