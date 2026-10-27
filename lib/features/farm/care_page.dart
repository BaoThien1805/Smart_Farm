import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_detail_page.dart';
import 'care_forms.dart';
import 'farm_repository.dart';
import 'farm_widgets.dart';

class CarePage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool canOperate, canCare, canExamine, canFinance;
  final int refreshRevision;
  const CarePage({
    super.key,
    required this.repository,
    required this.admin,
    this.canOperate = true,
    this.canCare = true,
    this.canExamine = false,
    this.canFinance = false,
    this.refreshRevision = 0,
  });
  @override
  State<CarePage> createState() => _CarePageState();
}

class _CarePageState extends State<CarePage> {
  late final controller = FarmController(widget.repository);
  String status = 'PENDING';
  int page = 1;
  bool busy = false;
  bool get canWrite => !busy && !controller.loading && controller.error == null;
  Future<void> load() async {
    await controller.load(
      '/care-tasks?page=$page${status.isEmpty ? '' : '&status=$status'}',
    );
    if (mounted &&
        controller.error == null &&
        controller.items('tasks').isEmpty &&
        page > 1) {
      final total = (controller.data['total'] as num?)?.toInt() ?? 0;
      page = ((total - 1) ~/ 20 + 1).clamp(1, page - 1);
      await controller.load(
        '/care-tasks?page=$page${status.isEmpty ? '' : '&status=$status'}',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant CarePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> edit([FarmRecord? task]) async {
    if (!canWrite ||
        !widget.canCare ||
        (task != null && task.text('status') != 'PENDING')) {
      return;
    }
    setState(() => busy = true);
    try {
      if (await careForm(context, widget.repository, task: task) && mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> complete(FarmRecord task) async {
    if (!canWrite ||
        !widget.canCare ||
        !(widget.admin || widget.canExamine) ||
        task.text('status') != 'PENDING') {
      return;
    }
    setState(() => busy = true);
    try {
      if (await completeCareForm(context, widget.repository, task) && mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancel(FarmRecord task) async {
    if (!canWrite || !widget.canCare || task.text('status') != 'PENDING') {
      return;
    }
    setState(() => busy = true);
    try {
      if (!await farmConfirm(
            context,
            'Hủy lịch ${task.text('title')}? Lịch được giữ trong lịch sử với trạng thái Đã hủy.',
          ) ||
          !mounted) {
        return;
      }
      await widget.repository.save(
        'POST',
        '/care-tasks/${task.id}/cancel',
        null,
      );
      if (mounted) await load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openProfile(FarmRecord task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AnimalDetailPage(
            repository: widget.repository,
            admin: widget.admin,
            id: task.text('animalId'),
            canOperate: widget.canOperate,
            canCare: widget.canCare,
            canExamine: widget.canExamine,
            canFinance: widget.canFinance,
          ),
        ),
      );
      if (mounted) await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget taskCard(FarmRecord task, String today) {
    final pending = task.text('status') == 'PENDING';
    final overdue =
        pending &&
        task.text('dueDate').isNotEmpty &&
        task.text('dueDate').compareTo(today) < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FarmInfoCard(
        key: ValueKey('care-task-${task.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: task.text('kind') == 'VACCINATION'
                        ? FarmColors.sky
                        : FarmColors.lavender,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    task.text('kind') == 'VACCINATION'
                        ? Icons.vaccines_outlined
                        : Icons.health_and_safety_outlined,
                    color: forest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.text('title'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(task.text('animalCode')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FarmStatusBadge(
                  label: label(task.text('status')),
                  tone: pending
                      ? FarmBadgeTone.info
                      : task.text('status') == 'DONE'
                      ? FarmBadgeTone.success
                      : FarmBadgeTone.neutral,
                ),
                if (overdue)
                  const FarmStatusBadge(
                    label: 'Quá hạn',
                    tone: FarmBadgeTone.warning,
                    icon: Icons.schedule,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${label(task.text('kind'))} · Hẹn ${farmDate(task.text('dueDate'))}',
            ),
            if (task.text('actualDate').isNotEmpty)
              Text('Ngày thực hiện: ${farmDate(task.text('actualDate'))}'),
            if (task.text('actorName').isNotEmpty)
              Text('Người tạo lịch: ${task.text('actorName')}'),
            if (task.text('notes').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ghi chú lịch: ${task.text('notes')}'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => openProfile(task),
                  child: const Text('Hồ sơ vật nuôi'),
                ),
                if (pending && widget.canCare) ...[
                  if (widget.admin || widget.canExamine)
                    FilledButton(
                      onPressed: canWrite ? () => complete(task) : null,
                      child: const Text('Hoàn thành'),
                    ),
                  TextButton(
                    onPressed: canWrite ? () => edit(task) : null,
                    child: const Text('Sửa lịch'),
                  ),
                  TextButton(
                    onPressed: canWrite ? () => cancel(task) : null,
                    child: const Text('Hủy lịch'),
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final groups = <String, List<FarmRecord>>{};
      for (final task in controller.items('tasks')) {
        groups.putIfAbsent(task.text('dueDate'), () => []).add(task);
      }
      final days = groups.keys.toList()..sort();
      final today = controller.data['today']?.toString() ?? farmToday();
      final total = (controller.data['total'] as num?)?.toInt() ?? 0;
      return FarmBody(
        controller: controller,
        title: 'Lịch chăm sóc',
        refresh: () {
          if (!busy) load();
        },
        actions: [
          if (widget.canCare)
            FilledButton.icon(
              onPressed: canWrite ? () => edit() : null,
              icon: const Icon(Icons.add),
              label: Text(busy ? 'Đang xử lý…' : 'Đặt lịch'),
            ),
        ],
        children: [
          Text('Ngày ${farmDate(today)}', style: const TextStyle(color: muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ['PENDING', 'DONE', 'CANCELLED', ''])
                ChoiceChip(
                  label: Text(s.isEmpty ? 'Tất cả' : label(s)),
                  selected: status == s,
                  onSelected: busy || controller.loading
                      ? null
                      : (_) {
                          setState(() {
                            status = s;
                            page = 1;
                          });
                          load();
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.error != null && controller.data.isNotEmpty) ...[
            const Text(
              'Đang hiển thị lịch từ lần tải trước. Tải lại thành công để tiếp tục chỉnh sửa.',
            ),
            const SizedBox(height: 16),
          ],
          if (controller.error == null && !controller.loading) ...[
            Text(
              '$total lịch · ${status.isEmpty ? 'Tất cả trạng thái' : label(status)}',
            ),
            const SizedBox(height: 16),
            if (groups.isEmpty)
              FarmEmptyState(
                icon: Icons.event_available_outlined,
                message: 'Không có lịch chăm sóc.',
                description: status.isEmpty
                    ? 'Các lịch đã đặt sẽ xuất hiện tại đây.'
                    : 'Chưa có lịch ở trạng thái đang chọn.',
              ),
          ],
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Semantics(
                header: true,
                child: Text(
                  day.isEmpty
                      ? 'Chưa có ngày hẹn'
                      : 'Ngày hẹn ${farmDate(day)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final task in groups[day]!) taskCard(task, today),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Trang trước',
                onPressed: busy || controller.loading || page <= 1
                    ? null
                    : () {
                        setState(() => page--);
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Text(
                  'Trang $page · $total kết quả',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Trang sau',
                onPressed: busy || controller.loading || page * 20 >= total
                    ? null
                    : () {
                        setState(() => page++);
                        load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
    },
  );
}
