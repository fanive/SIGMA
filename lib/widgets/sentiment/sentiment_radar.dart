// ignore_for_file: prefer_const_constructors, unused_import
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/sigma_models.dart';

class SentimentRadar extends StatelessWidget {
  const SentimentRadar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SigmaProvider>(
      builder: (context, sp, _) {
        final data = sp.sentimentData;
        final isDark = AppTheme.isDark(context);

        if (data == null) return _buildLoading(context, isDark);

        final score = data.score;
        final rating = data.rating;
        final color = _getColorForScore(score);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.getBorder(context), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, rating, score, color, isDark),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── STATS GRID (BIM STYLE) ──
                    _buildGauges(context, data, isDark),

                    const SizedBox(height: 40),

                    // ── PROBABILITY ENGINE ──
                    _buildMarketProbabilityMatrix(context, data, isDark),

                    if (data.backtest.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildBacktestInsight(context, data.backtest, isDark),
                    ],

                    const SizedBox(height: 40),

                    // ── SECTOR ANALYSIS ──
                    _bimSubHeader(context, 'PONDÉRATION PAR SECTEUR'),
                    const SizedBox(height: 16),
                    _buildSectorMatrix(context, data, isDark),

                    const SizedBox(height: 40),

                    // ── MARKET SCAN ──
                    _bimSubHeader(context, 'ANALYSE DES FLUX ACTIFS'),
                    const SizedBox(height: 16),
                    _buildMarketInternals(context, data, isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading(BuildContext context, bool isDark) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
          border: Border.all(color: AppTheme.getBorder(context), width: 0.5)),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppTheme.primary)),
            const SizedBox(width: 16),
            Text('SYNCHRONISATION EN COURS',
                style: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textTertiary,
                    letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String rating, double score,
      Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.white.withValues(alpha: 0.01)
            : AppTheme.black.withValues(alpha: 0.01),
        border: Border(
            bottom: BorderSide(color: AppTheme.getBorder(context), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MOTEUR DE SENTIMENT',
                  style: AppTheme.label(context)
                      .copyWith(fontSize: 9, color: AppTheme.textTertiary)),
              const SizedBox(height: 4),
              Text(rating.toUpperCase(),
                  style: GoogleFonts.lora(
                      fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('SCORE',
                  style: AppTheme.label(context)
                      .copyWith(fontSize: 9, color: AppTheme.textTertiary)),
              const SizedBox(height: 4),
              Text('${score.toInt()}/100',
                  style: GoogleFonts.lora(
                      fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGauges(BuildContext context, dynamic data, bool isDark) {
    final i = data.indicators;
    return Column(
      children: [
        _gaugeRow(context, 'MOMENTUM DU MARCHÉ', i['momentum']?['val'] ?? 50.0,
            i['momentum']?['rating'] ?? 'NEUTRE', isDark),
        const SizedBox(height: 16),
        _gaugeRow(context, 'FORCE DES PRIX', i['strength']?['val'] ?? 50.0,
            i['strength']?['rating'] ?? 'NEUTRE', isDark),
        const SizedBox(height: 16),
        _gaugeRow(context, 'LARGEUR DU MARCHÉ', i['breadth']?['val'] ?? 50.0,
            i['breadth']?['rating'] ?? 'NEUTRE', isDark),
      ],
    );
  }

  Widget _gaugeRow(BuildContext context, String label, dynamic val,
      String rating, bool isDark) {
    final double value = (val is num) ? val.toDouble() : 50.0;
    final color = _getColorForRating(rating);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textTertiary)),
            Text(rating.toUpperCase(),
                style: GoogleFonts.lora(
                    fontSize: 9, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: double.infinity,
          decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.white10
                  : AppTheme.black.withValues(alpha: 0.05)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (value / 100).clamp(0, 1),
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectorMatrix(BuildContext context, dynamic data, bool isDark) {
    final sectors =
        (data.sectors as Map<String, double>).entries.take(6).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.5,
      ),
      itemCount: sectors.length,
      itemBuilder: (context, i) {
        final s = sectors[i];
        final color = s.value >= 0 ? AppTheme.positive : AppTheme.negative;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.getBorder(context), width: 0.5)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(s.key.toUpperCase(),
                      style: AppTheme.label(context).copyWith(fontSize: 8),
                      maxLines: 1)),
              Text('${s.value >= 0 ? '+' : ''}${s.value.toStringAsFixed(1)}%',
                  style: GoogleFonts.lora(
                      fontSize: 10, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarketInternals(
      BuildContext context, dynamic data, bool isDark) {
    final market =
        (data.market as Map<String, MarketItem>).entries.take(4).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: market.map((e) {
        final item = e.value;
        return Container(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.getBorder(context), width: 0.5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key,
                  style: GoogleFonts.lora(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$${item.price.toStringAsFixed(1)}',
                      style: GoogleFonts.lora(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                      '${item.percent >= 0 ? '+' : ''}${item.percent.toStringAsFixed(1)}%',
                      style: GoogleFonts.lora(
                          fontSize: 9,
                          color: item.percent >= 0
                              ? AppTheme.positive
                              : AppTheme.negative,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMarketProbabilityMatrix(
      BuildContext context, FearGreedData data, bool isDark) {
    final score = data.score;
    final bullEdge = (100 - score) * 0.4 + 35;
    final bearEdge = 100 - bullEdge;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.03),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _probItem(context, 'PROBABILITÉ HAUSSIÈRE', bullEdge,
                  AppTheme.positive),
              _probItem(context, 'PROBABILITÉ BAISSIÈRE', bearEdge,
                  AppTheme.negative),
            ],
          ),
          const SizedBox(height: 20),
          Text('SCÉNARIO PRÉVISIONNEL (7J)',
              style: AppTheme.label(context)
                  .copyWith(fontSize: 8, color: AppTheme.gold)),
        ],
      ),
    );
  }

  Widget _probItem(
      BuildContext context, String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.lora(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text('${val.toInt()}%',
            style: GoogleFonts.lora(
                fontSize: 28, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildBacktestInsight(
      BuildContext context, Map<String, dynamic> backtest, bool isDark) {
    return Text(
      'BACKTEST STRATÉGIQUE : L\'achat sous ce régime génère historiquement un alpha de ${(backtest['avg_return_1m'] ?? 0) * 100}% à T+30.',
      style: AppTheme.body(context, size: 10)
          .copyWith(fontWeight: FontWeight.w800, color: AppTheme.gold),
    );
  }

  Widget _bimSubHeader(BuildContext context, String label) {
    return Row(
      children: [
        Container(width: 4, height: 4, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppTheme.textTertiary,
                letterSpacing: 1)),
      ],
    );
  }

  Color _getColorForScore(double s) {
    if (s < 20) return AppTheme.negative;
    if (s < 40) return AppTheme.orangeAccent;
    if (s < 60) return AppTheme.amberAccent;
    if (s < 80) return AppTheme.lightGreenAccent;
    return AppTheme.positive;
  }

  Color _getColorForRating(String r) {
    r = r.toUpperCase();
    if (r.contains('FEAR')) return AppTheme.negative;
    if (r.contains('GREED')) return AppTheme.positive;
    return AppTheme.amberAccent;
  }
}
