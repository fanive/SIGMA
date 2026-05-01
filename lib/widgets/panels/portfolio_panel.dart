import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';

import '../../utils/sigma_localization.dart';
import '../terminal/research_panel.dart';

class PortfolioPanel extends StatelessWidget {
  const PortfolioPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final dim = isDark ? AppTheme.white24 : AppTheme.black26;
    final txt = isDark ? AppTheme.white.withValues(alpha: 0.87) : AppTheme.black87;
    final dividerColor = isDark ? AppTheme.white.withValues(alpha: 0.05) : AppTheme.black.withValues(alpha: 0.05);
    
    return ResearchPanelContainer(
      title: context.t('portfolio'),
      icon: Icons.account_balance_wallet,
      child: Consumer<SigmaProvider>(
        builder: (context, sp, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // ── NAV SUMMARY ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NET ASSET VALUE',
                        style: GoogleFonts.lora(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: dim,
                            letterSpacing: 2)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$125,430.50',
                            style: GoogleFonts.lora(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: txt,
                                letterSpacing: -1)),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.positive.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text('+1.87%',
                                style: GoogleFonts.lora(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.positive)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('+\$2,340.12 TODAY',
                        style: GoogleFonts.lora(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.positive.withValues(alpha: 0.7))),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: dividerColor),

              // ── ALLOCATION BAR ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ALLOCATION',
                        style: GoogleFonts.lora(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: dim,
                            letterSpacing: 2)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 65,
                              child: Container(height: 4, color: AppTheme.primary)),
                          const SizedBox(width: 2),
                          Expanded(
                              flex: 25,
                              child: Container(height: 4, color: AppTheme.warning)),
                          const SizedBox(width: 2),
                          Expanded(
                              flex: 10,
                              child: Container(
                                  height: 4,
                                  color: isDark ? AppTheme.white24 : AppTheme.black26)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _allocLabel('EQUITIES', '65%', AppTheme.primary, dim),
                        const SizedBox(width: 20),
                        _allocLabel('CRYPTO', '25%', AppTheme.warning, dim),
                        const SizedBox(width: 20),
                        _allocLabel('CASH', '10%', dim, dim),
                      ],
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // ── POSITIONS ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text('POSITIONS',
                    style: GoogleFonts.lora(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: dim,
                        letterSpacing: 2)),
              ),
              _positionRow('AAPL', 'Apple Inc.', 145.20, 2.45, isDark, dim, txt, dividerColor),
              _positionRow('NVDA', 'NVIDIA Corp.', 12.40, 5.67, isDark, dim, txt, dividerColor),
              _positionRow('TSLA', 'Tesla, Inc.', 42.10, -1.12, isDark, dim, txt, dividerColor),
              _positionRow('BTC', 'Bitcoin', 0.45, 0.89, isDark, dim, txt, dividerColor),

              // ── COMING SOON ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.link, size: 20,
                        color: isDark ? AppTheme.white.withValues(alpha: 0.06) : AppTheme.black.withValues(alpha: 0.06)),
                    const SizedBox(height: 12),
                    Text('BROKERAGE SYNC COMING SOON',
                        style: GoogleFonts.lora(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: dim,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Text('Connect your brokerage to auto-sync positions.',
                        style: GoogleFonts.lora(
                            fontSize: 11, color: dim)),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _allocLabel(String label, String pct, Color color, Color dim) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 4),
        Text('$label $pct',
            style: GoogleFonts.lora(
                fontSize: 9, fontWeight: FontWeight.w700, color: dim)),
      ],
    );
  }

  Widget _positionRow(String symbol, String name, double shares, double change,
      bool isDark, Color dim, Color txt, Color dividerColor) {
    final changeColor = change >= 0 ? AppTheme.positive : AppTheme.negative;
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
              color: isDark ? AppTheme.white.withValues(alpha: 0.04) : AppTheme.black.withValues(alpha: 0.04),
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
          Text('$shares',
              style: GoogleFonts.lora(
                  fontSize: 12, fontWeight: FontWeight.w600, color: txt)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
                '${change >= 0 ? "+" : ""}${change.toStringAsFixed(2)}%',
                style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: changeColor)),
          ),
        ],
      ),
    );
  }
}

