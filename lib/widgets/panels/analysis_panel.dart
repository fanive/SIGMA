// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/sigma_provider.dart';
import '../../models/sigma_models.dart';
import '../../theme/app_theme.dart';
import '../sigma/sigma_favorite_button.dart';
import '../analysis/analysis_loading_widget.dart';
import '../../screens/financial_report_screen.dart';
import '../analysis/analysis_sections.dart';
import '../charts/interactive_stock_chart.dart';
import '../institutional/institutional_components.dart';

class AnalysisPanel extends StatefulWidget {
  const AnalysisPanel({super.key});

  @override
  State<AnalysisPanel> createState() => _AnalysisPanelState();
}

class _AnalysisPanelState extends State<AnalysisPanel> {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<SigmaProvider>();
    final a = p.currentAnalysis;
    final isLoading = p.isAnalysisLoading;
    final isDark = AppTheme.isDark(context);

    return Material(
      color: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isLoading
            ? AnalysisLoadingWidget(
                message: p.loadingMessage, progress: p.loadingProgress)
            : (a == null
                ? _buildEmpty(isDark)
                : _buildInstitutionalReport(a, p, isDark)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INSTITUTIONAL RESEARCH REPORT (GOLDMAN SACHS STYLE)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInstitutionalReport(
      AnalysisData a, SigmaProvider p, bool isDark) {
    return Scaffold(
      backgroundColor: AppTheme.transparent,
      body: CustomScrollView(
        key: ValueKey('GS_Report_${a.ticker}'),
        slivers: [
          SliverToBoxAdapter(child: _buildMasthead(a, p, isDark)),
          SliverToBoxAdapter(child: _buildCompanyIdentity(a, p, isDark)),
          SliverToBoxAdapter(child: _buildMetaStrip(a, isDark)),

          // GRAPHIQUE INTERACTIF INTEGRE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: InteractiveStockChart(ticker: a.ticker),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildReportBody(a, isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. RATING MASTHEAD ──────────────────────────────────────────────────
  Widget _buildMasthead(AnalysisData a, SigmaProvider p, bool isDark) {
    final vColor = verdictColor(a.verdict);
    double? upside;
    try {
      final current = double.parse(a.price.replaceAll(RegExp(r'[^\d.]'), ''));
      final target = double.parse(
          a.tradeSetup.cleanTargetPrice.replaceAll(RegExp(r'[^\d.]'), ''));
      if (current > 0 && target > 0) {
        upside = ((target - current) / current) * 100;
      }
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: vColor.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: vColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              a.verdict.toUpperCase(),
              style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.white,
                  letterSpacing: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          // Price target + upside
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('OBJECTIF',
                          softWrap: false,
                          style: GoogleFonts.lora(
                              fontSize: 9,
                              color: vColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2)),
                      Text('\$${a.tradeSetup.cleanTargetPrice}',
                          style: GoogleFonts.lora(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: vColor),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (upside != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          (upside >= 0 ? AppTheme.positive : AppTheme.negative)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                          color: (upside >= 0
                                  ? AppTheme.positive
                                  : AppTheme.negative)
                              .withValues(alpha: 0.4),
                          width: 0.5),
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
            ),
          ),
          const SizedBox(width: 16),
          // Confidence Metric (Institutional Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: vColor.withValues(alpha: 0.3), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(a.confidence * 100).toInt()}%',
                    style: GoogleFonts.lora(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: vColor)),
                Text('CONFIDENCE',
                    style: GoogleFonts.lora(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: vColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. COMPANY IDENTITY ─────────────────────────────────────────────────
  Widget _buildCompanyIdentity(AnalysisData a, SigmaProvider p, bool isDark) {
    final quote = p.favoriteQuotes[a.ticker.toUpperCase()];
    final name =
        (quote?['longName'] ?? quote?['shortName'] ?? a.companyName ?? a.ticker)
            .toString();
    final fmpUrl =
        'https://financialmodelingprep.com/image-stock/${a.ticker.toUpperCase()}.png';

    return Container(
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
          Container(
            width: 52,
            height: 52,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.bgTertiary : AppTheme.lightSurfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.lightBorder),
            ),
            padding: const EdgeInsets.all(10),
            child: a.image != null &&
                    a.image!.isNotEmpty &&
                    !a.image!.contains('eodhd.com')
                ? Image.network(a.image!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        _logoFallback(fmpUrl, a.ticker))
                : _logoFallback(fmpUrl, a.ticker),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.lora(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? AppTheme.white : AppTheme.lightTextPrimary,
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(a.ticker,
                          style: GoogleFonts.lora(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('PRIX: ${a.price}',
                          style: GoogleFonts.lora(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.white54
                                  : AppTheme.lightTextSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SigmaFavoriteButton(ticker: a.ticker, size: 14, padding: 8),
        ],
      ),
    );
  }

  // ─── 3. META STRIP ───────────────────────────────────────────────────────
  Widget _buildMetaStrip(AnalysisData a, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
        border: Border(
            bottom: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.lightBorder)),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today,
            size: 10,
            color: isDark ? AppTheme.white24 : AppTheme.lightTextMuted),
        const SizedBox(width: 5),
        Text(
            'MISE À JOUR: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
            style: GoogleFonts.lora(
                fontSize: 10,
                color: isDark ? AppTheme.white38 : AppTheme.lightTextMuted)),
        const SizedBox(width: 14),
        Icon(Icons.memory,
            size: 10,
            color: isDark ? AppTheme.white24 : AppTheme.lightTextMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text('GÉNÉRÉ PAR SIGMA INTELLIGENCE ENGINE',
              style: GoogleFonts.lora(
                  fontSize: 10,
                  color: isDark ? AppTheme.white38 : AppTheme.lightTextMuted),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ─── 4. REPORT BODY ──────────────────────────────────────────────────────
  Widget _buildReportBody(AnalysisData a, bool isDark) {
    final dim = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    final txt = isDark ? AppTheme.white : AppTheme.lightTextPrimary;
    final dividerColor = isDark
        ? AppTheme.textPrimaryLightStrong
        : AppTheme.black.withValues(alpha: 0.08);

    final summary =
        _cleanText(a.summary.isNotEmpty ? a.summary : a.companyProfile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EXECUTIVE SUMMARY
        _label('EXECUTIVE SUMMARY', dim),
        const SizedBox(height: 8),
        Text(
          summary,
          style: GoogleFonts.lora(
              fontSize: 14,
              height: 1.6,
              color: txt,
              fontWeight: FontWeight.w400),
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
        ),
        _divider(dividerColor),

        // KEY METRICS (Dense Institutional Strip)
        _label('KEY METRICS', dim),
        const SizedBox(height: 8),
        _buildKeyMetricsStrip(a, isDark, dividerColor),
        _divider(dividerColor),

        // EXPERT THESIS
        if (a.verdictReasons.isNotEmpty) ...[
          _label('INVESTMENT THESIS', dim),
          const SizedBox(height: 8),
          ...a.verdictReasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                          width: 4, height: 4, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(_cleanText(reason),
                            style: GoogleFonts.lora(
                                fontSize: 14, height: 1.5, color: txt))),
                  ],
                ),
              )),
          _divider(dividerColor),
        ],

        // BULL / BEAR CASE
        if (a.pros.isNotEmpty || a.cons.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.pros.isNotEmpty)
                Expanded(
                    child: _thesisList('BULL CASE', a.pros, AppTheme.positive,
                        Icons.trending_up, isDark)),
              if (a.pros.isNotEmpty && a.cons.isNotEmpty)
                const SizedBox(width: 16),
              if (a.cons.isNotEmpty)
                Expanded(
                    child: _thesisList('BEAR CASE', a.cons, AppTheme.negative,
                        Icons.trending_down, isDark)),
            ],
          ),
          _divider(dividerColor),
        ],

        // FINANCIAL HEALTH MATRIX
        if (a.financialMatrix.isNotEmpty) ...[
          _buildFinancialMatrix(context, a, txt, isDark),
          _divider(dividerColor),
        ],

        // TECHNICAL & QUANTITATIVE DYNAMICS
        if (a.technicalAnalysis.isNotEmpty) ...[
          _buildTechnicalInsights(a, txt, isDark),
          _divider(dividerColor),
        ],

        // STRATEGIC ACTION PLAN
        if (a.actionPlan.isNotEmpty) ...[
          _label('STRATEGIC ACTION PLAN', dim),
          const SizedBox(height: 8),
          ...a.actionPlan.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_forward,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_cleanText(plan),
                          style: GoogleFonts.lora(
                              fontSize: 13, height: 1.5, color: txt)),
                    ),
                  ],
                ),
              )),
          _divider(dividerColor),
        ],

        // NEWS FEED
        if (a.companyNews.isNotEmpty) ...[
          _label('MARKET INTELLIGENCE', dim),
          const SizedBox(height: 8),
          NewsSection(a),
          _divider(dividerColor),
        ],

        // REPORT BUTTON
        const SizedBox(height: 12),
        _reportButton(a),
        const SizedBox(height: 24),

        // DISCLAIMER
        Text(
          'Avertissement : Ce rapport est généré par l\'intelligence artificielle SIGMA. Les informations sont fournies à des fins d\'analyse et ne constituent pas un conseil en investissement. Les performances passées ne préjugent pas des résultats futurs.',
          style: GoogleFonts.lora(fontSize: 10, color: dim, height: 1.4),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _cleanText(String text) {
    return text.replaceAll('[AGENTIC OLLAMA]', '').trim();
  }

  Widget _buildKeyMetricsStrip(
      AnalysisData a, bool isDark, Color dividerColor) {
    final subtle = isDark
        ? AppTheme.surfaceCharcoal
        : AppTheme.black.withValues(alpha: 0.04);
    final metrics = [
      {'label': 'MARKET CAP', 'value': a.getMetric('CAPITALISATION BOURS.')},
      {'label': 'P/E RATIO', 'value': a.getMetric('P/E RATIO')},
      {
        'label': 'BETA',
        'value': a.volatility.beta.isNotEmpty ? a.volatility.beta : 'N/A'
      },
      {'label': 'SIGMA SCORE', 'value': '${a.sigmaScore.toInt()}'},
    ];

    return Column(
      children: metrics.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: subtle,
              border:
                  Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (m['label']!).toUpperCase(),
                  style: GoogleFonts.lora(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? AppTheme.white38 : AppTheme.lightTextMuted,
                      letterSpacing: 0.5),
                ),
                Text(
                  m['value']!,
                  style: GoogleFonts.lora(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark ? AppTheme.white : AppTheme.lightTextPrimary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _thesisList(String title, List<ProCon> items, Color color,
      IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•',
                      style: GoogleFonts.lora(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_cleanText(item.text),
                        style: GoogleFonts.lora(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark
                                ? AppTheme.white70
                                : AppTheme.lightTextSecondary)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildFinancialMatrix(
      BuildContext context, AnalysisData a, Color txt, bool isDark) {
    if (a.financialMatrix.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('FINANCIAL HEALTH & VALUATION',
            isDark ? AppTheme.white38 : AppTheme.lightTextMuted),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemCount: a.financialMatrix.length,
          itemBuilder: (context, index) {
            final item = a.financialMatrix[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceCharcoal
                    : AppTheme.black.withValues(alpha: 0.02),
                border: Border.all(
                    color: isDark
                        ? AppTheme.textPrimaryLightStrong
                        : AppTheme.black.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.label.toUpperCase(),
                      style: GoogleFonts.lora(
                          fontSize: 9,
                          color: isDark
                              ? AppTheme.white54
                              : AppTheme.lightTextMuted,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item.value,
                      style: GoogleFonts.lora(
                          fontSize: 14,
                          color: txt,
                          fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTechnicalInsights(AnalysisData a, Color txt, bool isDark) {
    if (a.technicalAnalysis.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('TECHNICAL & QUANTITATIVE DYNAMICS',
            isDark ? AppTheme.white38 : AppTheme.lightTextMuted),
        const SizedBox(height: 12),
        ...a.technicalAnalysis.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 65,
                    child: Text(t.indicator.toUpperCase(),
                        style: GoogleFonts.lora(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: txt)),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: '${t.value} ',
                              style: GoogleFonts.lora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? AppTheme.white
                                      : AppTheme.lightTextPrimary)),
                          TextSpan(
                              text: '— ${_cleanText(t.interpretation)}',
                              style: GoogleFonts.lora(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: isDark
                                      ? AppTheme.white60
                                      : AppTheme.lightTextSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _logoFallback(String url, String ticker) {
    return Image.network(url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
              child: Text(
                  ticker.isNotEmpty
                      ? ticker.substring(0, ticker.length >= 2 ? 2 : 1)
                      : '?',
                  style: GoogleFonts.lora(
                      fontSize: 14,
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w900)),
            ));
  }

  Widget _label(String text, Color color) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.lora(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.5),
    );
  }

  Widget _divider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Container(height: 1, color: color),
    );
  }

  Widget _reportButton(AnalysisData a) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FinancialReportScreen(analysis: a))),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, size: 16, color: AppTheme.white),
            const SizedBox(width: 10),
            Text('VOIR LE RAPPORT COMPLET',
                style: GoogleFonts.lora(
                    fontSize: 12,
                    color: AppTheme.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return const InstitutionalEmptyState(
      icon: Icons.find_in_page_rounded,
      title: 'Recherche société',
      message:
          'Recherchez une entreprise ou ouvrez une conviction pour générer une note structurée : thèse, valorisation, risques, catalyseurs et recommandation.',
    );
  }

  Color verdictColor(String verdict) {
    final v = verdict.toUpperCase();
    if (v.contains('ACHAT') ||
        v.contains('BUY') ||
        v.contains('SURPERFORMANCE')) return AppTheme.positive;
    if (v.contains('VENTE') ||
        v.contains('SELL') ||
        v.contains('SOUS-PERFORMANCE')) return AppTheme.negative;
    return AppTheme.warning;
  }
}
