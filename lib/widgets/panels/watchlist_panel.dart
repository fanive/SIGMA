// ignore_for_file: unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../terminal/research_panel.dart';
import '../institutional/institutional_components.dart';
import '../../utils/sigma_localization.dart';

class WatchlistPanel extends StatelessWidget {
  const WatchlistPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return ResearchPanelContainer(
      title: 'Convictions',
      icon: Icons.bookmark_added_rounded,
      child: Consumer<SigmaProvider>(
        builder: (context, sp, _) {
          final tickers = sp.favoriteTickers;
          final quotes = sp.favoriteQuotes;
          final loading = sp.isWatchlistLoading;

          if (tickers.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: () => sp.loadFavorites(),
            color: AppTheme.primary,
            backgroundColor: isDark ? AppTheme.bgSecondary : AppTheme.white,
            child: Column(
              children: [
                // Loading indicator bar
                if (loading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: AppTheme.transparent,
                    color: AppTheme.primary.withValues(alpha: 0.7),
                  ),
                _buildHeaderRow(context, isDark),
                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: tickers.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark
                          ? AppTheme.white.withValues(alpha: 0.05)
                          : AppTheme.black.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (ctx, i) {
                      final ticker = tickers[i].toUpperCase();
                      final data = quotes[ticker];

                      final price =
                          _dbl(data?['price'] ?? data?['regularMarketPrice']);
                      final change = _dbl(data?['changePercent'] ??
                          data?['regularMarketChangePercent']);

                      return _WatchlistTileFlat(
                        ticker: ticker,
                        price: price,
                        change: change,
                        isLoading: loading && data == null,
                        isDark: isDark,
                        data: data,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.read<TerminalProvider>().openAnalysis(ticker);
                          sp.analyzeTicker(ticker);
                        },
                        onDelete: () =>
                            _showDeleteConfirmation(context, ticker, sp),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isDark) {
    final txtStyle = GoogleFonts.lora(
      color: isDark ? AppTheme.white24 : AppTheme.black26,
      fontSize: 8,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isDark
                    ? AppTheme.white.withValues(alpha: 0.05)
                    : AppTheme.black.withValues(alpha: 0.05),
                width: 0.5)),
      ),
      child: Row(
        children: [
          Text(context.t('symbol').toUpperCase(), style: txtStyle),
          const Spacer(),
          Text('DATA', style: txtStyle),
          const SizedBox(width: 48),
          Text(context.t('price').toUpperCase(), style: txtStyle),
          const SizedBox(width: 48),
          Text(context.t('change').toUpperCase(), style: txtStyle),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, String ticker, SigmaProvider sp) {
    final isDark = AppTheme.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.bgSecondary : AppTheme.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('REMOVE $ticker?'.toUpperCase(),
                style: GoogleFonts.lora(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0)),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd)),
                        side: BorderSide(
                            color:
                                isDark ? AppTheme.white12 : AppTheme.black12)),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      sp.toggleFavorite(ticker);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.negative,
                        foregroundColor: AppTheme.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd))),
                    child: const Text('REMOVE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const InstitutionalEmptyState(
      icon: Icons.bookmark_add_outlined,
      title: 'Aucune conviction suivie',
      message:
          'Ajoutez des sociétés depuis la recherche pour construire votre univers d’investissement et lancer les analyses prioritaires.',
    );
  }

  double _dbl(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _WatchlistTileFlat extends StatelessWidget {
  final String ticker;
  final double price;
  final double change;
  final bool isDark;
  final bool isLoading;
  final Map<String, dynamic>? data;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WatchlistTileFlat({
    required this.ticker,
    required this.price,
    required this.change,
    required this.isDark,
    this.isLoading = false,
    this.data,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? AppTheme.white38 : AppTheme.black38;
    final color = change >= 0 ? AppTheme.positive : AppTheme.negative;

    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
              bottom:
                  BorderSide(color: AppTheme.getBorder(context), width: 0.5)),
        ),
        child: Row(
          children: [
            // Square Logo Container (Bloomberg Style)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.nearBlack0C
                    : AppTheme.black.withValues(alpha: 0.02),
                border:
                    Border.all(color: AppTheme.getBorder(context), width: 0.5),
              ),
              child: ClipRRect(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.network(
                    'https://financialmodelingprep.com/image-stock/${ticker.toUpperCase()}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        ticker.substring(0, 1),
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppTheme.white10 : AppTheme.black12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        ticker,
                        style: GoogleFonts.lora(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppTheme.white : AppTheme.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (data?['marketState'] != null)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data!['marketState'] == 'REGULAR'
                                ? AppTheme.positive
                                : AppTheme.amberAccent,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    (data?['longName'] ??
                            data?['shortName'] ??
                            data?['longname'] ??
                            data?['shortname'] ??
                            'EQUITY')
                        .toString()
                        .toUpperCase(),
                    style: GoogleFonts.lora(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: dim,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price > 0 ? '\$${price.toStringAsFixed(2)}' : '—',
                  style: GoogleFonts.lora(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppTheme.white : AppTheme.black,
                  ),
                ),
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                  style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.close, size: 12),
              onPressed: onDelete,
              color: isDark
                  ? AppTheme.white.withValues(alpha: 0.15)
                  : AppTheme.black.withValues(alpha: 0.15),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
