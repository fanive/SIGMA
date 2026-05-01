import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../terminal/research_panel.dart';
import '../institutional/institutional_components.dart';
import '../charts/interactive_stock_chart.dart';

class ChartPanel extends StatefulWidget {
  const ChartPanel({super.key});
  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel> {
  static const _ranges = ['1D', '5D', '1M', '6M', 'YTD', '1Y', '5Y', 'MAX'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = context.watch<TerminalProvider>();
    final ticker = tp.focusedTicker;
    return ResearchPanelContainer(
      title: 'Market Workbench${ticker != null ? " — $ticker" : ""}',
      icon: Icons.query_stats_rounded,
      child: ticker == null ? _noTicker() : _chart(isDark, ticker),
    );
  }

  Widget _noTicker() => const InstitutionalEmptyState(
        icon: Icons.query_stats_rounded,
        title: 'Aucun actif sélectionné',
        message:
            'Sélectionnez une société depuis la recherche ou vos convictions pour ouvrir le graphique, les volumes et les niveaux clés.',
      );

  Widget _chart(bool isDark, String ticker) {
    return Consumer<SigmaProvider>(
      builder: (context, sp, _) {
        return Column(
          children: [
            // Period selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isDark
                  ? AppTheme.surface.withValues(alpha: .5)
                  : AppTheme.lightSurfaceLight,
              child: Row(
                children: _ranges.map((r) {
                  final active = sp.chartRange == r;
                  return GestureDetector(
                    onTap: () => sp.fetchChartData(r),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.amber.withValues(alpha: .15)
                            : AppTheme.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        r,
                        style: GoogleFonts.lora(
                          color: active
                              ? AppTheme.amber
                              : (isDark
                                  ? AppTheme.textMuted
                                  : AppTheme.lightTextMuted),
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Chart area
            Expanded(
              child: sp.isChartLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppTheme.amber),
                      ),
                    )
                  : InteractiveStockChart(ticker: ticker),
            ),
          ],
        );
      },
    );
  }
}
