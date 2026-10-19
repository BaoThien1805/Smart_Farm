import 'dart:convert';
import 'dart:typed_data';

import '../../core/photo_picker.dart';
import '../../core/photo_view.dart';

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
  late final Map<String, TextEditingController> fields;
  Map<String, dynamic> catalogs = {};
  String? speciesId, breedId, penId, preferredAreaId;
  String gender = 'UNKNOWN';
  bool loading = true, busy = false, removePhoto = false;
  bool selectingPhoto = false;
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
          text: a?.text(key) ?? (key == 'arrivalDate' ? farmToday() : ''),
        ),
    };
    speciesId = a?.text('speciesId');
    breedId = a?.text('breedId');
    penId = a?.text('penId');
    gender = a?.text('gender') ?? 'UNKNOWN';
    load();
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await widget.repository.get('/farm/catalogs');
      if (mounted) {
        setState(() {
          catalogs = data;
          error = null;
          if (widget.animal == null &&
              !records('pens').any(
                (p) =>
                    p.id == penId &&
                    p.flag('active') &&
                    p.integer('occupied') < p.integer('capacity'),
              )) {
            penId = null;
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
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addSpecies() async {
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
    if (speciesId == null) return;
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
      setState(() => penId = createdId);
    }
  }

  Future<void> pickPhoto() async {
    if (selectingPhoto) return;
    setState(() => selectingPhoto = true);
    try {
      final bytes = await pickPhotoForUpload();
      if (bytes == null) return;
      if (mounted) {
        setState(() {
          photo = bytes;
          removePhoto = false;
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Không mở được ảnh. Hãy chọn lại từ thiết bị.');
      }
    } finally {
      if (mounted) setState(() => selectingPhoto = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final body = <String, dynamic>{
      for (final e in fields.entries) e.key: e.value.text.trim(),
      'breedId': breedId,
      'gender': gender,
      if (widget.animal == null) 'penId': penId,
      if (photo != null) 'photoBase64': base64Encode(photo!),
      if (removePhoto) 'photoBase64': null,
    };
    if (body['birthDate'] == '') body['birthDate'] = null;
    try {
      await widget.repository.save(
        widget.animal == null ? 'POST' : 'PATCH',
        '/animals${widget.animal == null ? '' : '/${widget.animal!.id}'}',
        body,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
      decoration: InputDecoration(
        labelText: title,
        suffixIcon: date && !readOnly && !required
            ? IconButton(
                tooltip: 'Xóa ngày',
                onPressed: () => fields[key]!.clear(),
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
                initialDate:
                    DateTime.tryParse(fields[key]!.text) ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (d != null && mounted) {
                fields[key]!.text = d.toIso8601String().substring(0, 10);
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
      decoration: InputDecoration(labelText: title),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: busy || readOnly ? null : changed,
      validator: (v) => v == null ? 'Vui lòng chọn.' : null,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final breeds = records('breeds')
        .where((b) => b.text('speciesId') == speciesId)
        .toList();
    final existing = removePhoto ? '' : widget.animal?.text('imageData') ?? '';
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(widget.animal == null ? 'Thêm vật nuôi' : 'Sửa hồ sơ'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) FeedbackBox(error!),
                  if (loading) const LinearProgressIndicator(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: busy || loading ? null : load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Cập nhật danh mục'),
                      ),
                      if (widget.admin && widget.animal == null)
                        TextButton.icon(
                          onPressed: busy || loading ? null : addSpecies,
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm loài'),
                        ),
                    ],
                  ),
                  dropdown(
                    'Loài',
                    speciesId,
                    recordOptions(records('species')),
                    (v) => setState(() {
                      speciesId = v;
                      breedId = null;
                    }),
                    readOnly: widget.animal != null,
                  ),
                  dropdown(
                    'Giống',
                    breedId,
                    recordOptions(breeds),
                    (v) => setState(() => breedId = v),
                  ),
                  if (speciesId != null && breeds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Loài này chưa có giống. ADMIN cần tạo giống trước khi thêm vật nuôi.',
                      ),
                    ),
                  if (widget.admin && speciesId != null)
                    TextButton.icon(
                      onPressed: busy || loading ? null : addBreed,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm giống cho loài này'),
                    ),
                  SuggestedCodeField(
                    api: widget.repository.api,
                    controller: fields['code']!,
                    kind: 'animals',
                    label: 'Mã vật nuôi',
                    enabled: !busy,
                    requiredValue: true,
                    suggestInitially: widget.animal == null,
                    name:
                        records('breeds')
                            .where((b) => b.id == breedId)
                            .map((b) => b.text('name'))
                            .firstOrNull ??
                        records('species')
                            .where((s) => s.id == speciesId)
                            .map((s) => s.text('name'))
                            .firstOrNull ??
                        '',
                  ),
                  const SizedBox(height: 16),
                  input('name', 'Tên / số hiệu (tùy chọn)'),
                  dropdown('Giới tính', gender, {
                    for (final g in ['MALE', 'FEMALE', 'UNKNOWN']) g: label(g),
                  }, (v) => setState(() => gender = v!)),
                  input('birthDate', 'Ngày sinh (nếu biết)', date: true),
                  input(
                    'arrivalDate',
                    'Ngày nhập đàn',
                    required: true,
                    date: true,
                    readOnly: widget.animal != null,
                  ),
                  if (widget.animal == null) ...[
                    if (!loading &&
                        !records('pens').any(
                          (p) =>
                              p.flag('active') &&
                              p.integer('occupied') < p.integer('capacity'),
                        ))
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
                            onPressed: busy || loading ? null : addArea,
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Thêm khu vực'),
                          ),
                          TextButton.icon(
                            onPressed: busy || loading ? null : addPen,
                            icon: const Icon(Icons.add_home_work_outlined),
                            label: const Text('Thêm chuồng'),
                          ),
                        ],
                      ),
                    dropdown('Chuồng', penId, {
                      for (final p in records('pens').where(
                        (p) =>
                            p.flag('active') &&
                            p.integer('occupied') < p.integer('capacity'),
                      ))
                        p.id:
                            '${p.text('code')} · ${p.text('name')} (${p.integer('occupied')}/${p.integer('capacity')})',
                    }, (v) => setState(() => penId = v)),
                  ],
                  input('origin', 'Nguồn gốc'),
                  input('notes', 'Ghi chú', lines: 3),
                  const Text('Ảnh đại diện · JPEG/PNG, tự động thu nhỏ'),
                  const SizedBox(height: 8),
                  if (photo != null)
                    Image.memory(
                      photo!,
                      height: 140,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Text('Ảnh không đọc được.'),
                    )
                  else if (existing.isNotEmpty)
                    PhotoView(data: existing, size: 140),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy || selectingPhoto ? null : pickPhoto,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          selectingPhoto
                              ? 'Đang xử lý ảnh…'
                              : 'Chọn ảnh từ thiết bị',
                        ),
                      ),
                      if (photo != null || existing.isNotEmpty)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  photo = null;
                                  removePhoto = true;
                                }),
                          child: const Text('Bỏ ảnh'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: busy || loading || selectingPhoto ? null : save,
            child: Text(busy ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}
