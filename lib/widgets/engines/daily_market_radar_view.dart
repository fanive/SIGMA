// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';

class DailyMarketRadarScreen extends StatefulWidget {
  const DailyMarketRadarScreen({super.key});

  @override
  State<DailyMarketRadarScreen> createState() => _DailyMarketRadarScreenState();
}

class _DailyMarketRadarScreenState extends State<DailyMarketRadarScreen> {
  // Engine service obtained from the Provider — no independent instance created.
  
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final now = DateTime.now();
    
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.transparent,
        elevation: 0,
        title: Text(
          'DAILY MARKET RADAR',
          style: GoogleFonts.lora(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildPhaseTimeline(isDark, now),
             const SizedBox(height: 32),
             _buildSectionTitle('LATEST INTEL: MID-DAY PIVOT'),
             const SizedBox(height: 16),
             _buildRadarPost(
               isDark,
               'Institutional flows are heavy in Large Cap Tech. Dark pool activity detected in \$NVDA and \$MSFT. VIX compression suggests stability for the afternoon session.',
               ['TECH ACCUMULATION', 'LOW VOLATILITY', 'DARK POOL ALERT'],
             ),
             const SizedBox(height: 24),
             _buildSectionTitle('ALPHA MOVERS'),
             const SizedBox(height: 16),
             _buildMoverRow('NVDA', '+4.2%', 'Artificial Intelligence Momentum'),
             _buildMoverRow('TSLA', '-2.1%', 'Under-delivery concerns hitting bids'),
             _buildMoverRow('AMD', '+1.8%', 'Sympathy trade with Sector Lead'),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseTimeline(bool isDark, DateTime now) {
    return Row(
      children: [
        _buildTimelineStep('9:30 AM', 'Opening', true, isDark),
        _buildConnector(true),
        _buildTimelineStep('12:00 PM', 'Mid-Day', true, isDark),
        _buildConnector(false),
        _buildTimelineStep('4:00 PM', 'Closing', false, isDark),
      ],
    );
  }

  Widget _buildTimelineStep(String time, String label, bool isDone, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppTheme.primary : (isDark ? AppTheme.white10 : AppTheme.black12),
              border: Border.all(color: isDone ? AppTheme.primary : (isDark ? AppTheme.white24 : AppTheme.black26)),
            ),
            child: Icon(
              isDone ? Icons.check : Icons.access_time,
              size: 14,
              color: isDone ? AppTheme.white : (isDark ? AppTheme.white38 : AppTheme.black38),
            ),
          ),
          const SizedBox(height: 8),
          Text(time, style: GoogleFonts.lora(fontSize: 10, fontWeight: FontWeight.w900)),
          Text(label, style: GoogleFonts.lora(fontSize: 9, color: isDark ? AppTheme.white38 : AppTheme.black38)),
        ],
      ),
    );
  }

  Widget _buildConnector(bool active) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 30),
      color: active ? AppTheme.primary : AppTheme.textTertiary.withValues(alpha: 0.2),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.lora(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppTheme.primary),
    );
  }

  Widget _buildRadarPost(bool isDark, String content, List<String> tags) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgSecondary : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.white.withValues(alpha: 0.05) : AppTheme.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: GoogleFonts.lora(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(t, style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.primary)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoverRow(String ticker, String change, String reason) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(ticker, style: GoogleFonts.lora(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(width: 8),
          Text(change, style: GoogleFonts.lora(fontSize: 11, fontWeight: FontWeight.w700, color: change.startsWith('+') ? AppTheme.greenAccent : AppTheme.redAccent)),
          const Spacer(),
          Text(reason, style: GoogleFonts.lora(fontSize: 10, color: AppTheme.white38)),
        ],
      ),
    );
  }
}


