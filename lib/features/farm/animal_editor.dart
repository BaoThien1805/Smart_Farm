import 'dart:convert';
import 'dart:typed_data';

import '../../core/photo_picker.dart';
import '../../core/farm_illustrations.dart';
import '../../core/ui_components.dart';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/suggested_code_field.dart';
import '../../core/theme.dart';
import 'farm_repository.dart';
import 'farm_widgets.dart';

Future<bool> animalForm(
  BuildContext context,
  FarmRepository repository,
  Map<String, dynamic> _, [
  FarmRecord? animal,
  bool admin = false,
]) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          AnimalEditor(repository: repository, animal: animal, admin: admin),
    ) ??
    false;

class AnimalEditor extends StatefulWidget {
  final FarmRepository repository;
  final FarmRecord? animal;
  final bool admin;
  const AnimalEditor({
    super.key,
    required this.repository,
    this.animal,
    this.admin = false,
  });
  @override
  State<AnimalEditor> createState() => _AnimalEditorState();
}

class _AnimalEditorState extends State<AnimalEditor> {
  final form = GlobalKey<FormState>();
  final errorAnchor = GlobalKey();
  late final Map<String, TextEditingController> fields;
  Map<String, dynamic> catalogs = {};
  String? speciesId, breedId, penId, preferredAreaId;
  String? areaFilterId;
  String gender = 'UNKNOWN';
  bool loading = true, busy = false, removePhoto = false;
  bool selectingPhoto = false;
  bool catalogError = false;
  bool batchMode = false;
  final quantity = TextEditingController(text: '1');
  late final requestId = FarmRepository.requestId();
  bool get batch => widget.animal == null && batchMode;
  int? get count => int.tryParse(quantity.text.trim());
  String? get lastCode {
    final match = RegExp(r'^(.*?)([0-9]+)$')
        .firstMatch(fields['code']!.text.trim());
    final n = count;
    if (match == null ||
        match[2]!.length > 12 ||
        n == null ||
        n < 1 ||
        n > 1000) {
      return null;
    }
    final last = int.parse(match[2]!) + n - 1;
    if (last > 999999999999) return null;
    final value =
        '${match[1]}${last.toString().padLeft(match[2]!.length, '0')}';
    return value.length <= 100 ? value : null;
  }

  void updateBatchPreview() {
    if (mounted) setState(() {});
  }

  String? error;
  Uint8List? photo;
  List<FarmRecord> records(String key) => FarmRepository.records(catalogs, key);
  @override
  void initState() {
    super.initState();
    final a = widget.animal;
    fields = {
      for (final key in [
        'code',
        'name',
        'birthDate',
        'arrivalDate',
        'origin',
        'notes',
      ])
        key: TextEditingController(
          text: key.endsWith('Date')
              ? farmDate(
                  a?.text(key) ?? (key == 'arrivalDate' ? farmToday() : ''),
                )
              : a?.text(key) ?? '',
        ),
    };
    speciesId = a?.text('speciesId');
    breedId = a?.text('breedId');
    penId = a?.text('penId');
    gender = a?.text('gender') ?? 'UNKNOWN';
    quantity.addListener(updateBatchPreview);
    fields['code']!.addListener(updateBatchPreview);
    load();
  }

