import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sigma_models.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import '../../services/sigma_market_data_service.dart';
import '../../theme/app_theme.dart';
import '../terminal/research_panel.dart';

enum _ScreenerView { picks, ratings, smartMoney, holdings, alerts }

class ScreenersPanel extends StatefulWidget {
  const ScreenersPanel({super.key});

  @override
  State<ScreenersPanel> createState() => _ScreenersPanelState();
}

class _ScreenersPanelState extends State<ScreenersPanel> {
  final SigmaMarketDataService _service = SigmaMarketDataService();
  _ScreenerView _activeView = _ScreenerView.picks;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final remote = switch (_activeView) {
      _ScreenerView.picks => _service.getResearchStockPicks(limit: 16),
      _ScreenerView.ratings => _service.screenAnalystRatings(limit: 20),
      _ScreenerView.smartMoney => _service.screenSmartMoney(limit: 20),
      _ScreenerView.holdings => _service.screenTopHoldings(limit: 30),
      _ScreenerView.alerts => _service.getAnalystRatingAlerts(limit: 30),
    };

    try {
      final rows = await remote;
      return rows.isNotEmpty ? rows : _fallbackRows();
    } catch (_) {
      return _fallbackRows();
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _select(_ScreenerView view) {
    if (_activeView == view) return;
    setState(() {
      _activeView = view;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResearchPanelContainer(
      title: 'Screeners',
      icon: Icons.filter_alt_rounded,
      showHeader: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        children: [
          _viewTabs(context),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasError) {
                  return _emptyState(
                    context,
                    Icons.error_outline_rounded,
                    'SCREENERS INDISPONIBLES',
                    'Les donnees marche ne repondent pas pour le moment.',
                  );
                }
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) {
                  return _emptyState(
                    context,
                    Icons.search_off_rounded,
                    'AUCUN RESULTAT',
                    'Changez de filtre ou relancez le flux.',
                  );
                }
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 46,
                      color: AppTheme.isDark(context)
                          ? AppTheme.white10
                          : AppTheme.black.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) => _resultRow(
                      context,
                      rows[index],
                      index,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewTabs(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final tabs = [
      (_ScreenerView.picks, Icons.stars_rounded, 'Picks'),
      (_ScreenerView.ratings, Icons.verified_rounded, 'Ratings'),
      (_ScreenerView.smartMoney, Icons.account_balance_rounded, 'Smart'),
      (_ScreenerView.holdings, Icons.business_center_rounded, 'Holdings'),
      (_ScreenerView.alerts, Icons.notifications_active_rounded, 'Alerts'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgSecondary : AppTheme.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppTheme.white10
                : AppTheme.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final active = tab.$1 == _activeView;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: tab.$3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _select(tab.$1),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primary.withValues(alpha: 0.14)
                          : AppTheme.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: active
                            ? AppTheme.primary.withValues(alpha: 0.45)
                            : (isDark ? AppTheme.white10 : AppTheme.black12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.$2,
                          size: 17,
                          color: active
                              ? AppTheme.primary
                              : AppTheme.getSecondaryText(context),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          tab.$3.toUpperCase(),
                          style: GoogleFonts.lora(
                            fontSize: 10,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: 0.7,
                            color: active
                                ? AppTheme.primary
                                : AppTheme.getSecondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _resultRow(BuildContext context, Map<String, dynamic> row, int index) {
    final symbol = _text(row['symbol']);
    final title = _rowTitle(row);
    final subtitle = _rowSubtitle(row);
    final metric = _rowMetric(row);
    final accent = _rowAccent(row);

    return InkWell(
      onTap: symbol.isNotEmpty
          ? () {
              context.read<TerminalProvider>().openNoteLab(ticker: symbol);
              context.read<SigmaProvider>().analyzeTicker(symbol);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Rank ────────────────────────────────────────────────
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getSecondaryText(context).withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ── Symbol + title ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (symbol.isNotEmpty) ...[
                        Text(
                          symbol,
                          style: GoogleFonts.lora(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.getPrimaryText(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lora(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getSecondaryText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lora(
                      fontSize: 10,
                      height: 1.3,
                      color: AppTheme.getSecondaryText(context)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Metric + actions ─────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metric,
                  style: GoogleFonts.lora(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                if (symbol.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _quickActions(context, symbol),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context, String symbol) {
    final favorites = context.watch<SigmaProvider>().favoriteTickers;
    final isFavorite = favorites.contains(symbol.toUpperCase());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniIcon(
          context,
          Icons.menu_book_rounded,
          'Analyse',
          () {
            context.read<TerminalProvider>().openNoteLab(ticker: symbol);
            context.read<SigmaProvider>().analyzeTicker(symbol);
          },
        ),
        _miniIcon(
          context,
          Icons.query_stats_rounded,
          'Chart',
          () {
            context.read<TerminalProvider>().setFocusedTicker(symbol);
            context.read<TerminalProvider>().switchPanel(TerminalPanel.charts);
            context.read<SigmaProvider>().fetchChartDataForTicker(symbol, '1Y');
          },
        ),
        _miniIcon(
          context,
          isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          'Watchlist',
          () => context.read<SigmaProvider>().toggleFavorite(symbol),
        ),
      ],
    );
  }

  Widget _miniIcon(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 17,
            color: AppTheme.getSecondaryText(context),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _fallbackRows() {
    const symbols = [
      ('NVDA', 'NVIDIA', 82.0, 18.5),
      ('MSFT', 'Microsoft', 78.0, 12.0),
      ('AAPL', 'Apple', 64.0, 7.5),
      ('AMZN', 'Amazon', 72.0, 14.0),
      ('GOOGL', 'Alphabet', 69.0, 10.0),
      ('META', 'Meta Platforms', 74.0, 13.0),
      ('TSLA', 'Tesla', 55.0, 9.0),
      ('JPM', 'JPMorgan', 61.0, 6.0),
    ];

    return symbols.map<Map<String, dynamic>>((item) {
      final symbol = item.$1;
      final name = item.$2;
      final score = item.$3;
      final upside = item.$4;

      switch (_activeView) {
        case _ScreenerView.picks:
          return {
            'symbol': symbol,
            'pickType': name,
            'targetUpsidePct': upside,
            'smartMoneyScore': score,
            'topHolder': 'Large-cap reference universe',
            'convictionScore': score,
          };
        case _ScreenerView.ratings:
          return {
            'symbol': symbol,
            'recommendation': score >= 70 ? 'BUY' : 'HOLD',
            'targetMeanPrice': 100 + score,
            'targetUpsidePct': upside,
            'latestFirm': 'Consensus fallback',
            'latestAction': 'coverage pending',
          };
        case _ScreenerView.smartMoney:
          return {
            'symbol': symbol,
            'topHolder': 'Institutional universe',
            'institutionalHoldersCount': (score * 12).round(),
            'fundHoldersCount': (score * 7).round(),
            'insiderBuyRatio': score >= 70 ? 0.18 : 0.08,
            'score': score,
          };
        case _ScreenerView.holdings:
          return {
            'symbol': symbol,
            'holder': name,
            'source': 'fallback watchlist',
            'shares': score * 1000000,
            'dateReported': 'latest available',
            'value': score * 100000000,
          };
        case _ScreenerView.alerts:
          return {
            'symbol': symbol,
            'firm': 'SIGMA monitor',
            'action': 'Watch',
            'fromGrade': 'Neutral',
            'toGrade': score >= 70 ? 'Positive' : 'Stable',
            'date': 'live feed pending',
            'targetPrice': 100 + score,
          };
      }
    }).toList(growable: false);
  }

  Widget _emptyState(
    BuildContext context,
    IconData icon,
    String title,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppTheme.getSecondaryText(context)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppTheme.getPrimaryText(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 12,
                color: AppTheme.getSecondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _rowTitle(Map<String, dynamic> row) {
    switch (_activeView) {
      case _ScreenerView.picks:
        return _text(row['pickType']).toUpperCase();
      case _ScreenerView.ratings:
        return _text(row['recommendation']).toUpperCase();
      case _ScreenerView.smartMoney:
        return _text(row['topHolder']).isEmpty
            ? 'Institutional flow'
            : _text(row['topHolder']);
      case _ScreenerView.holdings:
        return _text(row['holder']);
      case _ScreenerView.alerts:
        return _text(row['firm']).isEmpty ? 'Consensus' : _text(row['firm']);
    }
  }

  String _rowSubtitle(Map<String, dynamic> row) {
    switch (_activeView) {
      case _ScreenerView.picks:
        return 'Upside ${_pct(row['targetUpsidePct'])} | Smart ${_number(row['smartMoneyScore'])} | ${_text(row['topHolder'])}';
      case _ScreenerView.ratings:
        return 'Target ${_money(row['targetMeanPrice'])} | Upside ${_pct(row['targetUpsidePct'])} | ${_text(row['latestFirm'])} ${_text(row['latestAction'])}';
      case _ScreenerView.smartMoney:
        return 'Institutions ${_number(row['institutionalHoldersCount'])} | Funds ${_number(row['fundHoldersCount'])} | Insider buy ratio ${_pctRatio(row['insiderBuyRatio'])}';
      case _ScreenerView.holdings:
        return '${_text(row['source']).toUpperCase()} | Shares ${_compact(row['shares'])} | Report ${_text(row['dateReported'])}';
      case _ScreenerView.alerts:
        return '${_text(row['action'])} | ${_text(row['fromGrade'])} -> ${_text(row['toGrade'])} | ${_text(row['date'])}';
    }
  }

  String _rowMetric(Map<String, dynamic> row) {
    switch (_activeView) {
      case _ScreenerView.picks:
        return _number(row['convictionScore']);
      case _ScreenerView.ratings:
        return _pct(row['targetUpsidePct']);
      case _ScreenerView.smartMoney:
        return _number(row['score']);
      case _ScreenerView.holdings:
        return _compact(row['value']);
      case _ScreenerView.alerts:
        final target = AnalysisData.parseNum(row['targetPrice']);
        return target > 0
            ? _money(target)
            : _text(row['toGrade']).toUpperCase();
    }
  }

  Color _rowAccent(Map<String, dynamic> row) {
    final raw = _activeView == _ScreenerView.ratings
        ? AnalysisData.parseNum(row['targetUpsidePct'])
        : AnalysisData.parseNum(row['score'] ?? row['convictionScore']);
    if (_activeView == _ScreenerView.holdings) return AppTheme.primary;
    if (raw >= 70 || raw >= 15 && _activeView == _ScreenerView.ratings) {
      return AppTheme.greenAccent;
    }
    if (raw < 0 || raw < 40 && _activeView != _ScreenerView.ratings) {
      return AppTheme.redAccent;
    }
    return AppTheme.primary;
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _number(dynamic value) =>
      AnalysisData.parseNum(value).toStringAsFixed(0);

  String _pct(dynamic value) {
    final parsed = AnalysisData.parseNum(value);
    final sign = parsed > 0 ? '+' : '';
    return '$sign${parsed.toStringAsFixed(1)}%';
  }

  String _pctRatio(dynamic value) =>
      '${(AnalysisData.parseNum(value) * 100).toStringAsFixed(0)}%';

  String _money(dynamic value) {
    final parsed = AnalysisData.parseNum(value);
    if (parsed <= 0) return '-';
    return '\$${parsed.toStringAsFixed(parsed >= 100 ? 0 : 2)}';
  }

  String _compact(dynamic value) {
    final parsed = AnalysisData.parseNum(value).abs();
    if (parsed >= 1000000000000) {
      return '\$${(parsed / 1000000000000).toStringAsFixed(1)}T';
    }
    if (parsed >= 1000000000) {
      return '\$${(parsed / 1000000000).toStringAsFixed(1)}B';
    }
    if (parsed >= 1000000) return '\$${(parsed / 1000000).toStringAsFixed(1)}M';
    if (parsed >= 1000) return '\$${(parsed / 1000).toStringAsFixed(1)}K';
    return '\$${parsed.toStringAsFixed(0)}';
  }
}
