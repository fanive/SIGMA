import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../models/sigma_models.dart';
import 'analysis_helpers.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION WIDGETS — Each section of the analysis panel
// ═══════════════════════════════════════════════════════════════════════════════

/// 01 — VERDICT ANALYTIQUE
class VerdictSection extends StatelessWidget {
  final AnalysisData a;
  const VerdictSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(a.verdict);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Verdict + Score row
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VERDICT', style: AppTheme.label(context)),
          Text(a.verdict.toUpperCase(),
              style: AppTheme.serif(context,
                  size: 24, weight: FontWeight.w900, color: color)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('SIGMA SCORE', style: AppTheme.label(context)),
          Text('${a.sigmaScore.toInt()}',
              style: AppTheme.numeric(context,
                  size: 28, weight: FontWeight.w900, color: color)),
        ]),
      ]),
      const SizedBox(height: 16),
      // Trade Setup Box
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.2)),
            color: color.withValues(alpha: 0.02)),
        child: Column(children: [
          Row(children: [
            Icon(Icons.gps_fixed, size: 14, color: color),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('OBJECTIF DE PRIX',
                      style: AppTheme.label(context).copyWith(fontSize: 7)),
                  Text('\$${a.tradeSetup.cleanTargetPrice}',
                      style: AppTheme.numeric(context,
                          size: 16, weight: FontWeight.w900)),
                ])),
            RiskBadge(a.riskLevel),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _chip('ENTRÉE', a.tradeSetup.cleanEntryZone),
            const SizedBox(width: 8),
            _chip('STOP', a.tradeSetup.cleanStopLoss, isRed: true),
            const SizedBox(width: 8),
            _chip('R/R', a.tradeSetup.riskRewardRatio),
          ]),
        ]),
      ),
      // Confidence bar
      if (a.confidence > 0) ...[
        const SizedBox(height: 12),
        Row(children: [
          Text('CONFIANCE',
              style: GoogleFonts.lora(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textTertiary)),
          const SizedBox(width: 8),
          Expanded(
              child: LinearProgressIndicator(
            value: a.confidence.clamp(0, 1),
            backgroundColor: AppTheme.textTertiary.withValues(alpha: 0.1),
            color: color,
            minHeight: 3,
          )),
          const SizedBox(width: 8),
          Text('${(a.confidence * 100).toInt()}%',
              style: GoogleFonts.lora(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ]),
      ],
    ]);
  }

  Widget _chip(String label, String value, {bool isRed = false}) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(
            color: (isRed ? AppTheme.negative : AppTheme.textTertiary)
                .withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.lora(
                fontSize: 7, fontWeight: FontWeight.bold, color: AppTheme.textTertiary)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.lora(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isRed ? AppTheme.negative : null),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}

