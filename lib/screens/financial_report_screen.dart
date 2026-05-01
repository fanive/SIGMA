// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../models/sigma_models.dart';
import '../providers/sigma_provider.dart';
import '../services/financial_report_service.dart';
import '../widgets/sigma/sigma_favorite_button.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'analysis_screen.dart';

// ---------------------------------------------------------------------------
// SIGMA Financial Report Screen
// Génère et affiche un rapport de recherche institutionnel complet
// Style sell-side : Goldman Sachs / Morgan Stanley
// ---------------------------------------------------------------------------
class FinancialReportScreen extends StatefulWidget {
  final AnalysisData analysis;
  const FinancialReportScreen({super.key, required this.analysis});

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen>
    with TickerProviderStateMixin {
  FinancialReport? _report;
  bool _isLoading = false;
  String? _error;

  // Loading animation state
  int _phaseIndex = 0;
  late Timer _phaseTimer;
  late AnimationController _pulseController;

  static const _phases = [
    (icon: Icons.storage, label: 'Fetching market data...'),
    (icon: Icons.psychology, label: 'Processing financials...'),
    (icon: Icons.trending_up, label: 'Computing valuation...'),
    (icon: Icons.verified_user, label: 'Assessing risk factors...'),
    (icon: Icons.find_in_page, label: 'Cross-referencing sources...'),
    (icon: Icons.auto_awesome, label: 'Drafting recommendation...'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _generateReport();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isLoading) _phaseTimer.cancel();
    super.dispose();
  }

  void _startPhaseTimer() {
    _phaseTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      setState(() => _phaseIndex = (_phaseIndex + 1) % _phases.length);
    });
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
      _phaseIndex = 0;
    });
    _startPhaseTimer();

    final service = FinancialReportService.fromEnv();
    final lang = (context.read<SigmaProvider>().language ?? 'EN').toLowerCase();

    try {
      // Final Real-time Sync before AI analysis to ensure report accuracy
      AnalysisData analysisToUse = widget.analysis;
      try {
        final q = await context.read<SigmaProvider>().sigmaService.fmpService.getQuoteMap(widget.analysis.ticker);
        if (q.isNotEmpty && q['price'] != null) {
          analysisToUse = widget.analysis.copyWith(price: '\$${(q['price'] as num).toStringAsFixed(2)}');
        }
      } catch (e) {
        debugPrint('Report Pre-sync failed: $e');
      }

      final report = await service.generateReport(
        analysis: analysisToUse,
        language: lang,
      );

      if (mounted) {
        _phaseTimer.cancel();
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _phaseTimer.cancel();
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_report == null) return;
    Clipboard.setData(ClipboardData(text: jsonEncode(_report!.jsonContent)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rapport copié dans le presse-papier',
          style: GoogleFonts.lora(fontSize: 13),
        ),
        backgroundColor: AppTheme.getBackground(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _ratingColor(String rating) {
    final r = rating.toUpperCase();
    if (r.contains('STRONG BUY') || r.contains('STRONG_BUY') || r.contains('FORT ACHAT') || r.contains('SURPERFORMANCE')) {
      return AppTheme.successStrong;
    }
    if (r.contains('BUY') || r.contains('ACHET') || r.contains('HAUSSE') || r.contains('ACHETER')) {
      return AppTheme.positive;
    }
    if (r.contains('STRONG SELL') || r.contains('STRONG_SELL') || r.contains('FORTE VENTE') || r.contains('SOUS-PERFORMANCE')) {
      return AppTheme.bearishDeep;
    }
    if (r.contains('SELL') || r.contains('VEND') || r.contains('BAISSE') || r.contains('VENDRE')) {
      return AppTheme.negative;
    }
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bg = isDark ? AppTheme.bgPrimary : AppTheme.lightBg;
    final border = isDark ? AppTheme.borderDark : AppTheme.lightBorder;
    final secondaryText = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    final appBarIconColor = isDark ? AppTheme.white70 : AppTheme.lightText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: AppTheme.transparent,
        elevation: 0,
        leadingWidth: 80,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Icon(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? Icons.arrow_back_ios_new
                    : Icons.arrow_back,
                size: 18,
                color: appBarIconColor,
              ),
              const SizedBox(width: 4),
              Text('Retour', style: GoogleFonts.lora(fontSize: 13, color: appBarIconColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RESEARCH REPORT',
              style: GoogleFonts.lora(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: 2,
              ),
            ),
            Builder(
              builder: (context) {
                final p = context.watch<SigmaProvider>();
                final quote = p.favoriteQuotes[widget.analysis.ticker.toUpperCase()];
                final bestName = (quote?['longName'] ?? 
                                 quote?['shortName'] ?? 
                                 quote?['name'] ?? 
                                 widget.analysis.companyName ?? 
                                 'MARKET ASSET').toString().toUpperCase();
                return Text(
                  '${widget.analysis.ticker} — $bestName',
                  style: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: secondaryText,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }
            ),
          ],
        ),
        actions: [
          if (_report != null) ...[
            IconButton(
              icon: Icon(Icons.content_copy, size: 18, color: isDark ? AppTheme.white54 : AppTheme.lightTextMuted),
              tooltip: 'Copier le rapport',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: Icon(Icons.refresh, size: 18, color: isDark ? AppTheme.white54 : AppTheme.lightTextMuted),
              tooltip: 'Régénérer',
              onPressed: _generateReport,
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_report != null) return _buildReportView(_report!);
    if (_isLoading) return _buildLoadingView();
    if (_error != null) return _buildErrorView();
    return const SizedBox.shrink();
  }

  // ── ANIMATED LOADING ─────────────────────────────────────────────────────
  Widget _buildLoadingView() {
    final isDark = AppTheme.isDark(context);
    final ticker = widget.analysis.ticker;
    final phase = _phases[_phaseIndex];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final scale = 0.92 + 0.08 * _pulseController.value;
                final opacity = 0.55 + 0.45 * _pulseController.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary
                          .withValues(alpha: 0.08 + 0.06 * _pulseController.value),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: opacity * 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Icon(
                          phase.icon,
                          key: ValueKey(phase.icon),
                          size: 34,
                          color: AppTheme.primary.withValues(alpha: opacity),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Ticker badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                ticker,
                style: GoogleFonts.lora(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'GENERATING RESEARCH REPORT',
              style: GoogleFonts.lora(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.white70 : AppTheme.lightTextPrimary,
                letterSpacing: 1.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Animated phase description
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                phase.label,
                key: ValueKey(phase.label),
                style: GoogleFonts.lora(
                  fontSize: 13,
                  color: isDark ? AppTheme.white54 : AppTheme.lightTextSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),

            // Phase dots
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_phases.length, (i) {
                final active = i == _phaseIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: active
                        ? AppTheme.primary
                        : (isDark
                            ? AppTheme.white.withValues(alpha: 0.15)
                            : AppTheme.black.withValues(alpha: 0.12)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Disclaimer
            Text(
              'Institutional-grade analysis takes ~20–30s',
              style: GoogleFonts.lora(
                fontSize: 10,
                color: isDark ? AppTheme.white24 : AppTheme.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ERROR ─────────────────────────────────────────────────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: AppTheme.negative, size: 40),
            const SizedBox(height: 16),
            Text(
              'Report Generation Failed',
              style: AppTheme.heading(context, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: GoogleFonts.lora(fontSize: 12, color: AppTheme.isDark(context) ? AppTheme.white54 : AppTheme.lightTextMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.refresh, size: 14, color: AppTheme.primary),
              label: Text(
                'Retry',
                style: GoogleFonts.lora(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── REPORT VIEW ───────────────────────────────────────────────────────────
  Widget _buildReportView(FinancialReport report) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildReportHeader(report)),
        SliverToBoxAdapter(child: _buildReportBody(report)),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.bottomPadding)),
      ],
    );
  }

  Widget _buildReportHeader(FinancialReport report) {
    final isDark = AppTheme.isDark(context);
    final ratingColor = _ratingColor(report.rating);
    double? upside;
    if (report.priceTarget != null) {
      final current = double.tryParse(
          report.currentPrice.replaceAll(RegExp(r'[^\d.]'), ''));
      if (current != null && current > 0) {
        upside = ((report.priceTarget! - current) / current) * 100;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── RATING MASTHEAD ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: ratingColor.withValues(alpha: 0.12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ratingColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  report.rating.toUpperCase(),
                  style: GoogleFonts.lora(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      color: AppTheme.white, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(width: 12),
              // Price target + upside
              if (report.priceTarget != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('OBJECTIF',
                        softWrap: false,
                        style: GoogleFonts.lora(
                            fontSize: 9,
                            color: ratingColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                    Text('\$${report.priceTarget!.toStringAsFixed(2)}',
                        style: GoogleFonts.lora(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ratingColor),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
                if (upside != null) ...[
                  const SizedBox(width: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (upside >= 0
                              ? AppTheme.positive
                              : AppTheme.negative)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: (upside >= 0
                                  ? AppTheme.positive
                                  : AppTheme.negative)
                              .withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${upside >= 0 ? '+' : ''}${upside.toStringAsFixed(1)}%',
                      style: GoogleFonts.lora(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: upside >= 0
                              ? AppTheme.positive
                              : AppTheme.negative),
                    ),
                  ),
                ],
              ],
              const Spacer(),
              CircularPercentIndicator(
                radius: 26,
                lineWidth: 4,
                percent: (report.confidenceScore / 100).clamp(0.0, 1.0),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${report.confidenceScore.toInt()}%',
                        style: GoogleFonts.lora(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: ratingColor)),
                    Text('CONF',
                        style: GoogleFonts.lora(
                            fontSize: 6,
                            color: ratingColor.withValues(alpha: 0.6))),
                  ],
                ),
                progressColor: ratingColor,
                backgroundColor: ratingColor.withValues(alpha: 0.15),
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
        // ─── COMPANY IDENTITY ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.bgSecondary : AppTheme.lightSurface,
            border: Border(
              bottom: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.lightBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final ticker = report.ticker.toUpperCase();

                  final fmpUrl = 'https://financialmodelingprep.com/image-stock/$ticker.png';

                  return Container(
                    width: 52, height: 52,
                    margin: const EdgeInsets.only(right: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.bgTertiary : AppTheme.lightSurfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? AppTheme.borderDark : AppTheme.lightBorder),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Image.network(
                      fmpUrl, 
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          ticker.length >= 2 ? ticker.substring(0, 2) : ticker,
                          style: GoogleFonts.lora(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: AppTheme.gold),
                        ),
                      ),
                    ),
                  );
                }
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.companyName,
                        style: GoogleFonts.lora(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.white : AppTheme.lightTextPrimary,
                            height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(report.ticker,
                            style: GoogleFonts.lora(
                                fontSize: 11, fontWeight: FontWeight.w900,
                                color: AppTheme.primary)),
                      ),
                      const SizedBox(width: 10),
                      Text('PRIX ACTUEL: ${report.currentPrice}',
                          style: GoogleFonts.lora(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.white54
                                  : AppTheme.lightTextSecondary)),
                    ]),
                  ],
                ),
              ),
              SigmaFavoriteButton(ticker: report.ticker, size: 14, padding: 8),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 80.ms),
        // ─── META STRIP ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          color: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
          child: Row(children: [
            Icon(Icons.calendar_today, size: 10,
                color: isDark ? AppTheme.white24 : AppTheme.lightTextMuted),
            const SizedBox(width: 5),
            Text(report.dateFormatted,
                style: GoogleFonts.lora(
                    fontSize: 10,
                    color: isDark ? AppTheme.white38 : AppTheme.lightTextMuted)),
            const SizedBox(width: 14),
            Icon(Icons.memory, size: 10,
                color: isDark ? AppTheme.white24 : AppTheme.lightTextMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text('${report.providerName} · ${report.modelName}',
                  style: GoogleFonts.lora(
                      fontSize: 10,
                      color: isDark ? AppTheme.white38 : AppTheme.lightTextMuted),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 14),
          ]),
        ).animate().fadeIn(duration: 600.ms, delay: 150.ms),
      ],
    );
  }

  Widget _buildReportBody(FinancialReport report) {
    return _ReportBody(report: report);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORT BODY — Bloomberg / Institutional Terminal Style
// Dense, data-first, no fluff
// ══════════════════════════════════════════════════════════════════════════════
class _ReportBody extends StatelessWidget {
  final FinancialReport report;
  const _ReportBody({required this.report});

  Color _trendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'up':
        return AppTheme.positive;
      case 'down':
        return AppTheme.negative;
      default:
        return AppTheme.warning;
    }
  }

  IconData _trendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'up':
        return Icons.trending_up;
      case 'down':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = report.jsonContent;
    final isDark = AppTheme.isDark(context);
    final dim = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    final txt = isDark ? AppTheme.white : AppTheme.lightTextPrimary;
    final subtle = isDark ? AppTheme.surfaceCharcoal : AppTheme.black.withValues(alpha: 0.04);
    final dividerColor = isDark ? AppTheme.textPrimaryLightStrong : AppTheme.black.withValues(alpha: 0.08);

    final kpis = (j['kpis'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    final bull = (j['bull_case'] as List?) ?? [];
    final bear = (j['bear_case'] as List?) ?? [];
    final risks = (j['risk_factors'] as List?) ?? [];
    final catalysts = (j['catalysts'] as List?) ?? [];
    final projection = j['historical_financials'] as Map<String, dynamic>?;
    final valuation = j['valuation_table'] as Map<String, dynamic>?;
    final consensus = j['analyst_consensus'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // ── EXECUTIVE SUMMARY ──────────────────────────────────────────
          if (j['executive_summary'] != null) ...[
            Text(
              j['executive_summary'].toString(),
              style: GoogleFonts.lora(
                fontSize: 15,
                height: 1.65,
                color: txt,
                fontWeight: FontWeight.w400,
              ),
            ),
            _divider(dividerColor),
          ],

          // ── COMPANY OVERVIEW ───────────────────────────────────────────
          if (j['company_overview'] != null &&
              j['company_overview'].toString().isNotEmpty) ...[
            _label('COMPANY OVERVIEW', dim),
            const SizedBox(height: 6),
            Text(
              j['company_overview'].toString(),
              style: GoogleFonts.lora(fontSize: 13, height: 1.6, color: txt),
            ),
            _divider(dividerColor),
          ],

          // ── KPI STRIP — dense row, no cards ────────────────────────────
          if (kpis.isNotEmpty) ...[
            _label('KEY METRICS', dim),
            const SizedBox(height: 10),
            ...kpis.map((kpi) {
              final trend = kpi['trend']?.toString() ?? 'stable';
              return Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: subtle,
                    border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(_trendIcon(trend), size: 11, color: _trendColor(trend)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (kpi['label'] ?? '').toString().toUpperCase(),
                          style: GoogleFonts.lora(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: dim,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        (kpi['value'] ?? '-').toString(),
                        style: GoogleFonts.lora(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _trendColor(trend),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            _divider(dividerColor),
          ],

          // ── ANALYST CONSENSUS BAR ──────────────────────────────────────
          if (consensus != null && consensus is Map) ...[
            _label('ANALYST CONSENSUS', dim),
            const SizedBox(height: 10),
            _buildConsensusBar(context, consensus, isDark, dim),
            _divider(dividerColor),
          ],

          // ── BULL / BEAR — side-by-side compact ─────────────────────────
          if (bull.isNotEmpty || bear.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bull.isNotEmpty)
                  Expanded(
                    child: _thesisList(
                      context, 'BULL CASE', bull, AppTheme.positive,
                      Icons.trending_up, isDark,
                    ),
                  ),
                if (bull.isNotEmpty && bear.isNotEmpty)
                  const SizedBox(width: 12),
                if (bear.isNotEmpty)
                  Expanded(
                    child: _thesisList(
                      context, 'BEAR CASE', bear, AppTheme.negative,
                      Icons.trending_down, isDark,
                    ),
                  ),
              ],
            ),
            _divider(dividerColor),
          ],

          // ── HISTORICAL FINANCIALS CHART ─────────────────────────────────
          if (projection != null) ...[
            _label('HISTORICAL FINANCIALS (REVENUE & EARNINGS)', dim),
            const SizedBox(height: 10),
            _buildProjectionChart(context, projection, isDark, dividerColor),
            _divider(dividerColor),
          ],

          // ── VALUATION TABLE ────────────────────────────────────────────
          if (valuation != null) ...[
            _label('VALUATION SCENARIOS', dim),
            const SizedBox(height: 10),
            _buildValuationTable(context, valuation, isDark, dividerColor),
            _divider(dividerColor),
          ],

          // ── DECISION REASONING ─────────────────────────────────────────
          if (j['decision_reasoning'] != null) ...[
            _label('DETERMINATION', dim),
            const SizedBox(height: 6),
            Text(
              j['decision_reasoning'].toString(),
              style: GoogleFonts.lora(fontSize: 13, height: 1.6, color: txt, fontWeight: FontWeight.w500),
            ),
            _divider(dividerColor),
          ],

          // ── CATALYSTS + RISKS — inline lists ───────────────────────────
          if (catalysts.isNotEmpty || risks.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (catalysts.isNotEmpty)
                  Expanded(
                    child: _inlineList(context, 'STRATEGIC CATALYSTS', catalysts,
                        AppTheme.primary, isDark),
                  ),
                if (catalysts.isNotEmpty && risks.isNotEmpty)
                  const SizedBox(width: 12),
                if (risks.isNotEmpty)
                  Expanded(
                    child: _inlineList(context, 'CRITICAL RISKS', risks,
                        AppTheme.negative, isDark),
                  ),
              ],
            ),

          // ── SECTOR COMPETITORS ─────────────────────────────────────────
          if ((j['sector_peers'] as List?)?.isNotEmpty == true) ...[            _divider(dividerColor),
            _label('SECTOR COMPETITORS', dim),
            const SizedBox(height: 10),
            _buildSectorPeers(context, j['sector_peers'] as List, isDark, dividerColor),
          ],

          // ── FOOTER DISCLAIMER ──────────────────────────────────────────
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: subtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'This report is generated by SIGMA AI based on institutional data and real-time signals. '
              'It does not constitute financial advice. All investments carry risk.',
              style: GoogleFonts.lora(fontSize: 9, color: dim, height: 1.5),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ──────────────────────────────────────────────────────

  Widget _divider(Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(height: 0.5, color: c),
      );

  Widget _label(String text, Color color) => Text(
        text,
        style: GoogleFonts.lora(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.8,
        ),
      );

  Widget _thesisList(BuildContext context, String title, List items,
      Color color, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: GoogleFonts.lora(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),
        ...items.take(4).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark
                            ? AppTheme.white.withValues(alpha: 0.75)
                            : AppTheme.lightText,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _inlineList(BuildContext context, String title, List items,
      Color accentColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        ...items.take(4).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('–  ',
                      style: GoogleFonts.lora(
                          fontSize: 12, color: accentColor, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: GoogleFonts.lora(
                        fontSize: 12,
                        height: 1.45,
                        color: isDark
                            ? AppTheme.white.withValues(alpha: 0.7)
                            : AppTheme.lightText,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildConsensusBar(
      BuildContext context, Map consensus, bool isDark, Color dim) {
    final counts = [
      (consensus['strong_buy'] as num? ?? 0).toInt(),
      (consensus['buy'] as num? ?? 0).toInt(),
      (consensus['hold'] as num? ?? 0).toInt(),
      (consensus['sell'] as num? ?? 0).toInt(),
      (consensus['strong_sell'] as num? ?? 0).toInt(),
    ];
    final colors = <Color>[
      AppTheme.successStrong,
      AppTheme.positive,
      AppTheme.warning,
      AppTheme.negativeSoft,
      AppTheme.negative,
    ];
    final labels = ['SB', 'BUY', 'HOLD', 'SELL', 'SS'];
    final total = counts.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              for (int i = 0; i < counts.length; i++)
                if (counts[i] > 0)
                  Expanded(
                    flex: counts[i],
                    child: Container(height: 8, color: colors[i]),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Labels
        Row(
          children: [
            for (int i = 0; i < counts.length; i++)
              if (counts[i] > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: colors[i],
                            borderRadius: BorderRadius.circular(1.5))),
                    const SizedBox(width: 4),
                    Text('${labels[i]} ${counts[i]}',
                        style: GoogleFonts.lora(fontSize: 10, color: dim)),
                  ]),
                ),
            const Spacer(),
            Text('$total analysts',
                style: GoogleFonts.lora(fontSize: 10, fontWeight: FontWeight.w600, color: dim)),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectionChart(BuildContext context,
      Map<String, dynamic> projection, bool isDark, Color dividerColor) {
    final revenue = (projection['revenue'] as List?) ?? [];
    final earnings = (projection['earnings'] as List?) ?? [];
    if (revenue.isEmpty) return const SizedBox.shrink();

    final List<BarChartGroupData> barGroups = [];
    double maxVal = 0;

    for (int i = 0; i < revenue.length; i++) {
      final revMap = revenue[i] as Map<String, dynamic>;
      final revVal =
          double.tryParse(revMap['value']?.toString() ?? '0') ?? 0.0;
      double earnVal = 0.0;
      if (i < earnings.length) {
        final earnMap = earnings[i] as Map<String, dynamic>;
        earnVal =
            double.tryParse(earnMap['value']?.toString() ?? '0') ?? 0.0;
      }
      if (revVal > maxVal) maxVal = revVal;
      if (earnVal > maxVal) maxVal = earnVal;

      barGroups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: revVal,
          color: AppTheme.primary,
          width: 14,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(2)),
        ),
        BarChartRodData(
          toY: earnVal,
          color: AppTheme.positive,
          width: 14,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ]));
    }

    final dim = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    return Column(
      children: [
        // Legend
        Row(children: [
          _legendDot('Revenue', AppTheme.primary, dim),
          const SizedBox(width: 14),
          _legendDot('Earnings', AppTheme.positive, dim),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: dividerColor, strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, _) => Text(
                    val.toStringAsFixed(1),
                    style: GoogleFonts.lora(
                        fontSize: 8, color: dim)),
              )),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < revenue.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          revenue[idx]['period']?.toString() ?? '',
                          style: GoogleFonts.lora(
                              fontSize: 9, color: dim)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              )),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.textPrimaryLightStrong,
                getTooltipItem: (group, gIdx, rod, rIdx) {
                  return BarTooltipItem(
                    '${rIdx == 0 ? "REV" : "EPS"}: ${rod.toY}',
                    GoogleFonts.lora(
                        color: rod.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          )),
        ),
      ],
    );
  }

  Widget _legendDot(String label, Color color, Color textColor) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.lora(
                  fontSize: 9, color: textColor, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _buildValuationTable(BuildContext context,
      Map<String, dynamic> tableData, bool isDark, Color dividerColor) {
    final columns = (tableData['columns'] as List?) ?? [];
    final rows = (tableData['rows'] as List?) ?? [];
    if (columns.isEmpty || rows.isEmpty) return const SizedBox.shrink();

    final dim = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    final txt = isDark ? AppTheme.white.withValues(alpha: 0.87) : AppTheme.lightTextPrimary;

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(1.2),
        for (int i = 1; i < columns.length; i++) i: const FlexColumnWidth(1),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
          ),
          children: columns
              .map((col) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      col.toString().toUpperCase(),
                      style: GoogleFonts.lora(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.warning,
                          letterSpacing: 0.5),
                    ),
                  ))
              .toList(),
        ),
        // Data rows
        ...rows.map((row) {
          final cells = (row as List?) ?? [];
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: dividerColor, width: 0.5)),
            ),
            children: cells.asMap().entries.map((e) {
              final isFirst = e.key == 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  e.value.toString(),
                  style: GoogleFonts.lora(
                    fontSize: 12,
                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                    color: isFirst ? txt : dim,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildSectorPeers(BuildContext context, List peers,
      bool isDark, Color dividerColor) {
    final dim = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    final txt = isDark ? AppTheme.white.withValues(alpha: 0.87) : AppTheme.lightTextPrimary;

    Color verdictColor(String v) {
      final up = v.toUpperCase();
      if (up.contains('STRONG BUY') || up.contains('STRONG_BUY') || up.contains('SURPERFORMANCE')) return AppTheme.successStrong;
      if (up.contains('BUY') || up.contains('ACHET') || up.contains('HAUSSE') || up.contains('ACHETER')) return AppTheme.positive;
      if (up.contains('SELL') || up.contains('VEND') || up.contains('BAISSE') || up.contains('VENDRE')) return AppTheme.negative;
      return AppTheme.warning;
    }

    return Column(
      children: peers.take(6).map((p) {
        final peer = (p is Map<String, dynamic>) ? p : <String, dynamic>{};
        final ticker = peer['ticker']?.toString() ?? '';
        final name = peer['name']?.toString() ?? ticker;
        final price = peer['price']?.toString() ?? '—';
        final verdict = peer['verdict']?.toString() ?? 'HOLD';
        final vColor = verdictColor(verdict);

        return GestureDetector(
          onTap: () {
            if (ticker.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AnalysisScreen(ticker: ticker)),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://financialmodelingprep.com/image-stock/${ticker.toUpperCase()}.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ticker.isNotEmpty ? ticker[0] : '?',
                        style: GoogleFonts.lora(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Ticker + Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticker,
                          style: GoogleFonts.lora(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: txt)),
                      Text(name,
                          style: GoogleFonts.lora(
                              fontSize: 10, color: dim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Verdict
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: vColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(verdict.toUpperCase(),
                      style: GoogleFonts.lora(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: vColor)),
                ),
                const SizedBox(width: 10),
                // Price
                Text(price,
                    style: GoogleFonts.lora(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: txt)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right,
                    size: 12, color: dim),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}



