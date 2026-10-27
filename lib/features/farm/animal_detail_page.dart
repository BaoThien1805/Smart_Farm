import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_editor.dart';
import 'animal_qr_page.dart';
import 'animal_event_form.dart';
import 'farm_pages.dart' show WeightChart, careForm;
import 'farm_repository.dart';
import 'farm_widgets.dart';
import 'finance_page.dart';

class AnimalDetailPage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool canOperate, canCare, canExamine, canFinance;

  final String id;
  const AnimalDetailPage({
    super.key,
    required this.repository,
    required this.admin,
    required this.id,
    this.canOperate = true,
    this.canCare = true,
    this.canExamine = false,
    this.canFinance = false,
  });
  @override
  State<AnimalDetailPage> createState() => _AnimalDetailPageState();
}

class _AnimalDetailPageState extends State<AnimalDetailPage> {
  late final controller = FarmController(widget.repository);
  bool busy = false;
  int tab = 0, salesRevision = 0, loadRevision = 0;
  FarmRecord? get animal => controller.data['animal'] is Map
      ? FarmRecord(Map<String, dynamic>.from(controller.data['animal'] as Map))
      : null;
  Future<void> load({bool refreshSales = true}) async {
    final revision = ++loadRevision;
    await controller.load('/animals/${widget.id}', withCatalogs: true);
    if (mounted &&
        revision == loadRevision &&
        controller.error == null &&
        refreshSales) {
      setState(() => salesRevision++);
    }
  }

  bool get active => animal?.text('status') == 'ACTIVE';
  bool get canAct =>
      active && !busy && !controller.loading && controller.error == null;

