import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class ComplianceBanner extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final bool compact;

  const ComplianceBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.warning.withValues(alpha: 0.08)
            : AppTheme.warning.withValues(alpha: 0.10),
        border: Border(
          top: BorderSide(
            color: AppTheme.warning.withValues(alpha: 0.22),
            width: 0.8,
          ),
          bottom: BorderSide(
            color: AppTheme.warning.withValues(alpha: 0.22),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.gavel_rounded,
            size: compact ? 14 : 16,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Outil d\'aide a la recherche, pas un conseil financier ni une sollicitation d\'investissement.',
              style: GoogleFonts.lora(
                fontSize: compact ? 10 : 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.white70 : AppTheme.slate900Strong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const ConfidenceBadge({super.key, required this.confidence});

  String get _label {
    if (confidence >= 0.75) return 'Confiance elevee';
    if (confidence >= 0.45) return 'Confiance moyenne';
    return 'Confiance faible';
  }

  Color get _color {
    if (confidence >= 0.75) return AppTheme.positive;
    if (confidence >= 0.45) return AppTheme.warning;
    return AppTheme.negative;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.24), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$_label ${(confidence * 100).round()}%',
            style: GoogleFonts.lora(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class DataFreshnessChip extends StatelessWidget {
  final String? isoDate;

  const DataFreshnessChip({super.key, required this.isoDate});

  DateTime? get _parsed => DateTime.tryParse(isoDate ?? '');

  String get _label {
    final dt = _parsed;
    if (dt == null) return 'Fraicheur inconnue';
    final age = DateTime.now().difference(dt.toLocal());
    if (age.inHours < 6) return 'Donnees fraiches';
    if (age.inDays < 2) return 'Maj recente';
    if (age.inDays < 7) return 'Maj datee';
    return 'Donnees anciennes';
  }

  Color get _color {
    final dt = _parsed;
    if (dt == null) return AppTheme.warning;
    final age = DateTime.now().difference(dt.toLocal());
    if (age.inHours < 6) return AppTheme.positive;
    if (age.inDays < 2) return AppTheme.primary;
    if (age.inDays < 7) return AppTheme.warning;
    return AppTheme.negative;
  }

  String get _detail {
    final dt = _parsed;
    if (dt == null) return 'Date indisponible';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Text(
        '$_label - $_detail',
        style: GoogleFonts.lora(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
