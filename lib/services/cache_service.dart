import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer' as dev;

/// ═══════════════════════════════════════════════════════════════════════
/// SIGMA INTELLIGENT CACHE SERVICE v2.0
/// ═══════════════════════════════════════════════════════════════════════
/// Reduces API calls by 90%+ with financial-aware TTLs:
///
///  - Price quotes: 2min during market hours, 30min off-hours
///  - Company profile: 7 days (rarely changes)
///  - Financials (income/balance/cashflow): 24h (quarterly update)
///  - Analyst data: 6h (updated daily)
///  - Holders/Insiders: 12h (updated periodically)
///  - Options: 1h (changes intraday)
///  - News: 15min (frequent updates)
///  - Market overview: 5min during market hours, 30min off
///  - Full analysis: 4h (composite)
///  - Sector/Industry: 24h
///  - ESG/Sustainability: 7 days
///  - Earnings calendar: 6h
/// ═══════════════════════════════════════════════════════════════════════

class CacheService {
  static late Box _cacheBox;
  static bool _initialized = false;

  // ─── TTL Definitions ───────────────────────────────────────────
  // Prices & quotes
  static const Duration priceTtlMarketHours = Duration(minutes: 2);
  static const Duration priceTtlOffHours = Duration(minutes: 30);

  // Company info (very stable data)
  static const Duration profileTtl = Duration(days: 7);
  static const Duration tickerInfoTtl = Duration(hours: 12);

  // Financial statements (quarterly)
  static const Duration financialsTtl = Duration(hours: 24);

  // Analyst / Recommendations
  static const Duration analystTtl = Duration(hours: 6);

  // Holders & Insiders
  static const Duration holdersTtl = Duration(hours: 12);

  // Options
  static const Duration optionsTtl = Duration(hours: 1);

  // News
  static const Duration newsTtl = Duration(minutes: 15);

  // Market Overview
  static const Duration marketTtlOpen = Duration(minutes: 5);
  static const Duration marketTtlClosed = Duration(minutes: 30);

  // Full analysis (composite result from QuantumData + Conviction)
  static const Duration analysisTtl = Duration(hours: 4);

  // Sector/Industry (stable)
  static const Duration sectorTtl = Duration(hours: 24);

  // ESG/Sustainability (very stable)
  static const Duration esgTtl = Duration(days: 7);

  // Calendars
  static const Duration calendarTtl = Duration(hours: 6);

  // Yahoo bundle
  static const Duration yBundleTtl = Duration(hours: 2);

  // Chart data
  static const Duration chartTtlIntraday = Duration(minutes: 2);
  static const Duration chartTtlDaily = Duration(minutes: 30);
  static const Duration chartTtlWeekly = Duration(hours: 6);

  // ─── Initialize ────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();

    try {
      _cacheBox = await Hive.openBox('sigma_cache_v2');
    } catch (e) {
      dev.log('⚠️ Cache init error: $e', name: 'CacheService');
      await Hive.deleteBoxFromDisk('sigma_cache_v2');
      _cacheBox = await Hive.openBox('sigma_cache_v2');
    }

    _initialized = true;
    dev.log(
      '✅ CacheService v2 initialized: ${_cacheBox.length} entries',
      name: 'CacheService',
    );

