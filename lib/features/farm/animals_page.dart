import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'animal_editor.dart';
import 'animal_scanner_page.dart';
import 'catalog_page.dart';
import 'animal_detail_page.dart';
import 'farm_repository.dart';
import 'farm_refresh.dart';
import 'farm_widgets.dart';
import 'batch_transfer_form.dart';
import 'care_forms.dart';
import 'batch_lifecycle_form.dart';

enum _BatchAction { transfer, care, sell, death }

class AnimalsPage extends StatefulWidget {
  final FarmRepository repository;
  final int refreshRevision;
  final bool admin;
  final bool canOperate, canCare, canExamine, canFinance;
  final String? initialPenId, initialPenName;
  const AnimalsPage({
    super.key,
    required this.repository,
    this.refreshRevision = 0,
    required this.admin,
    this.canOperate = true,
    this.canCare = true,
    this.canExamine = false,
    this.canFinance = false,
    this.initialPenId,
    this.initialPenName,
  });
  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalFilters {
  const _AnimalFilters({
    this.status = 'ACTIVE',
    this.speciesId,
    this.penId,
    this.healthStatus,
  });
  final String status;
  final String? speciesId, penId, healthStatus;
  bool sameAs(_AnimalFilters other) =>
      status == other.status &&
      speciesId == other.speciesId &&
      penId == other.penId &&
      healthStatus == other.healthStatus;
}

class _AnimalsPageState extends State<AnimalsPage> {
  final refresh = FarmRefresh();
  late final controller = FarmController(widget.repository);
  final search = TextEditingController();
  Timer? debounce;
  int page = 1, loadedPage = 1, loadRevision = 0;
  String requestedSearch = '';
  bool filterOpen = false, creating = false;
  bool selecting = false, batchBusy = false;
  final selectedAnimals = <String, FarmRecord>{};
  bool get canSelect => widget.canOperate || widget.canCare;
  bool get selectionEnabled =>
      !controller.loading &&
      controller.error == null &&
      !batchBusy &&
      requestedSearch == search.text.trim();
  late _AnimalFilters filters = _AnimalFilters(penId: widget.initialPenId);

  Future<void> load() => refresh.run(loadData, supersede: true);

  Future<void> loadData() async {
    debounce?.cancel();
    final querySearch = search.text.trim();
    if (querySearch != requestedSearch) page = 1;
    requestedSearch = querySearch;
    final requestedPage = page, revision = ++loadRevision;
    final query = Uri(
      queryParameters: {
        'page': '$requestedPage',
        'search': querySearch,
        if (filters.status.isNotEmpty) 'status': filters.status,
        'speciesId': ?filters.speciesId,
        'penId': ?filters.penId,
        'healthStatus': ?filters.healthStatus,
      },
    ).query;
    await controller.load('/animals?$query', withCatalogs: true);
    if (mounted && revision == loadRevision && controller.error == null) {
      setState(() => loadedPage = requestedPage);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant AnimalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) {
      refresh.run(loadData);
    }
  }

  @override
  void dispose() {
    refresh.dispose();
    debounce?.cancel();
    search.dispose();
    controller.dispose();
    super.dispose();
  }

  Map<String, String> get penOptions => {
    ...recordOptions(controller.catalog('pens')),
    if (filters.penId != null &&
        !controller.catalog('pens').any((p) => p.id == filters.penId))
      filters.penId!: filters.penId == widget.initialPenId
          ? widget.initialPenName ?? 'Chuồng đã chọn'
          : 'Chuồng đã chọn',
  };
  Map<String, String> get speciesOptions => {
    ...recordOptions(controller.catalog('species')),
    if (filters.speciesId != null &&
        !controller.catalog('species').any((s) => s.id == filters.speciesId))
      filters.speciesId!: 'Loài đã chọn',
  };