/// 03 — PROS / CONS
class ProsConsSection extends StatelessWidget {
  final AnalysisData a;
  const ProsConsSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: _list(context, 'FORCES', a.pros, AppTheme.positive,
              Icons.trending_up)),
      const SizedBox(width: 16),
      Expanded(
          child: _list(context, 'RISQUES', a.cons, AppTheme.negative,
              Icons.trending_down)),
    ]);
  }

  Widget _list(BuildContext context, String title, List<ProCon> items,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTheme.label(context).copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.take(5).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•',
                        style: GoogleFonts.lora(
                            fontSize: 14,
                            color: color,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.text,
                        style: AppTheme.body(context, size: 12),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// 04 — MATRICE FONDAMENTALE
class FundamentalMatrixSection extends StatelessWidget {
  final AnalysisData a;
  const FundamentalMatrixSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final ks = a.keyStatistics;
    final metrics = <_M>[
      _M('CAPITALISATION', fmtLarge(ks?.marketCap)),
      _M('P/E (TTM)',
          ks?.trailingPE != 0 ? ks!.trailingPE.toStringAsFixed(1) : 'N/A'),
      _M('P/E (FWD)',
          ks?.forwardPE != 0 ? ks!.forwardPE.toStringAsFixed(1) : 'N/A'),
      _M('PEG RATIO',
          ks?.pegRatio != 0 ? ks!.pegRatio.toStringAsFixed(2) : 'N/A'),
      _M('ROE', ks?.returnOnEquity != 0 ? fmtPct(ks!.returnOnEquity) : 'N/A'),
      _M('DETTE/EQUITY',
          ks?.debtToEquity != 0 ? ks!.debtToEquity.toStringAsFixed(1) : 'N/A'),
      _M('MARGE PROFIT',
          ks?.profitMargins != 0 ? fmtPct(ks!.profitMargins) : 'N/A'),
      _M('CROISSANCE REV.',
          ks?.revenueGrowth != 0 ? fmtPct(ks!.revenueGrowth) : 'N/A'),
      _M('FREE CASHFLOW', fmtLarge(ks?.freeCashflow)),
      _M('REVENU TOTAL', fmtLarge(ks?.revenue)),
      _M('BETA', ks?.beta != 0 ? ks!.beta.toStringAsFixed(2) : 'N/A'),
      _M('SHORT RATIO',
          ks?.shortRatio != 0 ? ks!.shortRatio.toStringAsFixed(2) : 'N/A'),
      // NEW — yfinance dividend & range intelligence
      _M(
          'DIV. YIELD',
          ks != null && ks.dividendYield != 0
              ? fmtPct(ks.dividendYield)
              : 'N/A'),
      _M(
          'CROISS. BNA',
          ks != null && ks.earningsGrowth != 0
              ? fmtPct(ks.earningsGrowth)
              : 'N/A'),
      _M(
          'P/B RATIO',
          ks != null && ks.priceToBook != 0
              ? ks.priceToBook.toStringAsFixed(2)
              : 'N/A'),
      _M(
          'MARGE OPÉR.',
          ks != null && ks.operatingMargins != 0
              ? fmtPct(ks.operatingMargins)
              : 'N/A'),
      _M(
          '52W HIGH',
          ks != null && ks.fiftyTwoWeekHigh != 0
              ? '\$${ks.fiftyTwoWeekHigh.toStringAsFixed(2)}'
              : 'N/A'),
      _M(
          '52W LOW',
          ks != null && ks.fiftyTwoWeekLow != 0
              ? '\$${ks.fiftyTwoWeekLow.toStringAsFixed(2)}'
              : 'N/A'),
    ];

    // Only show metrics with actual data — hide N/A for clean density
    final active = metrics
        .where(
            (m) => m.value != 'N/A' && m.value != '\$0.00' && m.value != '0.0')
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.getBorder(context), width: 0.5),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            childAspectRatio: 2.4),
        itemCount: active.length,
        itemBuilder: (context, i) {
          final m = active[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.getBorder(context), width: 0.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(m.label,
                    style: AppTheme.label(context).copyWith(fontSize: 7),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(m.value,
                          style: AppTheme.numeric(context,
                              size: 14, weight: FontWeight.w900))),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _M {
  final String label, value;
  _M(this.label, this.value);
}

/// 05 — ANALYSE TECHNIQUE
class TechnicalSection extends StatelessWidget {
  final AnalysisData a;
  const TechnicalSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    if (a.technicalAnalysis.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...a.technicalAnalysis.take(8).map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                  flex: 2,
                  child: Text(t.indicator,
                      style: GoogleFonts.lora(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Expanded(
                  flex: 1,
                  child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(t.value,
                          style: GoogleFonts.lora(
                              fontSize: 11, fontWeight: FontWeight.w800)))),
              const Spacer(flex: 1),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _interpColor(t.interpretation).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(t.interpretation,
                    style: GoogleFonts.lora(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: _interpColor(t.interpretation)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          )),
      // Supports & Resistances
      if (a.supports.isNotEmpty || a.resistances.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [
          if (a.supports.isNotEmpty)
            Expanded(
                child: _levelRow('SUPPORTS', a.supports, AppTheme.positive)),
          if (a.resistances.isNotEmpty)
            Expanded(
                child:
                    _levelRow('RÉSISTANCES', a.resistances, AppTheme.negative)),
        ]),
      ],
    ]);
  }

  Widget _levelRow(String title, List<String> levels, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.lora(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1)),
      const SizedBox(height: 4),
      Wrap(
          spacing: 6,
          runSpacing: 4,
          children: levels
              .take(3)
              .map((l) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: color.withValues(alpha: 0.3))),
                    child: Text(l,
                        style: GoogleFonts.lora(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ))
              .toList()),
    ]);
  }

  Color _interpColor(String interp) {
    final i = interp.toUpperCase();
    if (i.contains('BULL') ||
        i.contains('ACHAT') ||
        i.contains('UP') ||
        i.contains('HAUSSE')) {
      return AppTheme.positive;
    }
    if (i.contains('BEAR') ||
        i.contains('VENTE') ||
        i.contains('DOWN') ||
        i.contains('BAISSE')) {
      return AppTheme.negative;
    }
    return AppTheme.warning;
  }
}

