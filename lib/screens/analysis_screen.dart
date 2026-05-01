// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/sigma_models.dart';
import '../providers/sigma_provider.dart';

import '../widgets/sigma/sigma_ai_chatbot.dart';
import '../widgets/analysis/analysis_loading_widget.dart';
import '../widgets/charts/interactive_stock_chart.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../widgets/analysis/analysis_helpers.dart';
import '../widgets/analysis/analysis_sections.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA ANALYSIS PANEL — Complete Institutional-Grade Ticker Analysis
// ═══════════════════════════════════════════════════════════════════════════════
// Displays ALL available data from the analysis pipeline:
// 01. Verdict & Trade Setup     06. Catalysts (Drivers/Risks)
// 02. Market Structure (Chart)  07. Analyst Consensus
// 03. Strategic Synthesis       08. Sentiment & Institutional
// 04. Pros / Cons               09. Corporate Identity & Holders
// 05. Fundamental Matrix        10. Sector Peers
//                               11. Market Intelligence (News)
// ═══════════════════════════════════════════════════════════════════════════════

class AnalysisScreen extends StatefulWidget {
  final String ticker;
  const AnalysisScreen({super.key, required this.ticker});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<SigmaProvider>();
      _isFav = p.isFavorite(widget.ticker);
      p.analyzeTicker(widget.ticker);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Consumer<SigmaProvider>(
      builder: (context, provider, _) {
        final a = provider.currentAnalysis;
        final loading = provider.isAnalysisLoading;
        final error = provider.error;

        return Scaffold(
          backgroundColor: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
          body: CustomScrollView(
            slivers: [
              _buildAppBar(a, loading, provider, isDark),
              if (loading)
                SliverFillRemaining(
                    child: AnalysisLoadingWidget(
                        message: provider.loadingMessage,
                        progress: provider.loadingProgress))
              else if (a != null)
                _buildContent(a, isDark, provider)
              else if (error != null && error.isNotEmpty)
                SliverFillRemaining(child: _buildError(error, provider, isDark))
              else
                SliverFillRemaining(
                    child: Center(
                        child: Text('AUCUNE DONNÉE',
                            style: GoogleFonts.lora(color: AppTheme.textTertiary, fontSize: 11, letterSpacing: 1)))),
            ],
          ),
          floatingActionButton: a != null ? _buildChatFAB(a) : null,
        );
      },
    );
  }

  Widget _buildInstitutionalThesis(AnalysisData a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THÈSE D\'INVESTISSEMENT INSTITUTIONNELLE',
            style: AppTheme.label(context).copyWith(color: AppTheme.accent)),
        const SizedBox(height: 12),
        Text(a.verdict.toUpperCase(),
            style: AppTheme.serif(context,
                size: 28,
                weight: FontWeight.w900,
                color: verdictColor(a.verdict))),
        const SizedBox(height: 8),
        Text(
          'Notre analyse suggère une position ${a.verdict.toLowerCase()} basée sur les dynamiques de marché actuelles.',
          style: AppTheme.body(context, muted: true),
        ),
        const SizedBox(height: 24),
        BeginnerInsight(
          title: 'Pourquoi ce verdict ?',
          insight: a.verdictReasons.isNotEmpty
              ? a.verdictReasons.first
              : 'Les fondamentaux et indicateurs techniques convergent vers cette décision.',
        ),
      ],
    );
  }

  Widget _buildFundamentalInsight(AnalysisData a) {
    return BeginnerInsight(
      title: 'Santé Financière',
      insight:
          'La matrice fondamentale évalue la rentabilité, l\'endettement et la valorisation. Un score élevé ici indique une entreprise robuste capable de traverser les cycles économiques.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR DISPLAY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildError(String errorMessage, SigmaProvider provider, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.negative.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rotate_left,
                size: 48,
                color: AppTheme.negative,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ERREUR D\'ANALYSE',
              style: AppTheme.serif(context,
                  size: 24, weight: FontWeight.w900, color: AppTheme.negative),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: AppTheme.body(context, muted: true),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                provider.resetAnalysis();
                provider.analyzeTicker(widget.ticker, forceRefresh: true);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('RÉESSAYER', style: AppTheme.label(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(
      AnalysisData? a, bool loading, SigmaProvider p, bool isDark) {
    final color = isDark ? AppTheme.white : AppTheme.black;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.transparent,
      surfaceTintColor: AppTheme.transparent,
      leading: IconButton(
          icon: Icon(Icons.chevron_left, color: color),
          onPressed: () => Navigator.pop(context)),
      actions: [
        IconButton(
          icon: Icon(Icons.rotate_left,
              size: 18, color: color.withValues(alpha: 0.5)),
          onPressed: () => p.analyzeTicker(widget.ticker, forceRefresh: true),
        ),
        IconButton(
          icon: Icon(Icons.star,
              color: _isFav ? AppTheme.warning : color.withValues(alpha: 0.3)),
          onPressed: () {
            p.toggleFavorite(widget.ticker);
            setState(() => _isFav = !_isFav);
          },
        ),
        const SizedBox(width: 8),
      ],
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(a?.ticker ?? widget.ticker,
                style:
                    AppTheme.serif(context, size: 20, weight: FontWeight.w900)),
            if (a?.price != null &&
                a!.price.isNotEmpty &&
                a.price != 'N/A') ...[
              const SizedBox(width: 10),
              Text('\$${a.price}',
                  style: AppTheme.numeric(context,
                      size: 16,
                      weight: FontWeight.w700,
                      color: AppTheme.accent)),
            ],
          ]),
          if (a?.companyName != null && a!.companyName!.isNotEmpty)
            Text(a.companyName!.toUpperCase(),
                style: AppTheme.label(context).copyWith(
                    fontSize: 8, color: AppTheme.getSecondaryText(context))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN CONTENT — All 11 sections
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildContent(AnalysisData a, bool isDark, SigmaProvider provider) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── INSTITUTIONAL THESIS (Beginner Friendly) ────────────────
          _buildInstitutionalThesis(a),
          const SizedBox(height: 48),

          // ── 01. MARKET STRUCTURE (Chart) ─────────────────────────
          const SectionHeader('01', 'STRUCTURE DU MARCHÉ'),
          InteractiveStockChart(ticker: a.ticker),
          const SizedBox(height: 48),

          // ── 02. STRATEGIC EXECUTIVE SUMMARY ────────────────────────
          const SectionHeader('02', 'RÉSUMÉ EXÉCUTIF STRATÉGIQUE'),
          _buildSynthesis(a),
          const SizedBox(height: 48),

          // ── 03. RISK-REWARD APPRAISAL ──────────────────────────────
          if (a.pros.isNotEmpty || a.cons.isNotEmpty) ...[
            const SectionHeader('03', 'ÉVALUATION RISQUE-RENDEMENT'),
            ProsConsSection(a),
            const SizedBox(height: 48),
          ],

          // ── 04. FUNDAMENTAL APPRAISAL ──────────────────────────────
          const SectionHeader('04', 'APPRÉCIATION FONDAMENTALE'),
          FundamentalMatrixSection(a),
          const SizedBox(height: 24),
          RangeBarSection(a),
          const SizedBox(height: 24),
          _buildFundamentalInsight(a),
          const SizedBox(height: 48),

          // ── 05. TACTICAL ANALYSIS ─────────────────────────────────
          if (a.technicalAnalysis.isNotEmpty) ...[
            const SectionHeader('05', 'ANALYSE TACTIQUE'),
            TechnicalSection(a),
            const SizedBox(height: 48),
          ],

          // ── 06. STRATEGIC CATALYSTS ───────────────────────────────
          if (a.catalysts.isNotEmpty) ...[
            const SectionHeader('06', 'CATALYSEURS STRATÉGIQUES'),
            CatalystsSection(a),
            const SizedBox(height: 48),
          ],

          // ── 07. CONSENSUS & EARNINGS ──────────────────────────────
          const SectionHeader('07', 'CONSENSUS & RÉSULTATS CORPORATE'),
          AnalystConsensusSection(a),
          if (a.earningsCalendar != null && a.earningsCalendar!.isNotEmpty) ...[
            const SizedBox(height: 16),
            EarningsCalendarSection(a),
          ],
          const SizedBox(height: 48),

          // ── 08. MARKET INTELLIGENCE & FLOWS ──────────────────────
          const SectionHeader('08', 'INTELLIGENCE MARCHÉ & FLUX'),
          SentimentSection(a),
          const SizedBox(height: 48),

          // ── 09. COMPETITIVE LANDSCAPE ────────────────────────────
          if (a.sectorPeers.isNotEmpty) ...[
            const SectionHeader('09', 'PAYSAGE CONCURRENTIEL'),
            PeersSection(a),
            const SizedBox(height: 48),
          ],

          // ── 10. ACTIONABLE INTELLIGENCE ──────────────────────────
          if (a.actionPlan.isNotEmpty) ...[
            const SectionHeader('10', 'INTELLIGENCE ACTIONNABLE'),
            _buildActionPlan(a),
            const SizedBox(height: 48),
          ],

          const SizedBox(height: 100),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INLINE SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSynthesis(AnalysisData a) {
    final text = (a.summary.trim().isNotEmpty && a.summary != 'N/A')
        ? a.summary.trim()
        : ((a.companyProfile.isNotEmpty && a.companyProfile != 'N/A')
            ? a.companyProfile
            : 'Synthèse en cours de structuration...');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(text, style: AppTheme.body(context, muted: true)),
      if (a.verdictReasons.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('POINTS CLÉS DU VERDICT',
            style: AppTheme.label(context).copyWith(color: AppTheme.accent)),
        const SizedBox(height: 12),
        ...a.verdictReasons.take(5).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle,
                    size: 12, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(r, style: AppTheme.body(context, size: 13))),
              ]),
            )),
      ],
    ]);
  }

  Widget _buildActionPlan(AnalysisData a) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...a.actionPlan.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.key + 1}.',
                  style: AppTheme.numeric(context,
                      color: AppTheme.accent, weight: FontWeight.w900)),
              const SizedBox(width: 12),
              Expanded(child: Text(e.value, style: AppTheme.body(context))),
            ]),
          )),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildChatFAB(AnalysisData a) {
    return FloatingActionButton.extended(
      onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => SigmaAIChatbot(ticker: a.ticker, analysis: a)),
      backgroundColor: AppTheme.primary,
      icon:
          const Icon(Icons.chat_bubble_outline, size: 18, color: AppTheme.white),
      label: Text('SIGMA AI',
          style: AppTheme.label(context).copyWith(color: AppTheme.white)),
    );
  }
}


