import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/suggested_code_field.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';

class FarmField {
  final String key, title;
  final String initial;
  final bool requiredValue, numeric, date, boolean;
  final Map<String, String>? options;
  final bool readOnly;
  final bool allowZero;
  final bool integer;
  final String integerMessage;
  final num? maximum;
  const FarmField(
    this.key,
    this.title, {
    this.initial = '',
    this.requiredValue = true,
    this.numeric = false,
    this.date = false,
    this.boolean = false,
    this.options,
    this.readOnly = false,
    this.allowZero = false,
    this.integer = false,
    this.integerMessage = 'Nhập số nguyên VND.',
    this.maximum,
  });
}

Future<bool> farmForm(
  BuildContext context, {
  required String title,
  required List<FarmField> fields,
  ApiClient? codeApi,
  String? codeKind,
  Widget? intro,
  Widget Function(bool busy)? extraFields,
  required Future<void> Function(Map<String, dynamic>) save,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FarmDialog(
        title: title,
        fields: fields,
        save: save,
        codeApi: codeApi,
        codeKind: codeKind,
        intro: intro,
        extraFields: extraFields,
      ),
    ) ??
    false;

class _FarmDialog extends StatefulWidget {
  final String title;
  final ApiClient? codeApi;
  final String? codeKind;
  final Widget? intro;
  final Widget Function(bool busy)? extraFields;
  final List<FarmField> fields;
  final Future<void> Function(Map<String, dynamic>) save;
  const _FarmDialog({
    required this.title,
    this.codeApi,
    this.codeKind,
    this.intro,
    this.extraFields,
    required this.fields,
    required this.save,
  });
  @override
  State<_FarmDialog> createState() => _FarmDialogState();
}

class _FarmDialogState extends State<_FarmDialog> {
  final form = GlobalKey<FormState>();
  final errorAnchor = GlobalKey();
  late final Map<String, TextEditingController> controllers;
  late final Map<String, String?> selections;
  late final Map<String, bool> flags;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final f in widget.fields)
        f.key: TextEditingController(
          text: f.date ? farmDate(f.initial) : f.initial,
        ),
    };
    selections = {
      for (final f in widget.fields)
        f.key: f.initial.isEmpty ? null : f.initial,
    };
    flags = {for (final f in widget.fields) f.key: f.initial != 'false'};
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final values = <String, dynamic>{};
    for (final f in widget.fields) {
      final value = controllers[f.key]!.text.trim();
      if (f.key == 'code' && value.isEmpty && !f.requiredValue) continue;
      values[f.key] = f.boolean
          ? flags[f.key]
          : f.options != null
          ? selections[f.key]
          : f.numeric
          ? num.parse(value)
          : f.date
          ? farmIsoDate(value)
          : value;
    }
    try {
      await widget.save(values);
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: FarmFormLayout(
      title: widget.title,
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: FarmSubmitLabel(busy: busy, label: 'Lưu'),
        ),
      ],
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.intro != null) ...[
              widget.intro!,
              const SizedBox(height: 20),
            ],
            if (widget.extraFields != null) ...[
              widget.extraFields!(busy),
              const SizedBox(height: 20),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeedbackBox(error!, key: errorAnchor),
              ),
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child:
                    f.key == 'code' &&
                        widget.codeApi != null &&
                        widget.codeKind != null
                    ? SuggestedCodeField(
                        api: widget.codeApi!,
                        controller: controllers[f.key]!,
                        kind: widget.codeKind!,
                        name: controllers['name']?.text ?? '',
                        label: f.title,
                        enabled: !busy,
                        requiredValue: f.requiredValue,
                        suggestInitially: f.initial.isEmpty,
                      )
                    : f.boolean
                    ? SwitchListTile(
                        title: Text(f.title),
                        value: flags[f.key]!,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => flags[f.key] = v),
                      )
                    : f.options != null
                    ? DropdownButtonFormField<String>(
                        initialValue: selections[f.key],
                        isExpanded: true,
                        decoration: farmInputDecoration(label: f.title),
                        items: [
                          for (final e in f.options!.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy || f.readOnly
                            ? null
                            : (v) => selections[f.key] = v,
                        validator: (v) => f.requiredValue && v == null
                            ? 'Vui lòng chọn.'
                            : null,
                      )
                    : TextFormField(
                        controller: controllers[f.key],
                        onChanged: f.key == 'name' && widget.codeKind != null
                            ? (_) => setState(() {})
                            : null,
                        enabled: !busy,
                        readOnly: f.date || f.readOnly,
                        decoration: farmInputDecoration(
                          label: f.title,
                          suffixIcon: f.date
                              ? !f.requiredValue && !f.readOnly
                                    ? IconButton(
                                        tooltip: 'Xóa ngày',
                                        onPressed: busy
                                            ? null
                                            : () => controllers[f.key]!.clear(),
                                        icon: const Icon(Icons.clear),
                                      )
                                    : const Icon(Icons.calendar_today_outlined)
                              : null,
                        ),
                        keyboardType: f.numeric
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        maxLength: f.key == 'notes' || f.key == 'origin'
                            ? 2000
                            : 100,
                        maxLines: f.key == 'notes' ? 3 : 1,
                        onTap: f.date && !f.readOnly
                            ? () async {
                                final parsed = farmParseDate(
                                  controllers[f.key]!.text,
                                );
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: parsed ?? DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null && mounted) {
                                  controllers[f.key]!.text = farmDate(
                                    d.toIso8601String().substring(0, 10),
                                  );
                                }
                              }
                            : null,
                        validator: (v) {
                          if (f.requiredValue && (v ?? '').trim().isEmpty) {
                            return 'Vui lòng nhập.';
                          }
                          if (f.numeric &&
                              (num.tryParse(v ?? '') == null ||
                                  !num.parse(v!).isFinite ||
                                  (f.allowZero
                                      ? num.parse(v) < 0
                                      : num.parse(v) <= 0))) {
                            return f.allowZero
                                ? 'Nhập số không âm.'
                                : 'Nhập số lớn hơn 0.';
                          }
                          if (f.date &&
                              f.requiredValue &&
                              farmParseDate(v ?? '') == null) {
                            return 'Ngày không hợp lệ.';
                          }
                          if (f.numeric &&
                              f.integer &&
                              int.tryParse(v ?? '') == null) {
                            return f.integerMessage;
                          }
                          if (f.numeric &&
                              f.maximum != null &&
                              num.parse(v!) > f.maximum!) {
                            return 'Giá trị tối đa ${f.maximum}.';
                          }
                          return null;
                        },
                      ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> farmConfirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;
Map<String, String> recordOptions(
  List<FarmRecord> records, {
  String key = 'name',
}) => {for (final r in records) r.id: r.text(key)};

class FarmBody extends StatelessWidget {
  final FarmController controller;
  final Widget? menuAction;
  final String title;
  final VoidCallback refresh;
  final List<Widget> actions, children;
  const FarmBody({
    super.key,
    required this.controller,
    required this.title,
    required this.refresh,
    this.actions = const [],
    this.menuAction,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                FarmSectionHeader(
                  pageTitle: true,
                  title: title,
                  action: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?menuAction,
                      IconButton.filledTonal(
                        tooltip: 'Tải lại',
                        onPressed: controller.loading
                            ? null
                            : () {
                                if (!controller.loading) refresh();
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
              if (title.isNotEmpty || actions.isNotEmpty)
                const SizedBox(height: 20),
              if (controller.loading) const FarmLoadingState(),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FarmLoadError(
                    message: controller.error!,
                    onRetry: controller.loading
                        ? null
                        : () {
                            if (!controller.loading) refresh();
                          },
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}
