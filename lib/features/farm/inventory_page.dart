import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../farm/farm_repository.dart';
import '../farm/farm_widgets.dart';

class InventoryPage extends StatefulWidget {
  final FarmRepository repository;
  final bool admin;
  final bool canOperate;
  const InventoryPage({
    super.key,
    required this.repository,
    required this.admin,
    this.canOperate = true,
  });
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final controller = FarmController(widget.repository);
  List<FarmRecord> feeds = [];
  int page = 1;
  bool history = false, busy = false, preparing = false;
  String? error, feedId, kind, status;
  final from = TextEditingController(), to = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    controller.dispose();
    from.dispose();
    to.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => preparing = true);
    try {
      final data = await widget.repository.get('/feeds');
      if (!mounted) return;
      setState(() {
        feeds = FarmRepository.records(data, 'feeds');
        error = null;
      });
      final query = Uri(
        queryParameters: {
          'page': '$page',
          'feedId': ?feedId,
          'kind': ?kind,
          'status': ?status,
          if (from.text.isNotEmpty) 'from': from.text,
          if (to.text.isNotEmpty) 'to': to.text,
        },
      ).query;
      await controller.load('/stock-entries?$query', withCatalogs: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> editFeed([FarmRecord? feed]) async {
    if (await farmForm(
          context,
          title: feed == null ? 'Thêm thức ăn' : 'Sửa thức ăn',
          codeApi: widget.repository.api,
          codeKind: 'feeds',
          fields: [
            FarmField('code', 'Mã thức ăn', initial: feed?.text('code') ?? ''),
            FarmField('name', 'Tên thức ăn', initial: feed?.text('name') ?? ''),
            FarmField(
              'lowStock',
              'Ngưỡng tồn thấp (kg)',
              initial: feed?.text('lowStock') ?? '0',
              numeric: true,
              allowZero: true,
            ),
            FarmField(
              'active',
              'Đang sử dụng',
              initial: feed?.text('active') ?? 'true',
              boolean: true,
            ),
            FarmField(
              'notes',
              'Ghi chú',
              initial: feed?.text('notes') ?? '',
              requiredValue: false,
            ),
          ],
          save: (b) => widget.repository.save(
            feed == null ? 'POST' : 'PATCH',
            '/feeds${feed == null ? '' : '/${feed.id}'}',
            b,
          ),
        ) &&
        mounted) {
      load();
    }
  }

  Future<void> removeFeed(FarmRecord feed) async {
    if (!await farmConfirm(
          context,
          'Xóa ${feed.text('name')}? Chỉ xóa được thức ăn chưa có phiếu kho.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repository.save('DELETE', '/feeds/${feed.id}', null);
      if (mounted) load();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> entry(String kind) async {
    final requestId = FarmRepository.requestId();
    if (await farmForm(
          context,
          title: kind == 'IN' ? 'Nhập thức ăn' : 'Xuất thức ăn',
          fields: [
            FarmField(
              'feedId',
              'Thức ăn',
              options: {
                for (final f in feeds.where((f) => f.flag('active')))
                  f.id: '${f.text('name')} · tồn ${f.number('stock')} kg',
              },
            ),
            FarmField(
              'date',
              'Ngày ghi nhận',
              initial: farmToday(),
              date: true,
            ),
            const FarmField('quantity', 'Số lượng (kg)', numeric: true),
            if (kind == 'OUT')
              FarmField(
                'penId',
                'Chuồng (không bắt buộc)',
                requiredValue: false,
                options: recordOptions(
                  controller
                      .catalog('pens')
                      .where((p) => p.flag('active'))
                      .toList(),
                ),
              ),
            const FarmField('notes', 'Ghi chú', requiredValue: false),
          ],
          save: (b) => widget.repository.save('POST', '/stock-entries', {
            ...b,
            'kind': kind,
            'requestId': requestId,
          }),
        ) &&
        mounted) {
      load();
    }
  }

  Future<void> cancel(FarmRecord item) async {
    final requestId = FarmRepository.requestId();
    if (await farmForm(
          context,
          title: 'Hủy phiếu ${item.text('kind') == 'IN' ? 'nhập' : 'xuất'}',
          fields: const [FarmField('reason', 'Lý do hủy')],
          save: (b) => widget.repository.save(
            'POST',
            '/stock-entries/${item.id}/cancel',
            {...b, 'requestId': requestId},
          ),
        ) &&
        mounted) {
      load();
    }
  }

  Widget filter(
    String title,
    String? value,
    Map<String, String> options,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 210,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$title-$value-${options.keys.join()}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        setState(() => changed(v));
        page = 1;
        load();
      },
    ),
  );
  Future<void> pickDate(TextEditingController c) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null && mounted) {
      setState(() => c.text = d.toIso8601String().substring(0, 10));
      page = 1;
      load();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FarmBody(
      controller: controller,
      title: 'Kho thức ăn',
      refresh: load,
      actions: [
        if (widget.admin)
          OutlinedButton.icon(
            onPressed: busy || preparing ? null : () => editFeed(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm thức ăn'),
          ),
        if (widget.canOperate)
          FilledButton.icon(
            onPressed:
                !widget.canOperate ||
                    preparing ||
                    feeds.every((f) => !f.flag('active'))
                ? null
                : () => entry('IN'),
            icon: const Icon(Icons.south_west),
            label: const Text('Nhập kho'),
          ),
        if (widget.canOperate)
          OutlinedButton.icon(
            onPressed:
                !widget.canOperate ||
                    preparing ||
                    feeds.every((f) => !f.flag('active'))
                ? null
                : () => entry('OUT'),
            icon: const Icon(Icons.north_east),
            label: const Text('Xuất kho'),
          ),
      ],
      children: [
        if (error != null) FeedbackBox(error!),
        if (preparing) const LinearProgressIndicator(),
        const Text(
          'Đơn vị kg · Tồn tính từ phiếu hợp lệ. Phiếu đã ghi chỉ được hủy có lý do bởi ADMIN.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            ChoiceChip(
              label: const Text('Tồn kho'),
              selected: !history,
              onSelected: (_) => setState(() => history = false),
            ),
            ChoiceChip(
              label: const Text('Lịch sử nhập / xuất'),
              selected: history,
              onSelected: (_) => setState(() => history = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!history) ...[
          if (feeds.isEmpty && !preparing)
            const Text(
              'Chưa có thức ăn. ADMIN tạo thức ăn trước khi nhập kho.',
            ),
          for (final f in feeds)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f.text('code')} · ${f.text('name')}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${f.number('stock')} kg',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Ngưỡng: ${f.number('lowStock')} kg · ${f.flag('active') ? 'Đang sử dụng' : 'Ngừng sử dụng'}',
                      ),
                      if (f.flag('active') &&
                          f.number('stock') <= f.number('lowStock'))
                        const Chip(
                          avatar: Icon(Icons.warning_amber_rounded),
                          label: Text('Tồn thấp'),
                        ),
                      if (f.text('notes').isNotEmpty) Text(f.text('notes')),
                      if (widget.admin)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => editFeed(f),
                              child: const Text('Sửa'),
                            ),
                            TextButton(
                              onPressed: busy ? null : () => removeFeed(f),
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ] else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              filter(
                'Thức ăn',
                feedId,
                recordOptions(feeds),
                (v) => feedId = v,
              ),
              filter('Loại phiếu', kind, {
                'IN': 'Nhập',
                'OUT': 'Xuất',
              }, (v) => kind = v),
              filter('Trạng thái', status, {
                'VALID': 'Hợp lệ',
                'CANCELLED': 'Đã hủy',
              }, (v) => status = v),
              for (final e in {from: 'Từ ngày', to: 'Đến ngày'}.entries)
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: e.key,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: e.value,
                      suffixIcon: IconButton(
                        tooltip: 'Xóa ngày lọc',
                        onPressed: () {
                          e.key.clear();
                          page = 1;
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
          const SizedBox(height: 16),
          if (controller.items('entries').isEmpty && !controller.loading)
            const Text('Không có phiếu phù hợp.'),
          for (final e in controller.items('entries'))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${e.text('kind') == 'IN' ? 'Nhập' : 'Xuất'} · ${e.text('feedName')} · ${e.number('quantity')} kg',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${e.text('date')} · ${e.text('actorName')}${e.text('penName').isEmpty ? '' : ' · ${e.text('penName')}'}',
                      ),
                      if (e.text('notes').isNotEmpty) Text(e.text('notes')),
                      if (e.text('cancelledAt').isNotEmpty)
                        Text(
                          'Đã hủy: ${e.text('cancelReason')} · ${e.text('cancelledByName')}',
                        )
                      else if (widget.admin)
                        TextButton(
                          onPressed: busy ? null : () => cancel(e),
                          child: const Text('Hủy phiếu'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Trang trước',
                onPressed: controller.loading || page <= 1
                    ? null
                    : () {
                        page--;
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
                    controller.loading ||
                        page * 20 >=
                            ((controller.data['total'] as num?)?.toInt() ?? 0)
                    ? null
                    : () {
                        page++;
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
