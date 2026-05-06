// ignore_for_file: unnecessary_brace_in_string_interps
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../institutional/institutional_components.dart';

class WatchlistPanel extends StatelessWidget {
  const WatchlistPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      color: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
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
                      final rawData = quotes[ticker];
                      final data = rawData == null
                          ? null
                          : Map<String, dynamic>.from(rawData);

                      final price =
                          _dbl(data?['price'] ?? data?['regularMarketPrice']);
                      final change = _dbl(data?['changePercent'] ??
                          data?['regularMarketChangePercent']);

                      return _WatchlistTableRow(
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
                        onSwipeDelete: () => sp.toggleFavorite(ticker),
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
      color: isDark ? AppTheme.white38 : AppTheme.black38,
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.nearBlack0C : AppTheme.lightSurface,
        border: Border(
            bottom: BorderSide(
                color: isDark ? AppTheme.white12 : AppTheme.black12,
                width: 1.0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40), // Alignment for logo
          Expanded(flex: 3, child: Text('SYMBOL', style: txtStyle)),
          Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: Text('MKT CAP', style: txtStyle))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('PRICE', style: txtStyle))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('CHG %', style: txtStyle))),
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
        title: 'Aucune valeur suivie',
      message:
          'Ajoutez des societes depuis la recherche pour construire votre liste de suivi et lancer les analyses prioritaires.',
    );
  }

  double _dbl(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _WatchlistTableRow extends StatelessWidget {
  final String ticker;
  final double price;
  final double change;
  final bool isDark;
  final bool isLoading;
  final Map<String, dynamic>? data;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onSwipeDelete;

  const _WatchlistTableRow({
    required this.ticker,
    required this.price,
    required this.change,
    required this.isDark,
    this.isLoading = false,
    this.data,
    required this.onTap,
    required this.onDelete,
    required this.onSwipeDelete,
  });

  String _formatMarketCap(dynamic val) {
    double num = 0;
    if (val is double) num = val;
    else if (val is int) num = val.toDouble();
    else num = double.tryParse(val.toString()) ?? 0;
    
    if (num == 0) return '—';
    if (num >= 1e12) return '${(num / 1e12).toStringAsFixed(2)}T';
    if (num >= 1e9) return '${(num / 1e9).toStringAsFixed(2)}B';
    if (num >= 1e6) return '${(num / 1e6).toStringAsFixed(2)}M';
    return num.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? AppTheme.white38 : AppTheme.black38;
    final color = change >= 0 ? AppTheme.positive : AppTheme.negative;
    final name = (data?['companyName'] ?? data?['name'] ?? 'EQUITY').toString().toUpperCase();
    final mktCap = data?['marketCap'];
    final mktCapStr = mktCap != null ? _formatMarketCap(mktCap) : '—';

    return Dismissible(
      key: Key('watchlist_$ticker'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onSwipeDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        color: AppTheme.negative.withValues(alpha: 0.8),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: isDark ? AppTheme.white.withValues(alpha: 0.03) : AppTheme.black.withValues(alpha: 0.03),
                  width: 1.0)),
        ),
        child: Row(
          children: [
            // LOGO
            TickerLogoThumb(
              symbol: ticker,
              logoUrl: data?['image'] ?? data?['logo'],
              size: 28,
            ),
            const SizedBox(width: 12),
            // SYMBOL & NAME
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ticker,
                    style: GoogleFonts.lora(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.white : AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: GoogleFonts.lora(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: dim,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // MARKET CAP
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  mktCapStr,
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: dim,
                  ),
                ),
              ),
            ),
            // PRICE
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  price > 0 ? price.toStringAsFixed(2) : '—',
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.white : AppTheme.black,
                  ),
                ),
              ),
            ),
            // CHG %
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                    style: GoogleFonts.lora(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

