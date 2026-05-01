import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/sigma_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MARKET TICKER BAR â€” Scrolling price band (like CNBC/Bloomberg TV)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class MarketTickerBar extends StatefulWidget {
  const MarketTickerBar({super.key});

  @override
  State<MarketTickerBar> createState() => _MarketTickerBarState();
}

class _MarketTickerBarState extends State<MarketTickerBar>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  Timer? _scrollTimer;
  Timer? _refreshTimer;

  // Default indices to show
  static const List<String> _defaultSymbols = [
    '^GSPC', // S&P 500
    '^DJI', // Dow Jones
    '^IXIC', // NASDAQ
    '^FCHI', // CAC 40
    '^GDAXI', // DAX
    '^FTSE', // FTSE 100
    '^N225', // Nikkei
    'GC=F', // Gold
    'CL=F', // Oil (WTI)
    'BTC-USD', // Bitcoin
    'ETH-USD', // Ethereum
    'EURUSD=X', // EUR/USD
  ];

  static const Map<String, String> _symbolNames = {
    '^GSPC': 'S&P 500',
    '^DJI': 'DOW',
    '^IXIC': 'NASDAQ',
    '^FCHI': 'CAC 40',
    '^GDAXI': 'DAX',
    '^FTSE': 'FTSE',
    '^N225': 'NIKKEI',
    'GC=F': 'OR',
    'CL=F': 'PÃ‰TROLE',
    'BTC-USD': 'BTC',
    'ETH-USD': 'ETH',
    'EURUSD=X': 'EUR/USD',
  };

  Map<String, Map<String, dynamic>> _tickerData = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadData();
    // Auto-scroll horizontally
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        final current = _scrollController.offset;
        if (current >= max) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(current + 0.5);
        }
      }
    });
    // Refresh data every 30s
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final sp = context.read<SigmaProvider>();
      final overview = sp.marketOverview;
      if (overview != null && overview.yahooSummary != null) {
        final indices = overview.yahooSummary!;
        final Map<String, Map<String, dynamic>> data = {};
        for (final idx in indices) {
          data[idx.symbol] = {
            'price': idx.price.toDouble(),
            'change': idx.change.toDouble(),
            'changePercent': idx.changePercent.toDouble(),
          };
        }
        if (mounted && data.isNotEmpty) {
          setState(() => _tickerData = data);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: AppTheme.tickerBarHeight,
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.background.withValues(alpha: 0.95)
            : AppTheme.lightSurfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.border : AppTheme.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        // Repeat the list 3x for infinite scroll illusion
        itemCount: _defaultSymbols.length * 3,
        itemBuilder: (context, index) {
          final symbol = _defaultSymbols[index % _defaultSymbols.length];
          final data = _tickerData[symbol];
          final name = _symbolNames[symbol] ?? symbol;
          final price = data?['price'] ?? 0.0;
          final changePct = data?['changePercent'] ?? 0.0;
          final isUp = changePct >= 0;

          return _buildTickerItem(name, price, changePct, isUp, isDark);
        },
      ),
    );
  }

  Widget _buildTickerItem(
    String name,
    double price,
    double changePct,
    bool isUp,
    bool isDark,
  ) {
    final color = isUp ? AppTheme.positive : AppTheme.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: AppTheme.label(context).copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            price > 0 ? price.toStringAsFixed(price > 100 ? 0 : 2) : 'â€”',
            style: AppTheme.numeric(context, size: 10, weight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.expand_less : Icons.expand_more,
                  color: color,
                  size: 12,
                ),
                Text(
                  '${changePct.abs().toStringAsFixed(2)}%',
                  style: AppTheme.numeric(context, color: color, size: 9, weight: FontWeight.w900),
                ),
              ],
            ),
          ),
          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 1,
              height: 12,
              color: isDark
                  ? AppTheme.border.withValues(alpha: 0.5)
                  : AppTheme.lightBorder.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

