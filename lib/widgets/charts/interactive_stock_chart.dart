import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:interactive_chart/interactive_chart.dart';
import '../../providers/sigma_provider.dart';
import '../../screens/fullscreen_chart_screen.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../utils/chart_overlay_engine.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SIGMA Institutional Candlestick Chart
/// ═══════════════════════════════════════════════════════════════════════════
/// TradingView-grade OHLCV candlestick chart using the `interactive_chart` package.
/// Volume bars are built-in. SMA overlays are passed via the `trends` list in `CandleData`.
/// ═══════════════════════════════════════════════════════════════════════════
class InteractiveStockChart extends StatefulWidget {
  final String ticker;
  final bool isFullscreen;
  final Function(Map<String, dynamic>)? onPointSelected;

  const InteractiveStockChart({
    super.key,
    required this.ticker,
    this.isFullscreen = false,
    this.onPointSelected,
  });

  @override
  State<InteractiveStockChart> createState() => _InteractiveStockChartState();
}

class _InteractiveStockChartState extends State<InteractiveStockChart> {
  // ── Overlay state ──
  bool _showSma50 = false;
  bool _showSma200 = false;
  bool _showCrosses = true; // Still keeps toolbar buttons
  ChartOverlays? _overlays;
  List<Map<String, dynamic>>? _cachedDataRef;
  List<CandleData>? _cachedCandles;

  void _computeOverlaysAndCandles(List<Map<String, dynamic>> data) {
    if (identical(data, _cachedDataRef) &&
        _overlays != null &&
        _cachedCandles != null) return;

    _cachedDataRef = data;
    _overlays = ChartOverlayEngine.compute(data);

    _cachedCandles = <CandleData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final close = (item['close'] as num?)?.toDouble();
      if (close == null || close <= 0) continue;

      final open = (item['open'] as num?)?.toDouble() ?? close;
      final high = (item['high'] as num?)?.toDouble() ?? close;
      final low = (item['low'] as num?)?.toDouble() ?? close;
      final volume = (item['volume'] as num?)?.toDouble() ?? 0;

      DateTime date;
      final rawDate = item['date'];
      if (rawDate is DateTime) {
        date = rawDate;
      } else if (rawDate is String) {
        date = DateTime.tryParse(rawDate) ?? DateTime.now();
      } else if (rawDate is int) {
        date = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000);
      } else {
        date = DateTime.now().subtract(Duration(days: data.length - i));
      }

