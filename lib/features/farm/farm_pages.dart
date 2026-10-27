export 'dashboard_page.dart';
export 'catalog_page.dart';
export 'animals_page.dart';
export 'animal_detail_page.dart';
export 'care_page.dart';
export 'care_forms.dart';

import '../../core/photo_view.dart';

import 'species_chooser.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'farm_repository.dart';

class WeightChart extends StatelessWidget {
  final List<FarmRecord> records;
  const WeightChart({super.key, required this.records});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Semantics(
            label:
                'Biểu đồ cân nặng: ${records.first.number('kg')} đến ${records.last.number('kg')} kg, từ ${farmDate(records.first.text('date'))} đến ${farmDate(records.last.text('date'))}',
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(painter: _WeightPainter(records)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(farmDate(records.first.text('date')))),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  farmDate(records.last.text('date')),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _WeightPainter extends CustomPainter {
  final List<FarmRecord> records;
  _WeightPainter(this.records);
  @override
  void paint(Canvas canvas, Size size) {
    final max = records.map((r) => r.number('kg')).reduce(math.max) * 1.15;
    final first = DateTime.parse(records.first.text('date'))
        .millisecondsSinceEpoch
        .toDouble();
    final range =
        DateTime.parse(records.last.text('date')).millisecondsSinceEpoch -
        first;
    final width = math.max(1.0, size.width - 65);
    final height = size.height - 20;
    final linePaint = Paint()
      ..color = forest
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final x =
          50 +
          (DateTime.parse(r.text('date')).millisecondsSinceEpoch - first) /
              range *
              width;
      final y = height - r.number('kg') / max * (height - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = forest);
    }
    for (var i = 0; i <= 4; i++) {
      final kg = max * i / 4;
      final y = height - kg / max * (height - 10);
      canvas.drawLine(
        Offset(48, y),
        Offset(size.width, y),
        Paint()..color = line,
      );
      final t = TextPainter(
        text: TextSpan(
          text: '${kg.toStringAsFixed(0)} kg',
          style: const TextStyle(
            color: muted,
            fontSize: 12,
            fontFamily: 'FarmRoboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, Offset(0, y - 7));
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) => old.records != records;
}

Widget animalAvatar(FarmRecord animal, {double size = 48}) => PhotoView(
  data: animal.text('imageData'),
  size: size,
  fallback: speciesIcon(animal.text('speciesName')),
  label: 'Ảnh vật nuôi ${animal.text('code')}',
);
