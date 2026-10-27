import 'package:flutter/material.dart';

import 'theme.dart';

/// Small colored illustrations for actions; the surrounding label owns meaning.
class FarmFeatureIcon extends StatelessWidget {
  const FarmFeatureIcon({
    super.key,
    required this.icon,
    this.size = 48,
    this.color = forest,
    this.background = FarmColors.mint,
  });
  final IconData icon;
  final double size;
  final Color color, background;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: .75), background],
        ),
      ),
      padding: EdgeInsets.all(size * .17),
      child:
          icon == Icons.inventory_2_outlined ||
              icon == Icons.account_balance_wallet_outlined
          ? CustomPaint(
              painter: _FarmSymbol(icon == Icons.inventory_2_outlined),
            )
          : Icon(_filled(icon), size: size * .6, color: color),
    ),
  );

  static IconData _filled(IconData icon) => switch (icon) {
    Icons.people_outline => Icons.groups_rounded,
    Icons.category_outlined => Icons.article_rounded,
    Icons.person_outline => Icons.person_rounded,
    Icons.location_on_outlined => Icons.location_on_rounded,
    Icons.home_work_outlined => Icons.home_work_rounded,
    Icons.pets_outlined => Icons.pets_rounded,
    Icons.health_and_safety_outlined => Icons.favorite_rounded,
    _ => icon,
  };
}

class _FarmSymbol extends CustomPainter {
  const _FarmSymbol(this.bag);
  final bool bag;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    if (bag) {
      final path = Path()
        ..moveTo(13, 9)
        ..lineTo(10, 3)
        ..quadraticBezierTo(20, 6, 29, 3)
        ..lineTo(26, 10)
        ..cubicTo(29, 18, 37, 32, 29, 37)
        ..quadraticBezierTo(20, 41, 10, 37)
        ..cubicTo(2, 33, 11, 17, 13, 9)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFC68E));
      canvas.drawPath(
        path,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawLine(
        const Offset(13, 10),
        const Offset(26, 10),
        Paint()
          ..color = ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      final leaf = Path()
        ..moveTo(19, 31)
        ..cubicTo(9, 23, 15, 18, 20, 24)
        ..cubicTo(20, 18, 25, 17, 28, 18)
        ..cubicTo(29, 26, 24, 31, 19, 31)
        ..close();
      canvas.drawPath(leaf, Paint()..color = const Color(0xFF22915E));
      canvas.drawLine(
        const Offset(19, 30),
        const Offset(25, 21),
        Paint()
          ..color = const Color(0xFFBFE8A8)
          ..strokeWidth = 1.5,
      );
    } else {
      for (final (x, bottom, count) in [(24.0, 26.0, 4), (12.0, 36.0, 3)]) {
        for (var i = 0; i < count; i++) {
          final y = bottom - i * 5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 10, y - 4, 20, 7),
              const Radius.circular(3),
            ),
            Paint()..color = const Color(0xFFF5A900),
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y - 4), width: 20, height: 7),
            Paint()..color = const Color(0xFFFFD24C),
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y - 4), width: 20, height: 7),
            Paint()
              ..color = const Color(0xFFFFEB98)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FarmSymbol oldDelegate) => bag != oldDelegate.bag;
}