      _cachedCandles!.add(CandleData(
        timestamp: date.millisecondsSinceEpoch,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
        trends: [], // Will be applied dynamically
      ));
    }
  }

  void _applyTrends() {
    if (_cachedCandles == null || _overlays == null) return;
    for (int i = 0; i < _cachedCandles!.length; i++) {
      final List<double?> trends = [];
      if (_showSma50 && i < _overlays!.sma50.length)
        trends.add(_overlays!.sma50[i]);
      if (_showSma200 && i < _overlays!.sma200.length)
        trends.add(_overlays!.sma200[i]);
      _cachedCandles![i].trends = trends;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SigmaProvider>(
      builder: (context, provider, _) {
        final data = provider.chartHistory;
        final isLoading = provider.isChartLoading;

        if (data.isNotEmpty) {
          _computeOverlaysAndCandles(data);
          _applyTrends();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPriceHeader(provider, data),
            const SizedBox(height: 8),
            if (widget.isFullscreen)
              Expanded(
                child: isLoading
                    ? _buildLoadingState()
                    : (data.length < 3 || (_cachedCandles?.length ?? 0) < 3)
                        ? _buildEmptyState()
                        : _buildCandlestickChart(),
              )
            else
              SizedBox(
                height: 280,
                child: isLoading
                    ? _buildLoadingState()
                    : (data.length < 3 || (_cachedCandles?.length ?? 0) < 3)
                        ? _buildEmptyState()
                        : _buildCandlestickChart(),
              ),
            const SizedBox(height: 8),
            _buildToolbarAndIndicators(),
            const SizedBox(height: 8),
            _buildRangeSelector(provider),
            _buildRangeAnalysis(provider),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRICE HEADER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPriceHeader(
      SigmaProvider provider, List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRIX DU MARCHÉ', style: _mono(9, c: AppTheme.textTertiary)),
          Text('---', style: _mono(18, c: AppTheme.white)),
        ]),
      ]);
    }

    final validPrices = data
        .map((d) => (d['close'] as num?)?.toDouble() ?? 0.0)
        .where((v) => v > 0)
        .toList();
    if (validPrices.isEmpty) {
      return Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRIX DU MARCHÉ', style: _mono(9, c: AppTheme.textTertiary)),
          Text('---', style: _mono(18, c: AppTheme.white)),
        ]),
      ]);
    }

    final lastPrice = validPrices.last;
    final firstPrice = validPrices.first;
    final minY = validPrices.reduce((a, b) => a < b ? a : b);
    final maxY = validPrices.reduce((a, b) => a > b ? a : b);
    final delta = lastPrice - firstPrice;
    final percent = firstPrice != 0 ? (delta / firstPrice) * 100 : 0.0;
    final isUp = delta >= 0;
    final color = isUp ? AppTheme.positive : AppTheme.negative;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(provider.chartRange,
                          style: _mono(9,
                              c: AppTheme.textTertiary, w: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
                          style: GoogleFonts.lora(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                      if (_overlays != null && _overlays!.regime != 'NEUTRAL')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_overlays!.regime == 'BULLISH'
                                    ? AppTheme.positive
                                    : AppTheme.negative)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _overlays!.regime == 'BULLISH'
                                ? '▲ BULL'
                                : '▼ BEAR',
                            style: GoogleFonts.lora(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: _overlays!.regime == 'BULLISH'
                                  ? AppTheme.positive
                                  : AppTheme.negative,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${lastPrice.toStringAsFixed(2)}',
                            style: _mono(24,
                                c: AppTheme.white, w: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}',
                            style: GoogleFonts.lora(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildFullscreenButton(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
                'H: \$${maxY.toStringAsFixed(2)} | L: \$${minY.toStringAsFixed(2)}',
                style: GoogleFonts.lora(
                    fontSize: 8,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text('CANDLESTICK',
                style: _mono(7, c: AppTheme.gold, w: FontWeight.w700, ls: 1)),
          ],
        ),
      ],
    );
  }

  Widget _buildFullscreenButton() {
    return GestureDetector(
      onTap: () {
        if (widget.isFullscreen) {
          Navigator.pop(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenChartScreen(ticker: widget.ticker),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          widget.isFullscreen ? Icons.close_fullscreen : Icons.open_in_full,
          size: 14,
          color: AppTheme.white70,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CANDLESTICK CHART (Core)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCandlestickChart() {
    final candles = _cachedCandles ?? [];

    // Setup trend line styles (SMA 50 is blue, SMA 200 is red)
    final trendStyles = <Paint>[];
    if (_showSma50) {
      trendStyles.add(Paint()
        ..color = AppTheme.infoStrong
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke);
    }
    if (_showSma200) {
      trendStyles.add(Paint()
        ..color = AppTheme.negativeStrong
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke);
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          InteractiveChart(
            candles: candles,
            initialVisibleCandleCount:
                candles.length < 50 ? candles.length : 50,
            style: ChartStyle(
              volumeHeightFactor: 0.2, // volume area is 20% of total height
              priceLabelWidth: 48.0, // Breathing room for price scale
              timeLabelHeight: 32.0, // Breathing room for dates
              priceGainColor: AppTheme.positive,
              priceLossColor: AppTheme.negative,
              volumeColor: AppTheme.white.withValues(alpha: 0.15),
              trendLineStyles: trendStyles,
              timeLabelStyle:
                  GoogleFonts.lora(fontSize: 10, color: AppTheme.textTertiary),
              priceLabelStyle:
                  GoogleFonts.lora(fontSize: 10, color: AppTheme.textTertiary),
              overlayTextStyle:
                  GoogleFonts.lora(fontSize: 11, color: AppTheme.white),
              priceGridLineColor: AppTheme.white.withValues(alpha: 0.05),
              overlayBackgroundColor:
                  AppTheme.bgSecondary.withValues(alpha: 0.95),
              selectionHighlightColor: AppTheme.white.withValues(alpha: 0.05),
            ),
            priceLabel: (price) => '\$${price.toStringAsFixed(2)}',
            onTap: (candle) {
              HapticFeedback.selectionClick();
            },
            overlayInfo: (candle) {
              final date = DateFormat('dd MMM yyyy HH:mm').format(
                  DateTime.fromMillisecondsSinceEpoch(candle.timestamp));
              final info = <String, String>{
                "Date": date,
                "Open": "\$${candle.open?.toStringAsFixed(2) ?? "-"}",
                "High": "\$${candle.high?.toStringAsFixed(2) ?? "-"}",
                "Low": "\$${candle.low?.toStringAsFixed(2) ?? "-"}",
                "Close": "\$${candle.close?.toStringAsFixed(2) ?? "-"}",
                "Volume": candle.volume?.toStringAsFixed(0) ?? "-",
              };

              int trendIdx = 0;
              if (_showSma50) {
                final v = candle.trends.length > trendIdx
                    ? candle.trends[trendIdx]
                    : null;
                final label =
                    _overlays != null ? "MA${_overlays!.fastPeriod}" : "MA50";
                info[label] = v != null ? "\$${v.toStringAsFixed(2)}" : "-";
                trendIdx++;
              }
              if (_showSma200) {
                final v = candle.trends.length > trendIdx
                    ? candle.trends[trendIdx]
                    : null;
                final label =
                    _overlays != null ? "MA${_overlays!.slowPeriod}" : "MA200";
                info[label] = v != null ? "\$${v.toStringAsFixed(2)}" : "-";
              }

              return info;
            },
            timeLabel: (timestamp, visibleDataCount) {
              final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
              return DateFormat('dd MMM').format(date);
            },
          ),
          // We overlay custom UI elements over the chart area if needed...
        ],
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UNIFIED TOOLBAR & INDICATORS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildToolbarAndIndicators() {
    final hasData = _overlays != null && !_overlays!.isEmpty;
    final crossCount = _overlays?.crossEvents.length ?? 0;
    final latestHist = _overlays?.latestMacdHist;
    final fastStr = hasData ? "MA${_overlays!.fastPeriod}" : "MA50";
    final slowStr = hasData ? "MA${_overlays!.slowPeriod}" : "MA200";

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // MA 50 Toggle
          _toolbarAction(
            fastStr,
            _showSma50,
            AppTheme.infoStrong,
            () => setState(() => _showSma50 = !_showSma50),
          ),
          const SizedBox(width: 6),
          // MA 200 Toggle
          _toolbarAction(
            slowStr,
            _showSma200,
            AppTheme.negativeStrong,
            () => setState(() => _showSma200 = !_showSma200),
          ),
          const SizedBox(width: 6),
          // CROSSES Toggle
          _overlayChip(
            'CROSSES${crossCount > 0 ? ' ($crossCount)' : ''}',
            _showCrosses,
            AppTheme.gold,
            hasData && crossCount > 0,
            () => setState(() => _showCrosses = !_showCrosses),
          ),
          const SizedBox(width: 6),
          // MACD Badge
          if (latestHist != null)
            _statusBadge(
              'MACD ${latestHist > 0 ? "+" : ""}${latestHist.toStringAsFixed(2)}',
              latestHist > 0 ? AppTheme.positive : AppTheme.negative,
            ),
          const SizedBox(width: 6),
          // OBV Badge
          if (hasData)
            _statusBadge(
              'OBV ${_overlays!.isObvBullish ? "BULL" : "BEAR"}',
              _overlays!.isObvBullish ? AppTheme.positive : AppTheme.negative,
            ),
          const SizedBox(width: 6),
          // Cross Event Markers
          if (_showCrosses && _overlays != null)
            ..._overlays!.crossEvents.map((event) {
              final isGolden = event.isGolden;
              final isStrong = event.isStrong;
              final c = isGolden ? AppTheme.positive : AppTheme.negative;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _showCrossDetail(event),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: isStrong ? 0.2 : 0.1),
                      border: Border.all(
                          color: c.withValues(alpha: 0.5),
                          width: isStrong ? 1.5 : 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isGolden
                              ? Icons.arrow_circle_up
                              : Icons.arrow_circle_down,
                          size: 10,
                          color: c,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isGolden
                              ? (isStrong ? 'GC+' : 'GC')
                              : (isStrong ? 'DC+' : 'DC'),
                          style: GoogleFonts.lora(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: c),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
        ],
      ),
    );
  }

  Widget _toolbarAction(
      String label, bool active, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : AppTheme.transparent,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.6) : AppTheme.white24,
            width: active ? 1 : 0.5,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label,
            style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: active ? color : AppTheme.textTertiary)),
      ),
    );
  }

  void _showCrossDetail(CrossEvent event) {
    final isGolden = event.isGolden;
    final color = isGolden ? AppTheme.positive : AppTheme.negative;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGolden ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  isGolden ? 'GOLDEN CROSS' : 'DEATH CROSS',
                  style: _mono(14, c: color, w: FontWeight.w900, ls: 1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    event.isStrong ? 'FORT' : 'FAIBLE',
                    style: _mono(8, c: color, w: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Prix au croisement: \$${event.price.toStringAsFixed(2)}',
                style: _mono(12, c: AppTheme.white)),
            const SizedBox(height: 12),
            _confirmationRow('MACD Histogram', event.macdConfirmed),
            const SizedBox(height: 8),
            _confirmationRow('OBV > SMA(21)', event.obvConfirmed),
            const SizedBox(height: 16),
            Text(
              isGolden
                  ? 'Le SMA 50 croise au-dessus du SMA 200 — signal haussier macro.'
                  : 'Le SMA 50 croise en dessous du SMA 200 — signal baissier macro.',
              style: GoogleFonts.lora(
                  fontSize: 12, color: AppTheme.white60, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _confirmationRow(String label, bool confirmed) {
    return Row(
      children: [
        Icon(
          confirmed ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: confirmed ? AppTheme.positive : AppTheme.negative,
        ),
        const SizedBox(width: 8),
        Text(label, style: _mono(10, c: AppTheme.white70)),
        const Spacer(),
        Text(
          confirmed ? 'CONFIRMÉ' : 'NON CONFIRMÉ',
          style: _mono(8,
              c: confirmed ? AppTheme.positive : AppTheme.negative,
              w: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _overlayChip(String label, bool active, Color color, bool enabled,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : AppTheme.transparent,
          border: Border.all(
            color: active ? color.withValues(alpha: 0.6) : AppTheme.white10,
            width: active ? 1 : 0.5,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: GoogleFonts.lora(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: enabled
                ? (active ? color : AppTheme.textTertiary)
                : AppTheme.textTertiary.withValues(alpha: 0.3),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.white10, width: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.lora(
                  fontSize: 8, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RANGE SELECTOR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRangeSelector(SigmaProvider provider) {
    final ranges = ['1D', '5D', '1M', '6M', '1Y', '5Y', 'MAX'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ranges.map((r) {
          final isSelected = provider.chartRange == r;
          return GestureDetector(
            onTap: () {
              if (provider.isChartLoading) return;
              provider.fetchChartData(r);
              setState(() {
                _overlays = null;
                _cachedDataRef = null;
                _cachedCandles = null;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.gold : AppTheme.transparent,
                borderRadius: BorderRadius.circular(4),
                border: isSelected ? null : Border.all(color: AppTheme.white10),
              ),
              child: Text(
                r,
                style: GoogleFonts.lora(
                  color: isSelected ? AppTheme.black : AppTheme.textTertiary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 9,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RANGE ANALYSIS REPORT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRangeAnalysis(SigmaProvider provider) {
    if (widget.isFullscreen) return const SizedBox.shrink();
    final analysisText =
        provider.getCachedRangeAnalysis(widget.ticker, provider.chartRange);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.03),
        border:
            const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_search,
                  size: 12, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('ANALYSE DU GRAPHIQUE (${provider.chartRange})',
                  style: GoogleFonts.lora(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          if (analysisText != null && analysisText.isNotEmpty)
            Text(analysisText.replaceAll('[AGENTIC OLLAMA]', '').trim(),
                style: GoogleFonts.lora(
                    fontSize: 11, color: AppTheme.white70, height: 1.5))
          else if (provider.isChartLoading)
            Row(children: [
              const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary)),
              const SizedBox(width: 8),
              Text('Analyse des prix en cours...',
                  style: GoogleFonts.lora(
                      fontSize: 11, color: AppTheme.textTertiary)),
            ])
          else
            Row(children: [
              const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary)),
              const SizedBox(width: 8),
              Text('Génération de l\'analyse IA en cours (patientez)...',
                  style: GoogleFonts.lora(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                      fontStyle: FontStyle.italic)),
            ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return const Center(
        child: CircularProgressIndicator(strokeWidth: 1, color: AppTheme.gold));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.candlestick_chart,
              color: AppTheme.textTertiary.withValues(alpha: 0.5), size: 40),
          const SizedBox(height: 8),
          Text('PAS ASSEZ DE DONNÉES (MIN 3)',
              style: _mono(10, c: AppTheme.textTertiary)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context
                .read<SigmaProvider>()
                .fetchChartData(context.read<SigmaProvider>().chartRange),
            child: Text('RETRY',
                style: _mono(9, c: AppTheme.gold, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Typography helpers ──
  TextStyle _mono(double s, {Color? c, FontWeight? w, double? ls, double? h}) =>
      GoogleFonts.lora(
          fontSize: s, color: c, fontWeight: w, letterSpacing: ls, height: h);
}
