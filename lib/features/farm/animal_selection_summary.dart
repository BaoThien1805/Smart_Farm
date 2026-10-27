import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'farm_repository.dart';

class AnimalSelectionSummary extends StatelessWidget {
  const AnimalSelectionSummary({super.key, required this.animals});
  final List<FarmRecord> animals;

  @override
  Widget build(BuildContext context) => Material(
    color: FarmColors.mint.withValues(alpha: .45),
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      title: Text('Đã chọn ${animals.length} vật nuôi'),
      subtitle: Text(
        animals.take(3).map((a) => a.text('code')).join(', '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        SizedBox(
          height: math.min(240.0, animals.length * 90.0),
          child: ListView.builder(
            primary: false,
            itemCount: animals.length,
            itemBuilder: (_, index) => ListTile(
              title: Text(
                '${animals[index].text('code')} · ${animals[index].text('name')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                animals[index].text('penName'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
