import 'package:flutter/material.dart';
import 'dart:math';
import '../theme/app_theme.dart';

/// Draws a single hand-drawn wobbly pill path.
Path handDrawnPillPath(Rect rect, {int seed = 0, double wobble = 1.0, double topDip = 0.0}) {
  final rng = Random(seed);
  final cx = rect.center.dx;
  final cy = rect.center.dy;
  final hw = rect.width / 2;
  final hh = rect.height / 2;
  final radius = hh;

  double jx() => (rng.nextDouble() - 0.5) * hh * 0.45 * wobble;
  double jy() => (rng.nextDouble() - 0.5) * hh * 0.5 * wobble;

  final path = Path();

  final topLeftX = cx - hw + radius + jx();
  final topLeftY = cy - hh + jy() * 0.3;
  path.moveTo(topLeftX, topLeftY);

  // Top edge — topDip pushes the midpoint downward
  final topMidX = cx + jx();
  final topMidY = cy - hh + jy() * 0.4 + topDip;
  final topRightX = cx + hw - radius + jx();
  final topRightY = cy - hh + jy() * 0.3;

  path.cubicTo(
    topLeftX + (topMidX - topLeftX) * 0.3 + jx(), topLeftY + jy() * 0.5,
    topMidX - (topMidX - topLeftX) * 0.3 + jx(), topMidY + jy() * 0.5,
    topMidX, topMidY,
  );
  path.cubicTo(
    topMidX + (topRightX - topMidX) * 0.3 + jx(), topMidY + jy() * 0.5,
    topRightX - (topRightX - topMidX) * 0.3 + jx(), topRightY + jy() * 0.5,
    topRightX, topRightY,
  );

  // Right cap
  final rCapCx = cx + hw - radius;
  path.cubicTo(
    rCapCx + radius * 0.8 + jx() * 0.5, cy - hh * 0.6 + jy() * 0.3,
    rCapCx + radius * 1.1 + jx() * 0.4, cy - hh * 0.15 + jy() * 0.3,
    rCapCx + radius + jx() * 0.3, cy + jy() * 0.2,
  );
  path.cubicTo(
    rCapCx + radius * 1.1 + jx() * 0.4, cy + hh * 0.15 + jy() * 0.3,
    rCapCx + radius * 0.8 + jx() * 0.5, cy + hh * 0.6 + jy() * 0.3,
    cx + hw - radius + jx(), cy + hh + jy() * 0.3,
  );

  // Bottom edge
  final botRightX = cx + hw - radius + jx();
  final botRightY = cy + hh + jy() * 0.3;
  final botMidX = cx + jx();
  final botMidY = cy + hh + jy() * 0.4;
  final botLeftX = cx - hw + radius + jx();
  final botLeftY = cy + hh + jy() * 0.3;

  path.cubicTo(
    botRightX - (botRightX - botMidX) * 0.3 + jx(), botRightY + jy() * 0.5,
    botMidX + (botRightX - botMidX) * 0.3 + jx(), botMidY + jy() * 0.5,
    botMidX, botMidY,
  );
  path.cubicTo(
    botMidX - (botMidX - botLeftX) * 0.3 + jx(), botMidY + jy() * 0.5,
    botLeftX + (botMidX - botLeftX) * 0.3 + jx(), botLeftY + jy() * 0.5,
    botLeftX, botLeftY,
  );

  // Left cap
  final lCapCx = cx - hw + radius;
  path.cubicTo(
    lCapCx - radius * 0.8 + jx() * 0.5, cy + hh * 0.6 + jy() * 0.3,
    lCapCx - radius * 1.1 + jx() * 0.4, cy + hh * 0.15 + jy() * 0.3,
    lCapCx - radius - jx() * 0.3, cy + jy() * 0.2,
  );
  path.cubicTo(
    lCapCx - radius * 1.1 + jx() * 0.4, cy - hh * 0.15 + jy() * 0.3,
    lCapCx - radius * 0.8 + jx() * 0.5, cy - hh * 0.6 + jy() * 0.3,
    topLeftX, topLeftY,
  );

  path.close();
  return path;
}

/// Background with soft gradient blobs and a few intentional wobbly pills.
class PillBackground extends StatelessWidget {
  const PillBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(),
      size: Size.infinite,
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dark = AppTheme.isDark.value;

    // Large soft gradient blobs for depth
    if (dark) {
      _drawBlob(canvas, Offset(w * 0.15, h * 0.08), w * 0.35,
          const Color(0xFF1A1A1A).withValues(alpha: 0.5));
      _drawBlob(canvas, Offset(w * 0.85, h * 0.15), w * 0.28,
          const Color(0xFF1E1E1E).withValues(alpha: 0.4));
      _drawBlob(canvas, Offset(w * 0.5, h * 0.92), w * 0.4,
          const Color(0xFF1A1A1A).withValues(alpha: 0.45));
      _drawBlob(canvas, Offset(w * 0.9, h * 0.7), w * 0.3,
          const Color(0xFF1E1E1E).withValues(alpha: 0.35));
      _drawBlob(canvas, Offset(w * 0.05, h * 0.55), w * 0.22,
          const Color(0xFF1A1A1A).withValues(alpha: 0.3));
    } else {
      _drawBlob(canvas, Offset(w * 0.15, h * 0.08), w * 0.35,
          const Color(0xFFFFCDD2).withValues(alpha: 0.5));
      _drawBlob(canvas, Offset(w * 0.85, h * 0.15), w * 0.28,
          const Color(0xFFF8BBD0).withValues(alpha: 0.4));
      _drawBlob(canvas, Offset(w * 0.5, h * 0.92), w * 0.4,
          const Color(0xFFFFCDD2).withValues(alpha: 0.45));
      _drawBlob(canvas, Offset(w * 0.9, h * 0.7), w * 0.3,
          const Color(0xFFF8BBD0).withValues(alpha: 0.35));
      _drawBlob(canvas, Offset(w * 0.05, h * 0.55), w * 0.22,
          const Color(0xFFFFCDD2).withValues(alpha: 0.3));
    }

