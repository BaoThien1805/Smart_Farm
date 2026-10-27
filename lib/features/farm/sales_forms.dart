import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';
import 'finance_values.dart';

Future<bool> sellAnimalForm(
  BuildContext context,
  FarmRepository repository,
  FarmRecord animal, {
  required bool admin,
}) async {
  if (!admin || animal.text('status') != 'ACTIVE') return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SaleEditor(repository: repository, animal: animal),
      ) ??
      false;
}

Future<bool> cancelSaleForm(
  BuildContext context,
  FarmRepository repository,
  FarmRecord sale, {
  required bool admin,
}) async {
  if (!admin || sale.text('cancelledAt').isNotEmpty) return false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SaleEditor(repository: repository, sale: sale),
      ) ??
      false;
}

class SaleEditor extends StatefulWidget {
  const SaleEditor({
    super.key,
    required this.repository,
    this.animal,
    this.sale,
  }) : assert((animal == null) != (sale == null));
  final FarmRepository repository;
  final FarmRecord? animal, sale;
  @override
  State<SaleEditor> createState() => _SaleEditorState();
}

class _SaleEditorState extends State<SaleEditor> {
  final form = GlobalKey<FormState>(), errorAnchor = GlobalKey();
  late final requestId = FarmRepository.requestId();
  final date = TextEditingController(text: farmDate(farmToday()));
  final amount = TextEditingController(), buyer = TextEditingController();
  final notes = TextEditingController(), reason = TextEditingController();
  bool busy = false, loadingPens = false;
  String? penId, error, penError;
  List<FarmRecord> pens = [];
  bool get cancelling => widget.sale != null;
  List<FarmRecord> get availablePens => pens
      .where(
        (p) =>
            p.flag('active') && p.integer('occupied') < p.integer('capacity'),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    if (cancelling) loadPens();
  }