  Future<void> editProfile() async {
    if (!canAct || !widget.canOperate) return;
    setState(() => busy = true);
    try {
      if (await animalForm(
            context,
            widget.repository,
            controller.catalogs,
            animal,
            widget.admin,
          ) &&
          mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> schedule() async {
    if (!canAct || !widget.canCare) return;
    setState(() => busy = true);
    try {
      if (await careForm(context, widget.repository, animal: animal) &&
          mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sell() async {
    if (!canAct || !widget.admin) return;
    setState(() => busy = true);
    try {
      if (await sellAnimalForm(
            context,
            widget.repository,
            animal!,
            admin: widget.admin,
          ) &&
          mounted) {
        setState(() => tab = 3);
        await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
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

  Future<void> event(String kind) async {
    final allowed = switch (kind) {
      'weights' || 'transfer' => widget.canOperate,
      'health' => widget.canCare,
      'exams' => widget.canExamine || widget.admin,
      'death' => widget.admin,
      _ => false,
    };
    if (!canAct || !allowed) return;
    setState(() => busy = true);
    try {
      final id = FarmRepository.requestId();
      if (kind == 'death' &&
          !await farmConfirm(
            context,
            'Ghi nhận chết sẽ kết thúc nuôi, giải phóng chỗ chuồng và hủy các lịch đang chờ. Lịch sử được giữ lại.',
          )) {
        return;
      }
      if (!mounted) return;
      final saved = await animalEventForm(
        context,
        repository: widget.repository,
        animal: animal!,
        kind: AnimalEventKind.values.byName(kind),
        pens: controller.catalog('pens'),
        weights: controller.items('weights'),
        requestId: id,
      );
      if (saved && mounted) await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    if (!canAct || !widget.admin) return;
    if (!await farmConfirm(
          context,
          'Xóa hồ sơ nhập nhầm? Chỉ xóa được vật nuôi chưa có lịch sử.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.save('DELETE', '/animals/${widget.id}', null);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget details(Map<String, String> values) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 650
          ? 3
          : constraints.maxWidth >= 250
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final entry in values.entries)
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: const TextStyle(color: muted)),
                  const SizedBox(height: 4),
                  Text(entry.value.isEmpty ? '—' : entry.value),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget header(FarmRecord a) => FarmInfoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FarmAnimalImage(
              photoData: a.text('imageData'),
              speciesName: a.text('speciesName'),
              size: 104,
              semanticLabel: 'Ảnh vật nuôi ${a.text('code')}',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.text('code'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (a.text('name').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.text('name')),
                  ],
                  OutlinedButton.icon(
                    key: const ValueKey('animal-show-qr'),
                    onPressed:
                        busy || controller.loading || controller.error != null
                        ? null
                        : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnimalQrPage(animal: a),
                            ),
                          ),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Thẻ QR'),
                  ),
                  if (active && widget.canOperate)
                    IconButton(
                      tooltip: 'Đổi ảnh qua chỉnh sửa hồ sơ',
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      onPressed: canAct ? editProfile : null,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FarmStatusBadge(
              label:
                  'Vòng đời: ${a.text('status').isEmpty ? 'Chưa có dữ liệu' : label(a.text('status'))}',
              tone: a.text('status') == 'ACTIVE'
                  ? FarmBadgeTone.success
                  : a.text('status') == 'SOLD'
                  ? FarmBadgeTone.info
                  : FarmBadgeTone.neutral,
            ),
            FarmStatusBadge(
              label:
                  'Sức khỏe: ${a.text('healthStatus').isEmpty ? 'Chưa có dữ liệu' : label(a.text('healthStatus'))}',
              tone: a.text('healthStatus') == 'NEEDS_CARE'
                  ? FarmBadgeTone.warning
                  : a.text('healthStatus') == 'NORMAL'
                  ? FarmBadgeTone.success
                  : FarmBadgeTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 20),
        details({
          'Loài': a.text('speciesName'),
          'Giống': a.text('breedName'),
          'Giới tính': label(a.text('gender')),
          'Chuồng': a.text('penName'),
        }),
      ],
    ),
  );

  Widget quickActions() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      const actionStyle = ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, 76)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
      );
      ButtonStyle tint(Color background, Color foreground) =>
          actionStyle.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? background.withValues(alpha: .5)
                  : background,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.disabled) ? muted : foreground,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Colors.transparent),
            ),
          );
      final actions = <Widget>[
        if (widget.canOperate) ...[
          FilledButton.icon(
            style: tint(FarmColors.sky, FarmColors.blue),
            onPressed: canAct ? () => event('weights') : null,
            icon: const Icon(Icons.monitor_weight_outlined),
            label: const Text('Ghi cân nặng'),
          ),
          OutlinedButton.icon(
            style: tint(FarmColors.peach, FarmColors.coral),
            onPressed: canAct ? () => event('transfer') : null,
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('Chuyển chuồng'),
          ),
        ],
        if (widget.canCare)
          FilledButton.icon(
            style: tint(FarmColors.lavender, FarmColors.lilac),
            onPressed: canAct ? () => event('health') : null,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Ghi sức khỏe'),
          ),
        if (widget.canExamine || widget.admin)
          FilledButton.icon(
            style: tint(FarmColors.mint, forest),
            onPressed: canAct ? () => event('exams') : null,
            icon: const Icon(Icons.medical_services_outlined),
            label: const Text('Khám thú y'),
          ),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final action in actions) SizedBox(width: width, child: action),
        ],
      );
    },
  );

  Widget information(FarmRecord a) {
    String area = '';
    for (final pen
        in controller.catalog('pens').where((p) => p.id == a.text('penId'))) {
      for (final region
          in controller
              .catalog('areas')
              .where((r) => r.id == pen.text('areaId'))) {
        area = region.text('name');
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FarmInfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FarmSectionHeader(title: 'Thông tin chung'),
              const SizedBox(height: 20),
              details({
                if (area.isNotEmpty) 'Khu vực': area,
                'Ngày sinh': farmDate(a.text('birthDate')),
                'Nhập đàn': farmDate(a.text('arrivalDate')),
                if (a.text('endedDate').isNotEmpty)
                  'Kết thúc nuôi': farmDate(a.text('endedDate')),
                'Nguồn gốc': a.text('origin'),
              }),
              const SizedBox(height: 20),
              const Text('Ghi chú', style: TextStyle(color: muted)),
              const SizedBox(height: 4),
              Text(
                a.text('notes').isEmpty ? 'Chưa có ghi chú.' : a.text('notes'),
              ),
            ],
          ),
        ),
        if (active &&
            (widget.canOperate || widget.canCare || widget.admin)) ...[
          const SizedBox(height: 16),
          FarmInfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FarmSectionHeader(title: 'Thao tác hồ sơ'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (widget.canOperate)
                      OutlinedButton(
                        onPressed: canAct ? editProfile : null,
                        child: const Text('Sửa hồ sơ'),
                      ),
                    if (widget.canCare)
                      OutlinedButton(
                        onPressed: canAct ? schedule : null,
                        child: const Text('Đặt lịch chăm sóc'),
                      ),
                    if (widget.admin) ...[
                      FilledButton(
                        onPressed: canAct ? sell : null,
                        child: const Text('Bán vật nuôi'),
                      ),
                      OutlinedButton(
                        onPressed: canAct ? () => event('death') : null,
                        child: const Text('Ghi nhận chết'),
                      ),
                      IconButton(
                        tooltip: 'Xóa hồ sơ nhập nhầm',
                        onPressed: canAct ? remove : null,
                        icon: const Icon(Icons.delete_outline),
                        color: FarmColors.danger,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget recordCard({
    required String title,
    required String date,
    required String body,
    String actor = '',
    String actorLabel = 'Người thực hiện',
    IconData icon = Icons.event_note_outlined,
    Color color = FarmColors.mint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FarmInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color,
                foregroundColor: forest,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(farmDate(date), style: const TextStyle(color: muted)),
          if (actor.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('$actorLabel: $actor', style: const TextStyle(color: muted)),
          ],
          if (body.isNotEmpty) ...[const SizedBox(height: 8), Text(body)],
        ],
      ),
    ),
  );

  String healthBody(FarmRecord h) => [
    h.text('content'),
    'Tình trạng: ${label(h.text('status'))}',
    if (h.text('notes').isNotEmpty) 'Ghi chú: ${h.text('notes')}',
    if (h.text('recordType') == 'EXAM') ...[
      'Chẩn đoán: ${h.text('diagnosis')}',
      'Hướng dẫn điều trị: ${h.text('treatment').isEmpty ? '—' : h.text('treatment')}',
    ],
  ].where((s) => s.isNotEmpty).join('\n');

  Widget weights() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FarmSectionHeader(title: 'Tăng trưởng (kg)'),
      const SizedBox(height: 16),
      if (controller.items('weights').length >= 2)
        WeightChart(records: controller.items('weights')),
      if (controller.items('weights').isEmpty)
        const FarmInfoCard(
          color: FarmColors.sky,
          child: Text('Chưa ghi cân nặng.'),
        ),
      for (final w in controller.items('weights').reversed)
        recordCard(
          title: '${w.number('kg')} kg',
          date: w.text('date'),
          actor: w.text('actorName'),
          body: w.text('notes'),
          icon: Icons.monitor_weight_outlined,
          color: FarmColors.sky,
        ),
    ],
  );

  Widget health() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const FarmSectionHeader(title: 'Lịch sử sức khỏe'),
      const SizedBox(height: 16),
      if (controller.items('healthRecords').isEmpty)
        const FarmInfoCard(
          color: FarmColors.sky,
          child: Text('Chưa có lần kiểm tra / điều trị.'),
        ),
      for (final h in controller.items('healthRecords'))
        recordCard(
          title: h.text('recordType') == 'EXAM'
              ? 'Khám thú y'
              : 'Ghi nhận sức khỏe',
          date: h.text('date'),
          actor: h.text('actorName'),
          body: healthBody(h),
          icon: Icons.medical_services_outlined,
          color: FarmColors.lavender,
        ),
    ],
  );

  Widget history() {
    final events =
        <
          ({
            String date,
            String kind,
            String title,
            String body,
            String actor,
            String actorLabel,
            IconData icon,
            Color color,
          })
        >[
          for (final w in controller.items('weights'))
            (
              date: w.text('date'),
              kind: 'weights',
              title: 'Ghi cân: ${w.number('kg')} kg',
              body: w.text('notes'),
              actor: w.text('actorName'),
              actorLabel: 'Người thực hiện',
              icon: Icons.monitor_weight_outlined,
              color: FarmColors.sky,
            ),
          for (final t in controller.items('transfers'))
            (
              date: t.text('date'),
              kind: 'transfer',
              title: 'Chuyển chuồng',
              body:
                  'Từ ${t.text('fromPenName')} đến ${t.text('toPenName')}${t.text('notes').isEmpty ? '' : '\n${t.text('notes')}'}',
              actor: t.text('actorName'),
              actorLabel: 'Người thực hiện',
              icon: Icons.home_work_outlined,
              color: FarmColors.peach,
            ),
          for (final h in controller.items('healthRecords'))
            (
              date: h.text('date'),
              kind: 'health',
              title: h.text('recordType') == 'EXAM'
                  ? 'Khám thú y'
                  : 'Ghi nhận sức khỏe',
              body: healthBody(h),
              actor: h.text('actorName'),
              actorLabel: 'Người thực hiện',
              icon: Icons.health_and_safety_outlined,
              color: FarmColors.lavender,
            ),
          for (final t in controller.items('careTasks'))
            (
              date:
                  t.text('status') == 'DONE' && t.text('actualDate').isNotEmpty
                  ? t.text('actualDate')
                  : t.text('dueDate'),
              kind: 'care',
              title: 'Lịch chăm sóc: ${t.text('title')}',
              body:
                  '${label(t.text('kind'))} · ${label(t.text('status'))}\nNgày hẹn: ${farmDate(t.text('dueDate'))}'
                  '${t.text('actualDate').isEmpty ? '' : '\nThực hiện: ${farmDate(t.text('actualDate'))}'}'
                  '${t.text('notes').isEmpty ? '' : '\n${t.text('notes')}'}',
              actor: t.text('actorName'),
              actorLabel: 'Người tạo lịch',
              icon: Icons.event_note_outlined,
              color: FarmColors.mint,
            ),
        ];
    events.sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FarmSectionHeader(
          title: 'Hoạt động cá thể',
          subtitle:
              'Theo ngày của bản ghi; lịch chưa hoàn thành dùng ngày hẹn.',
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          const FarmInfoCard(
            color: FarmColors.sky,
            child: Text(
              'Chưa có bản ghi cân, chuyển chuồng, sức khỏe hoặc lịch chăm sóc.',
            ),
          ),
        for (var index = 0; index < events.length; index++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: forest,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index < events.length - 1)
                        Expanded(child: Container(width: 2, color: line)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: recordCard(
                    title: events[index].title,
                    date: events[index].kind == 'care'
                        ? 'Ngày của lịch: ${events[index].date}'
                        : events[index].date,
                    actor: events[index].actor,
                    actorLabel: events[index].actorLabel,
                    body: events[index].body,
                    icon: events[index].icon,
                    color: events[index].color,
                  ),
                ),
              ],
            ),
          ),
        if (widget.admin || widget.canFinance) ...[
          const SizedBox(height: 16),
          FarmInfoCard(
            key: const ValueKey('profile-sales'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FarmSectionHeader(
                  title: 'Lịch sử giao dịch bán',
                  subtitle: 'Ngày bán, khoản thu và thông tin hủy bán.',
                ),
                const SizedBox(height: 16),
                SalesHistory(
                  repository: widget.repository,
                  animalId: widget.id,
                  admin: widget.admin,
                  revision: salesRevision,
                  onChanged: () {
                    setState(() => tab = 0);
                    load(refreshSales: false);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ vật nuôi')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final a = animal;
        return FarmBody(
          controller: controller,
          title: '',
          refresh: load,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                tooltip: 'Tải lại hồ sơ',
                onPressed: controller.loading || busy ? null : load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            if (a == null && !controller.loading && controller.error == null)
              const FarmInfoCard(
                color: FarmColors.sky,
                child: Text('Chưa có dữ liệu hồ sơ.'),
              ),
            if (a != null) ...[
              if (controller.error != null) ...[
                const FarmInfoCard(
                  color: FarmColors.amber,
                  child: Text(
                    'Đang hiển thị hồ sơ từ lần tải trước. Hãy thử tải lại.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              header(a),
              const SizedBox(height: 16),
              if (active) ...[quickActions(), const SizedBox(height: 16)],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    0: 'Thông tin',
                    1: 'Cân nặng',
                    2: 'Sức khỏe',
                    3: 'Lịch sử',
                  }.entries)
                    ChoiceChip(
                      key: ValueKey('profile-tab-${entry.key}'),
                      label: Text(entry.value),
                      selected: tab == entry.key,
                      onSelected: (_) => setState(() => tab = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              for (final entry in [
                information(a),
                weights(),
                health(),
                history(),
              ].asMap().entries)
                Offstage(
                  key: ValueKey('profile-section-${entry.key}'),
                  offstage: tab != entry.key,
                  child: TickerMode(
                    enabled: tab == entry.key,
                    child: entry.value,
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}
