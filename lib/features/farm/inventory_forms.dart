import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/suggested_code_field.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'finance_values.dart';
import 'inventory_widgets.dart';

enum InventoryFormKind { feed, incoming, outgoing, cancel }

Future<bool> inventoryForm(
  BuildContext context, {
  required FarmRepository repository,
  required InventoryFormKind kind,
  FarmRecord? feed,
  FarmRecord? entry,
  List<FarmRecord> feeds = const [],
  List<FarmRecord> pens = const [],
}) async {
  if (kind == InventoryFormKind.cancel &&
      (entry == null || entry.text('cancelledAt').isNotEmpty)) {
    return false;
  }
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InventoryEditor(
          repository: repository,
          kind: kind,
          feed: feed,
          entry: entry,
          feeds: feeds,
          pens: pens,
        ),
      ) ??
      false;
}

class InventoryEditor extends StatefulWidget {
  const InventoryEditor({
    super.key,
    required this.repository,
    required this.kind,
    this.feed,
    this.entry,
    this.feeds = const [],
    this.pens = const [],
  });
  final FarmRepository repository;
  final InventoryFormKind kind;
  final FarmRecord? feed, entry;
  final List<FarmRecord> feeds, pens;
  @override
  State<InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends State<InventoryEditor> {
  final form = GlobalKey<FormState>(), errorAnchor = GlobalKey();
  late final requestId = FarmRepository.requestId();
  late final fields = <String, TextEditingController>{
    for (final key in [
      'code',
      'name',
      'lowStock',
      'notes',
      'date',
      'quantity',
      'amount',
      'reason',
    ])
      key: TextEditingController(
        text: key == 'date'
            ? farmDate(farmToday())
            : widget.feed?.text(key) ?? (key == 'lowStock' ? '0' : ''),
      ),
  };
  late bool active = widget.feed?.flag('active') ?? true;
  String? feedId, penId, error;
  bool busy = false;
  bool get isFeed => widget.kind == InventoryFormKind.feed;
  bool get isCancel => widget.kind == InventoryFormKind.cancel;
  bool get outgoing => widget.kind == InventoryFormKind.outgoing;
  List<FarmRecord> get feeds =>
      widget.feeds.where((f) => f.flag('active')).toList();
  FarmRecord? get selectedFeed =>
      feeds.where((f) => f.id == feedId).firstOrNull;
  String get action => isFeed
      ? 'Lưu thức ăn'
      : isCancel
      ? 'Hủy phiếu'
      : outgoing
      ? 'Lưu phiếu xuất'
      : 'Lưu phiếu nhập';
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
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
    final body = isFeed
        ? <String, dynamic>{
            'code': fields['code']!.text.trim(),
            'name': fields['name']!.text.trim(),
            'lowStock': parseInventoryKg(fields['lowStock']!.text)!,
            'active': active,
            'notes': fields['notes']!.text.trim(),
          }
        : isCancel
        ? <String, dynamic>{
            'reason': fields['reason']!.text.trim(),
            'requestId': requestId,
          }
        : <String, dynamic>{
            'feedId': feedId,
            'kind': outgoing ? 'OUT' : 'IN',
            'date': farmIsoDate(fields['date']!.text),
            'quantity': parseInventoryKg(fields['quantity']!.text)!,
            if (!outgoing) 'amount': int.parse(fields['amount']!.text.trim()),
            if (outgoing) 'penId': penId,
            'notes': fields['notes']!.text.trim(),
            'requestId': requestId,
          };
    final path = isFeed
        ? '/feeds${widget.feed == null ? '' : '/${widget.feed!.id}'}'
        : isCancel
        ? '/stock-entries/${widget.entry!.id}/cancel'
        : '/stock-entries';
    try {
      await widget.repository.save(
        isFeed && widget.feed != null ? 'PATCH' : 'POST',
        path,
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
    String label, {
    bool requiredValue = false,
    bool numeric = false,
    bool allowZero = false,
    int lines = 1,
    int limit = 2000,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy,
      maxLines: lines,
      maxLength: numeric ? null : limit,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.multiline,
      onChanged: numeric || key == 'name' ? (_) => setState(() {}) : null,
      decoration: farmInputDecoration(
        label: label,
        helperText: numeric
            ? 'Tối đa 3 số lẻ. Dùng dấu phẩy hoặc dấu chấm, không tách hàng nghìn.'
            : requiredValue
            ? null
            : 'Tùy chọn.',
      ),
      validator: (v) => numeric
          ? validateInventoryKg(v, allowZero: allowZero)
          : requiredValue && (v ?? '').trim().isEmpty
          ? 'Vui lòng nhập.'
          : null,
    ),
  );

  Widget dateInput() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields['date'],
      readOnly: true,
      enabled: !busy,
      decoration: farmInputDecoration(
        label: 'Ngày ghi nhận',
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: farmParseDate(fields['date']!.text) ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) {
          fields['date']!.text = farmDate(
            date.toIso8601String().substring(0, 10),
          );
        }
      },
      validator: (v) =>
          farmParseDate(v ?? '') == null ? 'Ngày không hợp lệ.' : null,
    ),
  );

  Widget feedInputs() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          FeedSackIllustration(),
          SizedBox(width: 12),
          Expanded(
            child: Text('Thông tin thức ăn và ngưỡng cảnh báo tồn kho.'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SuggestedCodeField(
        api: widget.repository.api,
        controller: fields['code']!,
        kind: 'feeds',
        name: fields['name']!.text,
        label: 'Mã thức ăn',
        enabled: !busy,
        requiredValue: true,
        suggestInitially: widget.feed == null,
      ),
      const SizedBox(height: 16),
      input('name', 'Tên thức ăn', requiredValue: true, limit: 100),
      input('lowStock', 'Ngưỡng tồn thấp (kg)', numeric: true, allowZero: true),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Đang sử dụng'),
        subtitle: const Text(
          'Chỉ thức ăn đang sử dụng mới được nhập hoặc xuất kho.',
        ),
        value: active,
        onChanged: busy ? null : (v) => setState(() => active = v),
      ),
      const SizedBox(height: 16),
      input('notes', 'Ghi chú', lines: 4),
    ],
  );

  Widget entryInputs() {
    final selected = selectedFeed;
    final stock = selected == null ? null : inventoryValue(selected, 'stock');
    final quantity = parseInventoryKg(fields['quantity']!.text);
    final valid = validateInventoryKg(fields['quantity']!.text) == null;
    final balance = stock != null && valid
        ? ((stock * 1000).round() +
                  (outgoing ? -1 : 1) * (quantity! * 1000).round()) /
              1000
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (feeds.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Chưa có thức ăn đang sử dụng để ghi phiếu.'),
          ),
        DropdownButtonFormField<String>(
          initialValue: feedId,
          isExpanded: true,
          decoration: farmInputDecoration(label: 'Thức ăn'),
          items: [
            for (final f in feeds)
              DropdownMenuItem(
                value: f.id,
                child: Text(
                  '${f.text('code')} · ${f.text('name')}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: busy ? null : (v) => setState(() => feedId = v),
          validator: (v) =>
              feeds.any((f) => f.id == v) ? null : 'Vui lòng chọn.',
        ),
        const SizedBox(height: 16),
        if (selected != null) ...[
          InventorySummary(
            title: 'Tồn kho hiện tại',
            name: selected.text('name'),
            quantity: stock,
          ),
          const SizedBox(height: 20),
        ],
        dateInput(),
        input('quantity', 'Số lượng (kg)', numeric: true),
        if (!outgoing) ...[
          TextFormField(
            controller: fields['amount'],
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: farmInputDecoration(
              label: 'Tổng tiền mua (VND)',
              helperText: 'Tổng tiền của cả phiếu nhập. Nhập số nguyên, không tách hàng nghìn.',
            ),
            validator: validateVndAmount,
          ),
          const SizedBox(height: 12),
          const Text(
            'Lưu phiếu sẽ tự ghi khoản chi Thức ăn trong Thu chi. Không cần ghi chi thêm lần nữa.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
        ],
        if (balance != null) ...[
          Text(
            'Dự kiến sau ${outgoing ? 'xuất' : 'nhập'}: ${inventoryKg(balance)} kg',
            style: TextStyle(
              color: balance < 0 ? FarmColors.danger : forest,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            balance < 0
                ? 'Số lượng xuất vượt tồn đang hiển thị. Tồn được kiểm tra lại khi lưu.'
                : 'Ước tính từ tồn đã tải. Tồn được kiểm tra lại khi lưu.',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
        ],
        if (outgoing) ...[
          DropdownButtonFormField<String>(
            initialValue: penId,
            isExpanded: true,
            decoration: farmInputDecoration(label: 'Chuồng (không bắt buộc)'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Không chọn chuồng'),
              ),
              for (final p in widget.pens.where((p) => p.flag('active')))
                DropdownMenuItem(
                  value: p.id,
                  child: Text(p.text('name'), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => penId = v),
          ),
          const SizedBox(height: 16),
        ],
        input('notes', 'Ghi chú', lines: 4),
      ],
    );
  }

  Widget cancelInputs() {
    final e = widget.entry!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InventorySummary(
          title: e.text('kind') == 'IN' ? 'Phiếu nhập' : 'Phiếu xuất',
          name: e.text('feedName'),
          quantity: inventoryValue(e, 'quantity'),
          details: '${farmDate(e.text('date'))} · ${e.text('actorName')}',
        ),
        const SizedBox(height: 20),
        const FeedbackBox(
          'Khi xác nhận, phiếu được đánh dấu đã hủy và vẫn giữ trong lịch sử. Tồn kho được điều chỉnh ngược lại; hủy phiếu nhập sẽ bị từ chối nếu gây âm tồn.',
        ),
        if (e.text('financeEntryId').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Khoản chi mua thức ăn ${vnd(e.values['amount'])} cũng sẽ được hủy.',
          ),
        ],
        const SizedBox(height: 20),
        input(
          'reason',
          'Lý do hủy',
          requiredValue: true,
          lines: 4,
          limit: 1000,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FarmFormLayout(
      title: isFeed
          ? widget.feed == null
                ? 'Thêm thức ăn'
                : 'Sửa thức ăn'
          : isCancel
          ? 'Hủy phiếu kho'
          : outgoing
          ? 'Xuất thức ăn'
          : 'Nhập thức ăn',
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(isCancel ? 'Giữ phiếu' : 'Hủy'),
        ),
        FilledButton(
          onPressed: busy || (!isFeed && !isCancel && feeds.isEmpty)
              ? null
              : submit,
          style: isCancel
              ? FilledButton.styleFrom(
                  backgroundColor: FarmColors.danger,
                  foregroundColor: Colors.white,
                )
              : null,
          child: FarmSubmitLabel(busy: busy, label: action),
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
            if (isFeed)
              feedInputs()
            else if (isCancel)
              cancelInputs()
            else
              entryInputs(),
          ],
        ),
      ),
    ),
  );
}
