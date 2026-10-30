import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animals_page.dart';
import 'farm_repository.dart';
import 'farm_refresh.dart';
import 'farm_widgets.dart';
import 'pen_icon_picker.dart';

class CatalogPage extends StatefulWidget {
  final FarmRepository repository;
  final int refreshRevision;
  final bool admin, canOperate, canCare, canExamine, canFinance;
  final String initialKind;
  final String? initialAreaId;
  final List<String> availableKinds;
  const CatalogPage({
    super.key,
    required this.repository,
    this.refreshRevision = 0,
    required this.admin,
    this.canOperate = false,
    this.canCare = false,
    this.canExamine = false,
    this.canFinance = false,
    this.initialKind = 'pens',
    this.initialAreaId,
    this.availableKinds = const ['pens', 'areas', 'species', 'breeds'],
  }) : assert(availableKinds.length > 0);
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  static const names = {
    'pens': 'chuồng trại',
    'areas': 'khu vực',
    'species': 'loài',
    'breeds': 'giống',
  };
  final refresh = FarmRefresh();
  late final controller = FarmController(widget.repository);
  final search = TextEditingController();
  late String kind = widget.availableKinds.contains(widget.initialKind)
      ? widget.initialKind
      : widget.availableKinds.first;
  late String areaId = widget.initialAreaId ?? '';
  String speciesId = '', usage = '';
  bool busy = false;

