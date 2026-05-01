import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA ANALYSIS — Shared UI Components
// ═══════════════════════════════════════════════════════════════════════════════

/// Section header with level number and label
/// Section header with GS Serif styling
class SectionHeader extends StatelessWidget {
  final String level;
  final String label;
  const SectionHeader(this.level, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(level, style: GoogleFonts.lora(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.accent, letterSpacing: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label.toUpperCase(), style: AppTheme.serif(context, size: 20, weight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 0.5, color: AppTheme.accent),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A widget to explain complex terms to beginners (GS "Academic" style)
class BeginnerInsight extends StatelessWidget {
  final String title;
  final String insight;
  const BeginnerInsight({super.key, required this.title, required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.05),
        border: const Border(left: BorderSide(color: AppTheme.accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text('COMPRENDRE LE MARCHÉ', style: AppTheme.label(context).copyWith(color: AppTheme.accent, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: AppTheme.sans(context, weight: FontWeight.w700, size: 13)),
          const SizedBox(height: 4),
          Text(insight, style: AppTheme.body(context, size: 12, muted: true)),
        ],
      ),
    );
  }
}


/// Compact metric row: LABEL — VALUE
class MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const MetricRow(this.label, this.value, {this.valueColor, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: Text(label, style: GoogleFonts.lora(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.lora(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Risk badge
class RiskBadge extends StatelessWidget {
  final String risk;
  const RiskBadge(this.risk, {super.key});

  @override
  Widget build(BuildContext context) {
    final isHigh = risk.toUpperCase().contains('HIGH') || risk.toUpperCase().contains('ÉLEV');
    final color = isHigh ? AppTheme.negative : AppTheme.positive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(risk.toUpperCase(), style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

/// Format large numbers
String fmtLarge(double? v) {
  if (v == null || v == 0) return 'N/A';
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  if (abs >= 1e12) return '$sign${(abs / 1e12).toStringAsFixed(1)}T';
  if (abs >= 1e9) return '$sign${(abs / 1e9).toStringAsFixed(1)}B';
  if (abs >= 1e6) return '$sign${(abs / 1e6).toStringAsFixed(1)}M';
  if (abs >= 1e3) return '$sign${(abs / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

/// Format percentage
String fmtPct(double? v) {
  if (v == null) return 'N/A';
  return '${(v * 100).toStringAsFixed(1)}%';
}

/// Verdict color helper
Color verdictColor(String verdict) {
  final v = verdict.toUpperCase();
  if (v.contains('BUY') || v.contains('ACHAT')) return AppTheme.positive;
  if (v.contains('SELL') || v.contains('VENTE')) return AppTheme.negative;
  return AppTheme.warning;
}


