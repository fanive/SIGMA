import 'package:flutter/material.dart';
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
  String? _loadedTicker;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalProvider>();
    final ticker = tp.focusedTicker;
    return ResearchPanelContainer(
      title: 'Market Workbench${ticker != null ? " — $ticker" : ""}',
      icon: Icons.query_stats_rounded,
      child: ticker == null ? _noTicker() : _chart(ticker),
    );
  }

  Widget _noTicker() => const InstitutionalEmptyState(
        icon: Icons.query_stats_rounded,
        title: 'Aucun actif sélectionné',
        message:
            'Selectionnez une societe depuis la recherche ou votre liste de suivi pour ouvrir le graphique, les volumes et les niveaux cles.',
      );

  Widget _chart(String ticker) {
    return Consumer<SigmaProvider>(
      builder: (context, sp, _) {
        final cleanTicker = ticker.trim().toUpperCase();
        if (_loadedTicker != cleanTicker && !sp.isChartLoading) {
          _loadedTicker = cleanTicker;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<SigmaProvider>().fetchChartDataForTicker(
                  cleanTicker,
                  sp.chartRange.isEmpty ? '1Y' : sp.chartRange,
                );
          });
        }

        return Column(
          children: [
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
