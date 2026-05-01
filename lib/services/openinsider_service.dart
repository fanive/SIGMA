// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/sigma_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SIGMA OpenInsider Service — Pure Dart, 100% Mobile-First
/// ═══════════════════════════════════════════════════════════════════════════
/// Scrapes SEC Form 4 insider trading data directly from openinsider.com.
/// NO Python backend needed — runs entirely on the user's device.
///
/// Architecture identique à YahooFinanceService :
///   • HTTP GET → Parse HTML → Normalize → Cache → Return models
///
/// Fonctionnalités :
///   • getLatestTrades()         → Bulk market-wide insider trades
///   • getTickerInsiderData()    → Per-ticker insider transactions + analytics
///   • getClusterBuys()          → Cluster buy detection (alpha signal)
///   • getInsiderTransactions()  → Drop-in replacement for Yahoo/FMP methods
///
/// Data normalizes directly to existing SIGMA models:
///   • GlobalInsiderTrade  → MarketOverview.insiderTrades
///   • InsiderTransaction  → AnalysisData.insiderTransactions
/// ═══════════════════════════════════════════════════════════════════════════
class OpenInsiderService {
  // ── OpenInsider Base URL ────────────────────────────────────────────────
  static const String _baseUrl = 'http://openinsider.com';

  // ── In-Memory Cache ─────────────────────────────────────────────────────
  final Map<String, _OICache> _cache = {};
  static const int _bulkTTL = 1800; // 30 minutes for bulk data
  static const int _tickerTTL = 1800; // 30 minutes for per-ticker
  static const int _clusterTTL = 1800; // 30 minutes for cluster buys