/// 06 — CATALYSEURS
class CatalystsSection extends StatelessWidget {
  final AnalysisData a;
  const CatalystsSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    if (a.catalysts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...a.catalysts.take(6).map((c) {
        final isRisk = c.type.toUpperCase().contains('RISQUE') ||
            c.type.toUpperCase().contains('RISK');
        final color = isRisk ? AppTheme.negative : AppTheme.positive;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: color.withValues(alpha: 0.1),
                child: Text(c.type.toUpperCase(),
                    style: GoogleFonts.lora(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(c.headline,
                style: GoogleFonts.lora(
                    fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (c.insight.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(c.insight,
                  style: GoogleFonts.lora(
                      fontSize: 10, color: AppTheme.textTertiary, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ]),
        );
      }),
    ]);
  }
}

/// 07 — CONSENSUS ANALYSTES
class AnalystConsensusSection extends StatelessWidget {
  final AnalysisData a;
  const AnalystConsensusSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final rec = a.analystRecommendations;
    final total =
        rec.strongBuy + rec.buy + rec.hold + rec.sell + rec.strongSell;
    if (total == 0 && a.analystRatings.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (total > 0) ...[
        // Consensus bar
        Row(children: [
          Text(rec.consensusLabel,
              style: GoogleFonts.lora(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: verdictColor(rec.consensusLabel))),
          const Spacer(),
          Text('$total analystes',
              style: GoogleFonts.lora(fontSize: 10, color: AppTheme.textTertiary)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Row(children: [
            _bar(rec.strongBuy, total, AppTheme.positiveStrong),
            _bar(rec.buy, total, AppTheme.positiveSoft),
            _bar(rec.hold, total, AppTheme.warningStrong),
            _bar(rec.sell, total, AppTheme.negativeSoft),
            _bar(rec.strongSell, total, AppTheme.negativeStrong),
          ]),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _label('SB ${rec.strongBuy}', AppTheme.positiveStrong),
          _label('B ${rec.buy}', AppTheme.positiveSoft),
          _label('H ${rec.hold}', AppTheme.warningStrong),
          _label('S ${rec.sell}', AppTheme.negativeSoft),
          _label('SS ${rec.strongSell}', AppTheme.negativeStrong),
        ]),
        const SizedBox(height: 16),
      ],
      // Target price
      if (a.targetPriceValue != null && a.targetPriceValue! > 0)
        MetricRow('OBJECTIF MOYEN ANALYSTES',
            '\$${a.targetPriceValue!.toStringAsFixed(2)}'),
      // Recent ratings
      if (a.analystRatings.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('DERNIÈRES NOTATIONS',
            style: GoogleFonts.lora(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: AppTheme.textTertiary,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        ...a.analystRatings.take(5).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(
                    width: 80,
                    child: Text(r.firm,
                        style: GoogleFonts.lora(
                            fontSize: 10, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: verdictColor(r.rating).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2)),
                  child: Text(r.rating,
                      style: GoogleFonts.lora(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: verdictColor(r.rating))),
                ),
                const Spacer(),
                Text(r.action,
                    style: GoogleFonts.lora(fontSize: 9, color: AppTheme.textTertiary)),
              ]),
            )),
      ],
    ]);
  }

  Widget _bar(int count, int total, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Expanded(flex: count, child: Container(height: 6, color: color));
  }

  Widget _label(String text, Color color) {
    return Text(text,
        style: GoogleFonts.lora(
            fontSize: 8, fontWeight: FontWeight.w700, color: color));
  }
}

/// 08 — NEWS
class NewsSection extends StatelessWidget {
  final AnalysisData a;
  const NewsSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    if (a.companyNews.isEmpty) return const SizedBox.shrink();
    return Column(
        children: a.companyNews.take(5).map((n) {
      return GestureDetector(
        onTap: () {
          if (n.url.isNotEmpty) launchUrl(Uri.parse(n.url));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.getBorder(context), width: 0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 3,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                color: AppTheme.primary.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(n.source.toUpperCase(),
                      style: GoogleFonts.lora(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                  const SizedBox(height: 3),
                  Text(n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                  if (n.summary.isNotEmpty && n.summary != 'N/A') ...[
                    const SizedBox(height: 4),
                    Text(n.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lora(
                            fontSize: 10, color: AppTheme.textTertiary, height: 1.4)),
                  ],
                ])),
            Icon(Icons.chevron_right,
                size: 14, color: AppTheme.textTertiary.withValues(alpha: 0.3)),
          ]),
        ),
      );
    }).toList());
  }
}

