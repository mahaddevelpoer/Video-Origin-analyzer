import 'package:flutter/material.dart';

/// A compact forensic identity: a lens inspecting a video strip and its
/// evidence trail. It intentionally avoids the familiar play-button silhouette.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.compact = false});

  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(compact: compact),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.scale(scale, scale);
    final bg = Paint()..color = const Color(0xFF12212B);
    final teal = Paint()
      ..color = const Color(0xFF4FE0C1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 4.5 : 4
      ..strokeCap = StrokeCap.round;
    final amber = Paint()..color = const Color(0xFFFFC857);
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(1, 1, 62, 62), const Radius.circular(18)),
      bg,
    );

    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(compact ? 12 : 10, compact ? 15 : 13, compact ? 31 : 34, compact ? 34 : 38),
      const Radius.circular(5),
    );
    canvas.drawRRect(frame, teal);
    for (var i = 0; i < 3; i++) {
      final x = (compact ? 18 : 16) + i * 8.5;
      canvas.drawCircle(Offset(x, compact ? 22 : 20), 2.2, amber);
      canvas.drawLine(Offset(x, compact ? 41 : 45), Offset(x + 5, compact ? 41 : 45), teal);
    }

    final lensCenter = Offset(compact ? 43 : 45, compact ? 36 : 35);
    canvas.drawCircle(lensCenter, compact ? 10 : 12, white);
    canvas.drawLine(
      lensCenter + const Offset(8, 8),
      lensCenter + const Offset(16, 16),
      white,
    );
    canvas.drawCircle(const Offset(53, 16), 3, amber);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => oldDelegate.compact != compact;
}
