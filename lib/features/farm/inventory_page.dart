import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'farm_refresh.dart';
import 'farm_widgets.dart';
import 'inventory_forms.dart';
import 'inventory_widgets.dart';

class InventoryPage extends StatefulWidget {
  final FarmRepository repository;
  final int refreshRevision;
  final bool admin, canOperate;
  const InventoryPage({
    super.key,
    required this.repository,
    this.refreshRevision = 0,
    required this.admin,
    this.canOperate = true,
  });
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final refresh = FarmRefresh();
  late final controller = FarmController(widget.repository);
  List<FarmRecord> feeds = [];
  int page = 1;
  bool history = false, busy = false, preparing = false, loadFailed = false;
  String? error, feedId, kind, status;
  final from = TextEditingController(), to = TextEditingController();
  bool get canWrite =>
      !busy && !preparing && !loadFailed && controller.error == null;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision) load();
  }

  @override
  void dispose() {
    refresh.dispose();
    controller.dispose();
    from.dispose();
    to.dispose();
    super.dispose();
  }

  String get entryPath =>
      '/stock-entries?${Uri(queryParameters: {'page': '$page', 'feedId': ?feedId, 'kind': ?kind, 'status': ?status, if (from.text.isNotEmpty) 'from': farmIsoDate(from.text), if (to.text.isNotEmpty) 'to': farmIsoDate(to.text)}).query}';
  Future<void> load() => refresh.run(loadData);

  Future<void> loadData() async {
    if (preparing) return;
    setState(() {
      preparing = true;
      error = null;
    });
    try {
      final data = await widget.repository.get('/feeds');
      if (!mounted) return;
      setState(() {
        feeds = FarmRepository.records(data, 'feeds');
        loadFailed = false;
      });
      if (widget.canOperate) {
        await controller.load(entryPath, withCatalogs: true);
        if (mounted &&
            controller.error == null &&
            controller.items('entries').isEmpty &&
            page > 1) {
          final total = (controller.data['total'] as num?)?.toInt() ?? 0;
          page = ((total - 1) ~/ 20 + 1).clamp(1, page - 1);
          await controller.load(entryPath);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loadFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> openForm(
    InventoryFormKind type, {
    FarmRecord? feed,
    FarmRecord? item,
  }) async {
    if (!canWrite) return;
    final allowed =
        type == InventoryFormKind.feed || type == InventoryFormKind.cancel
        ? widget.admin
        : widget.canOperate;
    if (!allowed ||
        (type == InventoryFormKind.cancel &&
            (item == null || item.text('cancelledAt').isNotEmpty))) {
      return;
    }
    setState(() => busy = true);
    try {
      final saved = await inventoryForm(
        context,
        repository: widget.repository,
        kind: type,
        feed: feed,
        entry: item,
        feeds: feeds,
        pens: controller.catalog('pens'),
      );
      if (saved && mounted) await load();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeFeed(FarmRecord feed) async {
    if (!canWrite || !widget.admin) return;
    setState(() => busy = true);
    try {
      if (!await farmConfirm(
            context,
            'Xóa ${feed.text('name')}? Chỉ xóa được thức ăn chưa có phiếu kho.',
          ) ||
          !mounted) {
        return;
      }
      await widget.repository.save('DELETE', '/feeds/${feed.id}', null);
      if (mounted) await load();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget feedCard(FarmRecord f) {
    final stock = inventoryValue(f, 'stock'),
        low = inventoryValue(f, 'lowStock');
    final lowStock =
        f.flag('active') && stock != null && low != null && stock <= low;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FarmInfoCard(
        key: ValueKey('feed-${f.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeedSackIllustration(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.text('name'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        f.text('code'),
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Tồn kho', style: TextStyle(color: muted)),
            Text(
              '${inventoryKg(stock)} kg',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: lowStock ? FarmColors.warning : forest),
            ),
            const SizedBox(height: 8),
            Text('Ngưỡng tồn thấp: ${inventoryKg(low)} kg'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FarmStatusBadge(
                  label: f.flag('active') ? 'Đang sử dụng' : 'Ngừng sử dụng',
                  tone: f.flag('active')
                      ? FarmBadgeTone.success
                      : FarmBadgeTone.neutral,
                ),
                if (lowStock)
                  const FarmStatusBadge(
                    label: 'Tồn thấp',
                    tone: FarmBadgeTone.warning,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),
            if (f.text('notes').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(f.text('notes')),
            ],
            if (widget.admin) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: canWrite
                        ? () => openForm(InventoryFormKind.feed, feed: f)
                        : null,
                    child: const Text('Sửa'),
                  ),
                  TextButton(
                    onPressed: canWrite ? () => removeFeed(f) : null,
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget entryCard(FarmRecord item) {
    final cancelled = item.text('cancelledAt').isNotEmpty;
    final incoming = item.text('kind') == 'IN';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FarmInfoCard(
        key: ValueKey('stock-entry-${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeedSackIllustration(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${incoming ? 'Nhập' : 'Xuất'} · ${item.text('feedName')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${cancelled
                            ? ''
                            : incoming
                            ? '+'
                            : '-'}${inventoryKg(inventoryValue(item, 'quantity'))} kg',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cancelled
                              ? muted
                              : incoming
                              ? forest
                              : FarmColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FarmStatusBadge(
                label: cancelled ? 'Đã hủy' : 'Hợp lệ',
                tone: cancelled ? FarmBadgeTone.neutral : FarmBadgeTone.success,
              ),
            ),
            const SizedBox(height: 12),
            Text('Ngày ghi nhận: ${farmDate(item.text('date'))}'),
            if (item.text('actorName').isNotEmpty)
              Text('Người thực hiện: ${item.text('actorName')}'),
            if (item.text('penName').isNotEmpty)
              Text('Chuồng: ${item.text('penName')}'),
            if (item.text('notes').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.text('notes')),
            ],
            if (cancelled) ...[
              const SizedBox(height: 12),
              const Text(
                'Phiếu không còn tính vào tồn kho.',
                style: TextStyle(color: muted),
              ),
              Text('Lý do hủy: ${item.text('cancelReason')}'),
              Text('Người hủy: ${item.text('cancelledByName')}'),
              Text(
                'Thời điểm hủy: ${inventoryTimestamp(item.text('cancelledAt'))}',
              ),
            ] else if (widget.admin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: canWrite
                      ? () => openForm(InventoryFormKind.cancel, item: item)
                      : null,
                  child: const Text('Hủy phiếu'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget filter(
    String title,
    String? value,
    Map<String, String> options,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$title-$value-${options.keys.join()}'),
    initialValue: value,
    isExpanded: true,
    decoration: farmInputDecoration(label: title),
    items: [
      const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
      for (final e in options.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: busy || preparing
        ? null
        : (v) {
            setState(() {
              changed(v);
              page = 1;
            });
            load();
          },
  );
  Future<void> pickDate(TextEditingController c) async {
    if (busy || preparing) return;
    final d = await showDatePicker(
      context: context,
      initialDate: farmParseDate(c.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) {
      setState(() {
        c.text = farmDate(d.toIso8601String().substring(0, 10));
        page = 1;
      });
      load();
    }
  }

  Widget historyFilters() => FarmInfoCard(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      key: const ValueKey('inventory-filters'),
      maintainState: true,
      title: const Text('Bộ lọc phiếu'),
      subtitle: const Text('Thức ăn, loại, trạng thái và khoảng ngày'),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        filter('Thức ăn', feedId, {
          ...recordOptions(feeds),
          if (feedId != null && !feeds.any((f) => f.id == feedId))
            feedId!: 'Thức ăn không còn trong danh mục',
        }, (v) => feedId = v),
        const SizedBox(height: 16),
        filter('Loại phiếu', kind, const {
          'IN': 'Nhập',
          'OUT': 'Xuất',
        }, (v) => kind = v),
        const SizedBox(height: 16),
        filter('Trạng thái', status, const {
          'VALID': 'Hợp lệ',
          'CANCELLED': 'Đã hủy',
        }, (v) => status = v),
        const SizedBox(height: 16),
        for (final e in {from: 'Từ ngày', to: 'Đến ngày'}.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: e.key,
              readOnly: true,
              enabled: !busy && !preparing,
              decoration: farmInputDecoration(
                label: e.value,
                suffixIcon: IconButton(
                  tooltip: 'Xóa ngày lọc',
                  onPressed: busy || preparing
                      ? null
                      : () {
                          setState(() {
                            e.key.clear();
                            page = 1;
                          });
                          load();
                        },
                  icon: const Icon(Icons.clear),
                ),
              ),
              onTap: () => pickDate(e.key),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: 'Kho thức ăn',
      refresh: () {
        if (!busy) load();
      },
      actions: [
        if (widget.admin)
          OutlinedButton.icon(
            onPressed: canWrite ? () => openForm(InventoryFormKind.feed) : null,
            icon: const Icon(Icons.add),
            label: const Text('Thêm thức ăn'),
          ),
        if (widget.canOperate) ...[
          FilledButton.icon(
            onPressed: canWrite && feeds.any((f) => f.flag('active'))
                ? () => openForm(InventoryFormKind.incoming)
                : null,
            icon: const Icon(Icons.south_west),
            label: const Text('Nhập kho'),
          ),
          OutlinedButton.icon(
            onPressed: canWrite && feeds.any((f) => f.flag('active'))
                ? () => openForm(InventoryFormKind.outgoing)
                : null,
            icon: const Icon(Icons.north_east),
            label: const Text('Xuất kho'),
          ),
        ],
      ],
      children: [
        if (error != null) ...[
          FarmLoadError(
            message: error!,
            onRetry: busy || preparing ? null : load,
          ),
          const SizedBox(height: 12),
        ],
        if (preparing && !controller.loading) const FarmLoadingState(),
        const Text(
          'Đơn vị kg · Tồn tính từ phiếu hợp lệ. Phiếu đã ghi chỉ được hủy có lý do bởi Chủ trang trại.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tồn kho'),
              selected: !history,
              onSelected: (_) => setState(() => history = false),
            ),
            if (widget.canOperate)
              ChoiceChip(
                label: const Text('Lịch sử nhập / xuất'),
                selected: history,
                onSelected: (_) => setState(() => history = true),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if ((loadFailed || controller.error != null) &&
            (feeds.isNotEmpty || controller.data.isNotEmpty)) ...[
          const Text(
            'Đang hiển thị dữ liệu từ lần tải trước. Tải lại thành công để tiếp tục ghi kho.',
          ),
          const SizedBox(height: 16),
        ],
        if (!history) ...[
          if (feeds.isEmpty && !preparing && !loadFailed)
            const FarmEmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Chưa có thức ăn. Chủ trang trại tạo thức ăn trước khi nhập kho.',
            ),
          for (final f in feeds) feedCard(f),
        ] else ...[
          historyFilters(),
          const SizedBox(height: 16),
          if (controller.items('entries').isEmpty &&
              !preparing &&
              !loadFailed &&
              controller.error == null)
            const FarmEmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Không có phiếu phù hợp.',
              description: 'Thử đổi khoảng ngày hoặc bộ lọc nhập / xuất.',
            ),
          for (final e in controller.items('entries')) entryCard(e),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Trang trước',
                onPressed: busy || preparing || page <= 1
                    ? null
                    : () {
                        setState(() => page--);
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Text(
                  'Trang $page · ${controller.data['total'] ?? 0} phiếu',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Trang sau',
                onPressed:
                    busy ||
                        preparing ||
                        page * 20 >=
                            ((controller.data['total'] as num?)?.toInt() ?? 0)
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
      ],
    ),
  );
}