    // A few intentional wobbly pills scattered around edges
    final pillColor = dark ? 0x15333333 : 0x20FF4081;
    final pillColor2 = dark ? 0x10444444 : 0x18FF80AB;
    final pillData = [
      _PillPlacement(0.08, 0.06, 90, 22, 0.6, pillColor, 51),
      _PillPlacement(0.82, 0.04, 60, 18, -0.3, pillColor2, 52),
      _PillPlacement(-0.02, 0.4, 80, 24, 1.2, pillColor, 53),
      _PillPlacement(0.92, 0.35, 70, 20, -0.8, pillColor2, 54),
      _PillPlacement(0.12, 0.88, 100, 26, 0.4, pillColor, 55),
      _PillPlacement(0.78, 0.92, 75, 22, -0.5, pillColor2, 56),
      _PillPlacement(0.45, 0.96, 85, 20, 0.15, dark ? 0x0C444444 : 0x14F8BBD0, 57),
    ];

    for (final p in pillData) {
      canvas.save();
      canvas.translate(w * p.rx, h * p.ry);
      canvas.rotate(p.angle);

      final rect = Rect.fromCenter(
          center: Offset.zero, width: p.width, height: p.height);
      final path = handDrawnPillPath(rect, seed: p.seed);

      canvas.drawPath(
        path,
        Paint()
          ..color = Color(p.colorHex)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Color(p.colorHex).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      canvas.restore();
    }
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PillPlacement {
  final double rx, ry, width, height, angle;
  final int colorHex, seed;

  _PillPlacement(this.rx, this.ry, this.width, this.height, this.angle,
      this.colorHex, this.seed);
}

/// Shared wobbly circle path — smooth organic shape with cubic beziers.
Path wobblyCirclePath(Size size, int seed) {
  final center = Offset(size.width / 2, size.height / 2);
  final baseRadius = size.width / 2 - 4;
  final rng = Random(seed * 7 + 13);

  const points = 16;
  final controlRadii = <double>[];
  for (int i = 0; i < points; i++) {
    controlRadii.add(baseRadius + (rng.nextDouble() - 0.5) * baseRadius * 0.18);
  }

  final smoothed = <double>[];
  for (int i = 0; i < points; i++) {
    final prev = controlRadii[(i - 1 + points) % points];
    final curr = controlRadii[i];
    final next = controlRadii[(i + 1) % points];
    smoothed.add(prev * 0.2 + curr * 0.6 + next * 0.2);
  }

  final path = Path();
  final startR = smoothed[0];
  path.moveTo(center.dx + startR, center.dy);

  for (int i = 0; i < points; i++) {
    final nextIdx = (i + 1) % points;
    final angle0 = (i / points) * 2 * pi;
    final angle1 = (nextIdx / points) * 2 * pi;
    final r0 = smoothed[i];
    final r1 = smoothed[nextIdx];

    final cAngle1 = angle0 + (angle1 - angle0 + (angle1 < angle0 ? 2 * pi : 0)) * 0.33;
    final cAngle2 = angle0 + (angle1 - angle0 + (angle1 < angle0 ? 2 * pi : 0)) * 0.66;
    final cR1 = r0 + (r1 - r0) * 0.33 + (rng.nextDouble() - 0.5) * 3;
    final cR2 = r0 + (r1 - r0) * 0.66 + (rng.nextDouble() - 0.5) * 3;

    path.cubicTo(
      center.dx + cR1 * cos(cAngle1),
      center.dy + cR1 * sin(cAngle1),
      center.dx + cR2 * cos(cAngle2),
      center.dy + cR2 * sin(cAngle2),
      center.dx + r1 * cos(angle1),
      center.dy + r1 * sin(angle1),
    );
  }

  path.close();
  return path;
}

/// Clips content into a wobbly circle shape.
class WobblyCircleClipper extends CustomClipper<Path> {
  final int seed;
  const WobblyCircleClipper({required this.seed});

  @override
  Path getClip(Size size) => wobblyCirclePath(size, seed);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Draws a wobbly circle border with glow — same as home page circles.
class WobblyCircleBorderPainter extends CustomPainter {
  final int seed;
  final Color borderColor;
  final Color glowColor;

  const WobblyCircleBorderPainter({
    required this.seed,
    this.borderColor = const Color(0xFFFF80AB),
    this.glowColor = const Color(0x33FF80AB),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = wobblyCirclePath(size, seed);

    // Soft glow
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Main border
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
