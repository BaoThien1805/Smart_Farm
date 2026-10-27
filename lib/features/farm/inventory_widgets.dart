import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'farm_repository.dart';

num? inventoryValue(FarmRecord record, String key) {
  final value = record.values[key];
  return value is num && value.isFinite ? value : null;
}

String inventoryKg(num? value) => value == null
    ? '—'
    : value
          .toStringAsFixed(3)
          .replaceFirst(RegExp(r'\.?0+$'), '')
          .replaceAll('.', ',');

num? parseInventoryKg(String value) =>
    num.tryParse(value.trim().replaceAll(',', '.'));

String inventoryTimestamp(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final date = parsed.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)} (UTC+7)';
}

String? validateInventoryKg(String? text, {bool allowZero = false}) {
  final value = parseInventoryKg(text ?? '');
  if (value == null ||
      !value.isFinite ||
      (allowZero ? value < 0 : value <= 0)) {
    return allowZero ? 'Nhập số không âm.' : 'Nhập số lớn hơn 0.';
  }
  if (value > 100000000) return 'Giá trị tối đa 100000000 kg.';
  if ((value * 1000 - (value * 1000).round()).abs() >= 1e-5) {
    return 'Tối đa 3 chữ số thập phân.';
  }
  return null;
}

/// A small code-native sack illustration, deliberately without a species mark.
class FeedSackIllustration extends StatelessWidget {
  const FeedSackIllustration({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FeedSackPainter()),
    ),
  );
}

class _FeedSackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeJoin = StrokeJoin.round;
    final sack = Path()
      ..moveTo(23, 15)
      ..lineTo(41, 15)
      ..cubicTo(42, 25, 54, 37, 52, 53)
      ..quadraticBezierTo(50, 60, 32, 59)
      ..quadraticBezierTo(14, 60, 12, 53)
      ..cubicTo(10, 37, 22, 25, 23, 15)
      ..close();
    canvas.drawPath(sack, Paint()..color = FarmColors.peach);
    canvas.drawPath(sack, outline);
    final tie = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 7, 24, 9),
      const Radius.circular(4),
    );
    canvas.drawRRect(tie, Paint()..color = FarmColors.amber);
    canvas.drawRRect(tie, outline);
    canvas.drawLine(const Offset(23, 21), const Offset(41, 21), outline);
    final stem = Paint()
      ..color = forest
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(32, 34), const Offset(32, 51), stem);
    canvas.drawOval(const Rect.fromLTWH(23, 33, 9, 6), Paint()..color = forest);
    canvas.drawOval(const Rect.fromLTWH(32, 38, 9, 6), Paint()..color = forest);
    canvas.drawOval(const Rect.fromLTWH(23, 43, 9, 6), Paint()..color = forest);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FeedSackPainter oldDelegate) => false;
}

class InventorySummary extends StatelessWidget {
  const InventorySummary({
    super.key,
    required this.title,
    required this.name,
    this.quantity,
    this.details,
    this.danger = false,
  });
  final String title, name;
  final num? quantity;
  final String? details;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: danger
          ? FarmColors.dangerSurface
          : FarmColors.mint.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(color: muted)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FeedSackIllustration(size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  if (quantity != null)
                    Text(
                      '${inventoryKg(quantity)} kg',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (details != null) ...[const SizedBox(height: 12), Text(details!)],
      ],
    ),
  );
}