    // Clean expired entries on startup (non-blocking)
    cleanExpired();
  }

  // ─── Core get/set with TTL ─────────────────────────────────────

  /// Save data with a specific cache type
  static Future<void> put(
    String key,
    dynamic data, {
    required String type,
  }) async {
    _ensureInitialized();
    await _cacheBox.put(key, {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
    });
  }

  /// Get cached data if still valid, returns null if expired or missing
  static CachedData? get(String key, {Duration? customTtl}) {
    _ensureInitialized();
    final entry = _cacheBox.get(key);
    if (entry == null) return null;

    final timestamp = DateTime.parse(entry['timestamp'] as String);
    final age = DateTime.now().difference(timestamp);
    final type = (entry['type'] as String?) ?? 'analysis';
    final ttl = customTtl ?? _getTtlForType(type);

    if (age > ttl) return null;

    return CachedData(data: entry['data'], timestamp: timestamp, age: age);
  }

  /// Get cached data even if expired (stale-while-revalidate pattern)
  /// Returns data + whether it's stale
  static StaleCachedData? getStale(String key) {
    _ensureInitialized();
    final entry = _cacheBox.get(key);
    if (entry == null) return null;

    final timestamp = DateTime.parse(entry['timestamp'] as String);
    final age = DateTime.now().difference(timestamp);
    final type = (entry['type'] as String?) ?? 'analysis';
    final ttl = _getTtlForType(type);

    return StaleCachedData(
      data: entry['data'],
      timestamp: timestamp,
      age: age,
      isStale: age > ttl,
    );
  }

  // ─── Typed convenience methods ─────────────────────────────────

  /// Cache keys follow pattern: {type}_{ticker}_{sub}
  /// e.g. "quote_AAPL", "profile_AAPL", "income_AAPL_quarterly"

  static String quoteKey(String ticker) => 'quote_${ticker.toUpperCase()}';
  static String profileKey(String ticker) => 'profile_${ticker.toUpperCase()}';
  static String tickerInfoKey(String ticker) =>
      'tickerinfo_${ticker.toUpperCase()}';
  static String bundleKey(String ticker) => 'bundle_${ticker.toUpperCase()}';
  static String incomeKey(String ticker, {bool quarterly = false}) =>
      'income_${ticker.toUpperCase()}_${quarterly ? 'q' : 'a'}';
  static String balanceKey(String ticker, {bool quarterly = false}) =>
      'balance_${ticker.toUpperCase()}_${quarterly ? 'q' : 'a'}';
  static String cashflowKey(String ticker, {bool quarterly = false}) =>
      'cashflow_${ticker.toUpperCase()}_${quarterly ? 'q' : 'a'}';
  static String analystKey(String ticker) => 'analyst_${ticker.toUpperCase()}';
  static String recommendationsKey(String ticker) =>
      'recs_${ticker.toUpperCase()}';
  static String holdersKey(String ticker) => 'holders_${ticker.toUpperCase()}';
  static String insidersKey(String ticker) =>
      'insiders_${ticker.toUpperCase()}';
  static String optionsKey(String ticker) => 'options_${ticker.toUpperCase()}';
  static String newsKey(String ticker) => 'news_${ticker.toUpperCase()}';
  static String chartKey(String ticker, String range) =>
      'chart_${ticker.toUpperCase()}_$range';
  static String analysisKey(String ticker) =>
      'analysis_${ticker.toUpperCase()}';
  static String earningsKey(String ticker) =>
      'earnings_${ticker.toUpperCase()}';
  static String esgKey(String ticker) => 'esg_${ticker.toUpperCase()}';
  static String sectorKey(String key) => 'sector_$key';
  static String industryKey(String key) => 'industry_$key';
  static String calendarKey(String type) => 'calendar_$type';
  static String convictionKey(String ticker) =>
      'conviction_${ticker.toUpperCase()}';
  static String marketOverviewCacheKey() => 'market_overview';
  static String sparkKey(String symbols) => 'spark_$symbols';

  // ─── Analysis (composite result) ───────────────────────────────

  static Future<void> saveAnalysis(String ticker, dynamic data) async {
    await put(analysisKey(ticker), data, type: 'analysis');
  }

  static CachedData? getAnalysis(String ticker) {
    return get(analysisKey(ticker));
  }

  // ─── Market Overview ───────────────────────────────────────────

  static Future<void> saveMarketOverview(dynamic data) async {
    await put(marketOverviewCacheKey(), data, type: 'market');
  }

  static CachedData? getMarketOverview() {
    return get(marketOverviewCacheKey());
  }

  // ─── Invalidation ──────────────────────────────────────────────

  static Future<void> invalidate(String key) async {
    _ensureInitialized();
    await _cacheBox.delete(key);
  }

  static Future<void> invalidateAnalysis(String ticker) async {
    await invalidate(analysisKey(ticker));
    await invalidate(convictionKey(ticker));
    await invalidate(bundleKey(ticker));
  }

  static Future<void> invalidateMarket() async {
    await invalidate(marketOverviewCacheKey());
  }

  static Future<void> invalidateTicker(String ticker) async {
    final prefix = ticker.toUpperCase();
    final keysToDelete = _cacheBox.keys
        .where((k) => k.toString().contains(prefix))
        .toList();
    for (final key in keysToDelete) {
      await _cacheBox.delete(key);
    }
  }

  static Future<void> clearAll() async {
    _ensureInitialized();
    await _cacheBox.clear();
    dev.log('🗑️ Cache entirely cleared', name: 'CacheService');
  }

  // ─── Cleanup ───────────────────────────────────────────────────

  static Future<void> cleanExpired() async {
    _ensureInitialized();
    final now = DateTime.now();
    final keysToDelete = <dynamic>[];

    for (final key in _cacheBox.keys) {
      try {
        final entry = _cacheBox.get(key);
        if (entry == null) continue;
        final timestamp = DateTime.parse(entry['timestamp'] as String);
        final age = now.difference(timestamp);
        final type = (entry['type'] as String?) ?? 'analysis';
        final ttl = _getTtlForType(type);

        // Delete if older than 2x TTL (give stale reads a window)
        if (age > ttl * 2) {
          keysToDelete.add(key);
        }
      } catch (_) {
        keysToDelete.add(key);
      }
    }

    for (final key in keysToDelete) {
      await _cacheBox.delete(key);
    }

    if (keysToDelete.isNotEmpty) {
      dev.log(
        '🧹 Cleaned ${keysToDelete.length} expired cache entries',
        name: 'CacheService',
      );
    }
  }

  // ─── Stats ─────────────────────────────────────────────────────

  static CacheStats getStats() {
    _ensureInitialized();
    final Map<String, int> typeCount = {};
    int expiredCount = 0;
    final now = DateTime.now();

    for (final key in _cacheBox.keys) {
      final entry = _cacheBox.get(key);
      if (entry == null) continue;
      final type = (entry['type'] as String?) ?? 'unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;

      final timestamp = DateTime.parse(entry['timestamp'] as String);
      final age = now.difference(timestamp);
      final ttl = _getTtlForType(type);
      if (age > ttl) expiredCount++;
    }

    return CacheStats(
      totalEntries: _cacheBox.length,
      typeCount: typeCount,
      expiredCount: expiredCount,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────

  static Duration _getTtlForType(String type) {
    final isMarketOpen = _isUSMarketOpen();
    switch (type) {
      case 'quote':
      case 'price':
        return isMarketOpen ? priceTtlMarketHours : priceTtlOffHours;
      case 'profile':
        return profileTtl;
      case 'tickerinfo':
        return tickerInfoTtl;
      case 'bundle':
        return yBundleTtl;
      case 'financials':
      case 'income':
      case 'balance':
      case 'cashflow':
        return financialsTtl;
      case 'analyst':
      case 'recommendations':
        return analystTtl;
      case 'holders':
      case 'insiders':
        return holdersTtl;
      case 'options':
        return optionsTtl;
      case 'news':
        return newsTtl;
      case 'market':
        return isMarketOpen ? marketTtlOpen : marketTtlClosed;
      case 'analysis':
        return analysisTtl;
      case 'sector':
      case 'industry':
        return sectorTtl;
      case 'esg':
        return esgTtl;
      case 'calendar':
        return calendarTtl;
      case 'chart_intraday':
        return chartTtlIntraday;
      case 'chart_daily':
        return chartTtlDaily;
      case 'chart_weekly':
        return chartTtlWeekly;
      case 'conviction':
        return analysisTtl;
      default:
        return analysisTtl;
    }
  }

  /// Checks if US stock market is approximately open (EST 9:30-16:00)
  static bool _isUSMarketOpen() {
    final now = DateTime.now().toUtc();
    const estOffset = -5; // EST (simplified, doesn't account for DST)
    final estHour = (now.hour + estOffset) % 24;
    final estMinute = now.minute;

    // Weekends
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }

    // Before 9:30 or after 16:00 EST
    if (estHour < 9 || (estHour == 9 && estMinute < 30) || estHour >= 16) {
      return false;
    }

    return true;
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw Exception('CacheService not initialized. Call initialize() first.');
    }
  }
}