/// 09 — SENTIMENT & INSTITUTIONAL
class SentimentSection extends StatelessWidget {
  final AnalysisData a;
  const SentimentSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Fear & Greed
      Row(children: [
        Expanded(
            child: _gauge(
                'FEAR & GREED', a.fearAndGreed.score, a.fearAndGreed.label)),
        const SizedBox(width: 12),
        Expanded(
            child: _gauge(
                'MARCHÉ', a.marketSentiment.score, a.marketSentiment.label)),
      ]),
      const SizedBox(height: 16),
      // Institutional Activity
      MetricRow('SMART MONEY',
          '${(a.institutionalActivity.smartMoneySentiment * 100).toInt()}%',
          valueColor: a.institutionalActivity.smartMoneySentiment > 0.5
              ? AppTheme.positive
              : AppTheme.negative),
      if (a.institutionalActivity.darkPoolInterpretation.isNotEmpty)
        MetricRow('FLUX INSTITUTIONNEL',
            a.institutionalActivity.darkPoolInterpretation),
      // Social
      if (a.socialSentiment != null) ...[
        const SizedBox(height: 8),
        MetricRow(
            'REDDIT', '${(a.socialSentiment!.redditSentiment * 100).toInt()}%'),
        MetricRow('TWITTER/X',
            '${(a.socialSentiment!.twitterSentiment * 100).toInt()}%'),
        MetricRow('MENTIONS', '${a.socialSentiment!.mentions}'),
      ],
      // Insider buy ratio
      if (a.insiderBuyRatio != null)
        MetricRow('INSIDER BUY RATIO', '${(a.insiderBuyRatio! * 100).toInt()}%',
            valueColor: a.insiderBuyRatio! > 0.5
                ? AppTheme.positive
                : AppTheme.negative),
      // ESG
      if (a.esgScore != null && a.esgScore! > 0)
        MetricRow('ESG SCORE', a.esgScore!.toStringAsFixed(0)),
    ]);
  }

  Widget _gauge(String label, double score, String rating) {
    final color = score > 60
        ? AppTheme.positive
        : score < 40
            ? AppTheme.negative
            : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(label,
            style: GoogleFonts.lora(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: AppTheme.textTertiary,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('${score.toInt()}',
            style: GoogleFonts.lora(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(rating.toUpperCase(),
            style: GoogleFonts.lora(
                fontSize: 8, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// 10 — CORPORATE IDENTITY
class CorporateSection extends StatelessWidget {
  final AnalysisData a;
  const CorporateSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (a.sector != null && a.sector!.isNotEmpty)
        MetricRow('SECTEUR', a.sector!),
      if (a.industry != null && a.industry!.isNotEmpty)
        MetricRow('INDUSTRIE', a.industry!),
      if (a.ceo != null && a.ceo!.isNotEmpty) MetricRow('CEO', a.ceo!),
      if (a.employees != null && a.employees! > 0)
        MetricRow('EMPLOYÉS', fmtLarge(a.employees!.toDouble())),
      if (a.exchange != null && a.exchange!.isNotEmpty)
        MetricRow('BOURSE', a.exchange!),
      if (a.country != null && a.country!.isNotEmpty)
        MetricRow('PAYS', a.country!),
      if (a.website != null && a.website!.isNotEmpty)
        MetricRow('SITE WEB', a.website!),
      // Holders
      if (a.holders != null) ...[
        const SizedBox(height: 12),
        Text('ACTIONNARIAT',
            style: GoogleFonts.lora(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: AppTheme.textTertiary,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        MetricRow('INSIDERS', fmtPct(a.holders!.insidersPercent)),
        MetricRow('INSTITUTIONS', fmtPct(a.holders!.institutionsPercent)),
        MetricRow('NB INSTITUTIONS', '${a.holders!.institutionsCount}'),
      ],
    ]);
  }
}

/// 11 — PEERS
class PeersSection extends StatelessWidget {
  final AnalysisData a;
  const PeersSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    if (a.sectorPeers.isEmpty) return const SizedBox.shrink();
    return Column(
        children: a.sectorPeers
            .take(5)
            .map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(
                        width: 50,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(p.ticker,
                                style: GoogleFonts.lora(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(p.name,
                            style: GoogleFonts.lora(
                                fontSize: 10, color: AppTheme.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text(
                        'P/E ${p.peRatio > 0 ? p.peRatio.toStringAsFixed(1) : "N/A"}',
                        style:
                            GoogleFonts.lora(fontSize: 9, color: AppTheme.textTertiary)),
                    const SizedBox(width: 8),
                    Flexible(
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(p.marketCap,
                                style: GoogleFonts.lora(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)))),
                  ]),
                ))
            .toList());
  }
}

/// 12 — EARNINGS CALENDAR (yfinance calendarEvents)
class EarningsCalendarSection extends StatelessWidget {
  final AnalysisData a;
  const EarningsCalendarSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final cal = a.earningsCalendar;
    if (cal == null || cal.isEmpty) return const SizedBox.shrink();
    final dates = cal['earningsDate'] as List? ?? [];
    final epsAvg = cal['earningsAverage'];
    final epsHigh = cal['earningsHigh'];
    final epsLow = cal['earningsLow'];
    final revAvg = cal['revenueAverage'];
    final exDiv = cal['exDividendDate'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (dates.isNotEmpty)
        _row('PROCHAINS RÉSULTATS', dates.first?.toString() ?? 'N/A',
            AppTheme.primary),
      if (epsAvg != null) _row('EPS ESTIMÉ (MOY)', epsAvg.toString()),
      if (epsHigh != null && epsLow != null)
        _row('EPS RANGE', '$epsLow — $epsHigh'),
      if (revAvg != null)
        _row('REVENU ESTIMÉ', fmtLarge((revAvg as num).toDouble())),
      if (exDiv != null && exDiv.toString().isNotEmpty)
        _row('EX-DIVIDENDE', exDiv.toString(), AppTheme.warning),
    ]);
  }

  Widget _row(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary))),
        Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.lora(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color))),
      ]),
    );
  }
}

