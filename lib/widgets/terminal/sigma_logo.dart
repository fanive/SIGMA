import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';

class SigmaLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const SigmaLogo({
    super.key,
    this.size = 120,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _SigmaMarkPainter(
            color: AppTheme.primary,
            glowColor: AppTheme.primary.withValues(alpha: 0.15),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Text(
            'SIGMA',
            style: GoogleFonts.lora(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: 6.0,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PRIVATE MARKETS INTELLIGENCE',
            style: GoogleFonts.lora(
              fontSize: size * 0.065,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDisabled,
              letterSpacing: 2.5,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SigmaMarkPainter extends CustomPainter {
  final Color color;
  final Color glowColor;

  _SigmaMarkPainter({required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // Outer ring with glow
    final ringPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    // Crisp outer ring
    final crispRing = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), r, crispRing);

    // Inner ring
    final innerRing = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(Offset(cx, cy), r * 0.7, innerRing);

    // Sigma symbol
    final sigmaPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pad = r * 0.35;
    final topY = cy - r * 0.55;
    final midY = cy;
    final botY = cy + r * 0.55;
    final leftX = cx - pad;
    final rightX = cx + pad;

    final path = Path()
      ..moveTo(leftX, topY)
      ..lineTo(rightX, topY)
      ..lineTo(leftX + pad * 0.3, midY)
      ..lineTo(rightX, botY)
      ..lineTo(leftX, botY);

    canvas.drawPath(path, sigmaPaint);

    // Accent dots at cardinal points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotR = size.width * 0.012;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - math.pi / 2;
      canvas.drawCircle(
        Offset(
          cx + r * math.cos(angle),
          cy + r * math.sin(angle),
        ),
        dotR,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