  @override
  void dispose() {
    quantity.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    if (busy || selectingPhoto) return;
    setState(() => loading = true);
    try {
      final data = await widget.repository.get('/farm/catalogs');
      if (mounted) {
        setState(() {
          catalogs = data;
          catalogError = false;
          error = null;
          if (!records('areas').any((a) => a.id == areaFilterId)) {
            areaFilterId = null;
          }
          if (widget.animal == null &&
              !records('pens').any(
                (p) =>
                    p.id == penId &&
                    p.flag('active') &&
                    p.integer('occupied') < p.integer('capacity'),
              )) {
            penId = null;
          }
          if (penId != null &&
              areaFilterId != null &&
              !records(
                'pens',
              ).any((p) => p.id == penId && p.text('areaId') == areaFilterId)) {
            areaFilterId = null;
          }
          if (!records('species').any((s) => s.id == speciesId)) {
            speciesId = null;
            breedId = null;
          }
          if (!records(
            'breeds',
          ).any((b) => b.id == breedId && b.text('speciesId') == speciesId)) {
            breedId = null;
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          catalogError = true;
        });
        revealError();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addSpecies() async {
    if (!widget.admin || widget.animal != null || busy || loading) return;
    if (await farmForm(
          context,
          title: 'Thêm loài',
          codeApi: widget.repository.api,
          codeKind: 'species',
          fields: const [
            FarmField('code', 'Mã loài', requiredValue: false),
            FarmField('name', 'Tên loài'),
          ],
          save: (b) => widget.repository.save('POST', '/farm/species', b),
        ) &&
        mounted) {
      await load();
    }
  }

  Future<void> addBreed() async {
    if (!widget.admin || busy || loading || speciesId == null) return;
    final selected = speciesId!;
    if (await farmForm(
          context,
          title: 'Thêm giống cho loài đã chọn',
          codeApi: widget.repository.api,
          codeKind: 'breeds',
          fields: const [
            FarmField('code', 'Mã giống', requiredValue: false),
            FarmField('name', 'Tên giống'),
          ],
          save: (b) => widget.repository.save('POST', '/farm/breeds', {
            ...b,
            'speciesId': selected,
          }),
        ) &&
        mounted) {
      await load();
    }
  }

  Future<String?> addArea() async {
    if (!widget.admin || busy || loading) return null;
    String? createdId;
    final saved = await farmForm(
      context,
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
        createdId = (data['item'] as Map<String, dynamic>?)?['id']?.toString();
      },
    );
    if (!saved || !mounted) return null;
    await load();
    if (mounted && records('areas').any((a) => a.id == createdId)) {
      preferredAreaId = createdId;
      return createdId;
    }
    return null;
  }

  Future<void> addPen() async {
    if (!widget.admin || busy || loading) return;
    if (records('areas').isEmpty) {
      if (await addArea() == null || !mounted) return;
    }
    if (!mounted) return;
    final areas = records('areas');
    String? createdId;
    final saved = await farmForm(
      context,
      title: 'Thêm chuồng',
      codeApi: widget.repository.api,
      codeKind: 'pens',
      fields: [
        const FarmField('code', 'Mã chuồng'),
        const FarmField('name', 'Tên chuồng'),
        FarmField(
          'areaId',
          'Khu vực',
          initial: areas.any((a) => a.id == preferredAreaId)
              ? preferredAreaId!
              : areas.first.id,
          options: recordOptions(areas),
        ),
        const FarmField(
          'capacity',
          'Sức chứa (con)',
          initial: '10',
          numeric: true,
          integer: true,
          maximum: 100000,
        ),
      ],
      save: (body) async {
        final data = await widget.repository.api.request(
          'POST',
          '/farm/pens',
          body: {...body, 'active': true},
        );
        createdId = (data['item'] as Map<String, dynamic>?)?['id']?.toString();
      },
    );
    if (!saved || !mounted) return;
    await load();
    if (mounted &&
        records('pens').any(
          (p) =>
              p.id == createdId &&
              p.flag('active') &&
              p.integer('occupied') < p.integer('capacity'),
        )) {
      final pen = records('pens').firstWhere((p) => p.id == createdId);
      setState(() {
        penId = createdId;
        areaFilterId = records('areas').any((a) => a.id == pen.text('areaId'))
            ? pen.text('areaId')
            : null;
      });
    }
  }

  Future<void> pickPhoto() async {
    if (busy || selectingPhoto) return;
    setState(() => selectingPhoto = true);
    try {
      final bytes = await pickPhotoForUpload();
      if (bytes == null) return;
      if (mounted) {
        setState(() {
          photo = bytes;
          removePhoto = false;
          if (!catalogError) error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
        revealError();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Không mở được ảnh. Hãy chọn lại từ thiết bị.');
        revealError();
      }
    } finally {
      if (mounted) setState(() => selectingPhoto = false);
    }
  }

  Future<void> save() async {
    if (busy || loading || selectingPhoto || catalogError) return;
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      Scrollable.ensureVisible(
        invalid.first.context,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, dynamic>{
      for (final e in fields.entries)
        e.key: e.key.endsWith('Date')
            ? farmIsoDate(e.value.text)
            : e.value.text.trim(),
      'breedId': breedId,
      'gender': gender,
      if (widget.animal == null) 'penId': penId,
      if (photo != null) 'photoBase64': base64Encode(photo!),
      if (removePhoto) 'photoBase64': null,
    };
    if (body['birthDate'] == '') body['birthDate'] = null;
    if (batch) {
      body['firstCode'] = body.remove('code');
      body['quantity'] = count;
      body['requestId'] = requestId;
    }
    try {
      await widget.repository.save(
        widget.animal == null ? 'POST' : 'PATCH',
        batch
            ? '/animals/batch/create'
            : '/animals${widget.animal == null ? '' : '/${widget.animal!.id}'}',
        body,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => error =
              batch &&
                  e.status == 404 &&
                  e.message == 'Không tìm thấy đường dẫn.'
              ? 'Máy chủ chưa hỗ trợ nhập theo số lượng. Cần cập nhật máy chủ trước khi nhập; nội dung vừa nhập vẫn được giữ.'
              : e.message,
        );
        revealError();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void revealError() {
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

  Widget input(
    String key,
    String title, {
    bool required = false,
    bool date = false,
    bool readOnly = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy,
      readOnly: date || readOnly,
      maxLength: key == 'notes' || key == 'origin' ? 2000 : 100,
      maxLines: lines,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: farmInputDecoration(
        label: title,
        suffixIcon: date && !readOnly && !required
            ? IconButton(
                tooltip: 'Xóa ngày',
                onPressed: busy ? null : () => fields[key]!.clear(),
                icon: const Icon(Icons.clear),
              )
            : date
            ? const Icon(Icons.calendar_today_outlined)
            : null,
      ),
      onTap: date && !readOnly
          ? () async {
              final d = await showDatePicker(
                context: context,
                initialDate: farmParseDate(fields[key]!.text) ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (d != null && mounted) {
                fields[key]!.text = farmDate(
                  d.toIso8601String().substring(0, 10),
                );
              }
            }
          : null,
      validator: (v) =>
          required && (v ?? '').trim().isEmpty ? 'Vui lòng nhập.' : null,
    ),
  );
  Widget dropdown(
    String title,
    String? value,
    Map<String, String> options,
    ValueChanged<String?> changed, {
    bool readOnly = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$title-$value-${options.keys.join()}'),
      initialValue: value,
      isExpanded: true,
      decoration: farmInputDecoration(label: title),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: busy || loading || readOnly ? null : changed,
      validator: (v) => v == null ? 'Vui lòng chọn.' : null,
    ),
  );
  Widget section(String title, IconData icon, String description) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: forest, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(color: muted)),
      ],
    ),
  );

  Widget photoCard(String existing, FarmRecord? species) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FarmColors.mint.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(FarmRadii.field),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FarmAnimalImage(
                photoData: photo == null ? existing : base64Encode(photo!),
                speciesCode: species?.text('code'),
                speciesName:
                    species?.text('name') ?? widget.animal?.text('speciesName'),
                size: 96,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ảnh vật nuôi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tùy chọn · JPEG/PNG dưới 12 MB. Ảnh được tự động thu nhỏ.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy || selectingPhoto ? null : pickPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            selectingPhoto ? 'Đang xử lý ảnh…' : 'Chọn ảnh từ thiết bị',
          ),
        ),
        if (photo != null || existing.isNotEmpty)
          TextButton(
            onPressed: busy || selectingPhoto
                ? null
                : () => setState(() {
                    photo = null;
                    removePhoto = true;
                  }),
            child: const Text('Bỏ ảnh'),
          ),
        if (removePhoto && widget.animal?.text('imageData').isNotEmpty == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Ảnh sẽ được gỡ khi lưu hồ sơ.',
              style: TextStyle(color: muted),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final creating = widget.animal == null;
    final breeds = records('breeds')
        .where((b) => b.text('speciesId') == speciesId)
        .toList();
    final species = records('species')
        .where((s) => s.id == speciesId)
        .firstOrNull;
    final availablePens = records('pens')
        .where(
          (p) =>
              p.flag('active') && p.integer('occupied') < p.integer('capacity'),
        )
        .toList();
    final existing = removePhoto ? '' : widget.animal?.text('imageData') ?? '';
    final currentPen = records('pens').where((p) => p.id == penId).firstOrNull;
    final currentArea = records('areas')
        .where((a) => a.id == currentPen?.text('areaId'))
        .firstOrNull;
    final locked = busy || loading || selectingPhoto;
    return PopScope(
      canPop: !busy && !selectingPhoto,
      child: FarmFormLayout(
        title: creating ? 'Thêm vật nuôi' : 'Sửa hồ sơ',
        actions: [
          TextButton(
            onPressed: busy || selectingPhoto
                ? null
                : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: locked || catalogError ? null : save,
            child: FarmSubmitLabel(
              busy: busy,
              label: batch ? 'Nhập ${count ?? 0} con' : 'Lưu',
            ),
          ),
        ],
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null) ...[
                FeedbackBox(error!, key: errorAnchor),
                const SizedBox(height: 12),
              ],
              if (loading) const LinearProgressIndicator(),
              if (creating) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Một con'),
                      selected: !batchMode,
                      onSelected: locked
                          ? null
                          : (_) => setState(() => batchMode = false),
                    ),
                    ChoiceChip(
                      label: const Text('Theo số lượng'),
                      selected: batchMode,
                      onSelected: locked
                          ? null
                          : (_) => setState(() => batchMode = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (batch) ...[
                  const Text(
                    'Mỗi con có một hồ sơ và mã riêng. Thông tin bên dưới áp dụng chung cho đợt nhập.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('animal-batch-quantity'),
                    controller: quantity,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: farmInputDecoration(
                      label: 'Số lượng (con)',
                      helperText: 'Từ 1 đến 1.000 con mỗi đợt.',
                    ).copyWith(counterText: ''),
                    validator: (_) =>
                        count == null ||
                            !RegExp(r'^[0-9]+$')
                                .hasMatch(quantity.text.trim()) ||
                            count! < 1 ||
                            count! > 1000
                        ? 'Nhập số nguyên từ 1 đến 1.000.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              if (catalogError)
                const Text(
                  'Cần tải lại danh mục trước khi lưu. Nội dung vừa nhập vẫn được giữ.',
                  style: TextStyle(color: FarmColors.danger),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: locked ? null : load,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    catalogError ? 'Thử tải lại danh mục' : 'Cập nhật danh mục',
                  ),
                ),
              ),
              photoCard(existing, species),
              const SizedBox(height: 20),
              section(
                'Nhận dạng',
                Icons.pets_outlined,
                'Loài, giống và mã giúp nhận diện vật nuôi. Tên / số hiệu là tùy chọn.',
              ),
              dropdown(
                'Loài',
                speciesId,
                recordOptions(records('species')),
                (v) => setState(() {
                  speciesId = v;
                  breedId = null;
                }),
                readOnly: !creating,
              ),
              if (widget.admin && creating)
                TextButton.icon(
                  onPressed: locked ? null : addSpecies,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm loài'),
                ),
              dropdown(
                'Giống',
                breedId,
                recordOptions(breeds),
                (v) => setState(() => breedId = v),
              ),
              if (speciesId != null && breeds.isEmpty && !loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Loài này chưa có giống. Chủ trang trại cần tạo giống trước khi thêm vật nuôi.',
                  ),
                ),
              if (widget.admin && speciesId != null)
                TextButton.icon(
                  onPressed: locked ? null : addBreed,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm giống cho loài này'),
                ),
              SuggestedCodeField(
                api: widget.repository.api,
                controller: fields['code']!,
                kind: 'animals',
                label: batch ? 'Mã đầu tiên' : 'Mã vật nuôi',
                enabled: !busy,
                requiredValue: true,
                suggestInitially: creating,
                validator: batch
                    ? (_) => lastCode == null
                          ? 'Mã cần kết thúc bằng số (tối đa 12 chữ số), ví dụ GA-001. Dãy mã không được vượt 100 ký tự.'
                          : null
                    : null,
                name:
                    breeds
                        .where((b) => b.id == breedId)
                        .map((b) => b.text('name'))
                        .firstOrNull ??
                    species?.text('name') ??
                    '',
              ),
              if (batch && lastCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Dãy mã: ${fields['code']!.text.trim()} → $lastCode',
                  key: const ValueKey('animal-batch-codes'),
                  style: const TextStyle(color: forest),
                ),
              ],
              const SizedBox(height: 16),
              input(
                'name',
                batch ? 'Tên chung (tùy chọn)' : 'Tên / số hiệu (tùy chọn)',
              ),
              dropdown('Giới tính', gender, {
                for (final g in ['MALE', 'FEMALE', 'UNKNOWN']) g: label(g),
              }, (v) => setState(() => gender = v!)),
              const Divider(height: 32),
              section(
                'Ngày & nguồn gốc',
                Icons.event_outlined,
                creating
                    ? 'Chọn ngày nhập đàn. Có thể bổ sung ngày sinh khi biết.'
                    : 'Ngày nhập đàn được giữ nguyên khi sửa hồ sơ.',
              ),
              input('birthDate', 'Ngày sinh (nếu biết)', date: true),
              input(
                'arrivalDate',
                'Ngày nhập đàn',
                required: true,
                date: true,
                readOnly: !creating,
              ),
              input('origin', 'Nguồn gốc', lines: 2),
              const Divider(height: 32),
              section(
                'Chuồng nuôi',
                Icons.home_work_outlined,
                creating
                    ? 'Chọn chuồng đang hoạt động và còn chỗ. Khu vực chỉ dùng để lọc chuồng.'
                    : 'Muốn đổi chuồng, dùng Chuyển chuồng trong hồ sơ để lưu lịch sử.',
              ),
              if (creating) ...[
                if (!loading && !catalogError && availablePens.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      widget.admin
                          ? 'Chưa có chuồng còn chỗ. Bạn có thể tạo khu vực và chuồng ngay tại đây.'
                          : 'Chưa có chuồng còn chỗ. Hãy liên hệ chủ trang trại để bổ sung chuồng.',
                    ),
                  ),
                if (widget.admin)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: locked ? null : addArea,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Thêm khu vực'),
                      ),
                      TextButton.icon(
                        onPressed: locked ? null : addPen,
                        icon: const Icon(Icons.add_home_work_outlined),
                        label: const Text('Thêm chuồng'),
                      ),
                    ],
                  ),
                if (records('areas').isNotEmpty)
                  dropdown(
                    'Khu vực (lọc chuồng)',
                    areaFilterId ?? '',
                    {'': 'Tất cả khu vực', ...recordOptions(records('areas'))},
                    (v) => setState(() {
                      areaFilterId = v == '' ? null : v;
                      preferredAreaId = areaFilterId;
                      if (areaFilterId != null &&
                          currentPen?.text('areaId') != areaFilterId) {
                        penId = null;
                      }
                    }),
                  ),
                dropdown('Chuồng', penId, {
                  for (final p in availablePens.where(
                    (p) =>
                        areaFilterId == null ||
                        p.text('areaId') == areaFilterId,
                  ))
                    p.id:
                        '${p.text('code')} · ${p.text('name')} (${p.integer('occupied')}/${p.integer('capacity')})',
                }, (v) => setState(() => penId = v)),
                if (batch && currentPen != null) ...[
                  Text(
                    'Chuồng còn ${currentPen.integer('capacity') - currentPen.integer('occupied')} chỗ. Sau khi nhập: ${currentPen.integer('occupied') + (count ?? 0)}/${currentPen.integer('capacity')} con.',
                    style: const TextStyle(color: muted),
                  ),
                  FormField<int>(
                    key: ValueKey('batch-capacity-$penId-${quantity.text}'),
                    validator: (_) =>
                        count != null &&
                            count! >
                                currentPen.integer('capacity') -
                                    currentPen.integer('occupied')
                        ? 'Chuồng không đủ chỗ cho $count con. Giảm số lượng hoặc chọn chuồng khác.'
                        : null,
                    builder: (state) => state.hasError
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              state.errorText!,
                              style: const TextStyle(color: FarmColors.danger),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!loading &&
                    areaFilterId != null &&
                    !availablePens.any((p) => p.text('areaId') == areaFilterId))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Khu vực này chưa có chuồng còn chỗ. Chọn khu vực khác hoặc Tất cả khu vực.',
                    ),
                  ),
              ] else ...[
                Text(
                  'Khu vực: ${currentArea?.text('name') ?? 'Chưa có thông tin khu vực'}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Chuồng: ${currentPen?.text('name') ?? widget.animal!.text('penName')}',
                ),
                const SizedBox(height: 16),
              ],
              const Divider(height: 32),
              section(
                'Ghi chú',
                Icons.notes_outlined,
                'Thông tin bổ sung, không bắt buộc.',
              ),
              input('notes', 'Ghi chú', lines: 4),
            ],
          ),
        ),
      ),
    );
  }
}