/// 13 — EPS TREND (yfinance earningsTrend)
class EpsTrendSection extends StatelessWidget {
  final AnalysisData a;
  const EpsTrendSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final trend = a.earningsTrend?['trend'] as List?;
    if (trend == null || trend.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
              flex: 2,
              child: Text('PÉRIODE',
                  style: GoogleFonts.lora(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1))),
          Expanded(
              child: Text('EPS EST.',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1))),
          Expanded(
              child: Text('CROISS.',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1))),
          Expanded(
              child: Text('ANALYSTES',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1))),
        ]),
      ),
      ...trend.take(4).map((item) {
        final m = Map<String, dynamic>.from(item);
        final growth = m['growth'];
        final growthVal = growth is num ? growth : 0.0;
        final growthColor = growthVal > 0
            ? AppTheme.positive
            : growthVal < 0
                ? AppTheme.negative
                : AppTheme.textTertiary;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.getBorder(context), width: 0.3))),
          child: Row(children: [
            Expanded(
                flex: 2,
                child: Text(m['period']?.toString() ?? '',
                    style: GoogleFonts.lora(
                        fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(
                child: Text(m['epsAvg']?.toString() ?? '-',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.lora(
                        fontSize: 10, fontWeight: FontWeight.w800))),
            Expanded(
                child: Text(
              growth != null ? '${(growthVal * 100).toStringAsFixed(1)}%' : '-',
              textAlign: TextAlign.right,
              style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: growthColor),
            )),
            Expanded(
                child: Text(m['numAnalysts']?.toString() ?? '-',
                    textAlign: TextAlign.right,
                    style:
                        GoogleFonts.lora(fontSize: 10, color: AppTheme.textTertiary))),
          ]),
        );
      }),
    ]);
  }
}

/// 14 — INSTITUTIONAL HOLDERS (yfinance institutionOwnership)
class InstitutionalHoldersSection extends StatelessWidget {
  final AnalysisData a;
  const InstitutionalHoldersSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final holders = a.institutionalHolders;
    if (holders == null || holders.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...holders.take(8).map((h) {
        final name = h['holder']?.toString() ?? '';
        final pct = h['pctHeld'];
        final pctStr = pct is num
            ? '${(pct * 100).toStringAsFixed(2)}%'
            : (pct?.toString() ?? '');
        final val = h['value'];
        final valStr = val is num ? fmtLarge(val.toDouble()) : '';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.getBorder(context), width: 0.3))),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: Text(name,
                    style: GoogleFonts.lora(
                        fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (pctStr.isNotEmpty)
              SizedBox(
                  width: 55,
                  child: Text(pctStr,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.lora(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary))),
            if (valStr.isNotEmpty)
              SizedBox(
                  width: 55,
                  child: Text(valStr,
                      textAlign: TextAlign.right,
                      style:
                          GoogleFonts.lora(fontSize: 9, color: AppTheme.textTertiary))),
          ]),
        );
      }),
    ]);
  }
}