  // ── HTTP Headers (browser-like to avoid blocking) ────────────────────────
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  T? _getCache<T>(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) return entry.data as T;
    _cache.remove(key);
    return null;
  }

  void _setCache(String key, dynamic data, int ttlSeconds) {
    _cache[key] =
        _OICache(data, DateTime.now().add(Duration(seconds: ttlSeconds)));
    if (_cache.length > 50) {
      _cache.removeWhere((_, e) => e.isExpired);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HTTP HELPER — avec retry
  // ═══════════════════════════════════════════════════════════════════════════

  Future<http.Response?> _get(Uri url, {int retries = 1}) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await http
            .get(url, headers: _headers)
            .timeout(const Duration(seconds: 30));

        dev.log(
            '📡 OpenInsider HTTP ${response.statusCode} | Length: ${response.body.length} | URL: ${url.toString().split('?')[0]}',
            name: 'OpenInsider');

        if (response.statusCode == 200) return response;
        if (response.statusCode == 429 && attempt < retries) {
          await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
          continue;
        }
        dev.log('⚠️ OpenInsider HTTP ${response.statusCode}: ${url.path}',
            name: 'OpenInsider');
      } catch (e) {
        if (attempt < retries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        dev.log('❌ OpenInsider HTTP Error: $e', name: 'OpenInsider');
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HTML TABLE PARSER — Le cœur du scraping (remplace BeautifulSoup Python)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parse une page OpenInsider et extrait les trades du tableau HTML
  List<GlobalInsiderTrade> _parseOpenInsiderTable(String htmlBody,
      {int maxRows = 100}) {
    try {
      final document = html_parser.parse(htmlBody);

      // Chercher le tableau principal (class="tinytable")
      dom.Element? table = document.querySelector('table.tinytable');

      // Fallback: trouver le plus grand tableau sur la page
      if (table == null) {
        final tables = document.querySelectorAll('table');
        if (tables.isEmpty) return [];
        table = tables.reduce((a, b) =>
            a.querySelectorAll('tr').length >= b.querySelectorAll('tr').length
                ? a
                : b);
      }

      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) return [];

      // ── Parser les en-têtes pour déterminer les indices de colonnes ──
      final headerCells = rows[0].querySelectorAll('th, td');
      final headers =
          headerCells.map((h) => h.text.trim().toLowerCase()).toList();

      final Map<String, int> colMap = {};
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].replaceAll('\u00a0', ' ').trim();
        if (h.contains('filing') && h.contains('date'))
          colMap['filing_date'] = i;
        else if (h.contains('trade') && h.contains('date'))
          colMap['trade_date'] = i;
        else if (h == 'ticker')
          colMap['ticker'] = i;
        else if (h.contains('company') && h.contains('name'))
          colMap['company'] = i;
        else if (h.contains('insider') && h.contains('name'))
          colMap['insider'] = i;
        else if (h == 'title')
          colMap['title'] = i;
        else if (h.contains('trade') && h.contains('type'))
          colMap['trade_type'] = i;
        else if (h == 'price')
          colMap['price'] = i;
        else if (h == 'qty')
          colMap['qty'] = i;
        else if (h == 'owned')
          colMap['owned'] = i;
        else if (h == 'value') colMap['value'] = i;
      }

      // ── Parser chaque ligne ──────────────────────────────────────────
      final List<GlobalInsiderTrade> trades = [];
      final limit = (rows.length - 1).clamp(0, maxRows);

      for (int r = 1; r <= limit; r++) {
        final cells = rows[r].querySelectorAll('td');
        if (cells.length < 8) continue;

        String cellText(String key) {
          final idx = colMap[key];
          if (idx != null && idx < cells.length) return cells[idx].text.trim();
          return '';
        }

        String cellLink(String key) {
          final idx = colMap[key];
          if (idx != null && idx < cells.length) {
            final a = cells[idx].querySelector('a');
            return a?.text.trim() ?? cells[idx].text.trim();
          }
          return '';
        }

        // Extraire le ticker
        final ticker = cellLink('ticker').toUpperCase();
        if (ticker.isEmpty) continue;

        // Extraire les données
        final insiderName = cellLink('insider');
        final tradeTypeRaw = cellText('trade_type');
        final price = _parsePrice(cellText('price'));
        final qty = _parseQty(cellText('qty'));
        final value = _parseValue(cellText('value'));
        final title = cellText('title');
        final tradeDate = cellText('trade_date');
        final filingDate = cellText('filing_date');

        // Déterminer buy/sell
        final ttLower = tradeTypeRaw.toLowerCase();
        String tradeType;
        if (ttLower.contains('purchase') || ttLower.startsWith('p ')) {
          tradeType = 'buy';
        } else if (ttLower.contains('sale') || ttLower.startsWith('s ')) {
          tradeType = 'sell';
        } else {
          tradeType = 'other';
        }

        // Calculer la valeur si manquante
        final finalValue = (value == 0 && price > 0 && qty != 0)
            ? (price * qty.abs()).abs()
            : value.abs();

        final csuite = _isCsuite(title);

        trades.add(GlobalInsiderTrade(
          type: tradeType,
          symbol: ticker,
          name: insiderName.isNotEmpty ? insiderName : 'Unknown',
          title: title.isNotEmpty ? title : 'Insider',
          shares: qty.abs(),
          price: price,
          value: finalValue,
          date: filingDate.isNotEmpty ? filingDate : tradeDate,
          csuite: csuite,
          labels: [], // Labels will be enriched later
        ));
      }

      return trades;
    } catch (e) {
      dev.log('❌ OpenInsider HTML parse error: $e', name: 'OpenInsider');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTELLIGENCE LABELLING — Enrichit chaque trade avec des labels
  // ═══════════════════════════════════════════════════════════════════════════

  List<GlobalInsiderTrade> _enrichWithLabels(List<GlobalInsiderTrade> trades) {
    // Détecter les Cluster Buys : 3+ acheteurs uniques sur le même ticker
    final Map<String, Set<String>> buyersPerTicker = {};
    for (var t in trades.where((t) => t.type == 'buy')) {
      buyersPerTicker.putIfAbsent(t.symbol, () => {}).add(t.name);
    }

    return trades.map((t) {
      final List<String> labels = [];
      if (t.csuite) labels.add('C-SUITE');
      if (t.value >= 500000) labels.add('SIGNIFICANT');
      if (t.value >= 5000000) labels.add('MEGA');
      if (t.type == 'buy' && (buyersPerTicker[t.symbol]?.length ?? 0) >= 3) {
        labels.add('CLUSTER');
      }
      return GlobalInsiderTrade(
        type: t.type,
        symbol: t.symbol,
        name: t.name,
        title: t.title,
        shares: t.shares,
        price: t.price,
        value: t.value,
        date: t.date,
        csuite: t.csuite,
        labels: labels,
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. BULK LATEST — Insider trades marché global
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère les derniers insider trades depuis OpenInsider.
  /// Utilisé par : MarketOverviewPanel → section insiderTrades
  /// Remplace : FMP getBulkInsiderTrading() (qui nécessite un tier payant)
  Future<List<GlobalInsiderTrade>> getLatestTrades({
    int days = 7,
    String tradeType = 'all',
    int minValue = 0,
    int count = 100,
  }) async {
    final cacheKey = 'latest:$days:$tradeType:$minValue:$count';
    final cached = _getCache<List<GlobalInsiderTrade>>(cacheKey);
    if (cached != null) return cached;

    // Construire l'URL OpenInsider screener
    final params = {
      's': '',
      'o': '',
      'pl': '',
      'ph': '',
      'll': '',
      'lh': '',
      'vl': minValue > 0 ? (minValue / 1000).toInt().toString() : '',
      'vh': '',
      'fd': days.toString(),
      'td': '0',
      'cnt': count.toString(),
      'sortcol': '0',
      'page': '1',
    };

    final queryString =
        params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final url = Uri.parse('$_baseUrl/screener?$queryString');

    final response = await _get(url);
    if (response == null) return [];

    var trades = _parseOpenInsiderTable(response.body, maxRows: count);

    // Filtrer par type de trade
    if (tradeType == 'buy') {
      trades = trades.where((t) => t.type == 'buy').toList();
    } else if (tradeType == 'sell') {
      trades = trades.where((t) => t.type == 'sell').toList();
    }

    // Enrichir avec les labels d'intelligence
    trades = _enrichWithLabels(trades);

    _setCache(cacheKey, trades, _bulkTTL);
    dev.log('✅ OpenInsider: ${trades.length} trades (${days}d, mobile-direct)',
        name: 'OpenInsider');
    return trades;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. PER-TICKER — Insider transactions pour un ticker spécifique
  // ═══════════════════════════════════════════════════════════════════════════

  /// Récupère toutes les transactions insider pour un ticker donné.
  /// Utilisé par : SmartMoneyWidget, AnalysisPanel §08 (Sentiment & Flux)
  /// Remplace : Yahoo getInsiderTransactions() + FMP getInsiderTrading()
  Future<Map<String, dynamic>> getTickerInsiderData(String symbol,
      {int months = 6}) async {
    final sym = symbol.toUpperCase().trim();
    final cacheKey = 'ticker:$sym:$months';
    final cached = _getCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    final url = Uri.parse(
        '$_baseUrl/screener?s=$sym&o=&pl=&ph=&ll=&lh=&vl=&vh=&fd=${months * 30}&td=0&cnt=100&sortcol=0&page=1');
    final response = await _get(url);

    if (response == null) {
      return _emptyTickerResult();
    }

    var trades = _parseOpenInsiderTable(response.body, maxRows: 100);
    trades = _enrichWithLabels(trades);

    // Calculer le ratio d'achat insider
    final buys = trades.where((t) => t.type == 'buy').toList();
    final sells = trades.where((t) => t.type == 'sell').toList();
    final total = buys.length + sells.length;
    final buyRatio = total > 0 ? buys.length / total : 0.0;

    // Calculer la valeur nette insider
    final buyValue = buys.fold<double>(0.0, (sum, t) => sum + t.value);
    final sellValue = sells.fold<double>(0.0, (sum, t) => sum + t.value);

    // Convertir en InsiderTransaction (pour AnalysisData)
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

    final result = {
      'trades': trades,
      'transactions': transactions,
      'insiderBuyRatio': buyRatio,
      'netInsiderValue': buyValue - sellValue,
      'totalBuyValue': buyValue,
      'totalSellValue': sellValue,
      'buyCount': buys.length,
      'sellCount': sells.length,
      'csuiteTrades': trades.where((t) => t.csuite).toList(),
    };

    _setCache(cacheKey, result, _tickerTTL);
    dev.log(
        '✅ OpenInsider: ${trades.length} trades for $sym (buyRatio: ${buyRatio.toStringAsFixed(2)}, mobile)',
        name: 'OpenInsider');
    return result;
  }

  /// Méthode de convenance : retourne uniquement la liste InsiderTransaction
  /// Drop-in replacement pour les méthodes Yahoo/FMP
  Future<List<InsiderTransaction>> getInsiderTransactions(String symbol) async {
    final data = await getTickerInsiderData(symbol);
    return data['transactions'] as List<InsiderTransaction>? ?? [];
  }

  /// Méthode de convenance : retourne juste le ratio d'achat insider (0.0 - 1.0)
  Future<double> getInsiderBuyRatio(String symbol) async {
    final data = await getTickerInsiderData(symbol);
    return data['insiderBuyRatio'] as double? ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. CLUSTER BUYS — Le signal alpha le plus puissant
  // ═══════════════════════════════════════════════════════════════════════════

  /// Détecte les cluster buys : tickers avec 3+ acheteurs insiders uniques.
  /// Utilisé par : DailyMarketRadar, CatalystInsight
  /// Exclusif à OpenInsider — ni FMP ni Yahoo n'exposent cette analyse croisée.
  Future<List<Map<String, dynamic>>> getClusterBuys({int days = 14}) async {
    final cacheKey = 'clusters:$days';
    final cached = _getCache<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    // Récupérer les achats significatifs (>$100K) -> vl=100 (K$)
    final url = Uri.parse(
        '$_baseUrl/screener?s=&o=&pl=&ph=&ll=&lh=&vl=100&vh=&fd=$days&td=0&cnt=500&sortcol=0&page=1');
    final response = await _get(url);
    if (response == null) return [];

    var trades = _parseOpenInsiderTable(response.body, maxRows: 500);

    // Filtrer uniquement les achats
    final buys = trades.where((t) => t.type == 'buy').toList();

    // Grouper par ticker
    final Map<String, Map<String, dynamic>> tickerData = {};
    for (var t in buys) {
      final sym = t.symbol;
      if (!tickerData.containsKey(sym)) {
        tickerData[sym] = {
          'symbol': sym,
          'buyers': <String>{},
          'trades': <GlobalInsiderTrade>[],
          'totalValue': 0.0,
          'csuiteCount': 0,
        };
      }
      (tickerData[sym]!['buyers'] as Set<String>).add(t.name);
      (tickerData[sym]!['trades'] as List<GlobalInsiderTrade>).add(t);
      tickerData[sym]!['totalValue'] =
          (tickerData[sym]!['totalValue'] as double) + t.value;
      if (t.csuite)
        tickerData[sym]!['csuiteCount'] =
            (tickerData[sym]!['csuiteCount'] as int) + 1;
    }

    // Filtrer pour cluster buys (3+ acheteurs uniques)
    final List<Map<String, dynamic>> clusters = [];
    for (var entry in tickerData.entries) {
      final data = entry.value;
      final buyers = data['buyers'] as Set<String>;
      if (buyers.length >= 3) {
        clusters.add({
          'symbol': data['symbol'],
          'uniqueBuyers': buyers.length,
          'totalTrades': (data['trades'] as List).length,
          'totalValue': data['totalValue'],
          'csuiteCount': data['csuiteCount'],
          'buyers': buyers.toList(),
          'labels': [
            'CLUSTER',
            if ((data['csuiteCount'] as int) > 0) 'C-SUITE'
          ],
        });
      }
    }

    // Trier par valeur totale décroissante
    clusters.sort((a, b) =>
        ((b['totalValue'] as double)).compareTo(a['totalValue'] as double));

    _setCache(cacheKey, clusters, _clusterTTL);
    dev.log('✅ OpenInsider: ${clusters.length} cluster buy signals (mobile)',
        name: 'OpenInsider');
    return clusters;
  }

  /// Convertit les cluster buys en CatalystInsight pour le Radar
  Future<List<CatalystInsight>> getClusterBuysAsCatalysts(
      {int days = 14}) async {
    final clusters = await getClusterBuys(days: days);
    return clusters.map((c) {
      final sym = c['symbol'] ?? 'N/A';
      final buyers = c['uniqueBuyers'] ?? 0;
      final value = (c['totalValue'] as num?)?.toDouble() ?? 0.0;
      final hasCsuite = (c['csuiteCount'] ?? 0) > 0;

      return CatalystInsight(
        ticker: sym,
        title: '${buyers}x INSIDER CLUSTER BUY${hasCsuite ? " (C-SUITE)" : ""}',
        description:
            '$buyers unique insiders purchased \$${_fmtValue(value)} in $sym over the last $days days. ${hasCsuite ? "Includes C-Suite executive(s)." : ""}',
        impactScore: _clusterImpactScore(buyers, value, hasCsuite),
        isNegative: false,
        source: 'OpenInsider (SEC Form 4)',
        timestamp: DateTime.now(),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS — Parsing des valeurs OpenInsider
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parse les prix : "$145.50" → 145.50
  double _parsePrice(String s) {
    if (s.isEmpty) return 0.0;
    final cleaned = s.replaceAll('\$', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse les valeurs dollar : "+\$14,254,646" → 14254646.0
  double _parseValue(String s) {
    if (s.isEmpty) return 0.0;
    final cleaned =
        s.replaceAll('\$', '').replaceAll(',', '').replaceAll('+', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse les quantités : "+1,500" → 1500
  int _parseQty(String s) {
    if (s.isEmpty) return 0;
    final cleaned = s.replaceAll(',', '').replaceAll('+', '').trim();
    return (double.tryParse(cleaned) ?? 0.0).toInt();
  }

  /// Détecte les dirigeants C-Suite
  bool _isCsuite(String title) {
    final t = title.toUpperCase();
    return t.contains('CEO') ||
        t.contains('CFO') ||
        t.contains('COO') ||
        t.contains('CTO') ||
        t.contains('CMO') ||
        t.contains('PRESIDENT') ||
        t.contains('CHIEF') ||
        t.contains('CHAIRMAN');
  }

  /// Score d'impact pour les cluster buys
  double _clusterImpactScore(int buyers, double value, bool hasCsuite) {
    double score = 0.3;
    if (buyers >= 5)
      score += 0.3;
    else if (buyers >= 3) score += 0.15;
    if (value >= 5000000)
      score += 0.2;
    else if (value >= 1000000) score += 0.1;
    if (hasCsuite) score += 0.15;
    return score.clamp(0.0, 1.0);
  }

  /// Formatte une valeur monétaire en notation compacte
  String _fmtValue(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  /// Résultat vide pour fallback
  Map<String, dynamic> _emptyTickerResult() => {
        'trades': <GlobalInsiderTrade>[],
        'transactions': <InsiderTransaction>[],
        'insiderBuyRatio': 0.0,
        'netInsiderValue': 0.0,
        'totalBuyValue': 0.0,
        'totalSellValue': 0.0,
        'buyCount': 0,
        'sellCount': 0,
        'csuiteTrades': <GlobalInsiderTrade>[],
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// CACHE ENTRY — Simple TTL cache
// ═══════════════════════════════════════════════════════════════════════════
class _OICache {
  final dynamic data;
  final DateTime expiry;
  _OICache(this.data, this.expiry);
  bool get isExpired => DateTime.now().isAfter(expiry);
}
