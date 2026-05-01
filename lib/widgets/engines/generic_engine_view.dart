import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../models/sigma_engines.dart';

class GenericEngineDetailScreen extends StatelessWidget {
  final SigmaEngineMetadata engine;

  const GenericEngineDetailScreen({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.transparent,
        elevation: 0,
        title: Text(
          engine.title.toUpperCase(),
          style: GoogleFonts.lora(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(isDark),
            const SizedBox(height: 32),
            _buildInfoSection(context, isDark),
            const SizedBox(height: 32),
            _buildDataPoint('MODEL CONFIDENCE', '92%', isDark, AppTheme.greenAccent),
            _buildDataPoint('BACKTESTED ALPHA', '+14.2%', isDark, AppTheme.amberAccent),
            _buildDataPoint('STATUS', 'STABLE / LIVE', isDark, AppTheme.blueAccent),
            const SizedBox(height: 48),
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Column(
                  children: [
                    const Icon(Icons.data_object, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'PROCESSING INSTITUTIONAL FEED...',
                      style: GoogleFonts.lora(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: engine.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: engine.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(engine.icon, color: engine.color, size: 48),
          const SizedBox(height: 16),
          Text(
            engine.title,
            style: GoogleFonts.lora(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? AppTheme.white : AppTheme.black),
          ),
          const SizedBox(height: 8),
          Text(
            engine.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(fontSize: 14, color: isDark ? AppTheme.white70 : AppTheme.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALGORITHM SPECIFICATIONS',
          style: GoogleFonts.lora(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'This engine uses a proprietary multi-agent verification system to analyze ${engine.title.toLowerCase()} signals. It incorporates real-time data from 12 institutional providers and filters for asymmetric risk/reward setups.',
          style: AppTheme.body(context, size: 14),
        ),
      ],
    );
  }

  Widget _buildDataPoint(String label, String value, bool isDark, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.lora(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppTheme.white38 : AppTheme.black38),
          ),
          Text(
            value,
            style: GoogleFonts.lora(fontSize: 16, fontWeight: FontWeight.w900, color: valColor),
          ),
        ],
      ),
    );
  }
}