/// 15 — 52-WEEK RANGE BAR (yfinance summaryDetail)
class RangeBarSection extends StatelessWidget {
  final AnalysisData a;
  const RangeBarSection(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final ks = a.keyStatistics;
    if (ks == null || ks.fiftyTwoWeekHigh == 0 || ks.fiftyTwoWeekLow == 0) {
      return const SizedBox.shrink();
    }
    final low = ks.fiftyTwoWeekLow;
    final high = ks.fiftyTwoWeekHigh;
    final range = high - low;
    if (range <= 0) return const SizedBox.shrink();

    final currentPrice =
        double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final pricePct =
        range > 0 ? ((currentPrice - low) / range).clamp(0.0, 1.0) : 0.5;
    final ma50Pct = ks.fiftyDayAverage > 0
        ? ((ks.fiftyDayAverage - low) / range).clamp(0.0, 1.0)
        : -1.0;
    final ma200Pct = ks.twoHundredDayAverage > 0
        ? ((ks.twoHundredDayAverage - low) / range).clamp(0.0, 1.0)
        : -1.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Labels
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('\$${low.toStringAsFixed(2)}',
            style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.negative)),
        Text('\$${high.toStringAsFixed(2)}',
            style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.positive)),
      ]),
      const SizedBox(height: 6),
      // Range bar
      SizedBox(
        height: 20,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(children: [
            // Background bar
            Container(
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    AppTheme.negativeStrong,
                    AppTheme.warningStrong,
                    AppTheme.positiveStrong
                  ]),
                  borderRadius: BorderRadius.circular(2),
                )),
            // MA200 marker
            if (ma200Pct >= 0)
              Positioned(
                  left: w * ma200Pct - 1,
                  top: 4,
                  child: Container(
                      width: 2,
                      height: 12,
                      color: AppTheme.blueAccent.withValues(alpha: 0.6))),
            // MA50 marker
            if (ma50Pct >= 0)
              Positioned(
                  left: w * ma50Pct - 1,
                  top: 4,
                  child: Container(
                      width: 2,
                      height: 12,
                      color: AppTheme.orangeAccent.withValues(alpha: 0.6))),
            // Current price marker
            Positioned(
                left: w * pricePct - 4,
                top: 2,
                child: Container(
                  width: 8,
                  height: 16,
                  decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppTheme.primary, width: 1.5)),
                )),
          ]);
        }),
      ),
      const SizedBox(height: 8),
      // Legend
      Wrap(spacing: 12, runSpacing: 4, children: [
        _legend('PRIX', AppTheme.white),
        if (ma50Pct >= 0)
          _legend('MA50 \$${ks.fiftyDayAverage.toStringAsFixed(0)}',
              AppTheme.orangeAccent),
        if (ma200Pct >= 0)
          _legend('MA200 \$${ks.twoHundredDayAverage.toStringAsFixed(0)}',
              AppTheme.blueAccent),
      ]),
      // Dividend strip
      if (ks.dividendYield > 0) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.positive.withValues(alpha: 0.2)),
              color: AppTheme.positive.withValues(alpha: 0.02)),
          child: Row(children: [
            const Icon(Icons.payments,
                size: 14, color: AppTheme.positive),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('DIVIDENDE',
                      style: GoogleFonts.lora(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.positive,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(
                      'Rendement: ${fmtPct(ks.dividendYield)} · Taux: \$${ks.dividendRate.toStringAsFixed(2)} · Payout: ${fmtPct(ks.payoutRatio)}',
                      style: GoogleFonts.lora(
                          fontSize: 10, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ])),
          ]),
        ),
      ],
    ]);
  }

  Widget _legend(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 3,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(1))),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.lora(
              fontSize: 7, fontWeight: FontWeight.w700, color: AppTheme.textTertiary)),
    ]);
  }
}