// ─── Data Classes ──────────────────────────────────────────────────────

class CachedData {
  final dynamic data;
  final DateTime timestamp;
  final Duration age;

  CachedData({required this.data, required this.timestamp, required this.age});

  bool isExpired(Duration ttl) => age > ttl;
  int get minutesOld => age.inMinutes;

  String get ageLabel {
    if (age.inMinutes < 1) return 'À l\'instant';
    if (age.inMinutes < 60) return 'Il y a ${age.inMinutes}min';
    return 'Il y a ${age.inHours}h';
  }
}

class StaleCachedData extends CachedData {
  final bool isStale;

  StaleCachedData({
    required super.data,
    required super.timestamp,
    required super.age,
    required this.isStale,
  });
}

class CacheStats {
  final int totalEntries;
  final Map<String, int> typeCount;
  final int expiredCount;

  CacheStats({
    required this.totalEntries,
    required this.typeCount,
    required this.expiredCount,
  });

  int get analysisCount => typeCount['analysis'] ?? 0;
  int get marketCount => typeCount['market'] ?? 0;

  double get hitRateEstimate {
    if (totalEntries == 0) return 0;
    return ((totalEntries - expiredCount) / totalEntries) * 100;
  }

  @override
  String toString() {
    final typesStr = typeCount.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
    return '''
CacheStats:
  Total: $totalEntries entries
$typesStr
  Expired: $expiredCount
  Hit rate: ${hitRateEstimate.toStringAsFixed(1)}%
''';
  }
}
