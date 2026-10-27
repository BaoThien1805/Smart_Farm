import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/farm_illustrations.dart';
import '../../core/photo_picker.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class PenIconChoice {
  const PenIconChoice(this.key, {this.data = '', this.upload});
  final String key, data;
  final String? upload;
}

class PenIconField extends StatefulWidget {
  const PenIconField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.enabled = true,
    this.speciesNames = const [],
  });
  final PenIconChoice initial;
  final ValueChanged<PenIconChoice> onChanged;
  final bool enabled;
  final List<String> speciesNames;
  @override
  State<PenIconField> createState() => _PenIconFieldState();
}

class _PenIconFieldState extends State<PenIconField> {
  late PenIconChoice choice = widget.initial;
  Future<void> choose() async {
    if (!widget.enabled) return;
    final result = await showDialog<PenIconChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          PenIconDialog(initial: choice, speciesNames: widget.speciesNames),
    );
    if (mounted && result != null) {
      setState(() => choice = result);
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Icon chuồng', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Row(
        children: [
          FarmPenIllustration(
            size: 72,
            iconKey: choice.key,
            iconData: choice.data,
            speciesNames: widget.speciesNames,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.enabled ? choose : null,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Chọn icon'),
            ),
          ),
        ],
      ),
    ],
  );
}

class PenIconDialog extends StatefulWidget {
  const PenIconDialog({
    super.key,
    required this.initial,
    required this.speciesNames,
  });
  final PenIconChoice initial;
  final List<String> speciesNames;
  @override
  State<PenIconDialog> createState() => _PenIconDialogState();
}

class _PenIconDialogState extends State<PenIconDialog> {
  late PenIconChoice choice = widget.initial;
  late PenIconChoice? customChoice = widget.initial.key == 'custom'
      ? widget.initial
      : null;
  bool picking = false;
  String? error;
  Future<void> upload() async {
    if (picking) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final bytes = await pickPhotoForUpload();
      if (mounted && bytes != null) {
        final encoded = base64Encode(bytes);
        setState(
          () => choice = customChoice = PenIconChoice(
            'custom',
            data: encoded,
            upload: encoded,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Không chọn được ảnh. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !picking,
    child: FarmFormLayout(
      title: 'Chọn icon chuồng',
      actions: [
        TextButton(
          onPressed: picking ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: picking ? null : () => Navigator.pop(context, choice),
          child: const Text('Dùng icon này'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: FarmPenIllustration(
              size: 96,
              iconKey: choice.key,
              iconData: choice.data,
              speciesNames: widget.speciesNames,
            ),
          ),
          const SizedBox(height: 12),
          if (error != null) ...[
            FeedbackBox(error!),
            const SizedBox(height: 12),
          ],
          const Text('Icon có sẵn'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in {
                if (customChoice != null) 'custom': 'Ảnh tải lên',
                'auto': 'Tự động',
                'barn': 'Chuồng trại',
                for (final art in FarmSpeciesArt.values)
                  art.filename: art.label,
              }.entries)
                SizedBox(
                  width: 88,
                  height: 112,
                  child: Semantics(
                    selected: choice.key == entry.key,
                    button: true,
                    label: entry.value,
                    child: Material(
                      color: choice.key == entry.key
                          ? FarmColors.mint
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: choice.key == entry.key ? forest : line,
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('pen-icon-${entry.key}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: picking
                            ? null
                            : () => setState(
                                () => choice = entry.key == 'custom'
                                    ? customChoice!
                                    : PenIconChoice(entry.key),
                              ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              FarmPenIllustration(
                                size: 48,
                                iconKey: entry.key,
                                iconData: entry.key == 'custom'
                                    ? customChoice!.data
                                    : '',
                                speciesNames: widget.speciesNames,
                                decorative: true,
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tự động: dùng icon của loài đang nuôi; chuồng trống hoặc nhiều loài dùng icon chuồng trại.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: picking ? null : upload,
            icon: const Icon(Icons.upload_outlined),
            label: Text(picking ? 'Đang xử lý…' : 'Tải icon từ thiết bị'),
          ),
          const SizedBox(height: 4),
          const Text('Ảnh PNG/JPEG tối đa 12 MB. PNG giữ nền trong suốt.'),
        ],
      ),
    ),
  );
}
