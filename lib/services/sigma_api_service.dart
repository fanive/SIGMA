// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../utils/logo_resolver.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SIGMA API Service — Single source of truth for all financial data
/// ═══════════════════════════════════════════════════════════════════════════
/// All market data comes from https://sigma-yfinance-api.onrender.com/
/// No external API keys required.
/// ═══════════════════════════════════════════════════════════════════════════
class SigmaApiService {
  static const String _base = 'https://sigma-yfinance-api.onrender.com';
  // Render free tier cold-start can take 60-90s; we also add one retry below.
  static const Duration _timeout = Duration(seconds: 90);

  // ── In-memory cache ──────────────────────────────────────────────────────
  static final Map<String, _Cache> _cache = {};

  static T? _getCache<T>(String key) {
    final e = _cache[key];
    if (e != null && !e.isExpired) return e.data as T;
    _cache.remove(key);
    return null;
  }

  static void _setCache(String key, dynamic data, Duration ttl) {
    _cache[key] = _Cache(data, DateTime.now().add(ttl));
  }

  static Future<void> keepAlive() async {
    await _get('/', timeout: const Duration(seconds: 8), retries: 1);
  }

  // ── HTTP helper ──────────────────────────────────────────────────────────
  static Future<dynamic> _get(
    String path, {
    Map<String, String>? params,
    Duration? timeout,
    int retries = 2,
  }) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: params);
    final t = timeout ?? _timeout;
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await http.get(uri).timeout(t);
        final code = response.statusCode;
        if (code == 200) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        }
        if (code == 429 || code == 503 || code >= 500) {
          dev.log(
            'SigmaApi $path → $code (attempt ${attempt + 1}/$retries)',
            name: 'SigmaApiService',
          );
          if (attempt < retries - 1) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
        } else {
          dev.log('SigmaApi $path → $code', name: 'SigmaApiService');
          return null;
        }
      } catch (e) {
        dev.log('SigmaApi $path error (attempt ${attempt + 1}/$retries): $e',
            name: 'SigmaApiService');
        if (attempt < retries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUOTE  /quote/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getQuote(String ticker) async {
    final key = 'quote:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/profile');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(seconds: 30));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MULTI-QUOTE  /multi-quote?symbols=AAPL,TSLA,...
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getMultiQuote(
      List<String> tickers) async {
    if (tickers.isEmpty) return [];
    final key = 'multi:${tickers.map((t) => t.toUpperCase()).join(',')}';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/market/quotes',
        params: {'symbols': tickers.map((t) => t.toUpperCase()).join(',')});
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(seconds: 30));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HISTORY  /history/{symbol}?range=1y&interval=1d
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getHistory(
      String ticker, String range, String interval) async {
    final key = 'history:${ticker.toUpperCase()}:$range:$interval';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/history',
        params: {'range': range, 'interval': interval});
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 1));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTRADAY  /intraday/{symbol}?range=1d&interval=5m&prepost=true
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getIntraday(
      String ticker, String range, String interval,
      {bool prepost = true}) async {
    final key = 'intraday:${ticker.toUpperCase()}:$range:$interval:$prepost';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data =
        await _get('/equities/${ticker.toUpperCase()}/intraday', params: {
      'range': range,
      'interval': interval,
      'prepost': prepost.toString(),
    });
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 1));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OPTIONS  /options/{symbol}?expiration=YYYY-MM-DD
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getOptions(
    String ticker, {
    String? expiration,
  }) async {
    final cacheSuffix =
        expiration?.trim().isNotEmpty == true ? expiration!.trim() : '_default';
    final key = 'options:${ticker.toUpperCase()}:$cacheSuffix';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final params = <String, String>{};
    if (expiration != null && expiration.trim().isNotEmpty) {
      params['expiration'] = expiration.trim();
    }
    final data =
        await _get('/equities/${ticker.toUpperCase()}/options', params: params);
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 5));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FINANCIALS  /financials/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getFinancials(String ticker) async {
    final key = 'financials:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/financials');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 1));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANALYSIS  /analysis/{symbol}  (analyst targets, estimates)
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getAnalysis(String ticker) async {
    final key = 'analysis:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/intelligence');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 4));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OWNERSHIP  /ownership/{symbol}  (institutional + insider holders)
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getOwnership(String ticker) async {
    final key = 'ownership:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/ownership');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 4));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // YFINANCE COVERAGE  /yfinance-coverage/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getYFinanceCoverage(String ticker) async {
    final key = 'yf_coverage:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data =
        await _get('/equities/${ticker.toUpperCase()}/yfinance-coverage');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 30));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEWS  /news/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getNews(String ticker) async {
    final key = 'news:${ticker.toUpperCase()}';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/news');
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 5));
      return list;
    }
    if (data is Map && data['articles'] is List) {
      final list = (data['articles'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _setCache(key, list, const Duration(minutes: 5));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EVENTS  /events/{symbol}  (earnings calendar, dividends, splits)
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getEvents(String ticker) async {
    final key = 'events:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/events');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 1));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INSIDER  /insider/{symbol}  (SEC Form 4, OpenInsider)
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getInsider(String ticker) async {
    final key = 'insider:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/insider');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 4));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEC  /sec/{symbol}  (SEC EDGAR XBRL)
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getSec(String ticker) async {
    final key = 'sec:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/sec');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 24));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MACRO  /macro
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getMacro() async {
    const key = 'macro';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/market/indices');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 5));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MOVERS  /market/gainers, /market/losers, /market/most-active
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getGainers() async {
    const key = 'market_gainers';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/market/gainers');
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 5));
      return list;
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getLosers() async {
    const key = 'market_losers';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/market/losers');
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 5));
      return list;
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getMostActive() async {
    const key = 'market_active';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/market/most-active');
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 5));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MARKET NEWS  /market/news
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getMarketNews(
      {int limit = 30}) async {
    final key = 'market_news:$limit';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final symbols = ['SPY', 'QQQ', 'DIA', 'IWM'];
    final results = await Future.wait(symbols.map(getNews));
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final articles in results) {
      for (final article in articles) {
        final title = article['title']?.toString().trim() ?? '';
        if (title.isEmpty || !seen.add(title.toLowerCase())) continue;
        list.add(article);
      }
    }
    list.sort((a, b) => (b['publishedAt'] ?? b['publishedDate'] ?? '')
        .toString()
        .compareTo((a['publishedAt'] ?? a['publishedDate'] ?? '').toString()));
    final trimmed = list.take(limit).toList();
    _setCache(key, trimmed, const Duration(minutes: 5));
    return trimmed;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH  /search?q=query
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.isEmpty) return [];
    final key = 'search:${query.toLowerCase()}';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    // Search must feel instant. Short timeout, single attempt; the UI already
    // falls back to a local universe if the backend is slow or cold.
    final data = await _get(
      '/search',
      params: {'q': query},
      timeout: const Duration(seconds: 8),
      retries: 1,
    );
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 10));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SNAPSHOT  /snapshot/{symbol}  (quote + insider_sentiment + sec_fundamentals)
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getSnapshot(String ticker) async {
    final key = 'snapshot:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/snapshot');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 1));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LOGO  /search/logo/{symbol}?json=true
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getLogo(String ticker) async {
    final symbol = ticker.toUpperCase().trim();
    if (symbol.isEmpty) return {};
    final key = 'logo:$symbol';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final encodedSymbol = Uri.encodeComponent(symbol);
    final data =
        await _get('/search/logo/$encodedSymbol', params: {'json': 'true'});
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      if (m['logoUrls'] is Map) {
        final urls = (m['logoUrls'] as Map).cast<String, dynamic>();
        final candidate = m['logoUrl'] ??
            urls['fmp'] ??
            urls['parqet'] ??
            urls['clearbit'] ??
            urls['primary'];
        m['logoUrl'] =
            LogoResolver.resolve(symbol, providedUrl: candidate?.toString());
      } else {
        m['logoUrl'] =
            LogoResolver.resolve(symbol, providedUrl: m['logoUrl']?.toString());
      }
      _setCache(key, m, const Duration(hours: 24));
      return m;
    }

    final profile = await _get('/equities/$symbol/profile');
    if (profile is Map) {
      final logoUrl = profile['logoUrl'] ?? profile['image'];
      final m = <String, dynamic>{
        'symbol': symbol,
        'logoUrl':
            LogoResolver.resolve(symbol, providedUrl: logoUrl?.toString()),
        if (profile['website'] != null) 'website': profile['website'],
      };
      _setCache(key, m, const Duration(hours: 24));
      return m;
    }
    return {};
  }

  /// Clears the in-memory cache.
  static void clearCache() {
    _cache.clear();
    dev.log('🗑️ SigmaApiService cache cleared', name: 'SigmaApiService');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GOOGLE FINANCE  /google_finance/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getGoogleFinance(String ticker) async {
    final key = 'gf:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/equities/${ticker.toUpperCase()}/google-finance');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 5));
      return m;
    }
    return {};
  }
}

// ── Internal cache entry ────────────────────────────────────────────────────
class _Cache {
  final dynamic data;
  final DateTime expiry;
  _Cache(this.data, this.expiry);
  bool get isExpired => DateTime.now().isAfter(expiry);
}
