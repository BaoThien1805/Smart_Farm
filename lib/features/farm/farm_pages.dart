export 'dashboard_page.dart';
import 'finance_page.dart';

import '../../core/photo_view.dart';

import 'species_chooser.dart';
import 'animal_editor.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'farm_repository.dart';
import 'farm_widgets.dart';

class CatalogPage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final String initialKind;
  const CatalogPage({
    super.key,
    required this.repository,
    required this.admin,
    this.initialKind = 'pens',
  });
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final controller = FarmController(widget.repository);
  late String kind = widget.initialKind;
  bool busy = false;
  void load() => controller.load('/farm/catalogs', withCatalogs: true);
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

  Future<void> edit([FarmRecord? item]) async {
    final fields = [
      FarmField(
        'code',
        'Mã ${kind == 'pens'
            ? 'chuồng'
            : kind == 'areas'
            ? 'khu vực'
            : kind == 'breeds'
            ? 'giống'
            : 'loài'}',
        initial: item?.text('code') ?? '',
        requiredValue: kind == 'pens',
      ),
      FarmField('name', 'Tên', initial: item?.text('name') ?? ''),
      if (kind == 'breeds')
        FarmField(
          'speciesId',
          'Loài',
          initial: item?.text('speciesId') ?? '',
          options: recordOptions(controller.catalog('species')),
        ),
      if (kind == 'pens') ...[
        FarmField(
          'areaId',
          'Khu vực',
          initial: item?.text('areaId') ?? '',
          options: recordOptions(controller.catalog('areas')),
        ),
        FarmField(
          'capacity',
          'Sức chứa (con)',
          initial: item?.text('capacity') ?? '10',
          numeric: true,
        ),
        FarmField(
          'active',
          'Đang sử dụng',
          initial: item?.text('active') ?? 'true',
          boolean: true,
        ),
      ],
    ];
    final saved = await farmForm(
      context,
      title: item == null ? 'Thêm danh mục' : 'Sửa danh mục',
      fields: fields,
      codeApi: widget.repository.api,
      codeKind: kind,
      save: (b) => widget.repository.save(
        item == null ? 'POST' : 'PATCH',
        '/farm/$kind${item == null ? '' : '/${item.id}'}',
        b,
      ),
    );
    if (saved && mounted) load();
  }

  Future<void> remove(FarmRecord item) async {
    if (!await farmConfirm(
          context,
          'Xóa ${item.text('name')}? Danh mục đã có dữ liệu liên quan sẽ không thể xóa.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.save('DELETE', '/farm/$kind/${item.id}', null);
      load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: 'Chuồng & danh mục',
      refresh: load,
      actions: [
        if (widget.admin)
          FilledButton.icon(
            onPressed: controller.loading ? null : () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm'),
          ),
      ],
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final e in {
              'pens': 'Chuồng',
              'areas': 'Khu vực',
              'species': 'Loài',
              'breeds': 'Giống',
            }.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: kind == e.key,
                onSelected: (_) => setState(() => kind = e.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!controller.loading && controller.items(kind).isEmpty)
          const Text(
            'Chưa có dữ liệu. Tạo loài → giống; khu vực → chuồng trước khi thêm vật nuôi.',
          ),
        for (final item in controller.items(kind))
          Card(
            child: ListTile(
              title: Text(
                '${item.text('code').isNotEmpty ? '${item.text('code')} · ' : ''}${item.text('name')}',
              ),
              subtitle: Text(
                kind == 'pens'
                    ? '${item.integer('occupied')}/${item.integer('capacity')} con · ${item.flag('active') ? 'Đang sử dụng' : 'Ngừng sử dụng'}'
                    : kind == 'breeds'
                    ? controller
                          .catalog('species')
                          .where((s) => s.id == item.text('speciesId'))
                          .map((s) => s.text('name'))
                          .join()
                    : '',
              ),
              trailing: widget.admin
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sửa',
                          onPressed: busy ? null : () => edit(item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          onPressed: busy ? null : () => remove(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    ),
  );
}

class AnimalsPage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool canOperate, canCare, canExamine, canFinance;
  const AnimalsPage({
    super.key,
    required this.repository,
    required this.admin,
    this.canOperate = true,
    this.canCare = true,
    this.canExamine = false,
    this.canFinance = false,
  });
  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  late final controller = FarmController(widget.repository);
  final search = TextEditingController();
  Timer? debounce;
  int page = 1;
  String status = 'ACTIVE';
  String? speciesId, penId, healthStatus;
  void load() {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'search': search.text.trim(),
        if (status.isNotEmpty) 'status': status,
        'speciesId': ?speciesId,
        'penId': ?penId,
        'healthStatus': ?healthStatus,
      },
    ).query;
    controller.load('/animals?$query', withCatalogs: true);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (await animalForm(
          context,
          widget.repository,
          controller.catalogs,
          null,
          widget.admin,
        ) &&
        mounted) {
      load();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: 'Đàn vật nuôi',
      refresh: load,
      actions: [
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Trang trại')),
                    body: CatalogPage(
                      repository: widget.repository,
                      admin: widget.admin,
                    ),
                  ),
                ),
              ).then((_) {
                if (mounted) load();
              }),
          icon: const Icon(Icons.home_work_outlined),
          label: const Text('Chuồng & danh mục'),
        ),
        if (widget.canOperate)
          FilledButton.icon(
            onPressed: controller.loading ? null : create,
            icon: const Icon(Icons.add),
            label: const Text('Thêm vật nuôi'),
          ),
      ],
      children: [
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'Tìm theo mã / tên vật nuôi',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 350), () {
              page = 1;
              load();
            });
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: ExpansionTile(
            initiallyExpanded: MediaQuery.sizeOf(context).width >= 700,
            leading: const Icon(Icons.filter_list),
            title: const Text('Bộ lọc vật nuôi'),
            subtitle: Text(
              '${status.isEmpty ? 'Tất cả' : label(status)} · ${controller.data['total'] ?? 0} kết quả',
            ),
            shape: const Border(),
            collapsedShape: const Border(),
            childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filter(
                    'Trạng thái',
                    status,
                    {
                      '': 'Tất cả',
                      'ACTIVE': 'Đang nuôi',
                      'DEAD': 'Đã chết',
                      'SOLD': 'Đã bán',
                    },
                    (v) {
                      status = v ?? '';
                      page = 1;
                      load();
                    },
                  ),
                  _filter(
                    'Loài',
                    speciesId,
                    recordOptions(controller.catalog('species')),
                    (v) {
                      speciesId = v;
                      page = 1;
                      load();
                    },
                    all: true,
                  ),
                  _filter(
                    'Chuồng',
                    penId,
                    recordOptions(controller.catalog('pens')),
                    (v) {
                      penId = v;
                      page = 1;
                      load();
                    },
                    all: true,
                  ),
                  _filter(
                    'Sức khỏe',
                    healthStatus,
                    {'NORMAL': 'Bình thường', 'NEEDS_CARE': 'Cần chăm sóc'},
                    (v) {
                      healthStatus = v;
                      page = 1;
                      load();
                    },
                    all: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!controller.loading && controller.items('animals').isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không có vật nuôi phù hợp.'),
          ),
        for (final a in controller.items('animals'))
          Card(
            child: ListTile(
              leading: animalAvatar(a),
              title: Text('${a.text('code')} · ${a.text('speciesName')}'),
              subtitle: Text(
                '${a.text('breedName')} · ${a.text('penName')}\n${label(a.text('status'))} · ${label(a.text('healthStatus'))}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AnimalDetailPage(
                      repository: widget.repository,
                      admin: widget.admin,
                      canOperate: widget.canOperate,
                      canCare: widget.canCare,
                      canExamine: widget.canExamine,
                      canFinance: widget.canFinance,
                      id: a.id,
                    ),
                  ),
                );
                if (mounted) load();
              },
            ),
          ),
        _pagination(
          page,
          (controller.data['total'] as num?)?.toInt() ?? 0,
          20,
          controller.loading,
          (p) {
            page = p;
            load();
          },
        ),
      ],
    ),
  );
}

