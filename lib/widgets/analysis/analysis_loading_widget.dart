import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';

// ─── Analysis phases shown sequentially during the loading process ──────────
const _kPhases = [
  (icon: Icons.bolt, label: 'CONNEXION SÉCURISÉE', detail: 'TLS 1.3 handshake'),
  (
    icon: Icons.candlestick_chart,
    label: 'PRIX & VOLUMES',
    detail: 'Yahoo Finance real-time'
  ),
  (
    icon: Icons.account_balance,
    label: 'DONNÉES FONDAMENTAUX',
    detail: 'Bilans, P&L, cash flows'
  ),
  (
    icon: Icons.insights,
    label: 'ANALYSE TECHNIQUE',
    detail: 'RSI · MACD · Bandes de Bollinger'
  ),
  (
    icon: Icons.people_alt,
    label: 'CONSENSUS ANALYSTES',
    detail: 'Bloomberg / Refinitiv'
  ),
  (
    icon: Icons.newspaper,
    label: 'CATALYSEURS RÉCENTS',
    detail: 'News & événements'
  ),
  (
    icon: Icons.manage_search,
    label: 'SYNTHÈSE RECHERCHE',
    detail: 'Sources, risques et signaux'
  ),
  (
    icon: Icons.check_circle_outline,
    label: 'COMPILATION DU RAPPORT',
    detail: 'Scoring & synthèse'
  ),
];

class AnalysisLoadingWidget extends StatefulWidget {
  final String message;
  final double progress;

  const AnalysisLoadingWidget({
    super.key,
    required this.message,
    required this.progress,
  });

  @override
  State<AnalysisLoadingWidget> createState() => _AnalysisLoadingWidgetState();
}

class _AnalysisLoadingWidgetState extends State<AnalysisLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _dotCtrl;
  int _visiblePhases = 1;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat();
    // Progressively reveal phases every 2.5 s to give the feeling of live work
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() {
        if (_visiblePhases < _kPhases.length) _visiblePhases++;
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.bgPrimary : AppTheme.lightBg;
    final surf = isDark ? AppTheme.bgSecondary : AppTheme.white;
    final border = isDark ? AppTheme.borderDark : AppTheme.lightBorder;

    // Sync visible phases with actual progress too
    final progressPhases =
        (widget.progress * _kPhases.length).ceil().clamp(1, _kPhases.length);
    final shown =
        progressPhases > _visiblePhases ? progressPhases : _visiblePhases;

    return Container(
      color: bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.positive
                            .withValues(alpha: 0.4 + 0.6 * _pulseCtrl.value),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.positive
                                .withValues(alpha: 0.4 * _pulseCtrl.value),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SIGMA RESEARCH ENGINE',
                    style: GoogleFonts.lora(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.white70 : AppTheme.black54,
                        letterSpacing: 2),
                  ),
                  const Spacer(),
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: GoogleFonts.lora(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Progress bar ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 28),
              // ── Current step label ───────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: surf,
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _dotCtrl,
                      builder: (_, __) {
                        final dots = '.' * ((_dotCtrl.value * 3).floor() + 1);
                        return Text(
                          dots,
                          style: GoogleFonts.lora(
                              fontSize: 14,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w900),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message.toUpperCase(),
                        style: GoogleFonts.lora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.white : AppTheme.black87,
                            letterSpacing: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Phase checklist ──────────────────────────────────────────
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border),
                  ),
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _kPhases.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: border),
                    itemBuilder: (_, i) {
                      final phase = _kPhases[i];
                      final done = i < shown - 1;
                      final active = i == shown - 1;
                      final pending = i >= shown;
                      return _PhaseRow(
                        icon: phase.icon,
                        label: phase.label,
                        detail: phase.detail,
                        done: done,
                        active: active,
                        pending: pending,
                        isDark: isDark,
                        pulseCtrl: _pulseCtrl,
                        dotCtrl: _dotCtrl,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'TRAITEMENT EN COURS — VEUILLEZ PATIENTER',
                  style: GoogleFonts.lora(
                      fontSize: 8,
                      letterSpacing: 1.5,
                      color: isDark ? AppTheme.white24 : AppTheme.black26),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool done;
  final bool active;
  final bool pending;
  final bool isDark;
  final AnimationController pulseCtrl;
  final AnimationController dotCtrl;

  const _PhaseRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.done,
    required this.active,
    required this.pending,
    required this.isDark,
    required this.pulseCtrl,
    required this.dotCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconCol = done
        ? AppTheme.positive
        : active
            ? AppTheme.primary
            : (isDark ? AppTheme.white12 : AppTheme.black12);
    final Color labelCol = done
        ? (isDark ? AppTheme.white54 : AppTheme.black45)
        : active
            ? (isDark ? AppTheme.white : AppTheme.black87)
            : (isDark ? AppTheme.white24 : AppTheme.black26);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: done
                ? const Icon(Icons.check, size: 14, color: AppTheme.positive)
                : active
                    ? AnimatedBuilder(
                        animation: pulseCtrl,
                        builder: (_, __) => Icon(icon,
                            size: 14,
                            color: AppTheme.primary.withValues(
                                alpha: 0.5 + 0.5 * pulseCtrl.value)),
                      )
                    : Icon(icon, size: 14, color: iconCol),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.lora(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: labelCol)),
                if (!pending)
                  Text(detail,
                      style: GoogleFonts.lora(
                          fontSize: 9,
                          color: done
                              ? (isDark ? AppTheme.white30 : AppTheme.black26)
                              : AppTheme.primary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (active)
            AnimatedBuilder(
              animation: dotCtrl,
              builder: (_, __) {
                final n = (dotCtrl.value * 3).floor() + 1;
                return Text('•' * n,
                    style: GoogleFonts.lora(
                        fontSize: 10, color: AppTheme.primary));
              },
            )
          else if (done)
            Text(
              'OK',
              style: GoogleFonts.lora(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.positive.withValues(alpha: 0.7),
                  letterSpacing: 1),
            ),
        ],
      ),
    );
  }
}
