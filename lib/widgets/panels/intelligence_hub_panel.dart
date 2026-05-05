// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../models/sigma_engines.dart';
import '../engines/daily_cream_report_view.dart';
import '../engines/daily_market_radar_view.dart';
import '../engines/generic_engine_view.dart';
import '../institutional/institutional_components.dart';

class IntelligencePanel extends StatefulWidget {
  const IntelligencePanel({super.key});

  @override
  State<IntelligencePanel> createState() => _IntelligencePanelState();
}

class _IntelligencePanelState extends State<IntelligencePanel> {
  // Engine service obtained from Provider — no independent instance created.

  final Map<String, List<SigmaEngineMetadata>> _engineCategories = {
    'DAILY OPERATIONS': [
      const SigmaEngineMetadata(
        title: 'Daily Cream Report',
        description:
          'Daily market briefing with top movers and research synthesis.',
        icon: Icons.local_cafe,
        color: AppTheme.amberAccent,
        trademark: '™',
      ),
      const SigmaEngineMetadata(
        title: 'Daily Market Radar',
        description: '3x daily automated reports (9:30 AM, 12 PM, 4 PM ET).',
        icon: Icons.radar,
        color: AppTheme.blueAccent,
      ),
    ],
    'RESEARCH MONITORING': [
      const SigmaEngineMetadata(
        title: 'Earnings Beat Signal',
        description: 'Earnings scenario monitor, guidance context and options positioning.',
        icon: Icons.bolt,
        color: AppTheme.yellowAccent,
        trademark: '™',
      ),
      const SigmaEngineMetadata(
        title: 'Earnings Intelligence',
        description: 'Transform complex earnings calls into structured research notes.',
        icon: Icons.mic,
        color: AppTheme.purpleAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Unusual Options Signal',
        description: 'Highlights unusual options activity around cash-generative companies.',
        icon: Icons.monitor_heart,
        color: AppTheme.redAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Deep Value Signal',
        description: 'Profitability, valuation and balance-sheet screening.',
        icon: Icons.diamond,
        color: AppTheme.emerald,
      ),
      const SigmaEngineMetadata(
        title: 'Trend Reversal Signal',
        description: 'Trend change and breakout monitoring for research follow-up.',
        icon: Icons.trending_up,
        color: AppTheme.academyTrackPattern,
      ),
    ],
    'FUNDAMENTAL ENGINES': [
      const SigmaEngineMetadata(
        title: 'FCF Growth Engine',
        description: 'Cash-flow growth monitor for recurring quality patterns.',
        icon: Icons.water_drop,
        color: AppTheme.cyan,
      ),
      const SigmaEngineMetadata(
        title: 'Quarterly FCF X-Ray',
        description: 'Your Quarterly Free Cash Flow Report Card.',
        icon: Icons.document_scanner,
        color: AppTheme.tealAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Margin Acceleration',
        description: 'Track margin expansion patterns watched by the market.',
        icon: Icons.north_east,
        color: AppTheme.orangeAccent,
      ),
      const SigmaEngineMetadata(
        title: 'First Positive Quarter',
        description: 'Monitor inflection points after a first positive quarter.',
        icon: Icons.star,
        color: AppTheme.white,
      ),
      const SigmaEngineMetadata(
        title: 'Consistency Engine',
        description: 'Revenue and EPS consistency patterns for follow-up research.',
        icon: Icons.check_circle,
        color: AppTheme.greenAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Balance Sheet Engine',
        description: 'Companies ranked by cash strength and balance-sheet resilience.',
        icon: Icons.account_balance,
        color: AppTheme.orange,
      ),
    ],
    'GROWTH & STRATEGY': [
      const SigmaEngineMetadata(
        title: 'AskiDojo Growth/Value',
        description: 'Growth, value, ETF and dividend universes for comparative research.',
        icon: Icons.eco,
        color: AppTheme.green,
        isVerified: true,
      ),
      const SigmaEngineMetadata(
        title: 'Momentum Growth',
        description: 'Momentum leaders to review as part of market leadership analysis.',
        icon: Icons.rocket_launch,
        color: AppTheme.pinkAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Sector Intelligence',
        description: 'Sector-by-sector ranking for comparative company review.',
        icon: Icons.layers,
        color: AppTheme.indigo,
        isVerified: true,
      ),
      const SigmaEngineMetadata(
        title: 'Research Report Engine',
        description: 'Long-form research drafting tool for deep-dive review.',
        icon: Icons.find_in_page,
        color: AppTheme.teal,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      color: AppTheme.getBackground(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _engineCategories.length,
              itemBuilder: (context, index) {
                final category = _engineCategories.keys.elementAt(index);
                final engines = _engineCategories[category]!;
                return _buildCategorySection(
                    context, category, engines, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, String title,
      List<SigmaEngineMetadata> engines, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 0, 12),
          child: Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.white38 : AppTheme.black38,
              letterSpacing: 1.8,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 900
                ? 3
                : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.3,
          ),
          itemCount: engines.length,
          itemBuilder: (context, index) =>
              _buildEngineCard(engines[index], isDark),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: InstitutionalHeader(
        eyebrow: 'Research library',
        title: 'Research Engines',
        thesis:
          'Des modules specialises pour comprendre un ticker vite, comparer des societes proprement et decider avec methode.',
        icon: Icons.auto_graph_rounded,
        actions: [_buildPulseIndicator()],
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.greenAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'RESEARCH CORE ONLINE',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildEngineCard(SigmaEngineMetadata engine, bool isDark) {
    return InstitutionalSurface(
      accentColor: engine.color,
      padding: EdgeInsets.zero,
      child: Material(
        color: AppTheme.transparent,
        child: InkWell(
          onTap: () => _openEngine(engine),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: engine.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(engine.icon, color: engine.color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${engine.title.toUpperCase()}${engine.trademark}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.white : AppTheme.black,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (engine.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle,
                                color: AppTheme.blue, size: 12),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        engine.description,
                        style: GoogleFonts.lora(
                          fontSize: 10,
                          color: isDark ? AppTheme.white38 : AppTheme.black38,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEngine(SigmaEngineMetadata engine) {
    if (engine.title == 'Daily Cream Report') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailyCreamReportScreen()),
      );
      return;
    }

    if (engine.title == 'Daily Market Radar') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailyMarketRadarScreen()),
      );
      return;
    }

    // Default for other engines
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => GenericEngineDetailScreen(engine: engine)),
    );
  }
}
