import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'ui_components.dart';

class SuggestedCodeField extends StatefulWidget {
  final ApiClient api;
  final TextEditingController controller;
  final String kind, name, label;
  final bool enabled, requiredValue, suggestInitially;
  final FormFieldValidator<String>? validator;
  const SuggestedCodeField({
    super.key,
    required this.api,
    required this.controller,
    required this.kind,
    required this.name,
    required this.label,
    this.enabled = true,
    this.requiredValue = false,
    this.suggestInitially = true,
    this.validator,
  });
  @override
  State<SuggestedCodeField> createState() => _SuggestedCodeFieldState();
}

class _SuggestedCodeFieldState extends State<SuggestedCodeField> {
  Timer? debounce;
  int revision = 0;
  String? generated, error;
  bool loading = false;
  @override
  void initState() {
    super.initState();
    if (widget.suggestInitially && widget.controller.text.isEmpty) {
      requestCode();
    }
  }

  @override
  void didUpdateWidget(covariant SuggestedCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && widget.suggestInitially) {
      revision++;
      loading = false;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), requestCode);
    }
  }

  Future<void> requestCode({bool replace = false}) async {
    if (!replace &&
        widget.controller.text.isNotEmpty &&
        widget.controller.text != generated) {
      return;
    }
    final current = ++revision;
    final initial = widget.controller.text;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final query = Uri(
        queryParameters: {'kind': widget.kind, 'name': widget.name},
      ).query;
      final response = await widget.api.request(
        'GET',
        '/code-suggestion?$query',
      );
      final code = response['code'];
      if (mounted && current == revision && widget.controller.text == initial) {
        if (code is String && code.isNotEmpty) {
          widget.controller.text = code;
          generated = code;
        } else {
          error = 'Chưa có gợi ý mã. Bạn có thể tự nhập mã.';
        }
      }
    } on ApiException catch (e) {
      if (mounted && current == revision) {
        error = e.status == 404
            ? 'Máy chủ chưa có chức năng đề xuất mã. Cần cập nhật backend v10 trên Render; bạn vẫn có thể tự nhập mã.'
            : 'Chưa lấy được gợi ý. Bạn có thể tự nhập mã.';
      }
    } finally {
      if (mounted && current == revision) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    maxLength: 100,
    decoration: farmInputDecoration(
      label: widget.label,
      helperText: error ?? 'Mã đề xuất có thể sửa trước khi lưu.',
      suffixIcon: loading
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              tooltip: 'Đề xuất mã',
              onPressed: widget.enabled
                  ? () => requestCode(replace: true)
                  : null,
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
    ),
    validator:
        widget.validator ??
        (v) => widget.requiredValue && (v == null || v.trim().isEmpty)
            ? 'Nhập mã.'
            : null,
  );
}
