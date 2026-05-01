// ignore_for_file: dead_null_aware_expression, prefer_const_constructors, unnecessary_non_null_assertion, unused_import
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../models/sigma_models.dart';
import '../../models/sigma_engines.dart';
import '../../services/ollama_news_service.dart';
import '../terminal/research_panel.dart';
import '../institutional/institutional_components.dart';
import '../sentiment/sentiment_radar.dart';
import '../sentiment/sentiment_history_chart.dart';
import '../sentiment/sentiment_gauge.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA BIM MARKET MODULE — Refined architectural data architecture
// ═══════════════════════════════════════════════════════════════════════════════

class MarketOverviewPanel extends StatefulWidget {
  const MarketOverviewPanel({super.key});
  @override
  State<MarketOverviewPanel> createState() => _MarketOverviewPanelState();
}

class _MarketOverviewPanelState extends State<MarketOverviewPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SigmaProvider>();
      if (sp.marketOverview == null) sp.fetchMarketOverview();
      sp.fetchCatalystRadar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResearchPanelContainer(
      title: '',
      icon: Icons.dashboard,
      showHeader: false,
      padding: EdgeInsets.zero,
      child: Consumer<SigmaProvider>(
        builder: (context, sp, _) {
          if (sp.isMarketLoading && sp.marketOverview == null) {
            return _loading(context);
          }

          final overview = sp.marketOverview;
          if (overview == null) return _errorState(context, sp);

          return RefreshIndicator(
            onRefresh: () async {
              await sp.fetchMarketOverview(forceRefresh: true);
              await sp.fetchCatalystRadar(forceRefresh: true);
            },
            color: AppTheme.primary,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _investmentCommitteeBrief(overview, sp, context),
                // ── MASTHEAD: VIX + SENTIMENT ────────────────────────
                _bimVixSentimentStrip(overview, context),
                _bimSentimentIntelligence(overview, context),

                // ── DAILY CREAM REPORT™ ──────────────────────────────
                if (sp.dailyCreamReport != null)
                  _bimDailyCreamSection(sp.dailyCreamReport!, context),

                // ── INTELLIGENCE ÉCONOMIQUE ──────────────────────────
                _bimSectionHeader('INTELLIGENCE ÉCONOMIQUE'),
                _bimIntelligenceSection(overview, sp, context),

                // ── MACRO & OBLIGATIONS ──────────────────────────────
                _bimSectionHeader('MACRO & OBLIGATIONS'),
                _bimMacroGrid(overview, context),
                _bimEconomicCalendar(overview, context),

                // ── DYNAMIQUE DES SECTEURS ───────────────────────────
                if (overview.sectors.isNotEmpty) ...[
                  _bimSectionHeader('DYNAMIQUE DES SECTEURS'),
                  _bimSectorGrid(overview, context),
                ],

                // ── TOP MOVERS ───────────────────────────────────────
                if ((overview.topGainers?.isNotEmpty ?? false) ||
                    (overview.topLosers?.isNotEmpty ?? false)) ...[
                  _bimSectionHeader('TOP MOVERS'),
                  _bimTopMovers(overview, context),
                ],

                // ── CATALYSEURS ACTIFS ───────────────────────────────
                if (sp.catalystInsights.isNotEmpty) ...[
                  _bimSectionHeader('CATALYSEURS ACTIFS'),
                  _bimCatalystList(context, sp),
                ],

                // ── TRANSACTIONS D'INITIÉS ───────────────────────────
                if (overview.insiderTrades?.isNotEmpty ?? false) ...[
                  _bimSectionHeader("TRANSACTIONS D'INITIÉS"),
                  _bimInsiderTrades(overview, context),
                ],

                // ── SENTIMENT ALTERNATIF & RISQUES ───────────────────
                if (overview.indicators != null &&
                    overview.indicators!.isNotEmpty) ...[
                  _bimSectionHeader('SENTIMENT ALTERNATIF & RISQUES'),
                  _bimAlternativeData(overview, context),
                ],

                if (sp.currentTier == SigmaTier.free) _bimProTeaser(context),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text('SYNCHRONISATION GLOBALE...',
              style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textTertiary,
                  letterSpacing: 2)),
        ],
      ),
    );
  }

  // ─── BIM UI ARCHITECTURE ───────────────────────────────────────────────

  Widget _investmentCommitteeBrief(
    MarketOverview overview,
    SigmaProvider sp,
    BuildContext context,
  ) {
    final topGainers = overview.topGainers?.length ?? 0;
    final topLosers = overview.topLosers?.length ?? 0;
    final sectorCount = overview.sectors.length;
    final catalystCount = sp.catalystInsights.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InstitutionalHeader(
            eyebrow: 'Comité d’investissement',
            title: 'Vue Macro & Marchés',
            thesis:
                'Prioriser le régime de marché, la rotation sectorielle et les catalyseurs avant de descendre au niveau société.',
            icon: Icons.account_balance_rounded,
            actions: [
              TextButton.icon(
                onPressed: () => sp.fetchMarketOverview(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final metrics = [
                InstitutionalMetric(
                  label: 'Sectors covered',
                  value: '$sectorCount',
                  footnote: 'Breadth of current market read',
                  icon: Icons.layers_rounded,
                ),
                InstitutionalMetric(
                  label: 'Top movers',
                  value: '${topGainers + topLosers}',
                  footnote: 'Upside and downside dislocations',
                  icon: Icons.swap_vert_rounded,
                ),
                InstitutionalMetric(
                  label: 'Catalysts',
                  value: '$catalystCount',
                  footnote: 'Events requiring follow-up',
                  icon: Icons.event_available_rounded,
                ),
              ];

              if (!isWide) {
                return Column(
                  children: metrics
                      .map((metric) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: metric,
                          ))
                      .toList(),
                );
              }

              return Row(
                children: metrics
                    .map((metric) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: metric,
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _bimSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.lora(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.isDark(context)
                      ? AppTheme.white38
                      : AppTheme.black38,
                  letterSpacing: 2.0)),
          const SizedBox(height: 8),
          Container(height: 0.5, color: AppTheme.getBorder(context)),
        ],
      ),
    );
  }

  Widget _bimIntelligenceSection(
      MarketOverview overview, SigmaProvider sp, BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overview.marketRegime != 'UNKNOWN')
                _bimExecutiveSummary(overview, context),
              const SizedBox(height: 24),
              if (sp.marketIntelligence != null)
                _bimStrategicBrief(sp.marketIntelligence!, context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bimExecutiveSummary(MarketOverview overview, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final color = overview.sentimentValue > 60
        ? AppTheme.positive
        : (overview.sentimentValue < 40 ? AppTheme.negative : AppTheme.warning);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              color: color,
            ),
            const SizedBox(width: 12),
            Text('STATUT DU RÉGIME DE MARCHÉ',
                style: GoogleFonts.lora(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppTheme.white38 : AppTheme.black38,
                    letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 16),
        Text(overview.marketRegime.toUpperCase(),
            style: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.white : AppTheme.black,
                letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Text(
            "L'analyse structurelle indique une phase de ${overview.marketRegime.toLowerCase()} avec une intensité de sentiment de ${overview.sentimentValue.toInt()}%. Les corrélations entre actifs restent ${overview.vixValue > 20 ? 'élevées' : 'stables'}.",
            style: GoogleFonts.lora(
                fontSize: 14,
                height: 1.5,
                color: isDark ? AppTheme.white70 : AppTheme.black87)),
      ],
    );
  }

  List<Widget> _renderBimText(String text, BuildContext context,
      {TextStyle? style}) {
    if (text.isEmpty) return [];
    // Clean markdown bolding and bullets
    final clean = text.replaceAll('**', '').replaceAll('###', '').trim();
    final lines = clean.split('\n');

    return lines.where((l) => l.trim().isNotEmpty).map((line) {
      final l = line.trim();

      // Detect Bullets: -, •, *
      final bool isBullet =
          l.startsWith('•') || l.startsWith('-') || l.startsWith('*');
      // Detect Numbers: 1. , 1) , (1)
      final numMatch = RegExp(r'^(\(?(\d+)[\.\)]?)').firstMatch(l);
      final bool isNumbered = numMatch != null && !isBullet;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBullet) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: AppTheme.primary, shape: BoxShape.circle)),
              )
            ] else if (isNumbered) ...[
              Container(
                margin: const EdgeInsets.only(top: 4, right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
                child: Text(
                  numMatch.group(2) ?? '?',
                  style: GoogleFonts.lora(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.black),
                ),
              ),
            ],
            Expanded(
              child: _richBimText(
                isNumbered
                    ? l.replaceFirst(numMatch.group(1)!, '').trim()
                    : l.replaceFirst(RegExp(r'^[-•\*]'), '').trim(),
                context,
                baseStyle: style?.copyWith(color: AppTheme.textPrimary) ??
                    AppTheme.body(context, size: 14)
                        .copyWith(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _richBimText(String text, BuildContext context,
      {required TextStyle baseStyle}) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(
        r'([\+\-]?\d+[\.,]\d+%?)|(BULLISH|BEARISH|ACHETER|VENDRE|HAUSSIER|BAISSIER)|(\$[0-9\.,]+)');

    int lastMatchEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final value = match.group(0)!;
      Color? color;
      if (value.contains('%') || value.contains('+') || value.contains('-')) {
        color = value.contains('-') ? AppTheme.negative : AppTheme.positive;
      } else if (value.toUpperCase().contains('BULL') ||
          value.toUpperCase().contains('HAUSS')) {
        color = AppTheme.positive;
      } else if (value.toUpperCase().contains('BEAR') ||
          value.toUpperCase().contains('BAISS')) {
        color = AppTheme.negative;
      } else if (value.contains('\$')) {
        color = AppTheme.gold;
      }

      spans.add(TextSpan(
        text: value,
        style: baseStyle.copyWith(
          color: color ?? AppTheme.primary,
          fontWeight: FontWeight.w900,
          fontFamily: GoogleFonts.lora().fontFamily,
          fontSize: baseStyle.fontSize! - 1,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }

  Widget _bimStrategicBrief(MarketIntelligence intel, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border:
            const Border(left: BorderSide(color: AppTheme.warning, width: 3)),
        color: AppTheme.warning.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_bad, size: 14, color: AppTheme.warning),
              const SizedBox(width: 8),
              Text('ANALYSES STRATÉGIQUES',
                  style: GoogleFonts.lora(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.warning,
                      letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          ..._renderBimText(intel.brief, context,
              style: GoogleFonts.lora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: isDark
                      ? AppTheme.white.withValues(alpha: 0.9)
                      : AppTheme.black.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _bimMacroGrid(MarketOverview overview, BuildContext context) {
    final macro = overview.macroIndicators;
    if (macro == null) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);
    final items = [
      {
        'label': 'US 10Y BOND',
        'value': '${macro.treasury10Y.toStringAsFixed(2)}%',
        'icon': Icons.trending_up,
      },
      {
        'label': 'DXY INDEX',
        'value': macro.dollarIndex.toStringAsFixed(2),
        'icon': Icons.attach_money,
      },
      {
        'label': 'XAU GOLD',
        'value': '\$${macro.goldPrice.toStringAsFixed(0)}',
        'icon': Icons.diamond,
      },
      {
        'label': 'BRENT CRUDE',
        'value': '\$${macro.oilPrice.toStringAsFixed(1)}',
        'icon': Icons.local_gas_station,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
          childAspectRatio: 2.8,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.getBorder(context), width: 0.5),
              color: isDark
                  ? AppTheme.surfaceUltraDark
                  : AppTheme.black.withValues(alpha: 0.01),
            ),
            child: Row(
              children: [
                Icon(item['icon'] as IconData,
                    size: 10, color: AppTheme.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item['label'] as String,
                      style: GoogleFonts.lora(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textTertiary,
                          letterSpacing: 0.5)),
                ),
                Text(item['value'] as String,
                    style: GoogleFonts.lora(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.white : AppTheme.black)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bimTopMovers(MarketOverview overview, BuildContext context) {
    if ((overview.topGainers?.isEmpty ?? true) &&
        (overview.topLosers?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }

    Widget buildMoverList(List<MarketMover>? movers, bool isGainer) {
      if (movers == null || movers.isEmpty) return const SizedBox.shrink();
      final color = isGainer ? AppTheme.positive : AppTheme.negative;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: movers.take(5).map((m) {
          return InkWell(
            onTap: () {
              context.read<TerminalProvider>().openAnalysis(m.ticker);
              context.read<SigmaProvider>().analyzeTicker(m.ticker);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.getBorder(context), width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.ticker,
                            style: GoogleFonts.lora(
                                fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${m.change >= 0 ? '+' : ''}${m.change.toStringAsFixed(1)}%',
                          style: GoogleFonts.lora(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: color)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overview.topGainers?.isNotEmpty ?? false)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOP GAINERS',
                      style: AppTheme.label(context).copyWith(
                          fontSize: 8,
                          color: AppTheme.positive,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  buildMoverList(overview.topGainers, true),
                ],
              ),
            ),
          if ((overview.topGainers?.isNotEmpty ?? false) &&
              (overview.topLosers?.isNotEmpty ?? false))
            const SizedBox(width: 16),
          if (overview.topLosers?.isNotEmpty ?? false)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LAGGARDS (BAISSE)',
                      style: AppTheme.label(context)
                          .copyWith(fontSize: 9, color: AppTheme.negative)),
                  const SizedBox(height: 8),
                  buildMoverList(overview.topLosers, false),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bimCatalystList(BuildContext context, SigmaProvider sp) {
    final catalysts = sp.catalystInsights;
    if (catalysts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...catalysts.take(4).map((c) {
          final color = c.isNegative ? AppTheme.negative : AppTheme.positive;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.getBorder(context), width: 0.5)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  color: color.withValues(alpha: 0.05),
                ),
                child: Center(
                    child: Text('${(c.impactScore * 100).toInt()}',
                        style: GoogleFonts.lora(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: color))),
              ),
              title: Text(c.ticker,
                  style: GoogleFonts.lora(
                      fontSize: 14, fontWeight: FontWeight.w900, color: color)),
              subtitle: Text(c.title,
                  style: AppTheme.body(context, size: 12)
                      .copyWith(height: 1.4, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              trailing: Icon(
                  c.isNegative ? Icons.trending_down : Icons.trending_up,
                  size: 16,
                  color: color),
              onTap: () {
                context.read<TerminalProvider>().openAnalysis(c.ticker);
                context.read<SigmaProvider>().analyzeTicker(c.ticker);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _bimInsiderTrades(MarketOverview overview, BuildContext context) {
    final trades = overview.insiderTrades ?? [];
    if (trades.isEmpty) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);

    return Column(
      children: [
        ...trades.take(10).map((t) {
          final isBuy = t.type.toUpperCase().contains('BUY') ||
              t.type.toUpperCase().contains('ACHAT');
          final color = isBuy ? AppTheme.positive : AppTheme.negative;
          return InkWell(
            onTap: () {
              context.read<TerminalProvider>().openAnalysis(t.symbol);
              context.read<SigmaProvider>().analyzeTicker(t.symbol);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.getBorder(context), width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Text(t.symbol.substring(0, 1),
                          style: GoogleFonts.lora(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: color)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(t.symbol,
                                style: GoogleFonts.lora(
                                    fontSize: 12, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            if (t.labels.isNotEmpty)
                              ...t.labels.take(1).map((l) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: l == 'CLUSTER'
                                          ? AppTheme.amberAccent
                                              .withValues(alpha: 0.1)
                                          : AppTheme.primary
                                              .withValues(alpha: 0.05),
                                    ),
                                    child: Text(l,
                                        style: GoogleFonts.lora(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w900,
                                            color: l == 'CLUSTER'
                                                ? AppTheme.amberAccent
                                                : AppTheme.primary)),
                                  )),
                          ],
                        ),
                        Text(t.name,
                            style: GoogleFonts.lora(
                                fontSize: 9,
                                color: isDark
                                    ? AppTheme.white38
                                    : AppTheme.black38,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${(t.value / 1000000).toStringAsFixed(1)}M',
                        style: GoogleFonts.lora(
                            fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                      Text(_formatDate(t.date),
                          style: GoogleFonts.lora(
                              fontSize: 8,
                              color: AppTheme.textTertiary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _bimAlternativeData(MarketOverview overview, BuildContext context) {
    final indicators = overview.indicators ?? {};
    if (indicators.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.0,
            ),
            itemCount: indicators.length.clamp(0, 6),
            itemBuilder: (context, index) {
              final key = indicators.keys.elementAt(index);
              final val = indicators[key].toString();
              return _altMetricCard(key.toUpperCase(), val, AppTheme.gold,
                  Icons.data_object, context);
            },
          ),
        ],
      ),
    );
  }

  Widget _altMetricCard(String title, String value, Color color, IconData icon,
      BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.surfaceUltraDark
            : AppTheme.black.withValues(alpha: 0.01),
        border: Border.all(color: AppTheme.getBorder(context), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: GoogleFonts.lora(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: GoogleFonts.lora(
                  fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _bimSectorGrid(MarketOverview overview, BuildContext context) {
    final sectors = overview.sectors.take(10).toList();
    if (sectors.isEmpty) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
          childAspectRatio: 2.6,
        ),
        itemCount: sectors.length,
        itemBuilder: (context, i) {
          final s = sectors[i];
          final color =
              s.performance >= 0 ? AppTheme.positive : AppTheme.negative;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.getBorder(context), width: 0.5),
              color: isDark
                  ? AppTheme.surfaceUltraDark
                  : AppTheme.black.withValues(alpha: 0.01),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.name.toUpperCase(),
                          style: GoogleFonts.lora(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? AppTheme.white38 : AppTheme.black38,
                              letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(s.sentiment.toUpperCase(),
                          style: GoogleFonts.lora(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: s.sentiment.contains('HAUSS') ||
                                      s.sentiment.contains('BULL')
                                  ? AppTheme.positive
                                  : (s.sentiment.contains('BAISS') ||
                                          s.sentiment.contains('BEAR')
                                      ? AppTheme.negative
                                      : AppTheme.textTertiary))),
                    ],
                  ),
                ),
                Text(
                    '${s.performance >= 0 ? '+' : ''}${s.performance.toStringAsFixed(1)}%',
                    style: GoogleFonts.lora(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bimProTeaser(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary, width: 0.5)),
        child: Column(
          children: [
            Text('PASSER À SIGMA PRO',
                style: GoogleFonts.lora(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    letterSpacing: 2)),
            const SizedBox(height: 12),
            Text(
                'Débloquez les diagnostics structurels avancés et la corrélation multi-actifs.',
                textAlign: TextAlign.center,
                style: AppTheme.body(context, size: 12).copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _errorState(BuildContext context, SigmaProvider sp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storage, size: 24, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('ERREUR DE SYNCHRONISATION',
              style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textTertiary)),
          const SizedBox(height: 32),
          TextButton(
              onPressed: () => sp.fetchMarketOverview(forceRefresh: true),
              child: Text('RÉESSAYER LA SYNCHRONISATION',
                  style: AppTheme.label(context))),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'LIVE';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw.toUpperCase();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'NOW';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24) return '${diff.inHours}H';
      if (diff.inDays < 7) return '${diff.inDays}D';
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return raw.toUpperCase();
    }
  }

  Widget _bimDailyCreamSection(DailyCreamReport report, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDeep : AppTheme.white,
        border: Border.all(color: AppTheme.getBorder(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.surfaceMid
                  : AppTheme.black.withValues(alpha: 0.02),
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.getBorder(context), width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.gold, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text('DAILY CREAM REPORT™',
                    style: GoogleFonts.lora(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.gold,
                        letterSpacing: 1.5)),
                const Spacer(),
                Text(
                    DateFormat('dd MMM HH:mm')
                        .format(report.date)
                        .toUpperCase(),
                    style: GoogleFonts.lora(
                        fontSize: 8,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.marketSynthesis,
                    style: GoogleFonts.lora(
                        fontSize: 15,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTheme.white.withValues(alpha: 0.9)
                            : AppTheme.black.withValues(alpha: 0.9))),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: AppTheme.getBorder(context), width: 0.5)),
                  ),
                  child: Text('ALPHA SELECTIONS',
                      style: GoogleFonts.lora(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textTertiary,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                  ),
                  itemCount: report.alphaPicks.length,
                  itemBuilder: (context, i) =>
                      _bimAlphaItem(report.alphaPicks[i], context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bimAlphaItem(SigmaSignalEntry pick, BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<TerminalProvider>().openAnalysis(pick.ticker);
        context.read<SigmaProvider>().analyzeTicker(pick.ticker);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.getBorder(context), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(pick.ticker,
                    style: GoogleFonts.lora(
                        fontSize: 11, fontWeight: FontWeight.w900)),
                Text(pick.signal,
                    style: GoogleFonts.lora(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.positive)),
              ],
            ),
            Text('${pick.score.toInt()}',
                style: GoogleFonts.lora(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.gold)),
          ],
        ),
      ),
    );
  }

  Widget _bimVixSentimentStrip(MarketOverview overview, BuildContext context) {
    final isDark = AppTheme.isDark(context);
    double vixVal = overview.vixValue;
    if (vixVal <= 0) {
      vixVal = double.tryParse(
              overview.vixLevel.replaceAll(RegExp(r'[^0-9\.]'), '')) ??
          0.0;
    }
    final sentScore = overview.sentimentValue;

    // VIX Color Logic: <15 (Positive/Green), 15-20 (Yellow), 20-30 (Orange), >30 (Negative/Red)
    final vixColor = vixVal > 30
        ? AppTheme.negative
        : (vixVal > 20
            ? AppTheme.orange
            : (vixVal > 15 ? AppTheme.warning : AppTheme.positive));

    // Sentiment Color Logic: >75 (Extreme Greed/Green), 55-75 (Greed/Light Green), 45-55 (Neutral/Amber), 25-45 (Fear/Orange), <25 (Extreme Fear/Red)
    final sentColor = sentScore > 75
        ? AppTheme.positive
        : (sentScore > 55
            ? AppTheme.lightGreen
            : (sentScore > 45
                ? AppTheme.warning
                : (sentScore > 25 ? AppTheme.orange : AppTheme.negative)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDeep : AppTheme.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.getBorder(context), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stripItem('VIX INDEX', vixVal.toStringAsFixed(2), vixColor,
              Icons.monitor_heart),
          Container(width: 0.5, height: 24, color: AppTheme.getBorder(context)),
          _stripItem('SENTIMENT', '${sentScore.toInt()}%', sentColor,
              Icons.psychology),
          Container(width: 0.5, height: 24, color: AppTheme.getBorder(context)),
          _stripItem('SESSION', DateFormat('HH:mm').format(DateTime.now()),
              AppTheme.gold, Icons.access_time),
        ],
      ),
    );
  }

  Widget _stripItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.lora(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textTertiary,
                      letterSpacing: 0.5)),
              Text(value,
                  style: GoogleFonts.lora(
                      fontSize: 12, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bimSentimentIntelligence(
      MarketOverview overview, BuildContext context) {
    print(
        '🎨 Rendering SentimentIntelligence: backtest=${overview.backtest != null}, sectors=${overview.sectorSentiment != null}');
    if (overview.backtest == null && overview.sectorSentiment == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _bimSectionHeader('SENTIMENT INTELLIGENCE™'),
        if (overview.backtest != null)
          _bimStatisticalEdge(overview.backtest!, context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _bimStatisticalEdge(
      Map<String, dynamic> backtest, BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_object, size: 12, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text('PROBABILISTIC HISTORICAL RETURNS (STATISTICAL EDGE)',
                  style: GoogleFonts.lora(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.gold,
                      letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.surfaceNearBlack
                  : AppTheme.lightSurfaceLight,
              border:
                  Border.all(color: AppTheme.getBorder(context), width: 0.5),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                _tableHeader(['CONDITION', '1M AVG', '3M AVG', 'WIN RATE']),
                ...backtest.entries.map((e) {
                  final cat = e.key.replaceAll('_', ' ').toUpperCase();
                  final data = e.value['periods'] as List?;
                  if (data == null || data.isEmpty) {
                    return const TableRow(children: [
                      SizedBox(),
                      SizedBox(),
                      SizedBox(),
                      SizedBox()
                    ]);
                  }

                  final m1 = data[0];
                  final m3 = data[1];
                  final wr = m1['winRate'];

                  return _tableRow([
                    cat,
                    '${m1['avg'] > 0 ? '+' : ''}${m1['avg']}%',
                    '${m3['avg'] > 0 ? '+' : ''}${m3['avg']}%',
                    '$wr%',
                  ], isPositive: m1['avg'] > 0);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> labels) {
    return TableRow(
      decoration: BoxDecoration(
        color: AppTheme.textTertiary.withValues(alpha: 0.05),
        border: Border(
            bottom: BorderSide(
                color: AppTheme.textTertiary.withValues(alpha: 0.1),
                width: 0.5)),
      ),
      children: labels
          .map((l) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Text(l,
                    style: GoogleFonts.lora(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textTertiary)),
              ))
          .toList(),
    );
  }

  TableRow _tableRow(List<String> values, {bool isPositive = true}) {
    return TableRow(
      children: values.asMap().entries.map((entry) {
        final i = entry.key;
        final v = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(v,
              style: GoogleFonts.lora(
                fontSize: 10,
                fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                color: i == 0
                    ? null
                    : (v.contains('%')
                        ? (v.startsWith('+') ||
                                (double.tryParse(v.replaceAll('%', '')) ?? 0) >
                                    50
                            ? AppTheme.positive
                            : AppTheme.negative)
                        : null),
              )),
        );
      }).toList(),
    );
  }

  Widget _bimEconomicCalendar(MarketOverview overview, BuildContext context) {
    final events = overview.economicCalendar ?? [];
    final isDark = AppTheme.isDark(context);
    final dimText = isDark ? AppTheme.white38 : AppTheme.lightTextMuted;
    final mainText = isDark ? AppTheme.white : AppTheme.lightTextPrimary;
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('ÉVÉNEMENTS ÉCONOMIQUES',
              style: GoogleFonts.lora(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: dimText,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ...events.take(6).map((e) {
            final isHigh = e.impact.toUpperCase() == 'HIGH';
            final color = isHigh ? AppTheme.gold : dimText;
            return Container(
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: AppTheme.getBorder(context), width: 0.5)),
              ),
              child: Row(children: [
                SizedBox(
                    width: 48,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              e.date.split(' ').length > 1
                                  ? e.date.split(' ')[1]
                                  : e.date,
                              style: GoogleFonts.lora(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary)),
                          Text(e.country,
                              style: GoogleFonts.lora(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: dimText)),
                        ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(e.event.toUpperCase(),
                        style: GoogleFonts.lora(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isHigh ? color : mainText,
                            letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(e.actual != null && e.actual!.isNotEmpty ? e.actual! : '—',
                    style: GoogleFonts.lora(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isHigh ? AppTheme.gold : mainText)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