  Future<void> load() => refresh.run(
    () => controller.load(
      '/farm/catalogs',
      withCatalogs: true,
      withPenSpecies: widget.availableKinds.contains('pens'),
    ),
  );
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant CatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) load();
  }

  @override
  void dispose() {
    refresh.dispose();
    search.dispose();
    controller.dispose();
    super.dispose();
  }

  FarmRecord? related(String catalog, String id) {
    for (final item in controller.catalog(catalog)) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<FarmRecord> get filtered {
    final query = search.text.trim().toLowerCase();
    return controller.items(kind).where((item) {
      if (kind == 'pens') {
        if (areaId.isNotEmpty && item.text('areaId') != areaId) return false;
        if (usage.isNotEmpty && item.values['active'] != (usage == 'active')) {
          return false;
        }
      }
      if (kind == 'breeds' &&
          speciesId.isNotEmpty &&
          item.text('speciesId') != speciesId) {
        return false;
      }
      final parent = kind == 'pens'
          ? related('areas', item.text('areaId'))
          : kind == 'breeds'
          ? related('species', item.text('speciesId'))
          : null;
      return '${item.text('code')} ${item.text('name')} ${parent?.text('name') ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> edit([FarmRecord? item]) async {
    if (!widget.admin || busy || controller.loading) return;
    final editKind = kind;
    final noun = names[editKind]!;
    final requiredCode = editKind == 'pens';
    setState(() => busy = true);
    PenIconChoice? iconChoice;
    bool areaCreated = false;
    final fields = [
      FarmField(
        'code',
        'Mã ${requiredCode ? 'chuồng' : noun}${requiredCode ? '' : ' (tùy chọn)'}',
        initial: item?.text('code') ?? '',
        requiredValue: requiredCode,
      ),
      FarmField('name', 'Tên', initial: item?.text('name') ?? ''),
      if (editKind == 'breeds')
        FarmField(
          'speciesId',
          'Loài',
          initial: item?.text('speciesId') ?? speciesId,
          options: recordOptions(controller.catalog('species')),
        ),
      if (editKind == 'pens') ...[
        FarmField(
          'areaId',
          'Khu vực',
          initial: item?.text('areaId') ?? areaId,
          options: recordOptions(controller.catalog('areas')),
          createOptionLabel: 'Thêm khu vực',
          createOption: (formContext) async {
            FarmRecord? created;
            final saved = await farmForm(
              formContext,
              title: 'Thêm khu vực',
              codeApi: widget.repository.api,
              codeKind: 'areas',
              fields: const [
                FarmField('code', 'Mã khu vực', requiredValue: false),
                FarmField('name', 'Tên khu vực'),
              ],
              save: (body) async {
                final data = await widget.repository.api.request(
                  'POST',
                  '/farm/areas',
                  body: body,
                );
                final item = data['item'];
                if (item is! Map ||
                    item['id'] is! String ||
                    (item['id'] as String).isEmpty) {
                  throw const ApiException(
                    'Không nhận được khu vực vừa tạo. Vui lòng tải lại danh mục.',
                  );
                }
                created = FarmRecord({
                  ...body,
                  ...Map<String, dynamic>.from(item),
                });
                areaCreated = true;
              },
            );
            return saved ? created : null;
          },
        ),
        FarmField(
          'capacity',
          'Sức chứa (con)',
          initial: item?.text('capacity') ?? '10',
          numeric: true,
          integer: true,
          maximum: 100000,
          integerMessage: 'Nhập sức chứa là số nguyên.',
        ),
        FarmField(
          'active',
          'Đang sử dụng',
          initial: item?.text('active') ?? 'true',
          boolean: true,
        ),
      ],
    ];
    try {
      final saved = await farmForm(
        context,
        title: '${item == null ? 'Thêm' : 'Sửa'} $noun',
        fields: fields,
        codeApi: widget.repository.api,
        codeKind: editKind,
        extraFields: editKind == 'pens'
            ? (formBusy) => PenIconField(
                enabled: !formBusy,
                initial: PenIconChoice(
                  item?.text('iconKey').isNotEmpty == true
                      ? item!.text('iconKey')
                      : 'auto',
                  data: item?.text('iconData') ?? '',
                ),
                speciesNames:
                    (item?.values['speciesNames'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    const [],
                onChanged: (choice) => iconChoice = choice,
              )
            : null,
        intro: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editKind == 'pens'
                  ? 'Mỗi chuồng thuộc một khu vực. Sức chứa từ 1 đến 100.000 con; không giảm dưới số đang nuôi hoặc ngừng sử dụng chuồng còn vật nuôi.'
                  : editKind == 'breeds'
                  ? 'Mỗi giống thuộc một loài. Giống đã có vật nuôi không thể đổi loài. Mã không bắt buộc.'
                  : editKind == 'species'
                  ? 'Một loài có thể có nhiều giống. Mã không bắt buộc.'
                  : 'Một khu vực có thể có nhiều chuồng. Mã không bắt buộc.',
            ),
            if (editKind == 'pens' && controller.catalog('areas').isEmpty)
              const Text(
                'Chưa có khu vực. Chọn “Thêm khu vực” bên dưới để tạo ngay.',
              ),
            if (editKind == 'breeds' && controller.catalog('species').isEmpty)
              const Text('Cần thêm loài trong Danh mục trước khi tạo giống.'),
          ],
        ),
        save: (body) => widget.repository.save(
          item == null ? 'POST' : 'PATCH',
          '/farm/$editKind${item == null ? '' : '/${item.id}'}',
          {
            ...body,
            if (iconChoice != null) 'iconKey': iconChoice!.key,
            if (iconChoice?.upload != null) 'iconBase64': iconChoice!.upload,
          },
        ),
      );
      if ((saved || areaCreated) && mounted) await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(FarmRecord item) async {
    if (!widget.admin || busy || controller.loading) return;
    final deleteKind = kind;
    setState(() => busy = true);
    try {
      if (!await farmConfirm(
            context,
            deleteKind == 'pens'
                ? 'Xóa ${item.text('name')}? Chỉ có thể xóa chuồng không còn vật nuôi đang nuôi. Lịch sử nuôi và chuyển chuồng vẫn được giữ lại.'
                : 'Xóa ${item.text('name')}? Danh mục đã có dữ liệu liên quan sẽ không thể xóa.',
          ) ||
          !mounted) {
        return;
      }
      await widget.repository.save(
        'DELETE',
        '/farm/$deleteKind/${item.id}',
        null,
      );
      if (mounted) load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openPen(FarmRecord pen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Vật nuôi · ${pen.text('name')}')),
          body: AnimalsPage(
            repository: widget.repository,
            admin: widget.admin,
            initialPenId: pen.id,
            initialPenName: pen.text('name'),
            canOperate: widget.admin || widget.canOperate,
            canCare: widget.admin || widget.canCare,
            canExamine: widget.admin || widget.canExamine,
            canFinance: widget.admin || widget.canFinance,
          ),
        ),
      ),
    );
    if (mounted) load();
  }

  Widget filter(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$kind-$label-$value'),
    initialValue: options.containsKey(value) ? value : '',
    isExpanded: true,
    decoration: farmInputDecoration(label: label),
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) => setState(() => onChanged(value ?? '')),
  );

  Widget actions(FarmRecord item) => PopupMenuButton<String>(
    tooltip: 'Thao tác',
    enabled: !busy && !controller.loading,
    onSelected: (value) => value == 'edit' ? edit(item) : remove(item),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Sửa')),
      PopupMenuItem(value: 'delete', child: Text('Xóa')),
    ],
  );

  Widget penCard(FarmRecord item) {
    final occupied = item.values['occupied'],
        capacity = item.values['capacity'];
    final hasCapacity =
        occupied is num && occupied >= 0 && capacity is num && capacity > 0;
    final active = item.values['active'];
    final area = related('areas', item.text('areaId'));
    return FarmInfoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('pen-${item.id}'),
        borderRadius: BorderRadius.circular(FarmRadii.card),
        onTap: () => openPen(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FarmPenIllustration(
                    iconKey: item.text('iconKey'),
                    iconData: item.text('iconData'),
                    size: 80,
                    decorative: true,
                    speciesNames:
                        (item.values['speciesNames'] as List?)
                            ?.whereType<String>()
                            .toList() ??
                        const [],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text('name'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          [
                            item.text('code'),
                            if (area != null) area.text('name'),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (widget.admin)
                    actions(item)
                  else
                    const Icon(Icons.chevron_right, color: forest),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (hasCapacity)
                    Text('${occupied.toInt()}/${capacity.toInt()} con')
                  else
                    const Text('Chưa có dữ liệu sức chứa.'),
                  if (active is bool)
                    FarmStatusBadge(
                      label: active ? 'Đang sử dụng' : 'Ngừng sử dụng',
                      tone: active
                          ? FarmBadgeTone.success
                          : FarmBadgeTone.neutral,
                    ),
                ],
              ),
              if (hasCapacity) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (occupied / capacity).clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                  color: occupied >= capacity ? FarmColors.warning : forest,
                  backgroundColor: FarmColors.mint,
                  semanticsLabel:
                      'Sức chứa chuồng ${item.text('name')}: ${occupied.toInt()} trên ${capacity.toInt()} con',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget catalogCard(FarmRecord item) {
    final species = kind == 'species'
        ? item
        : related('species', item.text('speciesId'));
    final count = kind == 'species'
        ? controller
              .catalog('breeds')
              .where((b) => b.text('speciesId') == item.id)
              .length
        : controller
              .catalog('pens')
              .where((p) => p.text('areaId') == item.id)
              .length;
    return FarmInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kind == 'areas')
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: FarmColors.sky,
                  child: Icon(
                    Icons.landscape_outlined,
                    size: 36,
                    color: forest,
                  ),
                )
              else
                FarmSpeciesIllustration(
                  speciesCode: species?.text('code'),
                  speciesName: species?.text('name'),
                  size: 64,
                  decorative: true,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text('name'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (item.text('code').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.text('code'),
                        style: const TextStyle(color: muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (kind == 'breeds')
                      Text(
                        'Loài: ${species?.text('name') ?? 'Chưa có dữ liệu'}',
                      )
                    else if (controller.data[kind == 'species'
                            ? 'breeds'
                            : 'pens']
                        is List)
                      Text(
                        '$count ${kind == 'species' ? 'giống' : 'chuồng'} trong danh mục',
                      ),
                  ],
                ),
              ),
              if (widget.admin) actions(item),
            ],
          ),
          if (kind == 'species' && widget.availableKinds.contains('breeds'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        kind = 'breeds';
                        speciesId = item.id;
                        search.clear();
                      }),
                child: const Text('Xem giống của loài'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final items = filtered;
      return FarmBody(
        controller: controller,
        title:
            widget.availableKinds.length == 1 &&
                widget.availableKinds.single == 'pens'
            ? 'Chuồng trại'
            : widget.availableKinds.contains('pens')
            ? 'Chuồng & danh mục'
            : 'Danh mục',
        refresh: load,
        actions: [
          if (widget.admin)
            FilledButton.icon(
              onPressed: busy || controller.loading ? null : () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            ),
        ],
        children: [
          if (widget.availableKinds.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  'pens': 'Chuồng',
                  'species': 'Loài',
                  'breeds': 'Giống',
                  'areas': 'Khu vực',
                }.entries)
                  if (widget.availableKinds.contains(entry.key))
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: kind == entry.key,
                      onSelected: busy
                          ? null
                          : (_) => setState(() {
                              kind = entry.key;
                              search.clear();
                            }),
                    ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: search,
            decoration: farmInputDecoration(
              label: 'Tìm mã / tên ${names[kind]}',
              suffixIcon: search.text.isEmpty
                  ? const Icon(Icons.search)
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(search.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (kind == 'pens') ...[
            ExpansionTile(
              key: const PageStorageKey('pen-filters'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Bộ lọc chuồng'),
              subtitle: areaId.isEmpty && usage.isEmpty
                  ? null
                  : const Text('Đang áp dụng bộ lọc'),
              children: [
                filter('Khu vực', areaId, {
                  '': 'Tất cả khu vực',
                  ...recordOptions(controller.catalog('areas')),
                }, (v) => areaId = v),
                const SizedBox(height: 12),
                filter('Sử dụng', usage, const {
                  '': 'Tất cả trạng thái',
                  'active': 'Đang sử dụng',
                  'inactive': 'Ngừng sử dụng',
                }, (v) => usage = v),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (kind == 'breeds') ...[
            filter('Lọc loài', speciesId, {
              '': 'Tất cả loài',
              ...recordOptions(controller.catalog('species')),
            }, (v) => speciesId = v),
            const SizedBox(height: 16),
          ],
          if (controller.data.isNotEmpty) ...[
            Text(
              '${items.length} / ${controller.items(kind).length} ${names[kind]}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
          ],
          if (!controller.loading && controller.error == null && items.isEmpty)
            FarmEmptyState(
              icon: kind == 'pens'
                  ? Icons.home_work_outlined
                  : Icons.category_outlined,
              message: controller.items(kind).isEmpty
                  ? 'Chưa có ${names[kind]}. Tạo loài, giống, khu vực và chuồng trước khi thêm vật nuôi.'
                  : 'Không có ${names[kind]} phù hợp. Hãy đổi tìm kiếm hoặc bộ lọc.',
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: kind == 'pens' ? penCard(item) : catalogCard(item),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FarmInfoCard(
            color: FarmColors.sky,
            child: Text(
              kind == 'pens' || kind == 'areas'
                  ? 'Chạm chuồng để xem vật nuôi đang nuôi.'
                  : 'Mỗi giống thuộc một loài. Chỉ chủ trang trại được thêm, sửa hoặc xóa danh mục.',
            ),
          ),
        ],
      );
    },
  );
}
