import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui_components.dart';
import 'farm_repository.dart';

class CareTargetPicker extends StatefulWidget {
  const CareTargetPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.pens,
    this.enabled = true,
  });
  final List<FarmRecord> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool pens, enabled;

  @override
  State<CareTargetPicker> createState() => _CareTargetPickerState();
}

class _CareTargetPickerState extends State<CareTargetPicker> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final filtered = widget.options
        .where(
          (item) =>
              '${item.text('code')} ${item.text('name')} ${item.text('penName')}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: search,
          enabled: widget.enabled,
          onChanged: (_) => setState(() {}),
          decoration: farmInputDecoration(
            label: widget.pens ? 'Tìm chuồng' : 'Tìm vật nuôi',
            suffixIcon: const Icon(Icons.search),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: !widget.enabled || filtered.isEmpty
                  ? null
                  : () => widget.onChanged({
                      ...widget.selected,
                      ...filtered.map((o) => o.id),
                    }),
              child: Text(
                query.isEmpty ? 'Chọn tất cả' : 'Chọn tất cả kết quả',
              ),
            ),
            TextButton(
              onPressed: !widget.enabled || widget.selected.isEmpty
                  ? null
                  : () => widget.onChanged({}),
              child: const Text('Bỏ chọn tất cả'),
            ),
          ],
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Không có kết quả phù hợp.'),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            height: math.min(240.0, filtered.length * 100.0),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              key: ValueKey(widget.pens ? 'care-pen-list' : 'care-animal-list'),
              primary: false,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return CheckboxListTile(
                  key: ValueKey('care-target-${item.id}'),
                  value: widget.selected.contains(item.id),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    widget.pens
                        ? item.text('name')
                        : '${item.text('code')}${item.text('name').isEmpty ? '' : ' · ${item.text('name')}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    widget.pens
                        ? '${item.integer('count')} con đang nuôi'
                        : item.text('penName'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: !widget.enabled
                      ? null
                      : (value) {
                          final selected = {...widget.selected};
                          if (value == true) {
                            selected.add(item.id);
                          } else {
                            selected.remove(item.id);
                          }
                          widget.onChanged(selected);
                        },
                );
              },
            ),
          ),
      ],
    );
  }
}
