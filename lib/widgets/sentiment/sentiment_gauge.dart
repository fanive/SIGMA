// ignore_for_file: prefer_const_declarations
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class SentimentGauge extends StatelessWidget {
  final double value; // 0 to 100
  final String label;

  const SentimentGauge({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final color = _getSentimentColor(value);

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _GaugePainter(
                  value: value,
                  color: color,
                  isDark: isDark,
                ),
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      value.toInt().toString(),
                      style: GoogleFonts.lora(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.lora(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color.withValues(alpha: 0.8),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getSentimentColor(double v) {
    if (v < 25) return AppTheme.negative;
    if (v < 45) return AppTheme.orange;
    if (v < 55) return AppTheme.amberAccent;
    if (v < 75) return AppTheme.emerald;
    return AppTheme.positive;
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final bool isDark;

  _GaugePainter({
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 20);
    final radius = math.min(size.width / 2 - 20, size.height - 40);
    const strokeWidth = 14.0;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── 5 ZONES SYSTEM (Like Fear & Greed Index) ──────────────────────────
    final zones = [
      (color: AppTheme.negative, label: 'EXTREME FEAR', range: 20.0),
      (color: AppTheme.orange, label: 'FEAR', range: 25.0),
      (color: AppTheme.warning, label: 'NEUTRAL', range: 10.0),
      (color: AppTheme.positiveSoft, label: 'GREED', range: 25.0),
      (color: AppTheme.positive, label: 'EXTREME GREED', range: 20.0),
    ];

    double currentAngle = math.pi;
    for (var zone in zones) {
      final sweep = (zone.range / 100.0) * math.pi;
      final zonePaint = Paint()
        ..color = zone.color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      
      canvas.drawArc(rect, currentAngle, sweep, false, zonePaint);
      
      // Add subtle separator
      if (currentAngle > math.pi) {
         final sepPaint = Paint()..color = isDark ? AppTheme.black26 : AppTheme.white54 ..strokeWidth = 1;
         canvas.drawLine(
           Offset(center.dx + (radius - strokeWidth/2) * math.cos(currentAngle), center.dy + (radius - strokeWidth/2) * math.sin(currentAngle)),
           Offset(center.dx + (radius + strokeWidth/2) * math.cos(currentAngle), center.dy + (radius + strokeWidth/2) * math.sin(currentAngle)),
           sepPaint
         );
      }
      
      currentAngle += sweep;
    }

    // ── ACTIVE OVERLAY ────────────────────────────────────────────────────
    final activeSweep = (value / 100) * math.pi;
    final activePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    
    canvas.drawArc(rect, math.pi, activeSweep, false, activePaint);

    // ── TICKS & SCALE ─────────────────────────────────────────────────────
    for (int i = 0; i <= 20; i++) {
      final angle = math.pi + (i / 20) * math.pi;
      final isMajor = i % 5 == 0;
      final tickLen = isMajor ? 6.0 : 3.0;
      
      final start = Offset(
        center.dx + (radius + 10) * math.cos(angle),
        center.dy + (radius + 10) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (radius + 10 + tickLen) * math.cos(angle),
        center.dy + (radius + 10 + tickLen) * math.sin(angle),
      );
      
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = isDark ? AppTheme.white12 : AppTheme.black12
          ..strokeWidth = isMajor ? 1.5 : 1,
      );
    }

    // ── NEEDLE (High Precision) ───────────────────────────────────────────
    final needleAngle = math.pi + (value / 100) * math.pi;
    final needlePath = Path();
    
    // Needle tip
    final tip = Offset(
      center.dx + (radius + 5) * math.cos(needleAngle),
      center.dy + (radius + 5) * math.sin(needleAngle),
    );
    
    // Base of needle (perpendicular to angle)
    const baseWidth = 4.0;
    final b1 = Offset(
      center.dx + baseWidth * math.cos(needleAngle + math.pi/2),
      center.dy + baseWidth * math.sin(needleAngle + math.pi/2),
    );
    final b2 = Offset(
      center.dx + baseWidth * math.cos(needleAngle - math.pi/2),
      center.dy + baseWidth * math.sin(needleAngle - math.pi/2),
    );
    
    needlePath.moveTo(b1.dx, b1.dy);
    needlePath.lineTo(tip.dx, tip.dy);
    needlePath.lineTo(b2.dx, b2.dy);
    needlePath.close();
    
    canvas.drawPath(needlePath, Paint()..color = color ..style = PaintingStyle.fill);
    
    // Needle Glow
    canvas.drawCircle(
      tip, 
      4, 
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
    );

    // Pivot
    canvas.drawCircle(center, 8, Paint()..color = isDark ? AppTheme.bgPrimary : AppTheme.white);
    canvas.drawCircle(center, 5, Paint()..color = color);
    canvas.drawCircle(center, 2, Paint()..color = isDark ? AppTheme.white : AppTheme.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