  Future<void> openFilters() async {
    if (filterOpen || controller.loading) return;
    debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() => filterOpen = true);
    final result = await showDialog<_AnimalFilters>(
      context: context,
      builder: (_) => _AnimalFilterDialog(
        initial: filters,
        species: speciesOptions,
        pens: penOptions,
      ),
    );
    if (!mounted) return;
    final changed = result != null && !result.sameAs(filters);
    setState(() {
      filterOpen = false;
      if (changed) {
        filters = result;
        page = 1;
      }
    });
    if (changed || requestedSearch != search.text.trim()) await load();
  }

  Future<void> create() async {
    if (!widget.canOperate || creating || controller.loading) return;
    setState(() => creating = true);
    try {
      if (await animalForm(
            context,
            widget.repository,
            controller.catalogs,
            null,
            widget.admin,
          ) &&
          mounted) {
        await load();
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> openAnimal(FarmRecord animal) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AnimalDetailPage(
          repository: widget.repository,
          admin: widget.admin,
          id: animal.id,
          canOperate: widget.canOperate,
          canCare: widget.canCare,
          canExamine: widget.canExamine,
          canFinance: widget.canFinance,
        ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> scanQr() async {
    await openAnimalQrScanner(
      context,
      detailBuilder: (id) => AnimalDetailPage(
        repository: widget.repository,
        admin: widget.admin,
        id: id,
        canOperate: widget.canOperate,
        canCare: widget.canCare,
        canExamine: widget.canExamine,
        canFinance: widget.canFinance,
      ),
    );
    if (mounted) await load();
  }

  void toggleAnimal(FarmRecord animal) {
    if (!selectionEnabled || animal.text('status') != 'ACTIVE') return;
    if (!selectedAnimals.containsKey(animal.id) &&
        selectedAnimals.length >= 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mỗi lần chọn tối đa 1.000 vật nuôi.')),
      );
      return;
    }
    setState(() {
      if (selectedAnimals.containsKey(animal.id)) {
        selectedAnimals.remove(animal.id);
      } else {
        selectedAnimals[animal.id] = animal;
      }
    });
  }

  void exitSelection() => setState(() {
    selecting = false;
    selectedAnimals.clear();
  });

  Future<void> runBatch(_BatchAction action) async {
    final allowed = switch (action) {
      _BatchAction.transfer => widget.canOperate,
      _BatchAction.care => widget.canCare,
      _BatchAction.sell || _BatchAction.death => widget.admin,
    };
    if (!selectionEnabled || selectedAnimals.isEmpty || !allowed) {
      return;
    }
    setState(() => batchBusy = true);
    final selected = selectedAnimals.values.toList();
    try {
      final operation = switch (action) {
        _BatchAction.transfer => batchTransferForm(
          context,
          repository: widget.repository,
          animals: selected,
          pens: controller.catalog('pens'),
        ),
        _BatchAction.care => careForm(
          context,
          widget.repository,
          selectedAnimals: selected,
        ),
        _BatchAction.sell || _BatchAction.death => batchLifecycleForm(
          context,
          repository: widget.repository,
          animals: selected,
          selling: action == _BatchAction.sell,
        ),
      };
      final changed = await operation;
      if (changed && mounted) {
        exitSelection();
        if (action != _BatchAction.care) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(switch (action) {
                _BatchAction.sell => 'Đã bán ${selected.length} vật nuôi.',
                _BatchAction.death =>
                  'Đã ghi nhận đã chết cho ${selected.length} vật nuôi.',
                _ => 'Đã chuyển chuồng cho các vật nuôi đã chọn.',
              }),
            ),
          );
        }
        await load();
      }
    } finally {
      if (mounted) setState(() => batchBusy = false);
    }
  }