  Future<void> loadPens() async {
    setState(() {
      loadingPens = true;
      penError = null;
    });
    try {
      final data = await widget.repository.get('/farm/catalogs');
      if (!mounted) return;
      setState(() {
        pens = FarmRepository.records(data, 'pens');
        if (!availablePens.any((p) => p.id == penId)) penId = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => penError = e.message);
    } finally {
      if (mounted) setState(() => loadingPens = false);
    }
  }

  @override
  void dispose() {
    for (final c in [date, amount, buyer, notes, reason]) {
      c.dispose();
    }
    super.dispose();
  }

  void reveal(BuildContext? target) {
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  Future<void> submit() async {
    if (busy ||
        loadingPens ||
        (cancelling && (penError != null || availablePens.isEmpty))) {
      return;
    }
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reveal(invalid.first.context);
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, dynamic>{
      'requestId': requestId,
      'date': farmIsoDate(date.text),
      if (cancelling) ...{
        'penId': penId,
        'reason': reason.text.trim(),
      } else ...{
        'amount': int.parse(amount.text.trim()),
        'buyer': buyer.text.trim(),
        'notes': notes.text.trim(),
      },
    };
    try {
      await widget.repository.save(
        'POST',
        cancelling
            ? '/sales/${widget.sale!.id}/cancel'
            : '/animals/${widget.animal!.id}/sell',
        body,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) reveal(errorAnchor.currentContext);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget dateField() => TextFormField(
    controller: date,
    enabled: !busy,
    readOnly: true,
    decoration: farmInputDecoration(
      label: cancelling ? 'Ngày nhận lại' : 'Ngày bán',
      suffixIcon: const Icon(Icons.calendar_today_outlined),
    ),
    onTap: () async {
      final selected = await showDatePicker(
        context: context,
        initialDate: farmParseDate(date.text) ?? DateTime.parse(farmToday()),
        firstDate: DateTime(1900),
        lastDate: DateTime.parse(farmToday()),
      );
      if (selected != null && mounted) {
        setState(
          () =>
              date.text = farmDate(selected.toIso8601String().substring(0, 10)),
        );
      }
    },
    validator: (v) =>
        farmParseDate(v ?? '') == null ? 'Ngày không hợp lệ.' : null,
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    final s = widget.sale;
    final disabled =
        busy ||
        loadingPens ||
        (cancelling && (penError != null || availablePens.isEmpty));
    return PopScope(
      canPop: !busy,
      child: FarmFormLayout(
        title: cancelling
            ? 'Hủy bán · ${s!.text('animalCode')}'
            : 'Bán vật nuôi',
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: Text(cancelling ? 'Giữ giao dịch' : 'Hủy'),
          ),
          FilledButton(
            onPressed: disabled ? null : submit,
            style: cancelling
                ? FilledButton.styleFrom(
                    backgroundColor: FarmColors.danger,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: FarmSubmitLabel(
              busy: busy,
              label: cancelling ? 'Xác nhận hủy' : 'Xác nhận bán',
            ),
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
              if (a != null) ...[
                Row(
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
                          Text(
                            [
                              a.text('speciesName'),
                              a.text('breedName'),
                              label(a.text('gender')),
                            ].where((v) => v.isNotEmpty).join(' · '),
                          ),
                          if (a.text('penName').isNotEmpty)
                            Text('Chuồng: ${a.text('penName')}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FarmStatusBadge(
                    label: 'Đang nuôi',
                    tone: FarmBadgeTone.success,
                  ),
                ),
              ],
              if (s != null) ...[
                Text(
                  s.text('animalCode'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FarmStatusBadge(
                    label: 'Có hiệu lực',
                    tone: FarmBadgeTone.success,
                  ),
                ),
                const SizedBox(height: 20),
                const FarmSectionHeader(title: 'Thông tin giao dịch cũ'),
                const SizedBox(height: 12),
                Text(
                  vnd(s.values['amount']),
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: forest),
                ),
                Text('Ngày bán: ${farmDate(s.text('date'))}'),
                Text(
                  'Người mua: ${s.text('buyer').isEmpty ? 'Không ghi' : s.text('buyer')}',
                ),
                Text(
                  'Ghi chú: ${s.text('notes').isEmpty ? 'Không ghi' : s.text('notes')}',
                ),
              ],
              const SizedBox(height: 24),
              FarmSectionHeader(
                title: cancelling ? 'Thông tin hủy bán' : 'Thông tin bán',
              ),
              const SizedBox(height: 16),
              if (cancelling) ...[
                if (loadingPens) const LinearProgressIndicator(),
                if (penError != null) FeedbackBox(penError!),
                if (!loadingPens && penError == null && availablePens.isEmpty)
                  const FeedbackBox(
                    'Chưa có chuồng đang hoạt động còn chỗ để nhận lại. Hãy kiểm tra chuồng rồi tải lại.',
                  ),
                TextButton.icon(
                  onPressed: busy || loadingPens ? null : loadPens,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại chuồng'),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(availablePens.map((p) => p.id).join(',')),
                  initialValue: penId,
                  isExpanded: true,
                  decoration: farmInputDecoration(
                    label: 'Chuồng nhận lại',
                    helperText: 'Chỉ chuồng hoạt động còn chỗ. Sức chứa sẽ được kiểm tra lại khi xác nhận.',
                  ),
                  items: [
                    for (final p in availablePens)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.text('code')} · ${p.text('name')} (${p.integer('occupied')}/${p.integer('capacity')})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: disabled ? null : (v) => setState(() => penId = v),
                  validator: (v) => availablePens.any((p) => p.id == v)
                      ? null
                      : 'Chọn chuồng nhận lại.',
                ),
                const SizedBox(height: 16),
              ],
              dateField(),
              const SizedBox(height: 16),
              if (!cancelling) ...[
                TextFormField(
                  controller: amount,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: farmInputDecoration(
                    label: 'Số tiền (VND)',
                    helperText: int.tryParse(amount.text.trim()) != null
                        ? vnd(int.parse(amount.text.trim()))
                        : 'Nhập số nguyên VND, không dùng dấu phân cách.',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = num.tryParse((v ?? '').trim());
                    if (n == null || !n.isFinite || n <= 0) {
                      return 'Nhập số lớn hơn 0.';
                    }
                    final integer = int.tryParse((v ?? '').trim());
                    if (integer == null) return 'Nhập số nguyên VND.';
                    if (integer > 1000000000000) {
                      return 'Giá trị tối đa 1000000000000 VND.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: buyer,
                  enabled: !busy,
                  maxLength: 200,
                  decoration: farmInputDecoration(
                    label: 'Người mua (tùy chọn)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notes,
                  enabled: !busy,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: farmInputDecoration(label: 'Ghi chú (tùy chọn)'),
                ),
              ] else
                TextFormField(
                  controller: reason,
                  enabled: !busy,
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: farmInputDecoration(label: 'Lý do hủy bán'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Vui lòng nhập lý do.' : null,
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cancelling ? FarmColors.peach : FarmColors.sky,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: forest),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cancelling
                            ? 'Khi xác nhận, vật nuôi trở lại Đang nuôi tại chuồng đã chọn và khoản thu liên kết được hủy. Giao dịch, lịch sử vẫn được giữ; lịch chăm sóc đã hủy không tự khôi phục.'
                            : 'Khi xác nhận, hệ thống tạo phiếu thu liên kết, chuyển vật nuôi sang Đã bán và hủy các lịch chăm sóc đang chờ. Doanh thu bán đã nằm trong Tổng thu.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
