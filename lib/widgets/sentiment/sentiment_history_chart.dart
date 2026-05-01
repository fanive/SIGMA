// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:quantum_invest/theme/app_theme.dart';

class SentimentHistoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final bool compact;

  const SentimentHistoryChart({
    super.key,
    required this.history,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    // Filter last 90 days for clarity if compact, else last 1 year
    final days = compact ? 90 : 365;
    final data = history.length > days 
        ? history.sublist(history.length - days) 
        : history;

    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.history, size: 12, color: AppTheme.warning),
                const SizedBox(width: 8),
                Text(
                  'FEAR & GREED HISTORICAL TREND',
                  style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.warning,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          height: compact ? 120 : 200,
          margin: EdgeInsets.symmetric(horizontal: compact ? 0 : 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.white.withValues(alpha: 0.02) : AppTheme.black.withValues(alpha: 0.02),
            border: Border.all(color: isDark ? AppTheme.white10 : AppTheme.black12, width: 0.5),
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: !compact,
                    reservedSize: 22,
                    interval: (data.length / 4).floorToDouble(),
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= data.length) return const SizedBox.shrink();
                      final date = DateTime.parse(data[value.toInt()]['date']);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MMM').format(date).toUpperCase(),
                          style: GoogleFonts.lora(
                            fontSize: 7,
                            color: AppTheme.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: data.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), (e.value['score'] as num).toDouble());
                  }).toList(),
                  isCurved: true,
                  color: AppTheme.warning,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.warning.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark ? AppTheme.textPrimaryLightStrong : AppTheme.white,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final item = data[spot.x.toInt()];
                      return LineTooltipItem(
                        '${item['date']}\n',
                        GoogleFonts.lora(
                          fontSize: 10,
                          color: isDark ? AppTheme.white : AppTheme.black,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: 'Score: ${spot.y.toInt()}',
                            style: GoogleFonts.lora(
                              fontSize: 12,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}



