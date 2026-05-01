// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

/// ═══════════════════════════════════════════════════════════════════════════
/// SIGMA API Service — Single source of truth for all financial data
/// ═══════════════════════════════════════════════════════════════════════════
/// All market data comes from https://sigma-yfinance-api.onrender.com/
/// No external API keys required.
/// ═══════════════════════════════════════════════════════════════════════════
class SigmaApiService {
  static const String _base = 'https://sigma-yfinance-api.onrender.com';
  static const Duration _timeout = Duration(seconds: 30);

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

  // ── HTTP helper ──────────────────────────────────────────────────────────
  static Future<dynamic> _get(String path,
      {Map<String, String>? params}) async {
    final uri =
        Uri.parse('$_base$path').replace(queryParameters: params);
    try {
      final response =
          await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      dev.log('SigmaApi $path → ${response.statusCode}', name: 'SigmaApiService');
    } catch (e) {
      dev.log('SigmaApi $path error: $e', name: 'SigmaApiService');
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

    final data = await _get('/quote/${ticker.toUpperCase()}');
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

    final data = await _get('/multi-quote',
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

    final data = await _get('/history/${ticker.toUpperCase()}',
        params: {'range': range, 'interval': interval});
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
      _setCache(key, list, const Duration(minutes: 1));
      return list;
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FINANCIALS  /financials/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getFinancials(String ticker) async {
    final key = 'financials:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/financials/${ticker.toUpperCase()}');
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

    final data = await _get('/analysis/${ticker.toUpperCase()}');
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

    final data = await _get('/ownership/${ticker.toUpperCase()}');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(hours: 4));
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

    final data = await _get('/news/${ticker.toUpperCase()}');
    if (data is List) {
      final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
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

    final data = await _get('/events/${ticker.toUpperCase()}');
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

    final data = await _get('/insider/${ticker.toUpperCase()}');
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

    final data = await _get('/sec/${ticker.toUpperCase()}');
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

    final data = await _get('/macro');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 5));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH  /search?q=query
  // ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.isEmpty) return [];
    final key = 'search:${query.toLowerCase()}';
    final cached = _getCache<List<Map<String, dynamic>>>(key);
    if (cached != null) return cached;

    final data = await _get('/search', params: {'q': query});
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

    final data = await _get('/snapshot/${ticker.toUpperCase()}');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      _setCache(key, m, const Duration(minutes: 1));
      return m;
    }
    return {};
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LOGO  /logo/{symbol}
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getLogo(String ticker) async {
    final key = 'logo:${ticker.toUpperCase()}';
    final cached = _getCache<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final data = await _get('/logo/${ticker.toUpperCase()}');
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
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
}

// ── Internal cache entry ────────────────────────────────────────────────────
class _Cache {
  final dynamic data;
  final DateTime expiresAt;
  _Cache(this.data, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