  Widget selectionActions(List<FarmRecord> animals) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FarmInfoCard(
      color: FarmColors.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Đã chọn ${selectedAnimals.length} con',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: !selectionEnabled
                    ? null
                    : () {
                        final pageAnimals = animals.where(
                          (a) => a.text('status') == 'ACTIVE',
                        );
                        if ({
                              ...selectedAnimals.keys,
                              ...pageAnimals.map((a) => a.id),
                            }.length >
                            1000) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Mỗi lần chọn tối đa 1.000 vật nuôi.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(
                          () => selectedAnimals.addEntries(
                            pageAnimals.map((a) => MapEntry(a.id, a)),
                          ),
                        );
                      },
                child: const Text('Chọn trang này'),
              ),
              TextButton(
                onPressed: batchBusy
                    ? null
                    : () => setState(selectedAnimals.clear),
                child: const Text('Bỏ chọn tất cả'),
              ),
              TextButton(
                onPressed: batchBusy ? null : exitSelection,
                child: const Text('Thoát chọn'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.canOperate)
                FilledButton.icon(
                  key: const ValueKey('animals-batch-transfer'),
                  onPressed: !selectionEnabled || selectedAnimals.isEmpty
                      ? null
                      : () => runBatch(_BatchAction.transfer),
                  icon: const Icon(Icons.move_up),
                  label: const Text('Chuyển chuồng'),
                ),
              if (widget.canCare)
                OutlinedButton.icon(
                  key: const ValueKey('animals-batch-care'),
                  onPressed: !selectionEnabled || selectedAnimals.isEmpty
                      ? null
                      : () => runBatch(_BatchAction.care),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Đặt lịch chăm sóc'),
                ),
              if (widget.admin) ...[
                OutlinedButton.icon(
                  key: const ValueKey('animals-batch-sell'),
                  onPressed: !selectionEnabled || selectedAnimals.isEmpty
                      ? null
                      : () => runBatch(_BatchAction.sell),
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('Bán vật nuôi'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('animals-batch-death'),
                  onPressed: !selectionEnabled || selectedAnimals.isEmpty
                      ? null
                      : () => runBatch(_BatchAction.death),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Ghi nhận đã chết'),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  Widget animalCard(FarmRecord animal) {
    final status = animal.text('status'), health = animal.text('healthStatus');
    final metadata = [
      animal.text('speciesName'),
      animal.text('breedName'),
      if (animal.text('gender').isNotEmpty) label(animal.text('gender')),
    ].where((s) => s.isNotEmpty).join(' · ');
    final compact =
        !selecting &&
        MediaQuery.sizeOf(context).width >= 350 &&
        MediaQuery.textScalerOf(context).scale(14) <= 16.5;
    final badges = [
      FarmStatusBadge(
        label: status.isEmpty ? 'Chưa có vòng đời' : label(status),
        tone: status == 'ACTIVE'
            ? FarmBadgeTone.success
            : status == 'SOLD'
            ? FarmBadgeTone.info
            : FarmBadgeTone.neutral,
        icon: Icons.circle,
      ),
      FarmStatusBadge(
        label: health.isEmpty ? 'Chưa có sức khỏe' : label(health),
        tone: health == 'NEEDS_CARE'
            ? FarmBadgeTone.warning
            : health == 'NORMAL'
            ? FarmBadgeTone.success
            : FarmBadgeTone.neutral,
        icon: Icons.circle,
      ),
    ];
    return FarmInfoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('animal-${animal.id}'),
        borderRadius: BorderRadius.circular(FarmRadii.card),
        onTap: !selectionEnabled || (selecting && status != 'ACTIVE')
            ? null
            : () => selecting ? toggleAnimal(animal) : openAnimal(animal),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FarmAnimalImage(
                    photoData: animal.text('imageData'),
                    speciesName: animal.text('speciesName'),
                    size: 72,
                    semanticLabel: 'Ảnh vật nuôi ${animal.text('code')}',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    animal.text('code'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if (animal.text('name').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      animal.text('name'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (compact) ...[
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    badges[0],
                                    const SizedBox(height: 4),
                                    badges[1],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (metadata.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            metadata,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (filters.penId == null &&
                            animal.text('penName').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Chuồng: ${animal.text('penName')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selecting)
                    Checkbox(
                      key: ValueKey('animal-select-${animal.id}'),
                      value: selectedAnimals.containsKey(animal.id),
                      semanticLabel: 'Chọn ${animal.text('code')}',
                      onChanged: !selectionEnabled || status != 'ACTIVE'
                          ? null
                          : (_) => toggleAnimal(animal),
                    )
                  else
                    const Icon(Icons.chevron_right, color: forest),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: badges),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !selecting && !batchBusy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && selecting && !batchBusy) exitSelection();
    },
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final animals = controller.items('animals');
        final total = controller.data['total'] as num?;
        final pendingSearch = requestedSearch != search.text.trim();
        final busy = controller.loading || pendingSearch;
        return FarmBody(
          controller: controller,
          title: 'Đàn vật nuôi',
          refresh: load,
          menuAction: !canSelect
              ? null
              : PopupMenuButton<String>(
                  key: const ValueKey('animals-more'),
                  tooltip: 'Thao tác vật nuôi',
                  enabled: selectionEnabled && !creating,
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (_) => setState(() {
                    selecting = true;
                    FocusScope.of(context).unfocus();
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'select', child: Text('Chọn nhiều')),
                  ],
                ),
          actions: [
            OutlinedButton.icon(
              key: const ValueKey('animals-scan-qr'),
              onPressed: creating ? null : scanQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét QR'),
            ),
            if (widget.canOperate)
              FilledButton.icon(
                onPressed: controller.loading || creating ? null : create,
                icon: const Icon(Icons.add),
                label: const Text('Thêm vật nuôi'),
              ),
            if (!FarmPageNavigation.isWorkspace(context) &&
                !Navigator.canPop(context))
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Trang trại')),
                        body: CatalogPage(
                          repository: widget.repository,
                          admin: widget.admin,
                          canOperate: widget.canOperate,
                          canCare: widget.canCare,
                          canExamine: widget.canExamine,
                          canFinance: widget.canFinance,
                        ),
                      ),
                    ),
                  );
                  if (mounted) await load();
                },
                icon: const Icon(Icons.home_work_outlined),
                label: const Text('Chuồng & danh mục'),
              ),
          ],
          children: [
            if (selecting) selectionActions(animals),
            TextField(
              controller: search,
              maxLength: 100,
              decoration: farmInputDecoration(
                label: 'Tìm theo mã / tên vật nuôi',
                suffixIcon: search.text.isEmpty
                    ? const Icon(Icons.search)
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          search.clear();
                          page = 1;
                          load();
                        },
                      ),
              ),
              onChanged: (_) {
                debounce?.cancel();
                setState(() {});
                debounce = Timer(const Duration(milliseconds: 350), () {
                  page = 1;
                  load();
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('animal-filters'),
                  onPressed: controller.loading || filterOpen
                      ? null
                      : openFilters,
                  icon: const Icon(Icons.tune),
                  label: const Text('Bộ lọc vật nuôi'),
                ),

                FarmStatusBadge(
                  label: filters.status.isEmpty
                      ? 'Tất cả vòng đời'
                      : label(filters.status),
                ),
                if (filters.speciesId != null)
                  FarmStatusBadge(
                    label: 'Loài: ${speciesOptions[filters.speciesId]}',
                    tone: FarmBadgeTone.info,
                  ),
                if (filters.penId != null)
                  FarmStatusBadge(
                    label: 'Chuồng: ${penOptions[filters.penId]}',
                    tone: FarmBadgeTone.peach,
                  ),
                if (filters.healthStatus != null)
                  FarmStatusBadge(
                    label: 'Sức khỏe: ${label(filters.healthStatus!)}',
                    tone: filters.healthStatus == 'NEEDS_CARE'
                        ? FarmBadgeTone.warning
                        : FarmBadgeTone.success,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              busy
                  ? 'Đang tải kết quả…'
                  : total == null
                  ? 'Chưa có số lượng vật nuôi.'
                  : '${total.toInt()} vật nuôi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Thứ tự: mã vật nuôi', style: TextStyle(color: muted)),
            if ((busy || controller.error != null) && animals.isNotEmpty) ...[
              const SizedBox(height: 12),
              const FarmInfoCard(
                color: FarmColors.amber,
                child: Text(
                  'Danh sách bên dưới là kết quả lần tải trước. Hãy chờ tải xong hoặc thử tải lại.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!busy && controller.error == null && animals.isEmpty)
              FarmEmptyState(
                message: 'Không có vật nuôi phù hợp.',
                description: widget.canOperate
                    ? 'Thử đổi tìm kiếm hoặc bộ lọc, hoặc dùng nút Thêm vật nuôi ở đầu trang.'
                    : 'Thử đổi tìm kiếm hoặc bộ lọc. Liên hệ người quản lý nếu cần bổ sung vật nuôi.',
                illustration: const Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    FarmSpeciesIllustration(
                      speciesName: 'Bò',
                      size: 72,
                      decorative: true,
                    ),
                    FarmSpeciesIllustration(
                      speciesName: 'Heo',
                      size: 72,
                      decorative: true,
                    ),
                    FarmSpeciesIllustration(
                      speciesName: 'Dê',
                      size: 72,
                      decorative: true,
                    ),
                  ],
                ),
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
                    for (final animal in animals)
                      SizedBox(width: width, child: animalCard(animal)),
                  ],
                );
              },
            ),
            if (total != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Trang trước',
                      onPressed:
                          busy || controller.error != null || loadedPage <= 1
                          ? null
                          : () {
                              page = loadedPage - 1;
                              load();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Flexible(
                      child: Text(
                        'Trang $loadedPage · ${total.toInt()} kết quả',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Trang sau',
                      onPressed:
                          busy ||
                              controller.error != null ||
                              loadedPage * 20 >= total
                          ? null
                          : () {
                              page = loadedPage + 1;
                              load();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _AnimalFilterDialog extends StatefulWidget {
  const _AnimalFilterDialog({
    required this.initial,
    required this.species,
    required this.pens,
  });
  final _AnimalFilters initial;
  final Map<String, String> species, pens;
  @override
  State<_AnimalFilterDialog> createState() => _AnimalFilterDialogState();
}

class _AnimalFilterDialogState extends State<_AnimalFilterDialog> {
  late String status = widget.initial.status;
  late String? speciesId = widget.initial.speciesId,
      penId = widget.initial.penId,
      healthStatus = widget.initial.healthStatus;
  Widget dropdown(
    String title,
    String? selected,
    Map<String, String> options,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$title-$selected'),
    initialValue: selected ?? '',
    isExpanded: true,
    decoration: farmInputDecoration(label: title),
    items: [
      const DropdownMenuItem(value: '', child: Text('Tất cả')),
      for (final entry in options.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) => setState(() => changed(value == '' ? null : value)),
  );
  Widget choices(
    String title,
    String selected,
    Map<String, String> values,
    ValueChanged<String> changed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in values.entries)
            ChoiceChip(
              key: ValueKey('$title-${entry.key}'),
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => setState(() => changed(entry.key)),
            ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => FarmFormLayout(
    title: 'Bộ lọc vật nuôi',
    actions: [
      OutlinedButton(
        onPressed: () => setState(() {
          status = '';
          speciesId = null;
          penId = null;
          healthStatus = null;
        }),
        child: const Text('Đặt lại'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _AnimalFilters(
            status: status,
            speciesId: speciesId,
            penId: penId,
            healthStatus: healthStatus,
          ),
        ),
        child: const Text('Áp dụng'),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Đóng'),
          ),
        ),
        dropdown('Loài', speciesId, widget.species, (v) => speciesId = v),
        const SizedBox(height: 20),
        dropdown('Chuồng trại', penId, widget.pens, (v) => penId = v),
        const SizedBox(height: 20),
        choices('Tình trạng vòng đời', status, const {
          '': 'Tất cả',
          'ACTIVE': 'Đang nuôi',
          'SOLD': 'Đã bán',
          'DEAD': 'Đã chết',
        }, (v) => status = v),
        const SizedBox(height: 20),
        choices('Tình trạng sức khỏe', healthStatus ?? '', const {
          '': 'Tất cả',
          'NORMAL': 'Bình thường',
          'NEEDS_CARE': 'Cần chăm sóc',
        }, (v) => healthStatus = v.isEmpty ? null : v),
        const SizedBox(height: 20),
        const Text(
          'Bấm Áp dụng để cập nhật danh sách. Đặt lại bỏ mọi điều kiện lọc; từ khóa tìm kiếm được giữ.',
        ),
      ],
    ),
  );
}
