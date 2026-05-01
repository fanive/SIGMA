import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../models/sigma_engines.dart';
import '../../providers/sigma_provider.dart';

class DailyCreamReportScreen extends StatefulWidget {
  const DailyCreamReportScreen({super.key});

  @override
  State<DailyCreamReportScreen> createState() => _DailyCreamReportScreenState();
}

class _DailyCreamReportScreenState extends State<DailyCreamReportScreen> {
  bool _isLoading = true;
  DailyCreamReport? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final report = await context
        .read<SigmaProvider>()
        .engineService
        .generateDailyCreamReport();
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.transparent,
        elevation: 0,
        title: Text(
          'DAILY CREAM REPORT™',
          style: GoogleFonts.lora(
              fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(child: Text('Failed to load report'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSynthesis(isDark),
                      const SizedBox(height: 32),
                      _buildSectionTitle('ALPHA PICKS OF THE DAY'),
                      const SizedBox(height: 16),
                      ..._report!.alphaPicks
                          .map((s) => _buildSignalRow(s, isDark)),
                      const SizedBox(height: 32),
                      _buildSectionTitle('TOP MOVERS & FLOWS'),
                      const SizedBox(height: 16),
                      ..._report!.topMovers
                          .map((s) => _buildSignalRow(s, isDark)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSynthesis(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.slate900Strong, AppTheme.slate950]
              : [AppTheme.lightSurfaceLight, AppTheme.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.white10 : AppTheme.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppTheme.amberAccent, size: 18),
              const SizedBox(width: 10),
              Text(
                'MARKET SYNTHESIS',
                style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.amberAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _report!.marketSynthesis,
            style: GoogleFonts.lora(
              fontSize: 15,
              height: 1.6,
              color: isDark ? AppTheme.white : AppTheme.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.lora(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSignalRow(SigmaSignalEntry signal, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgSecondary : AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? AppTheme.white.withValues(alpha: 0.05)
                : AppTheme.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                signal.ticker[0],
                style: GoogleFonts.lora(
                    fontWeight: FontWeight.w900, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      signal.ticker,
                      style: GoogleFonts.lora(
                          fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.greenAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'RATED ${signal.score.toInt()}',
                        style: GoogleFonts.lora(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.greenAccent),
                      ),
                    ),
                  ],
                ),
                Text(
                  signal.insight,
                  style: GoogleFonts.lora(
                      fontSize: 11,
                      color: isDark ? AppTheme.white38 : AppTheme.black38),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: AppTheme.white24),
        ],
      ),
    );
  }
}
