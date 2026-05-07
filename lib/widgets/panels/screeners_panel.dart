import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sigma_models.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import '../../services/sigma_api_service.dart';
import '../../services/sigma_market_data_service.dart';
import '../../theme/app_theme.dart';
import '../terminal/research_panel.dart';

// Gainers / Losers / Most-Active → 1 appel backend each (scraping Yahoo Finance)
// Smart Money / Alerts → sur univers réduit de 12 tickers pour limiter les appels
enum _ScreenerView { gainers, losers, active, smartMoney, alerts }

class ScreenersPanel extends StatefulWidget {
  const ScreenersPanel({super.key});

  @override
  State<ScreenersPanel> createState() => _ScreenersPanelState();
}

class _ScreenersPanelState extends State<ScreenersPanel> {
  final SigmaMarketDataService _service = SigmaMarketDataService();
  _ScreenerView _activeView = _ScreenerView.gainers;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      return switch (_activeView) {
        _ScreenerView.gainers    => await SigmaApiService.getGainers(),
        _ScreenerView.losers     => await SigmaApiService.getLosers(),
        _ScreenerView.active     => await SigmaApiService.getMostActive(),
        _ScreenerView.smartMoney => await _service.screenSmartMoney(limit: 12),
        _ScreenerView.alerts     => await _service.getAnalystRatingAlerts(limit: 15),
      };
    } catch (_) {
      return [];
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
      (_ScreenerView.gainers,    Icons.trending_up_rounded,         'Gainers'),
      (_ScreenerView.losers,     Icons.trending_down_rounded,       'Losers'),
      (_ScreenerView.active,     Icons.local_fire_department_rounded,'Active'),
      (_ScreenerView.smartMoney, Icons.account_balance_rounded,     'Smart'),
      (_ScreenerView.alerts,     Icons.notifications_active_rounded,'Alerts'),
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
      case _ScreenerView.gainers:
      case _ScreenerView.losers:
      case _ScreenerView.active:
        return _text(row['name']);
      case _ScreenerView.smartMoney:
        final holder = _text(row['topHolder']);
        return holder.isEmpty ? 'Institutional flow' : holder;
      case _ScreenerView.alerts:
        final firm = _text(row['firm']);
        return firm.isEmpty ? 'Consensus' : firm;
    }
  }

  String _rowSubtitle(Map<String, dynamic> row) {
    switch (_activeView) {
      case _ScreenerView.gainers:
      case _ScreenerView.losers:
      case _ScreenerView.active:
        final price = AnalysisData.parseNum(row['price']);
        final pct = AnalysisData.parseNum(row['changesPercentage']);
        final priceStr = price > 0 ? '\$${price.toStringAsFixed(2)}' : '';
        final sign = pct >= 0 ? '+' : '';
        return '${priceStr.isNotEmpty ? '$priceStr  ' : ''}$sign${pct.toStringAsFixed(2)}%';
      case _ScreenerView.smartMoney:
        final inst = _number(row['institutionalHoldersCount']);
        final funds = _number(row['fundHoldersCount']);
        final ratio = _pctRatio(row['insiderBuyRatio']);
        return 'Inst $inst · Fonds $funds · Insiders $ratio achat';
      case _ScreenerView.alerts:
        final from = _text(row['fromGrade']);
        final to = _text(row['toGrade']);
        final action = _text(row['action']);
        final grade = from.isNotEmpty && to.isNotEmpty ? '$from → $to' : to;
        return '${action.isNotEmpty ? '$action · ' : ''}$grade';
    }
  }

  String _rowMetric(Map<String, dynamic> row) {
    switch (_activeView) {
      case _ScreenerView.gainers:
      case _ScreenerView.losers:
      case _ScreenerView.active:
        return _pct(row['changesPercentage']);
      case _ScreenerView.smartMoney:
        return _number(row['score']);
      case _ScreenerView.alerts:
        final target = AnalysisData.parseNum(row['targetPrice']);
        return target > 0 ? _money(target) : _text(row['toGrade']).toUpperCase();
    }
  }

  Color _rowAccent(Map<String, dynamic> row) {
    switch (_activeView) {
      case _ScreenerView.gainers:
        return AppTheme.greenAccent;
      case _ScreenerView.losers:
        return AppTheme.redAccent;
      case _ScreenerView.active:
        final pct = AnalysisData.parseNum(row['changesPercentage']);
        return pct >= 0 ? AppTheme.greenAccent : AppTheme.redAccent;
      case _ScreenerView.smartMoney:
        final score = AnalysisData.parseNum(row['score']);
        if (score >= 70) return AppTheme.greenAccent;
        if (score < 40) return AppTheme.redAccent;
        return AppTheme.primary;
      case _ScreenerView.alerts:
        return AppTheme.primary;
    }
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
}
