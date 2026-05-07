import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';

import '../../utils/sigma_localization.dart';
import '../../services/sigma_api_service.dart';
import '../terminal/research_panel.dart';

// Static portfolio definition — replace with brokerage sync when available.
const _kPositions = [
  {'symbol': 'AAPL', 'name': 'Apple Inc.', 'shares': 10.0, 'cost': 170.0},
  {'symbol': 'NVDA', 'name': 'NVIDIA Corp.', 'shares': 5.0, 'cost': 490.0},
  {'symbol': 'TSLA', 'name': 'Tesla, Inc.', 'shares': 8.0, 'cost': 200.0},
  {'symbol': 'MSFT', 'name': 'Microsoft Corp.', 'shares': 6.0, 'cost': 380.0},
];

class PortfolioPanel extends StatefulWidget {
  const PortfolioPanel({super.key});

  @override
  State<PortfolioPanel> createState() => _PortfolioPanelState();
}

class _PortfolioPanelState extends State<PortfolioPanel> {
  late Future<List<Map<String, dynamic>>> _quotesFuture;

  @override
  void initState() {
    super.initState();
    _quotesFuture = SigmaApiService.getMultiQuote(
      _kPositions.map((p) => p['symbol'] as String).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dim = isDark ? AppTheme.white24 : AppTheme.black26;
    final txt = isDark ? AppTheme.white.withValues(alpha: 0.87) : AppTheme.black87;
    final dividerColor = isDark
        ? AppTheme.white.withValues(alpha: 0.05)
        : AppTheme.black.withValues(alpha: 0.05);

    return ResearchPanelContainer(
      title: context.t('portfolio'),
      icon: Icons.account_balance_wallet,
      showHeader: false,
      child: Consumer<SigmaProvider>(
        builder: (context, sp, _) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _quotesFuture,
            builder: (ctx, snap) {
              final priceMap = <String, Map<String, dynamic>>{};
              if (snap.hasData) {
                for (final q in snap.data!) {
                  final sym = (q['symbol'] as String? ?? '').toUpperCase();
                  if (sym.isNotEmpty) priceMap[sym] = q;
                }
              }

              double totalValue = 0;
              double totalCost = 0;
              for (final pos in _kPositions) {
                final sym = pos['symbol'] as String;
                final shares = pos['shares'] as double;
                final cost = pos['cost'] as double;
                final price = (priceMap[sym]?['price'] as num?)?.toDouble() ?? cost;
                totalValue += price * shares;
                totalCost += cost * shares;
              }
              final totalGainPct = totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0.0;
              final totalGain = totalValue - totalCost;

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  // ── NAV SUMMARY ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NET ASSET VALUE',
                            style: GoogleFonts.lora(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: dim,
                                letterSpacing: 1.8)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            snap.connectionState == ConnectionState.waiting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 1.5))
                                : Text('\$${_fmt(totalValue)}',
                                    style: GoogleFonts.lora(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: txt,
                                        letterSpacing: -1)),
                            const SizedBox(width: 12),
                            if (snap.hasData)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (totalGainPct >= 0 ? AppTheme.positive : AppTheme.negative)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    '${totalGainPct >= 0 ? "+" : ""}${totalGainPct.toStringAsFixed(2)}%',
                                    style: GoogleFonts.lora(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: totalGainPct >= 0 ? AppTheme.positive : AppTheme.negative),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (snap.hasData) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${totalGain >= 0 ? "+" : ""}\$${_fmt(totalGain.abs())} TOTAL P&L',
                            style: GoogleFonts.lora(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: (totalGain >= 0 ? AppTheme.positive : AppTheme.negative)
                                    .withValues(alpha: 0.7)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(height: 1, color: dividerColor),

                  // ── POSITIONS ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text('POSITIONS',
                        style: GoogleFonts.lora(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: dim,
                            letterSpacing: 1.8)),
                  ),

                  ..._kPositions.map((pos) {
                    final sym = pos['symbol'] as String;
                    final name = pos['name'] as String;
                    final shares = pos['shares'] as double;
                    final cost = pos['cost'] as double;
                    final q = priceMap[sym];
                    final price = (q?['price'] as num?)?.toDouble() ?? cost;
                    final changePct = (q?['changePercent'] as num?)?.toDouble() ?? 0.0;
                    final posValue = price * shares;
                    final posGain = (price - cost) * shares;
                    final posGainPct = cost > 0 ? (price - cost) / cost * 100 : 0.0;
                    return _positionRow(
                      symbol: sym,
                      name: name,
                      shares: shares,
                      price: price,
                      changePct: changePct,
                      posValue: posValue,
                      posGain: posGain,
                      posGainPct: posGainPct,
                      isLoading: snap.connectionState == ConnectionState.waiting,
                      isDark: isDark,
                      dim: dim,
                      txt: txt,
                      dividerColor: dividerColor,
                    );
                  }),

                  // ── COMING SOON ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.link,
                            size: 20,
                            color: isDark
                                ? AppTheme.white.withValues(alpha: 0.06)
                                : AppTheme.black.withValues(alpha: 0.06)),
                        const SizedBox(height: 12),
                        Text('BROKERAGE SYNC COMING SOON',
                            style: GoogleFonts.lora(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: dim,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 6),
                        Text('Connect your brokerage to auto-sync positions.',
                            style: GoogleFonts.lora(fontSize: 11, color: dim)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _positionRow({
    required String symbol,
    required String name,
    required double shares,
    required double price,
    required double changePct,
    required double posValue,
    required double posGain,
    required double posGainPct,
    required bool isLoading,
    required bool isDark,
    required Color dim,
    required Color txt,
    required Color dividerColor,
  }) {
    final dayColor = changePct >= 0 ? AppTheme.positive : AppTheme.negative;
    final gainColor = posGainPct >= 0 ? AppTheme.positive : AppTheme.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? AppTheme.white.withValues(alpha: 0.04)
                  : AppTheme.black.withValues(alpha: 0.04),
            ),
            child: Center(
              child: Text(symbol[0],
                  style: GoogleFonts.lora(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppTheme.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol,
                    style: GoogleFonts.lora(
                        fontSize: 12, fontWeight: FontWeight.w800, color: txt)),
                Text(name,
                    style: GoogleFonts.lora(fontSize: 9, color: dim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.2))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${_fmt(posValue)}',
                    style: GoogleFonts.lora(
                        fontSize: 12, fontWeight: FontWeight.w700, color: txt)),
                Text(
                  '${shares % 1 == 0 ? shares.toInt() : shares} sh · \$${price.toStringAsFixed(2)}',
                  style: GoogleFonts.lora(fontSize: 9, color: dim),
                ),
              ],
            ),
          const SizedBox(width: 10),
          if (!isLoading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: dayColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${changePct >= 0 ? "+" : ""}${changePct.toStringAsFixed(2)}%',
                    style: GoogleFonts.lora(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: dayColor),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${posGain >= 0 ? "+" : ""}\$${_fmt(posGain.abs())}',
                  style: GoogleFonts.lora(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: gainColor.withValues(alpha: 0.7)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${buf.toString()}.${parts[1]}';
  }
}

