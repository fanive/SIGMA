// ignore_for_file: avoid_print
import 'dart:developer' as dev;
import '../models/sigma_models.dart';
import 'sigma_api_service.dart';

/// OpenInsiderService — thin compatibility wrapper around SigmaApiService.
/// All insider data now comes from https://sigma-yfinance-api.onrender.com/insider/{symbol}
/// No direct HTTP scraping of openinsider.com from the client.
class OpenInsiderService {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. PER-TICKER — Insider transactions + analytics
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns full insider data for [symbol]: trades, ratios, cluster signals.
  /// Structure mirrors the original return shape so all call-sites stay intact.
  Future<Map<String, dynamic>> getTickerInsiderData(String symbol,
      {int months = 6}) async {
    final data = await SigmaApiService.getInsider(symbol);

    final rawTrades = (data['trades'] as List?) ?? [];
    final trades = rawTrades
        .map((t) => GlobalInsiderTrade.fromJson(Map<String, dynamic>.from(t)))
        .toList();

    final buys = trades.where((t) => t.type == 'buy').toList();
    final sells = trades.where((t) => t.type == 'sell').toList();
    final total = buys.length + sells.length;
    final buyRatio = total > 0 ? buys.length / total : 0.0;

    final buyValue = buys.fold<double>(0.0, (s, t) => s + t.value);
    final sellValue = sells.fold<double>(0.0, (s, t) => s + t.value);

    final transactions = trades
        .map((t) => InsiderTransaction(
              name: t.name,
              share: t.shares.toString(),
              change: t.type == 'buy' ? 'Purchase' : 'Sale',
              filingDate: '',
              transactionDate: t.date,
              transactionPrice: t.price.toString(),
            ))
        .toList();

    dev.log(
        'OpenInsiderService: ${trades.length} trades for $symbol '
        '(backend)',
        name: 'OpenInsiderService');

    return {
      'trades': trades,
      'transactions': transactions,
      'insiderBuyRatio': buyRatio,
      'netInsiderValue': buyValue - sellValue,
      'totalBuyValue': buyValue,
      'totalSellValue': sellValue,
      'buyCount': buys.length,
      'sellCount': sells.length,
      'csuiteTrades': trades.where((t) => t.csuite).toList(),
      // Pass through backend summary fields when present
      'summary': data['summary'],
    };
  }

  /// Drop-in: only InsiderTransaction list.
  Future<List<InsiderTransaction>> getInsiderTransactions(String symbol) async {
    final data = await getTickerInsiderData(symbol);
    return (data['transactions'] as List?)?.cast<InsiderTransaction>() ?? [];
  }

  /// Insider buy ratio (0.0 – 1.0).
  Future<double> getInsiderBuyRatio(String symbol) async {
    final data = await getTickerInsiderData(symbol);
    return data['insiderBuyRatio'] as double? ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. BULK MARKET-WIDE (not available via backend — return empty)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<GlobalInsiderTrade>> getLatestTrades({
    int days = 90,
    int limit = 200,
  }) async {
    // Bulk market-wide feed not available on the backend.
    // Return empty to avoid scraping from the mobile client.
    dev.log('getLatestTrades: not available via backend', name: 'OpenInsiderService');
    return [];
  }

  Future<List<Map<String, dynamic>>> getClusterBuys({int days = 14}) async {
    // Cluster buy analysis requires bulk feed — not available.
    return [];
  }
}