Widget _filter(
  String title,
  String? selected,
  Map<String, String> options,
  ValueChanged<String?> changed, {
  bool all = false,
}) => SizedBox(
  width: 210,
  child: DropdownButtonFormField<String>(
    key: ValueKey('$title-$selected-${options.keys.join()}'),
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: title),
    items: [
      if (all)
        const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
      for (final e in options.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: changed,
  ),
);
Widget _pagination(
  int page,
  int total,
  int size,
  bool busy,
  ValueChanged<int> changed,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 20),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Trang trước',
        onPressed: busy || page <= 1 ? null : () => changed(page - 1),
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
        onPressed: busy || page * size >= total
            ? null
            : () => changed(page + 1),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  ),
);

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
  FarmRecord? get animal => controller.data['animal'] is Map
      ? FarmRecord(Map<String, dynamic>.from(controller.data['animal'] as Map))
      : null;
  void load() => controller.load('/animals/${widget.id}', withCatalogs: true);
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
    final id = FarmRepository.requestId();
    final fields = [
      FarmField(
        'date',
        kind == 'death' ? 'Ngày chết' : 'Ngày thực hiện',
        initial: farmToday(),
        date: true,
      ),
      if (kind == 'weights')
        const FarmField('kg', 'Cân nặng (kg)', numeric: true),
      if (kind == 'transfer')
        FarmField(
          'penId',
          'Chuồng mới',
          options: {
            for (final p
                in controller
                    .catalog('pens')
                    .where(
                      (p) =>
                          p.flag('active') &&
                          p.id != animal!.text('penId') &&
                          p.integer('occupied') < p.integer('capacity'),
                    ))
              p.id:
                  '${p.text('code')} · ${p.text('name')} (${p.integer('occupied')}/${p.integer('capacity')})',
          },
        ),
      if (kind == 'health' || kind == 'exams') ...[
        const FarmField('content', 'Nội dung kiểm tra / điều trị'),
        FarmField(
          'status',
          'Tình trạng',
          initial: animal!.text('healthStatus'),
          options: {'NORMAL': 'Bình thường', 'NEEDS_CARE': 'Cần chăm sóc'},
        ),
      ],
      if (kind == 'exams') ...[
        const FarmField('diagnosis', 'Chẩn đoán'),
        const FarmField(
          'treatment',
          'Hướng dẫn điều trị',
          requiredValue: false,
        ),
      ],
      const FarmField('notes', 'Ghi chú', requiredValue: false),
    ];
    if (kind == 'death' &&
        !await farmConfirm(
          context,
          'Ghi nhận chết sẽ kết thúc nuôi, giải phóng chỗ chuồng và hủy các lịch đang chờ. Lịch sử được giữ lại.',
        )) {
      return;
    }
    if (!mounted) return;
    final saved = await farmForm(
      context,
      title: {
        'weights': 'Ghi cân nặng',
        'transfer': 'Chuyển chuồng',
        'health': 'Ghi sức khỏe',
        'exams': 'Khám thú y',
        'death': 'Ghi nhận chết',
      }[kind]!,
      fields: fields,
      save: (b) => widget.repository.save(
        'POST',
        '/animals/${widget.id}/$kind',
        {...b, 'requestId': id},
      ),
    );
    if (saved && mounted) load();
  }

  Future<void> remove() async {
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ vật nuôi')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final a = animal;
        return FarmBody(
          controller: controller,
          title: a?.text('code') ?? 'Đang tải hồ sơ',
          refresh: load,
          actions: [
            if (a != null &&
                a.text('status') == 'ACTIVE' &&
                !controller.loading) ...[
              if (widget.canOperate)
                OutlinedButton(
                  onPressed: () async {
                    if (await animalForm(
                          context,
                          widget.repository,
                          controller.catalogs,
                          a,
                          widget.admin,
                        ) &&
                        mounted) {
                      load();
                    }
                  },
                  child: const Text('Sửa hồ sơ'),
                ),
              if (widget.canOperate)
                OutlinedButton(
                  onPressed: () => event('transfer'),
                  child: const Text('Chuyển chuồng'),
                ),
              if (widget.canOperate)
                FilledButton(
                  onPressed: () => event('weights'),
                  child: const Text('Ghi cân nặng'),
                ),
              if (widget.canCare)
                FilledButton(
                  onPressed: () => event('health'),
                  child: const Text('Ghi sức khỏe'),
                ),
              if (widget.canExamine || widget.admin)
                FilledButton.icon(
                  onPressed: () => event('exams'),
                  icon: const Icon(Icons.medical_services_outlined),
                  label: const Text('Khám thú y'),
                ),
              if (widget.canCare)
                OutlinedButton(
                  onPressed: () async {
                    if (await careForm(context, widget.repository, animal: a) &&
                        mounted) {
                      load();
                    }
                  },
                  child: const Text('Đặt lịch chăm sóc'),
                ),
              if (widget.admin) ...[
                FilledButton(
                  onPressed: () async {
                    if (await sellAnimalForm(
                          context,
                          widget.repository,
                          widget.id,
                        ) &&
                        mounted) {
                      load();
                    }
                  },
                  child: const Text('Bán vật nuôi'),
                ),
                OutlinedButton(
                  onPressed: () => event('death'),
                  child: const Text('Ghi nhận chết'),
                ),
                IconButton(
                  tooltip: 'Xóa hồ sơ nhập nhầm',
                  onPressed: busy ? null : remove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ],
          children: [
            if (a != null && (widget.admin || widget.canFinance)) ...[
              SalesHistory(
                key: ValueKey(
                  'sales-${a.text('status')}-${a.text('endedDate')}',
                ),
                repository: widget.repository,
                animalId: widget.id,
                admin: widget.admin,
                onChanged: load,
              ),
              const SizedBox(height: 20),
            ],
            if (a != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      animalAvatar(a, size: 112),
                      for (final e in {
                        'speciesName': 'Loài',
                        'breedName': 'Giống',
                        'name': 'Tên / số hiệu',
                        'gender': 'Giới tính',
                        'penName': 'Chuồng',
                        'birthDate': 'Ngày sinh',
                        'arrivalDate': 'Nhập đàn',
                        'status': 'Trạng thái',
                        'healthStatus': 'Sức khỏe',
                        'endedDate': 'Kết thúc nuôi',
                        'origin': 'Nguồn gốc',
                        'notes': 'Ghi chú',
                      }.entries)
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width < 600
                              ? (MediaQuery.sizeOf(context).width - 104) / 2
                              : 220,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.value,
                                style: const TextStyle(color: muted),
                              ),
                              Text(
                                a.text(e.key).isEmpty
                                    ? '—'
                                    : label(a.text(e.key)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tăng trưởng (kg)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.items('weights').length >= 2)
                WeightChart(records: controller.items('weights')),
              if (controller.items('weights').isEmpty)
                const Text('Chưa ghi cân nặng.'),
              for (final w in controller.items('weights'))
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text('${w.text('date')} · ${w.number('kg')} kg'),
                  subtitle: Text('${w.text('notes')} · ${w.text('actorName')}'),
                ),
              const Divider(),
              Text(
                'Lịch sử sức khỏe',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.items('healthRecords').isEmpty)
                const Text('Chưa có lần kiểm tra / điều trị.'),
              for (final h in controller.items('healthRecords'))
                ListTile(
                  title: Text('${h.text('date')} · ${h.text('content')}'),
                  subtitle: Text(
                    '${label(h.text('status'))} · ${h.text('notes')} · ${h.text('actorName')}'
                    '${h.text('recordType') == 'EXAM' ? '\nChẩn đoán: ${h.text('diagnosis')}\nHướng dẫn điều trị: ${h.text('treatment').isEmpty ? '—' : h.text('treatment')}' : ''}',
                  ),
                ),
              const Divider(),
              Text(
                'Lịch sử chuyển chuồng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.items('transfers').isEmpty)
                const Text('Chưa chuyển chuồng.'),
              for (final t in controller.items('transfers'))
                ListTile(
                  title: Text(
                    '${t.text('fromPenName')} → ${t.text('toPenName')}',
                  ),
                  subtitle: Text(
                    '${t.text('date')} · ${t.text('notes')} · ${t.text('actorName')}',
                  ),
                ),
              const Divider(),
              Text(
                'Lịch chăm sóc',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (controller.items('careTasks').isEmpty)
                const Text('Chưa có lịch chăm sóc.'),
              for (final t in controller.items('careTasks'))
                ListTile(
                  title: Text(t.text('title')),
                  subtitle: Text(
                    '${t.text('dueDate')} · ${label(t.text('status'))}${t.text('actualDate').isEmpty ? '' : ' · Thực hiện ${t.text('actualDate')}'}',
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class WeightChart extends StatelessWidget {
  final List<FarmRecord> records;
  const WeightChart({super.key, required this.records});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Semantics(
            label:
                'Biểu đồ cân nặng: ${records.first.number('kg')} đến ${records.last.number('kg')} kg, từ ${records.first.text('date')} đến ${records.last.text('date')}',
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(painter: _WeightPainter(records)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(records.first.text('date')),
              Text(records.last.text('date')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _WeightPainter extends CustomPainter {
  final List<FarmRecord> records;
  _WeightPainter(this.records);
  @override
  void paint(Canvas canvas, Size size) {
    final max = records.map((r) => r.number('kg')).reduce(math.max) * 1.15;
    final first = DateTime.parse(records.first.text('date'))
        .millisecondsSinceEpoch
        .toDouble();
    final range =
        DateTime.parse(records.last.text('date')).millisecondsSinceEpoch -
        first;
    final width = math.max(1.0, size.width - 65);
    final height = size.height - 20;
    final linePaint = Paint()
      ..color = forest
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final x =
          50 +
          (DateTime.parse(r.text('date')).millisecondsSinceEpoch - first) /
              range *
              width;
      final y = height - r.number('kg') / max * (height - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = forest);
    }
    for (var i = 0; i <= 4; i++) {
      final kg = max * i / 4;
      final y = height - kg / max * (height - 10);
      canvas.drawLine(
        Offset(48, y),
        Offset(size.width, y),
        Paint()..color = line,
      );
      final t = TextPainter(
        text: TextSpan(
          text: '${kg.toStringAsFixed(0)} kg',
          style: const TextStyle(color: muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, Offset(0, y - 7));
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) => old.records != records;
}

Future<bool> careForm(
  BuildContext context,
  FarmRepository repo, {
  FarmRecord? animal,
  FarmRecord? task,
}) async {
  List<FarmRecord> animals = [];
  if (animal == null && task == null) {
    // Fetch all pages: scheduling must not silently omit animals after page 100.
    var page = 1;
    int total = 0;
    try {
      do {
        final data = await repo.get(
          '/animals?status=ACTIVE&pageSize=100&page=$page',
        );
        final batch = FarmRepository.records(data, 'animals');
        if (batch.isEmpty) break;
        animals.addAll(batch);
        total = (data['total'] as num?)?.toInt() ?? 0;
        page++;
      } while (animals.length < total);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    }
  }
  if (!context.mounted) return false;
  return farmForm(
    context,
    title: task == null ? 'Đặt lịch chăm sóc' : 'Sửa lịch chăm sóc',
    fields: [
      if (task == null && animal == null)
        FarmField(
          'animalId',
          'Vật nuôi',
          options: recordOptions(animals, key: 'code'),
        ),
      FarmField(
        'kind',
        'Loại việc',
        initial: task?.text('kind') ?? 'CHECKUP',
        options: {'CHECKUP': 'Kiểm tra sức khỏe', 'VACCINATION': 'Tiêm phòng'},
      ),
      FarmField(
        'title',
        'Nội dung / tên vaccine',
        initial: task?.text('title') ?? '',
      ),
      FarmField(
        'dueDate',
        'Ngày hẹn',
        initial: task?.text('dueDate') ?? farmToday(),
        date: true,
      ),
      FarmField(
        'notes',
        'Ghi chú',
        initial: task?.text('notes') ?? '',
        requiredValue: false,
      ),
    ],
    save: (b) => repo.save(
      task == null ? 'POST' : 'PATCH',
      '/care-tasks${task == null ? '' : '/${task.id}'}',
      {...b, if (task == null && animal != null) 'animalId': animal.id},
    ),
  );
}

class CarePage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool canOperate, canCare, canExamine, canFinance;
  const CarePage({
    super.key,
    required this.repository,
    required this.admin,
    this.canOperate = true,
    this.canCare = true,
    this.canExamine = false,
    this.canFinance = false,
  });
  @override
  State<CarePage> createState() => _CarePageState();
}

class _CarePageState extends State<CarePage> {
  late final controller = FarmController(widget.repository);
  String status = 'PENDING';
  int page = 1;
  bool busy = false;
  void load() => controller.load(
    '/care-tasks?page=$page${status.isEmpty ? '' : '&status=$status'}',
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

  Future<void> complete(FarmRecord task) async {
    final id = FarmRepository.requestId();
    if (await farmForm(
          context,
          title: 'Hoàn thành ${task.text('title')}',
          fields: [
            FarmField(
              'date',
              'Ngày thực hiện',
              initial: farmToday(),
              date: true,
            ),
            const FarmField(
              'status',
              'Tình trạng sau chăm sóc',
              initial: 'NORMAL',
              options: {'NORMAL': 'Bình thường', 'NEEDS_CARE': 'Cần chăm sóc'},
            ),
            const FarmField('notes', 'Ghi chú kết quả', requiredValue: false),
          ],
          save: (b) => widget.repository.save(
            'POST',
            '/care-tasks/${task.id}/complete',
            {...b, 'requestId': id},
          ),
        ) &&
        mounted) {
      load();
    }
  }

  Future<void> cancel(FarmRecord task) async {
    if (!await farmConfirm(context, 'Hủy lịch ${task.text('title')}?') ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.save(
        'POST',
        '/care-tasks/${task.id}/cancel',
        null,
      );
      load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: 'Lịch chăm sóc',
      refresh: load,
      actions: [
        if (widget.canCare)
          FilledButton.icon(
            onPressed: controller.loading
                ? null
                : () async {
                    if (await careForm(context, widget.repository) && mounted) {
                      load();
                    }
                  },
            icon: const Icon(Icons.add),
            label: const Text('Đặt lịch'),
          ),
      ],
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final s in ['PENDING', 'DONE', 'CANCELLED', ''])
              ChoiceChip(
                label: Text(s.isEmpty ? 'Tất cả' : label(s)),
                selected: status == s,
                onSelected: (_) {
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
        if (!controller.loading && controller.items('tasks').isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không có lịch chăm sóc.'),
          ),
        for (final t in controller.items('tasks'))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${t.text('animalCode')} · ${t.text('title')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(
                          t.text('status') == 'PENDING' &&
                                  t
                                          .text('dueDate')
                                          .compareTo(
                                            controller.data['today']
                                                    ?.toString() ??
                                                farmToday(),
                                          ) <
                                      0
                              ? 'Quá hạn'
                              : label(t.text('status')),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${label(t.text('kind'))} · Hẹn ${t.text('dueDate')}${t.text('actualDate').isEmpty ? '' : ' · Thực hiện ${t.text('actualDate')}'}',
                  ),
                  if (t.text('notes').isNotEmpty) Text(t.text('notes')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AnimalDetailPage(
                                  repository: widget.repository,
                                  admin: widget.admin,
                                  canOperate: widget.canOperate,
                                  canCare: widget.canCare,
                                  canExamine: widget.canExamine,
                                  canFinance: widget.canFinance,
                                  id: t.text('animalId'),
                                ),
                              ),
                            ).then((_) {
                              if (mounted) load();
                            }),
                        child: const Text('Hồ sơ vật nuôi'),
                      ),
                      if (widget.canCare && t.text('status') == 'PENDING') ...[
                        if (widget.admin || widget.canExamine)
                          FilledButton(
                            onPressed: busy ? null : () => complete(t),
                            child: const Text('Hoàn thành'),
                          ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await careForm(
                                        context,
                                        widget.repository,
                                        task: t,
                                      ) &&
                                      mounted) {
                                    load();
                                  }
                                },
                          child: const Text('Sửa lịch'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => cancel(t),
                          child: const Text('Hủy lịch'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        _pagination(
          page,
          (controller.data['total'] as num?)?.toInt() ?? 0,
          20,
          controller.loading,
          (p) {
            page = p;
            load();
          },
        ),
      ],
    ),
  );
}

Widget animalAvatar(FarmRecord animal, {double size = 48}) => PhotoView(
  data: animal.text('imageData'),
  size: size,
  fallback: speciesIcon(animal.text('speciesName')),
  label: 'Ảnh vật nuôi ${animal.text('code')}',
);
