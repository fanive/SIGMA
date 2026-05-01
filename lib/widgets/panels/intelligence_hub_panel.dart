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
            'Daily market newsletter with top movers & alpha synthesis.',
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
    'SIGNAL INTELLIGENCE': [
      const SigmaEngineMetadata(
        title: 'Earnings Beat Signal',
        description: 'Beat Odds™, Guidance Raise Odds™ & Options convictions.',
        icon: Icons.bolt,
        color: AppTheme.yellowAccent,
        trademark: '™',
      ),
      const SigmaEngineMetadata(
        title: 'Earnings Intelligence',
        description: 'Transform complex earnings calls into actionable intel.',
        icon: Icons.mic,
        color: AppTheme.purpleAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Unusual Options Signal',
        description: 'Institutional conviction on FCF-positive stocks.',
        icon: Icons.monitor_heart,
        color: AppTheme.redAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Deep Value Signal',
        description: 'Profitability, valuation & fortress cash flow screening.',
        icon: Icons.diamond,
        color: AppTheme.emerald,
      ),
      const SigmaEngineMetadata(
        title: 'Trend Reversal Signal',
        description: 'Institutional-grade trend change & breakout detection.',
        icon: Icons.trending_up,
        color: AppTheme.academyTrackPattern,
      ),
    ],
    'FUNDAMENTAL ENGINES': [
      const SigmaEngineMetadata(
        title: 'FCF Growth Engine',
        description: 'Single source of truth — spot compounders early.',
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
        description: 'Find institutions\' most watched margin signals.',
        icon: Icons.north_east,
        color: AppTheme.orangeAccent,
      ),
      const SigmaEngineMetadata(
        title: 'First Positive Quarter',
        description: 'The biggest signal for early stock breakouts.',
        icon: Icons.star,
        color: AppTheme.white,
      ),
      const SigmaEngineMetadata(
        title: 'Consistency Engine',
        description: 'Revenue & EPS beat patterns that predict winners.',
        icon: Icons.check_circle,
        color: AppTheme.greenAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Balance Sheet Engine',
        description: 'Top 100 companies ranked by fortress cash positions.',
        icon: Icons.account_balance,
        color: AppTheme.orange,
      ),
    ],
    'GROWTH & STRATEGY': [
      const SigmaEngineMetadata(
        title: 'AskiDojo Growth/Value',
        description: 'High-conviction growth stocks, ETFs & dividend plays.',
        icon: Icons.eco,
        color: AppTheme.green,
        isVerified: true,
      ),
      const SigmaEngineMetadata(
        title: 'Momentum Growth',
        description: 'Find breakout companies leading the markets first.',
        icon: Icons.rocket_launch,
        color: AppTheme.pinkAccent,
      ),
      const SigmaEngineMetadata(
        title: 'Sector Intelligence',
        description: 'Find best stocks in every sector. AskiDojo Rated.',
        icon: Icons.layers,
        color: AppTheme.indigo,
        isVerified: true,
      ),
      const SigmaEngineMetadata(
        title: 'Research Report Engine',
        description: 'Personal institutional-grade depth research machine.',
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
          _buildHeader(context),
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
            style: GoogleFonts.lora(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isDark ? AppTheme.white38 : AppTheme.black38,
              letterSpacing: 2,
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
        eyebrow: 'Signal library',
        title: 'Research Engines',
        thesis:
            'Des modules spécialisés pour transformer le bruit de marché en signaux actionnables : earnings, cash-flow, momentum, qualité et valorisation.',
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
          'LIVE CORE ONLINE',
          style: GoogleFonts.lora(
            fontSize: 9,
            fontWeight: FontWeight.w700,
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
                              style: GoogleFonts.lora(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? AppTheme.white : AppTheme.black,
                                letterSpacing: 0.2,
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
