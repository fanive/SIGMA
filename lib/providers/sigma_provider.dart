// ignore_for_file: curly_braces_in_flow_control_structures, no_leading_underscores_for_local_identifiers, unnecessary_cast, unused_element, unused_local_variable
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:stock_market_data/stock_market_data.dart'
    hide YahooFinanceService;

import '../models/sigma_models.dart';
import '../services/sigma_service.dart';
import '../services/favorites_service.dart';
import '../services/cache_service.dart';
import '../services/embedding_service.dart';
import '../services/vector_store.dart';
import '../services/rag_service.dart';
import '../services/sentiment_service.dart';
import '../services/sigma_engine_service.dart';
import '../services/sigma_api_service.dart';
import '../services/ollama_news_service.dart';
import '../utils/logo_resolver.dart';
import '../models/sigma_engines.dart';

class SigmaProvider extends ChangeNotifier {
  final SigmaService _sigmaService = SigmaService.fromEnv();
  SigmaService get sigmaService => _sigmaService;
  late final SigmaEngineService _engineService;
  SigmaEngineService get engineService => _engineService;
  final SentimentService _sentimentService = SentimentService();
  RAGService? _ragService;

  static const List<Map<String, String>> _quickSearchUniverse = [
    {'symbol': 'AAPL', 'name': 'Apple Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'exchange': 'NASDAQ'},
    {'symbol': 'NVDA', 'name': 'NVIDIA Corporation', 'exchange': 'NASDAQ'},
    {'symbol': 'AMZN', 'name': 'Amazon.com Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'META', 'name': 'Meta Platforms Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'AMD', 'name': 'Advanced Micro Devices', 'exchange': 'NASDAQ'},
    {'symbol': 'AVGO', 'name': 'Broadcom Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'NFLX', 'name': 'Netflix Inc.', 'exchange': 'NASDAQ'},
    {'symbol': 'JPM', 'name': 'JPMorgan Chase & Co.', 'exchange': 'NYSE'},
    {'symbol': 'BAC', 'name': 'Bank of America Corp.', 'exchange': 'NYSE'},
    {'symbol': 'GS', 'name': 'Goldman Sachs Group Inc.', 'exchange': 'NYSE'},
    {'symbol': 'MS', 'name': 'Morgan Stanley', 'exchange': 'NYSE'},
    {'symbol': 'XOM', 'name': 'Exxon Mobil Corporation', 'exchange': 'NYSE'},
    {'symbol': 'CVX', 'name': 'Chevron Corporation', 'exchange': 'NYSE'},
    {'symbol': 'LLY', 'name': 'Eli Lilly and Company', 'exchange': 'NYSE'},
    {'symbol': 'UNH', 'name': 'UnitedHealth Group Inc.', 'exchange': 'NYSE'},
    {'symbol': 'V', 'name': 'Visa Inc.', 'exchange': 'NYSE'},
    {'symbol': 'MA', 'name': 'Mastercard Incorporated', 'exchange': 'NYSE'},
    {'symbol': 'SPY', 'name': 'SPDR S&P 500 ETF Trust', 'exchange': 'NYSEARCA'},
    {'symbol': 'QQQ', 'name': 'Invesco QQQ Trust', 'exchange': 'NASDAQ'},
    {
      'symbol': 'DIA',
      'name': 'SPDR Dow Jones Industrial Average ETF',
      'exchange': 'NYSEARCA'
    },
    {
      'symbol': 'IWM',
      'name': 'iShares Russell 2000 ETF',
      'exchange': 'NYSEARCA'
    },
  ];

  SigmaProvider() {
    // Inject the single SigmaService instance into SigmaEngineService
    _engineService = SigmaEngineService(
      sigmaService: _sigmaService,
    );
    initialize();
    // Listen to FavoritesService for cross-module synchronization
    FavoritesService().updateStream.listen((_) {
      dev.log('ðŸ”” Watchlist update detected via FavoritesService',
          name: 'SigmaProvider');
      loadFavorites(forceRefresh: true);
      fetchCatalystRadar(forceRefresh: true);
    });
  }

  List<Map<String, dynamic>> searchResults = [];
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  bool isSearching = false;
  int _searchRequestId = 0;
  bool isMarketLoading = false;
  bool isAnalysisLoading = false;
  bool isSynthesisStreaming = false;
  bool isBacktestLoading = false;
  bool isNewsEnriching = false; // Neural enrichment in progress
  MarketIntelligence? marketIntelligence; // Enriched news & insights
  FearGreedData? sentimentData;
  bool isSentimentLoading = false;
  String? error;
  String? language = 'EN';
  ThemeMode themeMode = ThemeMode.system;
  String? currentTicker;
  AnalysisData? currentAnalysis;
  bool isDebateLoading = false;
  TickerIntelligence? currentIntelligence;
  MarketOverview? marketOverview;
  double loadingProgress = 0.0;
  String loadingMessage = '';
  List<String> recentSearches = [];
  List<String> favoriteTickers = [];
  Map<String, Map<String, dynamic>> favoriteQuotes = {};
  bool isWatchlistLoading = false;
  bool isIntelligenceLoading = false;
  DailyCreamReport? dailyCreamReport;
  bool isDailyCreamLoading = false;
  bool showAiFab = true; // Floating AI assistance enabled by default
  SigmaTier currentTier = SigmaTier.elite;

  List<CatalystInsight> catalystInsights = [];
  bool isRadarLoading = false;

  List<Map<String, dynamic>> strategyResults = [];
  bool isStrategyLoading = false;

  void toggleAiFab() {
    showAiFab = !showAiFab;
    notifyListeners();
  }

  int unreadNotificationsCount = 0;

  Future<void> acceptLegal() async {
    hasAcceptedLegal = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sigma_legal_accepted', true);
    notifyListeners();
  }

  void markNotificationsAsRead() {
    unreadNotificationsCount = 0;
    notifyListeners();
  }

  final Map<String, AnalysisData> _analysisCache = {};
  static const String _cacheKeyPrefix = 'sigma_analysis_cache_';
  static const String _marketCacheKey = 'sigma_market_overview_cache';
  static const String _radarCacheKey = 'sigma_radar_insights_cache';
  static const Duration _analysisCacheTtl = Duration(minutes: 20);
  static const Duration _watchlistRefreshInterval = Duration(seconds: 20);

  Timer? _watchlistRefreshTimer;

  DateTime? _lastMarketFetch;
  DateTime? _lastRadarFetch;

  static const Duration _marketCacheTtl =
      Duration(minutes: 15); // Faster refresh for Ticker Prices
  static const Duration _radarCacheTtl = Duration(minutes: 60);

  // Interactive Chart State
  String chartRange = '1Y';
  List<Map<String, dynamic>> chartHistory = [];
  bool isChartLoading = false;
  List<YahooFinanceCandleData> chartCandles = [];

  // Predictive Analytics Cache (Range -> Neural Verdict)
  final Map<String, String> _periodAnalysesCache = {};
  String? getCachedRangeAnalysis(String ticker, String range) =>
      _periodAnalysesCache['${ticker.toUpperCase()}_$range'];

  // Getters for UI consistency
  List<String> get trendingSymbols =>
      marketOverview?.topGainers?.map((e) => e.ticker).toList() ?? [];
  List<MarketMover> get extremeGainers =>
      marketOverview?.topGainers?.where((m) => m.change >= 10.0).toList() ?? [];
  List<MarketMover> get extremeLosers =>
      marketOverview?.topLosers?.where((m) => m.change <= -10.0).toList() ?? [];
  List<Map<String, dynamic>> get economicCalendar =>
      marketOverview?.economicCalendar?.map((e) => e.toJson()).toList() ?? [];
  List<dynamic> get upcomingIpos => marketOverview?.upcomingIpos ?? [];
  List<Map<String, dynamic>> get earningsCalendar =>
      marketOverview?.economicCalendar?.map((e) => e.toJson()).toList() ?? [];
  bool get marketLoading => isMarketLoading;

  bool hasAcceptedLegal = false;

  Future<void> initialize() async {
    // 1. Initial preferences (Blocking because needed for UI logic)
    await _initPreferences();

    final prefs = await SharedPreferences.getInstance();
    hasAcceptedLegal = prefs.getBool('sigma_legal_accepted') ?? false;

    // 2. Start ALL tasks simultaneously (Cache + Network)
    // We launch them without 'await' first, then group them.
    // Removed legacy Hive migration to prevent watchlist pollution
    final p2 = _loadAnalysisCache();
    final p3 = _loadMarketFromCache();
    final p4 = _loadRadarFromCache();

    // Initialize RAG (non-blocking)
    _initRAG();

    // Start network fetch immediately
    final p5 = loadFavorites();
    final p6 = fetchMarketOverview();
    final p7 = fetchCatalystRadar();
    final p8 = refreshMacroIndicators();
    final p9 = fetchSentiment();
    fetchDailyCreamReport();
    _startWatchlistAutoRefresh();

    // We wait for a "minimum set" to be ready for the splash transition if needed,
    // but the provider itself remains reactive.
    Future.wait([p2, p3, p4, p5, p6, p7, p8, p9]);
  }

  void _startWatchlistAutoRefresh() {
    _watchlistRefreshTimer?.cancel();
    _watchlistRefreshTimer =
        Timer.periodic(_watchlistRefreshInterval, (_) async {
      if (favoriteTickers.isEmpty) return;
      await loadFavorites(forceRefresh: true);
    });
  }

  bool _isAnalysisFresh(AnalysisData data) {
    final ts = DateTime.tryParse(data.lastUpdated);
    if (ts == null) return false;
    return DateTime.now().difference(ts) <= _analysisCacheTtl;
  }

  @override
  void dispose() {
    _watchlistRefreshTimer?.cancel();
    super.dispose();
  }

  /// Getter public pour le RAG service (utilisÃ© par le chatbot).
  RAGService? get ragService => _ragService;

  // 🐂 BULL VS 🐻 BEAR DEBATE
  Future<void> runBullBearDebate() async {
    if (currentAnalysis == null) return;

    isDebateLoading = true;
    notifyListeners();

    try {
      final debate =
          await _sigmaService.generateBullBearDebate(currentAnalysis!);
      currentAnalysis = currentAnalysis!.copyWith(
        bullCase: debate['bull'],
        bearCase: debate['bear'],
      );

      // Update cache
      _analysisCache[currentAnalysis!.ticker.toUpperCase()] = currentAnalysis!;
      await _saveAnalysisToCache(currentAnalysis!);
    } catch (e) {
      dev.log('❌ Error in SigmaProvider.runBullBearDebate: $e');
    } finally {
      isDebateLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initRAG() async {
    try {
      final vectorStore = VectorStore();
      await vectorStore.init();
      final embedding = EmbeddingService.fromEnv();
      _ragService = RAGService(embedding: embedding, vectorStore: vectorStore);
      dev.log('RAG Service initialized (${vectorStore.count} docs)',
          name: 'SigmaProvider');
    } catch (e) {
      dev.log('RAG init skipped: $e', name: 'SigmaProvider');
    }
  }

  Future<void> _loadMarketFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_marketCacheKey);
      if (jsonStr != null) {
        marketOverview = MarketOverview.fromJson(jsonDecode(jsonStr));
        notifyListeners();
      }
    } catch (e) {
      dev.log('Error loading market cache: $e', name: 'SigmaProvider');
    }
  }

  Future<void> _saveMarketToCache(MarketOverview overview) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_marketCacheKey, jsonEncode(overview.toJson()));
    } catch (e) {
      dev.log('Error saving market cache: $e', name: 'SigmaProvider');
    }
  }

  Future<void> _loadAnalysisCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
      final staleKeys = <String>[];
      for (final key in keys) {
        final symbol = key.replaceFirst(_cacheKeyPrefix, '');
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr);
          final parsed = AnalysisData.fromJson(data);
          if (_isAnalysisFresh(parsed)) {
            _analysisCache[symbol] = parsed;
          } else {
            staleKeys.add(key);
          }
        }
      }
      for (final key in staleKeys) {
        await prefs.remove(key);
      }
      dev.log(
        'ðŸ“¦ Loaded ${_analysisCache.length} fresh analyses from cache',
        name: 'SigmaProvider',
      );
    } catch (e) {
      dev.log('Error loading analysis cache: $e', name: 'SigmaProvider');
    }
  }

  Future<void> _saveAnalysisToCache(AnalysisData data) async {
    try {
      _analysisCache[data.ticker.toUpperCase()] = data;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cacheKeyPrefix${data.ticker.toUpperCase()}',
        jsonEncode(data.toJson()),
      );
    } catch (e) {
      dev.log('Error saving analysis to cache: $e', name: 'SigmaProvider');
    }
  }

  Future<void> _initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? 'EN';
    final savedTheme = prefs.getString('theme_mode') ?? 'system';
    if (savedTheme == 'light') themeMode = ThemeMode.light;
    if (savedTheme == 'dark') themeMode = ThemeMode.dark;

    final savedRecent = prefs.getStringList('recent_searches') ?? [];
    recentSearches = savedRecent;

    final tierIndex = prefs.getInt('sigma_user_tier');
    // Force ELITE tier in production:
    currentTier = SigmaTier.elite;
    if (tierIndex != SigmaTier.elite.index) {
      await prefs.setInt('sigma_user_tier', SigmaTier.elite.index);
    }
  }

  Future<void> _loadRadarFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_radarCacheKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        catalystInsights =
            decoded.map((i) => CatalystInsight.fromJson(i)).toList();
        notifyListeners();
      }
    } catch (e) {
      dev.log('Error loading radar cache: $e', name: 'SigmaProvider');
    }
  }

  Future<void> _saveRadarToCache(List<CatalystInsight> insights) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(insights
          .map((i) => {
                'ticker': i.ticker,
                'title': i.title,
                'description': i.description,
                'impactScore': i.impactScore,
                'isNegative': i.isNegative,
                'source': i.source,
              })
          .toList());
      await prefs.setString(_radarCacheKey, jsonStr);
    } catch (e) {
      dev.log('Error saving radar cache: $e', name: 'SigmaProvider');
    }
  }

  Future<void> upgradeTier(SigmaTier tier) async {
    currentTier = tier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sigma_user_tier', tier.index);
    notifyListeners();
  }

  Future<void> _migrateFromHive() async {
    // Migration disabled. Old Hive data was automatically injecting previously searched tickers into the active favorites list.
    // If the legacy box exists, we wipe it so it no longer pollutes the state.
    try {
      if (Hive.isBoxOpen('watchlist')) {
        await Hive.box('watchlist').clear();
      }
    } catch (_) {}
  }

  Future<void> clearCache() async {
    dev.log('â˜¢ï¸ DESTRUCTIVE RESET INITIATED', name: 'SigmaProvider');

    // 1. Clear Memory
    _analysisCache.clear();
    currentAnalysis = null;
    currentTicker = null;
    marketOverview = null;
    marketIntelligence = null;
    catalystInsights = [];
    _lastMarketFetch = null;
    _lastRadarFetch = null;
    error = null;
    isAnalysisLoading = false;
    isMarketLoading = false;

    // 2. Persistent Storage Reset (Absolute)
    final prefs = await SharedPreferences.getInstance();

    // Backup what we MUST keep
    final favs = prefs.getStringList('favorite_tickers');
    final tier = prefs.getInt('sigma_user_tier');
    final theme = prefs.getString('theme_mode'); // correct key
    final lang = prefs.getString('language'); // correct key
    final searches = prefs.getStringList('recent_searches');
    final onboardingDone = prefs.getBool('onboarding_v2_complete');
    final legalAccepted = prefs.getBool('sigma_legal_accepted');

    // Backup stickers (complex keys)
    final stickers = <String, String>{};
    for (var key in prefs.getKeys()) {
      if (key.startsWith('sticker_')) {
        stickers[key] = prefs.getString(key) ?? '';
      }
    }

    // NUKE
    await prefs.clear();

    // RESTORE
    if (favs != null) await prefs.setStringList('favorite_tickers', favs);
    if (tier != null) await prefs.setInt('sigma_user_tier', tier);
    if (theme != null) await prefs.setString('theme_mode', theme);
    if (lang != null) await prefs.setString('language', lang);
    if (searches != null)
      await prefs.setStringList('recent_searches', searches);
    if (onboardingDone != null)
      await prefs.setBool('onboarding_v2_complete', onboardingDone);
    if (legalAccepted != null)
      await prefs.setBool('sigma_legal_accepted', legalAccepted);
    stickers.forEach((k, v) async => await prefs.setString(k, v));

    dev.log('ðŸ—‘ï¸ SharedPreferences NUKED & RESTORED (Protected only)',
        name: 'SigmaProvider');

    // 3. Clear Hive Cache
    try {
      await CacheService.clearAll();
      dev.log('ðŸ—‘ï¸ Hive Cache Box Purged.', name: 'SigmaProvider');
    } catch (e) {
      dev.log('âš ï¸ Hive Purge Warning: $e', name: 'SigmaProvider');
    }

    // 4. Reset Engine
    _sigmaService.reset();

    notifyListeners();
    dev.log('âœ… SYSTEM FULLY RESET - READY FOR FRESH ANALYSIS',
        name: 'SigmaProvider');
  }

  Future<void> loadFavorites({bool forceRefresh = false}) async {
    // Avoid redundant loads if one is already in progress
    if (isWatchlistLoading && !forceRefresh) return;

    final favorites = await FavoritesService().getFavorites();
    dev.log('ðŸ“‹ Watchlist synced: ${favorites.length} tickers',
        name: 'SigmaProvider');

    // Update tickers list immediately so UI shows rows/loaders instantly
    favoriteTickers = favorites;
    notifyListeners();

    if (favorites.isEmpty) {
      favoriteQuotes = {};
      isWatchlistLoading = false;
      notifyListeners();
      return;
    }

    isWatchlistLoading = true;
    notifyListeners();

    final Map<String, Map<String, dynamic>> newQuotes = {};

    try {
      final quotes = await _sigmaService.marketDataService.getQuotes(favorites);
      for (var quote in quotes) {
        final normalizedQuote = _normalizeStringMap(quote);
        final symbol = normalizedQuote['symbol']?.toString().toUpperCase();
        if (symbol == null) continue;

        newQuotes[symbol] = {
          ...normalizedQuote,
          'price': normalizedQuote['price'] ?? 0.0,
          'changePercent': normalizedQuote['changesPercentage'] ??
              normalizedQuote['changePercent'] ??
              0.0,
          'longName': normalizedQuote['longName'] ??
              normalizedQuote['shortName'] ??
              normalizedQuote['name'] ??
              symbol,
        };
      }
    } catch (e) {
      dev.log('âš ï¸ Sigma batch quote error: $e', name: 'SigmaProvider');
    }

    favoriteQuotes = newQuotes;
    isWatchlistLoading = false;
    notifyListeners();
  }

  Map<String, dynamic> _normalizeStringMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  String _fallbackMetric(dynamic value,
      {String prefix = '', String suffix = ''}) {
    if (value == null) return 'N/A';
    if (value is num) {
      final asDouble = value.toDouble();
      final formatted = asDouble.abs() >= 100
          ? asDouble.toStringAsFixed(0)
          : asDouble.toStringAsFixed(2);
      return '$prefix$formatted$suffix';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return 'N/A';
    return '$prefix$text$suffix';
  }

  List<FinancialMatrixItem> _buildFallbackFinancialMatrix(
    Map<String, dynamic> quote,
  ) {
    final metrics = <FinancialMatrixItem>[
      FinancialMatrixItem(
        label: 'CAPITALISATION BOURS.',
        value: _fallbackMetric(quote['marketCap']),
        assessment: 'NEUTRAL',
      ),
      FinancialMatrixItem(
        label: 'P/E RATIO',
        value: _fallbackMetric(quote['trailingPE'] ?? quote['pe']),
        assessment: 'NEUTRAL',
      ),
      FinancialMatrixItem(
        label: 'ROE',
        value: _fallbackMetric(quote['returnOnEquity'], suffix: '%'),
        assessment: 'NEUTRAL',
      ),
      FinancialMatrixItem(
        label: 'BETA',
        value: _fallbackMetric(quote['beta']),
        assessment: 'NEUTRAL',
      ),
      FinancialMatrixItem(
        label: 'OPERATING MARGIN',
        value: _fallbackMetric(quote['operatingMargins'], suffix: '%'),
        assessment: 'NEUTRAL',
      ),
      FinancialMatrixItem(
        label: 'NET MARGIN',
        value: _fallbackMetric(quote['profitMargins'], suffix: '%'),
        assessment: 'NEUTRAL',
      ),
    ];

    return metrics.where((item) => item.value != 'N/A').toList(growable: false);
  }

  Future<AnalysisData> _buildRawFallbackAnalysis(
    String ticker,
    String currentLanguage,
  ) async {
    final quote = _normalizeStringMap(
      await _sigmaService.marketDataService.getQuoteMap(ticker),
    );
    final rawNews = await _sigmaService.marketDataService.getStockNews(
      ticker,
      limit: 8,
    );
    final companyNews = rawNews
        .map((item) => NewsArticle.fromJson(_normalizeStringMap(item)))
        .where((item) => item.title.trim().isNotEmpty)
        .toList(growable: false);

    final companyName =
        (quote['longName'] ?? quote['shortName'] ?? ticker).toString();
    final price = quote['price'] ?? quote['regularMarketPrice'];
    final changePercent = (quote['changePercent'] ??
        quote['regularMarketChangePercent'] ??
        quote['changesPercentage']) as num?;
    final isFr = currentLanguage == 'FR';

    return AnalysisData(
      ticker: ticker,
      companyName: companyName,
      companyProfile: isFr
          ? 'Mode secours actif. Le moteur narratif est indisponible, mais les donnees marche et societes ont ete rechargees pour eviter un ecran vide.'
          : 'Fallback mode active. The narrative engine is unavailable, but market and company data were reloaded to avoid a blank screen.',
      lastUpdated: DateTime.now().toIso8601String(),
      price: _fallbackMetric(price, prefix: price == null ? '' : '\$'),
      verdict: isFr ? 'A VERIFIER' : 'REVIEW',
      verdictReasons: [
        isFr
            ? 'La synthese IA a echoue. Les donnees brutes restent affichees pour poursuivre la recherche.'
            : 'AI synthesis failed. Raw market data remains available so research can continue.',
      ],
      riskLevel: isFr ? 'MOYEN' : 'MEDIUM',
      pros: const [],
      cons: const [],
      sigmaScore: 50.0,
      confidence: 0.0,
      summary: isFr
          ? '$companyName est affiche en mode secours avec prix, identite entreprise, quelques ratios et dernieres news reelles. Relancez l\'analyse pour recuperer la synthese complete.'
          : '$companyName is shown in fallback mode with live price, company identity, key ratios, and latest real news. Retry analysis to recover the full synthesis.',
      hiddenSignals: const [],
      catalysts: const [],
      volatility: VolatilityData(
        ivRank: 'N/A',
        beta: _fallbackMetric(quote['beta']),
        interpretation: isFr
            ? 'Lecture brute sans synthese IA.'
            : 'Raw reading without AI synthesis.',
      ),
      fearAndGreed: StockSentiment(
        score: 50,
        label: isFr ? 'NEUTRE' : 'NEUTRAL',
        interpretation: 'N/A',
      ),
      marketSentiment: MarketSentiment(
        score: 50,
        label: isFr ? 'NEUTRE' : 'NEUTRAL',
      ),
      tradeSetup: TradeSetup(
        entryZone: 'N/A',
        targetPrice: 'N/A',
        stopLoss: 'N/A',
        riskRewardRatio: 'N/A',
      ),
      institutionalActivity: InstitutionalActivity(
        smartMoneySentiment: 50.0,
        retailSentiment: 50.0,
        darkPoolInterpretation: isFr
            ? 'Aucune lecture consolidee disponible en mode secours.'
            : 'No consolidated flow reading available in fallback mode.',
      ),
      technicalAnalysis: const [],
      projectedTrend: const [],
      financialMatrix: _buildFallbackFinancialMatrix(quote),
      sectorPeers: const [],
      topSources: const [],
      analystRecommendations: AnalystRecommendation(
        strongBuy: 0,
        buy: 0,
        hold: 0,
        sell: 0,
        strongSell: 0,
        period: '',
      ),
      actionPlan: [
        isFr
            ? 'Verifier les news recentes et la reaction de marche avant toute conclusion.'
            : 'Review recent news and market reaction before drawing a conclusion.',
        isFr
            ? 'Relancer l\'analyse complete quand les fournisseurs repondent de nouveau.'
            : 'Retry the full analysis once providers respond again.',
      ],
      companyNews: companyNews,
      scoreMethodology: isFr
          ? 'Mode secours: rapport compose a partir des donnees marche disponibles sans synthese IA complete.'
          : 'Fallback mode: report assembled from available market data without full AI synthesis.',
      employees: quote['fullTimeEmployees'] is num
          ? (quote['fullTimeEmployees'] as num).toInt()
          : null,
      website: quote['website']?.toString(),
      sector: quote['sector']?.toString(),
      industry: quote['industry']?.toString(),
      country: quote['country']?.toString(),
      exchange: quote['exchange']?.toString(),
      ceo: quote['companyOfficers'] is List &&
              (quote['companyOfficers'] as List).isNotEmpty
          ? _normalizeStringMap(
                  (quote['companyOfficers'] as List).first)['name']
              ?.toString()
          : null,
      image: quote['logoUrl']?.toString() ?? quote['image']?.toString(),
      changePercent: changePercent?.toDouble(),
    );
  }

  Map<String, dynamic> _normalizeComparisonQuoteToKeyStats(
    Map<String, dynamic> quote,
  ) {
    return {
      'marketCap': quote['marketCap'],
      'enterpriseValue': quote['enterpriseValue'],
      'trailingPE': quote['pe'] ?? quote['trailingPE'],
      'forwardPE': quote['forwardPE'],
      'pegRatio': quote['pegRatio'],
      'priceToSales': quote['priceToSales'],
      'priceToBook': quote['priceToBook'],
      'enterpriseToRevenue': quote['enterpriseToRevenue'],
      'enterpriseToEbitda': quote['enterpriseToEbitda'],
      'profitMargins': quote['profitMargins'],
      'operatingMargins': quote['operatingMargins'],
      'returnOnAssets': quote['returnOnAssets'],
      'returnOnEquity': quote['returnOnEquity'],
      'revenue': quote['totalRevenue'] ?? quote['revenue'],
      'revenueGrowth': quote['revenueGrowth'],
      'grossProfits': quote['grossProfits'],
      'freeCashflow': quote['freeCashflow'],
      'operatingCashflow': quote['operatingCashflow'],
      'totalCash': quote['totalCash'],
      'totalDebt': quote['totalDebt'],
      'debtToEquity': quote['debtToEquity'],
      'currentRatio': quote['currentRatio'],
      'quickRatio': quote['quickRatio'],
      'totalCashPerShare': quote['totalCashPerShare'],
      'revenuePerShare': quote['revenuePerShare'],
      'beta': quote['beta'],
      'shortRatio': quote['shortRatio'],
      'shortPercentOfFloat': quote['shortPercentOfFloat'],
      'sharesOutstanding': quote['sharesOutstanding'],
      'floatShares': quote['floatShares'],
      'dividendYield': quote['dividendYield'],
      'dividendRate': quote['dividendRate'],
      'fiveYearAvgDividendYield': quote['fiveYearAvgDividendYield'],
      'payoutRatio': quote['payoutRatio'],
      'fiftyTwoWeekHigh': quote['fiftyTwoWeekHigh'],
      'fiftyTwoWeekLow': quote['fiftyTwoWeekLow'],
      'fiftyDayAverage': quote['fiftyDayAverage'],
      'twoHundredDayAverage': quote['twoHundredDayAverage'],
      'trailingAnnualDividendYield': quote['trailingAnnualDividendYield'],
      'earningsGrowth': quote['earningsGrowth'],
      'averageVolume': quote['avgVolume'] ?? quote['averageVolume'],
      'trailingEps': quote['eps'] ?? quote['trailingEps'],
      'forwardEps': quote['forwardEps'],
    };
  }

  List<Map<String, dynamic>> _extractComparisonHistoricals(
    Map<String, dynamic> financials,
  ) {
    final annualIncome = (financials['annualIncomeStatement'] as List?) ?? [];
    return annualIncome.take(4).whereType<Map>().map((row) {
      final item = Map<String, dynamic>.from(row);
      return {
        'date': item['index'] ?? item['date'] ?? 'N/A',
        'revenue': item['TotalRevenue'] ?? item['revenue'] ?? 0,
        'netIncome': item['NetIncome'] ??
            item['NetIncomeLoss'] ??
            item['netIncome'] ??
            0,
        'eps': item['eps'] ?? 0.0,
      };
    }).toList(growable: false);
  }

  List<FinancialMatrixItem> _enrichComparisonFinancialMatrix(
    AnalysisData analysis,
    KeyStatistics keyStats,
  ) {
    final matrix = List<FinancialMatrixItem>.from(analysis.financialMatrix);

    void upsert(String label, String value) {
      if (value == 'N/A' || value.isEmpty) {
        return;
      }
      final index = matrix.indexWhere(
        (item) => item.label.toUpperCase().contains(label.toUpperCase()),
      );
      if (index >= 0) {
        matrix[index] = matrix[index].copyWith(value: value);
      } else {
        matrix.add(
          FinancialMatrixItem(
            label: label,
            value: value,
            assessment: 'NEUTRAL',
          ),
        );
      }
    }

    String pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
    String numFmt(double value) => value.toStringAsFixed(2);

    if (keyStats.trailingPE > 0)
      upsert('P/E RATIO', numFmt(keyStats.trailingPE));
    if (keyStats.enterpriseToEbitda > 0) {
      upsert('EV/EBITDA', numFmt(keyStats.enterpriseToEbitda));
    }
    if (keyStats.revenueGrowth != 0) {
      upsert('REVENUE GROWTH', pct(keyStats.revenueGrowth));
    }
    if (keyStats.earningsGrowth != 0) {
      upsert('EARNINGS GROWTH', pct(keyStats.earningsGrowth));
    }
    if (keyStats.operatingMargins != 0) {
      upsert('OPERATING MARGIN', pct(keyStats.operatingMargins));
    }
    if (keyStats.profitMargins != 0) {
      upsert('NET MARGIN', pct(keyStats.profitMargins));
    }
    if (keyStats.returnOnEquity != 0)
      upsert('ROE', pct(keyStats.returnOnEquity));
    if (keyStats.debtToEquity != 0)
      upsert('DEBT/EQUITY', numFmt(keyStats.debtToEquity));

    return matrix;
  }

  Future<AnalysisData> _enrichComparisonAnalysis(AnalysisData analysis) async {
    final ticker = analysis.ticker.toUpperCase();
    try {
      final results = await Future.wait([
        SigmaApiService.getQuote(ticker),
        SigmaApiService.getAnalysis(ticker),
        SigmaApiService.getFinancials(ticker),
        _sigmaService.marketDataService
            .getHoldersBundle(ticker)
            .catchError((_) => <String, dynamic>{}),
        SigmaApiService.getNews(ticker).catchError(
          (_) => <Map<String, dynamic>>[],
        ),
        SigmaApiService.getEvents(ticker).catchError(
          (_) => <String, dynamic>{},
        ),
        _sigmaService.marketDataService.getInsiderFull(ticker).catchError(
              (_) => <String, dynamic>{},
            ),
      ]);

      final quote = results[0] as Map<String, dynamic>;
      final endpointAnalysis = results[1] as Map<String, dynamic>;
      final financials = results[2] as Map<String, dynamic>;
      final holdersBundle = results[3] as Map<String, dynamic>;
      final newsRows = results[4] as List<Map<String, dynamic>>;
      final events = results[5] as Map<String, dynamic>;
      final insiderFull = results[6] as Map<String, dynamic>;

      final keyStats = KeyStatistics.fromJson(
        _normalizeComparisonQuoteToKeyStats(quote),
      );
      final historicals = _extractComparisonHistoricals(financials);
      final analystTargets = (endpointAnalysis['analystPriceTargets'] as Map?)
              ?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final recommendations =
          (endpointAnalysis['recommendations'] as List?) ?? [];
      final latestRec =
          recommendations.isNotEmpty && recommendations.first is Map
              ? Map<String, dynamic>.from(recommendations.first as Map)
              : <String, dynamic>{};
      final eventRows = _buildComparisonEvents(events);
      final newsArticles = newsRows
          .map((item) => NewsArticle.fromJson(_normalizeStringMap(item)))
          .where((item) => item.title.trim().isNotEmpty)
          .take(8)
          .toList(growable: false);
      final insiderSummary =
          (insiderFull['summary'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final buyCount = insiderSummary['buy_count'];
      final sellCount = insiderSummary['sell_count'];
      final insiderBuyRatio = buyCount is num && sellCount is num
          ? buyCount / math.max(1, buyCount + sellCount)
          : analysis.insiderBuyRatio;
      final institutionsList = (holdersBundle['institutionsList'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false) ??
          const <Map<String, dynamic>>[];

      return analysis.copyWith(
        companyName:
            (quote['companyName'] ?? quote['name'] ?? analysis.companyName)
                ?.toString(),
        sector: (quote['sector'] ?? analysis.sector)?.toString(),
        industry: (quote['industry'] ?? analysis.industry)?.toString(),
        image:
            (quote['logoUrl'] ?? quote['image'] ?? analysis.image)?.toString(),
        price: _fallbackMetric(
          quote['price'] ?? quote['regularMarketPrice'],
          prefix: (quote['price'] ?? quote['regularMarketPrice']) == null
              ? ''
              : '\$',
        ),
        changePercent: (quote['changePercent'] ?? quote['changesPercentage'])
                is num
            ? ((quote['changePercent'] ?? quote['changesPercentage']) as num)
                .toDouble()
            : analysis.changePercent,
        keyStatistics: keyStats,
        financialMatrix: _enrichComparisonFinancialMatrix(analysis, keyStats),
        holders: holdersBundle.isNotEmpty
            ? HoldersData.fromJson(holdersBundle)
            : analysis.holders,
        fullOwnership:
            holdersBundle.isNotEmpty ? holdersBundle : analysis.fullOwnership,
        institutionalHolders: institutionsList.isNotEmpty
            ? institutionsList
            : analysis.institutionalHolders,
        companyNews:
            newsArticles.isNotEmpty ? newsArticles : analysis.companyNews,
        corporateEvents: eventRows.isNotEmpty
            ? [...analysis.corporateEvents, ...eventRows]
            : analysis.corporateEvents,
        earningsCalendar: events['calendar'] is Map
            ? Map<String, dynamic>.from(events['calendar'] as Map)
            : analysis.earningsCalendar,
        insiderBuyRatio: insiderBuyRatio,
        insiderTransactions: insiderFull['trades'] is List
            ? (insiderFull['trades'] as List)
                .whereType<Map>()
                .map((item) => InsiderTransaction.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .toList(growable: false)
            : analysis.insiderTransactions,
        targetPriceValue:
            (analystTargets['mean'] ?? analystTargets['current']) is num
                ? ((analystTargets['mean'] ?? analystTargets['current']) as num)
                    .toDouble()
                : analysis.targetPriceValue,
        historicalEarnings:
            historicals.isNotEmpty ? historicals : analysis.historicalEarnings,
        analystRecommendations: latestRec.isNotEmpty
            ? AnalystRecommendation.fromJson(latestRec)
            : analysis.analystRecommendations,
      );
    } catch (e) {
      dev.log(
        'Comparison backend enrichment failed for $ticker: $e',
        name: 'SigmaProvider',
      );
      return analysis;
    }
  }

  List<CorporateEvent> _buildComparisonEvents(Map<String, dynamic> events) {
    final rows = <CorporateEvent>[];
    final calendar = (events['calendar'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final earningsRaw = calendar['Earnings Date'] ?? calendar['earningsDate'];
    final earningsDate = earningsRaw is List && earningsRaw.isNotEmpty
        ? earningsRaw.first?.toString()
        : earningsRaw?.toString();
    if (earningsDate != null && earningsDate.trim().isNotEmpty) {
      rows.add(
        CorporateEvent(
          date: earningsDate,
          event: 'Earnings',
          description:
              'Estimate EPS: ${calendar['Earnings Average'] ?? calendar['epsAverage'] ?? 'N/A'}',
        ),
      );
    }

    for (final item in (events['dividends'] as List? ?? []).take(3)) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      rows.add(
        CorporateEvent(
          date: row['date']?.toString() ?? '',
          event: 'Dividend',
          description: 'Dividend: ${row['dividend'] ?? row['value'] ?? 'N/A'}',
        ),
      );
    }

    for (final item in (events['splits'] as List? ?? []).take(2)) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      rows.add(
        CorporateEvent(
          date: row['date']?.toString() ?? '',
          event: 'Split',
          description: 'Split: ${row['split'] ?? row['value'] ?? 'N/A'}',
        ),
      );
    }

    return rows
        .where((event) => event.event.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<String> resolveTickerInput(
    String rawQuery, {
    bool strict = false,
  }) async {
    final query = rawQuery.trim().toUpperCase();
    if (query.isEmpty) return '';

    String fallbackResult() {
      if (_looksLikeTickerSymbol(query)) return query;
      return strict ? '' : query;
    }

    if (searchResults.isNotEmpty) {
      final exactLocal = searchResults.where(
        (item) => (item['symbol'] ?? '').toString().toUpperCase() == query,
      );
      if (exactLocal.isNotEmpty) {
        return (exactLocal.first['symbol'] ?? query).toString().toUpperCase();
      }
    }

    final quickMatch = _localSearchResults(query);
    if (quickMatch.isNotEmpty) {
      final selected = (quickMatch.first['symbol'] ?? query).toString();
      return selected.toUpperCase();
    }

    try {
      final remote = await _sigmaService.searchTickerSymbolsUnified(query);
      if (remote.isEmpty) return fallbackResult();

      final upperQuery = query.toUpperCase();
      remote.sort((a, b) {
        int score(Map<String, dynamic> item) {
          final symbol = (item['symbol'] ?? '').toString().toUpperCase();
          final name = (item['name'] ?? item['description'] ?? '')
              .toString()
              .toUpperCase();
          if (symbol == upperQuery) return 0;
          if (symbol.startsWith(upperQuery)) return 1;
          if (name.startsWith(upperQuery)) return 2;
          if (symbol.contains(upperQuery)) return 3;
          if (name.contains(upperQuery)) return 4;
          return 5;
        }

        return score(a).compareTo(score(b));
      });

      final selected =
          (remote.first['symbol'] ?? query).toString().toUpperCase();

      if (remote.isNotEmpty) {
        searchResults = remote
            .map((item) => _normalizeStringMap(item))
            .toList(growable: false);
        notifyListeners();
      }

      return selected;
    } catch (_) {
      return fallbackResult();
    }
  }

  bool _looksLikeTickerSymbol(String value) {
    final clean = value.trim().toUpperCase();
    if (clean.isEmpty || clean.contains(' ')) return false;
    return RegExp(r'^[A-Z0-9]{1,8}([.-][A-Z0-9]{1,5})?$').hasMatch(clean);
  }

  Future<List<AnalysisData>> analyzeComparisonResolved(
    String left,
    String right,
  ) async {
    final leftTicker = left.trim().toUpperCase();
    final rightTicker = right.trim().toUpperCase();

    if (leftTicker.isEmpty || rightTicker.isEmpty) {
      throw StateError('Deux tickers sont requis pour comparer.');
    }
    if (leftTicker == rightTicker) {
      throw StateError('Choisissez deux tickers differents pour comparer.');
    }

    final currentLanguage = language ?? 'EN';

    Future<AnalysisData> load(String ticker) async {
      try {
        final analysis = await _sigmaService.analyzeStock(
          ticker,
          language: currentLanguage,
        );
        return _enrichComparisonAnalysis(analysis);
      } catch (e) {
        dev.log(
          'Comparison analysis fallback for $ticker: $e',
          name: 'SigmaProvider',
        );
        final fallback =
            await _buildRawFallbackAnalysis(ticker, currentLanguage);
        return _enrichComparisonAnalysis(fallback);
      }
    }

    return Future.wait([
      load(leftTicker),
      load(rightTicker),
    ]);
  }

  Future<void> fetchCatalystRadar({bool forceRefresh = false}) async {
    // Check cache
    if (!forceRefresh &&
        catalystInsights.isNotEmpty &&
        _lastRadarFetch != null &&
        DateTime.now().difference(_lastRadarFetch!) < _radarCacheTtl) {
      return;
    }

    // Global Sentinel Logic: Combine watchlist with extreme market movers
    final List<String> tickersToScan = List.from(favoriteTickers);

    // Inject extreme outliers from global market (Sentinelle BIRD)
    if (marketOverview?.topGainers != null) {
      final outliers = marketOverview!.topGainers!
          .where((m) => m.change >= 10.0) // Scan anything jumping >10%
          .map((m) => m.ticker)
          .take(5)
          .toList();
      for (var t in outliers) {
        if (!tickersToScan.contains(t)) tickersToScan.add(t);
      }
    }

    // Ensure we always scan key macro assets if the list is sparse
    final defaultMacro = ['SPY', 'QQQ', 'BTC-USD', 'NVDA', 'TSLA'];
    for (var m in defaultMacro) {
      if (tickersToScan.length < 10 && !tickersToScan.contains(m)) {
        tickersToScan.add(m);
      }
    }

    isRadarLoading = true;
    notifyListeners();

    try {
      final newCatalysts = await _sigmaService.getAgenticRadar(tickersToScan);

      // If we got new data and weren't at zero, increment count
      if (newCatalysts.isNotEmpty &&
          newCatalysts.length != catalystInsights.length) {
        unreadNotificationsCount +=
            (newCatalysts.length - catalystInsights.length)
                .clamp(0, 99)
                .toInt();
      } else if (catalystInsights.isEmpty && newCatalysts.isNotEmpty) {
        unreadNotificationsCount = newCatalysts.length;
      }

      catalystInsights = newCatalysts;
      await _saveRadarToCache(catalystInsights);
      _lastRadarFetch = DateTime.now();
    } catch (e) {
      dev.log('Error fetching catalyst radar: $e', name: 'SigmaProvider');
    } finally {
      isRadarLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSentiment({bool forceRefresh = false}) async {
    if (!forceRefresh && sentimentData != null) return;

    isSentimentLoading = true;
    notifyListeners();

    try {
      final res = await _sentimentService.fetchFearGreed();
      if (res != null) {
        sentimentData = res;
      }
    } catch (e) {
      dev.log('Error fetching sentiment: $e', name: 'SigmaProvider');
    } finally {
      isSentimentLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String ticker) async {
    // The FavoritesService will notify via stream, which triggers loadFavorites() automatically.
    await FavoritesService().toggleFavorite(ticker.trim());
  }

  Future<void> searchByStrategy(String strategy) async {
    isSearching = true; // Use the same loader for consistency
    searchResults = [];
    notifyListeners();
    try {
      final results = await _sigmaService.searchTickersByStrategy(strategy);
      // Map results to the search result format
      searchResults = results
          .map((r) => {
                'symbol': r['symbol'],
                'description': r['name'] ?? r['companyName'] ?? '',
                'price': r['price'] ?? 0.0,
                'change': r['change'] ?? 0.0,
                'source': 'AI_STRATEGY',
              })
          .toList();
    } catch (e) {
      dev.log('Error searchByStrategy: $e', name: 'SigmaProvider');
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  bool isFavorite(String ticker) =>
      favoriteTickers.contains(ticker.trim().toUpperCase());

  Future<void> fetchMarketMovers() async {
    if (marketOverview == null) await fetchMarketOverview();
  }

  Future<void> fetchTrendingSymbols() async {
    if (marketOverview == null) await fetchMarketOverview();
  }

  void resetAnalysis() {
    currentAnalysis = null;
    currentTicker = null;
    error = null;
    isAnalysisLoading = false;
    notifyListeners();
  }

  Future<void> updateSearchResults(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      _searchRequestId++;
      searchResults = [];
      isSearching = false;
      notifyListeners();
      return;
    }

    final localResults = _localSearchResults(normalized);
    if (localResults.isNotEmpty) {
      searchResults = localResults;
      isSearching = true;
      notifyListeners();
    }

    // 0. Check local cache for instant results
    if (_searchCache.containsKey(normalized)) {
      searchResults = _searchCache[normalized]!;
      isSearching = false;
      notifyListeners();
      // Even if cached, we still run the background fetch to update prices/logos
      // but we don't block the UI.
    }

    final requestId = ++_searchRequestId;
    isSearching = true;
    notifyListeners();

    try {
      // Unified backend + Finnhub fallback search.
      List<Map<String, dynamic>> searchResultsUnified;
      if (_searchCache.containsKey(normalized)) {
        searchResultsUnified = _searchCache[normalized]!;
      } else {
        searchResultsUnified = await _sigmaService
            .searchTickerSymbolsUnified(normalized)
            .catchError((_) => <Map<String, dynamic>>[]);

        // Save to cache
        if (searchResultsUnified.isNotEmpty) {
          _searchCache[normalized] = searchResultsUnified;
        }
      }

      if (requestId != _searchRequestId) return;

      bool isEligibleTicker(String symbol) {
        // Keep primary listed instruments and common TSX suffixes.
        final s = symbol.toUpperCase();
        return RegExp(r'^[A-Z]{1,6}(\.(TO|V))?$').hasMatch(s);
      }

      bool isEligibleType(Map<String, dynamic> item) {
        final t = (item['type'] ?? item['typeDisp'] ?? item['quoteType'] ?? '')
            .toString()
            .toUpperCase();
        if (t.isEmpty) return true;
        return t.contains('EQUITY') ||
            t.contains('ETF') ||
            t.contains('ADR') ||
            t.contains('REIT') ||
            t.contains('FUND');
      }

      int venuePenalty(Map<String, dynamic> item) {
        final venue = (item['stockExchange'] ??
                item['exchangeShortName'] ??
                item['exchange'] ??
                '')
            .toString()
            .toUpperCase();
        if (venue.contains('NASDAQ') || venue.contains('NYSE')) return 0;
        if (venue.contains('TSX') || venue.contains('TORONTO')) return 1;
        if (venue.contains('AMEX') || venue.contains('ARCA')) return 2;
        if (venue.isEmpty) return 3;
        return 4;
      }

      int rankItem(Map<String, dynamic> item) {
        final symbol = (item['symbol'] ?? '').toString().toUpperCase();
        final name = (item['name'] ?? item['description'] ?? '')
            .toString()
            .toLowerCase();
        final q = normalized.toUpperCase();
        final qLower = normalized.toLowerCase();
        if (symbol == q) return 0 + venuePenalty(item);
        if (symbol.startsWith(q)) return 5 + venuePenalty(item);
        if (name.startsWith(qLower)) return 10 + venuePenalty(item);
        if (symbol.contains(q)) return 15 + venuePenalty(item);
        if (name.contains(qLower)) return 20 + venuePenalty(item);
        return 30 + venuePenalty(item);
      }

      final institutionals = searchResultsUnified.where((item) {
        final symbol = (item['symbol'] ?? '').toString().toUpperCase();
        if (symbol.isEmpty) return false;
        return isEligibleTicker(symbol) && isEligibleType(item);
      }).toList();

      final baseList =
          institutionals.isNotEmpty ? institutionals : searchResultsUnified;

      final sorted = [...baseList]
        ..sort((a, b) => rankItem(a).compareTo(rankItem(b)));

      final Map<String, Map<String, dynamic>> mergedResults = {};
      final Set<String> seenIdentity = <String>{};
      final List<String> symbolsToQuote = [];

      String canonicalSymbol(String symbol) {
        return symbol
            .toUpperCase()
            .trim()
            .replaceAll(RegExp(r'\.(TO|V|PA|DE|MI|MC|LS|AS|BR|L|SW)$'), '');
      }

      // 1) Build results immediately (autocomplete UX first).
      for (final item in sorted.take(16)) {
        final symbol = (item['symbol'] ?? '').toString().toUpperCase();
        if (symbol.isEmpty) continue;
        final mapped = _mapToSearchItem(item, symbol);
        final identity =
            '${canonicalSymbol(symbol)}|${(mapped['description'] ?? '').toString().toLowerCase()}';
        if (!seenIdentity.contains(identity) &&
            !mergedResults.containsKey(symbol)) {
          seenIdentity.add(identity);
          mergedResults[symbol] = mapped;
          symbolsToQuote.add(symbol);
        }
      }

      if (requestId != _searchRequestId) return;

      searchResults = mergedResults.values.toList();
      _searchCache[normalized] =
          searchResults; // Update cache with mapped items
      isSearching = false;
      notifyListeners();

      // 2) Hydrate prices + logos asynchronously (keep UI responsive).
      if (symbolsToQuote.isNotEmpty) {
        final hydrateSymbols = symbolsToQuote.take(20).toList();
        final hydrateResults = await Future.wait([
          _sigmaService.marketDataService
              .getQuotes(hydrateSymbols)
              .catchError((_) => <dynamic>[]),
          Future.wait(hydrateSymbols.map(
            (symbol) async {
              final logo = await _sigmaService.marketDataService
                  .getLogo(symbol)
                  .catchError((_) => <String, dynamic>{});
              return {'symbol': symbol, 'logo': logo};
            },
          )),
        ]);

        final quotes = hydrateResults[0] as List<dynamic>;
        final logoResults = hydrateResults[1] as List<dynamic>;

        if (requestId != _searchRequestId) return;
        for (final quote in quotes) {
          final s = quote['symbol']?.toString().toUpperCase();
          if (s != null && mergedResults.containsKey(s)) {
            mergedResults[s]!['price'] = quote['price'] ?? 0.0;
            mergedResults[s]!['change'] = quote['change'] ?? 0.0;
            mergedResults[s]!['changePercent'] =
                quote['changesPercentage'] ?? 0.0;
            final quoteLogo =
                (quote['logoUrl'] ?? quote['image'] ?? quote['logo'])
                    ?.toString()
                    .trim();
            if (quoteLogo != null && quoteLogo.isNotEmpty) {
              final logo = LogoResolver.resolve(s, providedUrl: quoteLogo);
              mergedResults[s]!['logoUrl'] = logo;
              mergedResults[s]!['logo'] = logo;
            }
          }
        }
        for (final row in logoResults) {
          if (row is! Map) continue;
          final s = row['symbol']?.toString().toUpperCase();
          final logoData = row['logo'];
          if (s != null &&
              mergedResults.containsKey(s) &&
              logoData is Map<String, dynamic>) {
            final logo = LogoResolver.resolve(
              s,
              providedUrl: logoData['logoUrl']?.toString(),
            );
            mergedResults[s]!['logoUrl'] = logo;
            mergedResults[s]!['logo'] = logo;
            if (logoData['logoUrls'] != null) {
              mergedResults[s]!['logoUrls'] = logoData['logoUrls'];
            }
          }
        }
      }

      if (requestId != _searchRequestId) return;
      searchResults = mergedResults.values.toList();
      notifyListeners();
    } catch (e) {
      dev.log('âŒ Global Search Convergence Failure: $e',
          name: 'SigmaProvider');
      if (requestId == _searchRequestId) {
        searchResults = [];
      }
    } finally {
      if (requestId == _searchRequestId) {
        isSearching = false;
        notifyListeners();
      }
    }
  }

  List<Map<String, dynamic>> _localSearchResults(String query) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return [];
    final matches = _quickSearchUniverse.where((item) {
      final symbol = item['symbol'] ?? '';
      final name = (item['name'] ?? '').toUpperCase();
      return symbol.startsWith(q) || symbol.contains(q) || name.contains(q);
    }).toList()
      ..sort((a, b) {
        final sa = a['symbol'] ?? '';
        final sb = b['symbol'] ?? '';
        final ra = sa == q ? 0 : (sa.startsWith(q) ? 1 : 2);
        final rb = sb == q ? 0 : (sb.startsWith(q) ? 1 : 2);
        if (ra != rb) return ra.compareTo(rb);
        return sa.compareTo(sb);
      });

    return matches.take(8).map<Map<String, dynamic>>((item) {
      final symbol = item['symbol']!;
      return <String, dynamic>{
        'symbol': symbol,
        'description': item['name'],
        'displaySymbol': symbol,
        'stockExchange': item['exchange'],
        'exchangeShortName': item['exchange'],
        'type': symbol == 'SPY' ||
                symbol == 'QQQ' ||
                symbol == 'DIA' ||
                symbol == 'IWM'
            ? 'ETF'
            : 'EQUITY',
        'logoUrl': LogoResolver.resolve(symbol),
        'logo': LogoResolver.resolve(symbol),
        'source': 'LOCAL',
      };
    }).toList();
  }

  List<Map<String, dynamic>> instantSearchResults(String query) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return const [];

    final merged = <String, Map<String, dynamic>>{};
    for (final item in _localSearchResults(q)) {
      final symbol = (item['symbol'] ?? '').toString().toUpperCase();
      if (symbol.isNotEmpty) merged[symbol] = item;
    }
    for (final item in searchResults) {
      final symbol = (item['symbol'] ?? '').toString().toUpperCase();
      final name =
          (item['description'] ?? item['name'] ?? '').toString().toUpperCase();
      if (symbol.isEmpty) continue;
      if (symbol.startsWith(q) || symbol.contains(q) || name.contains(q)) {
        merged[symbol] = item;
      }
    }

    final list = merged.values.toList(growable: false)
      ..sort((a, b) {
        int rank(Map<String, dynamic> item) {
          final symbol = (item['symbol'] ?? '').toString().toUpperCase();
          final name = (item['description'] ?? item['name'] ?? '')
              .toString()
              .toUpperCase();
          if (symbol == q) return 0;
          if (symbol.startsWith(q)) return 1;
          if (name.startsWith(q)) return 2;
          if (symbol.contains(q)) return 3;
          if (name.contains(q)) return 4;
          return 5;
        }

        final cmp = rank(a).compareTo(rank(b));
        if (cmp != 0) return cmp;
        return (a['symbol'] ?? '').toString().compareTo(
              (b['symbol'] ?? '').toString(),
            );
      });
    return list.take(8).toList(growable: false);
  }

  Map<String, dynamic> _mapToSearchItem(
      Map<String, dynamic> item, String symbol) {
    // Search API field names
    String name =
        item['name'] ?? item['longName'] ?? item['shortName'] ?? symbol;
    String exch = item['stockExchange'] ??
        item['exchangeShortName'] ??
        item['exchange'] ??
        '';

    final directLogo =
        (item['logo'] ?? item['logoUrl'] ?? item['image'])?.toString().trim();
    final logo = LogoResolver.resolve(symbol, providedUrl: directLogo);

    return {
      'symbol': symbol,
      'description': name,
      'displaySymbol': symbol,
      'stockExchange': exch,
      'type': item['typeDisp'] ?? item['quoteType'] ?? 'EQUITY',
      'logoUrl': logo,
      'logo': logo,
      'source': 'SIGMA',
    };
  }

  Future<void> analyzeTicker(
    String ticker, {
    dynamic resolvedSymbol,
    bool forceRefresh = false,
  }) async {
    final cleanTicker = ticker.toUpperCase().trim();
    if (cleanTicker.isEmpty) return;

    // Check cache first if not forcing refresh
    if (!forceRefresh && _analysisCache.containsKey(cleanTicker)) {
      final cached = _analysisCache[cleanTicker]!;
      if (!_isAnalysisFresh(cached)) {
        _analysisCache.remove(cleanTicker);
      } else {
        currentAnalysis = cached;
        currentTicker = cleanTicker;
        chartHistory = [];
        chartCandles = [];
        isAnalysisLoading = false;
        notifyListeners();

        // Prefetch charts in background
        _prefetchCharts(cleanTicker);

        // Update price in background without blocking UI
        _updatePriceAndCharts(cleanTicker);

        return;
      }
    }

    // Reset current state immediately to force loader to show
    currentAnalysis = null;
    currentTicker = cleanTicker;
    chartHistory = [];
    chartCandles = [];
    isAnalysisLoading = true;
    error = null;
    loadingMessage = 'Connecting to market data...';
    loadingProgress = 0.05;
    notifyListeners();

    Timer? progressTimer;
    try {
      if (!recentSearches.contains(cleanTicker)) {
        recentSearches.insert(0, cleanTicker);
        if (recentSearches.length > 10) recentSearches.removeLast();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('recent_searches', recentSearches);
      }

      loadingProgress = 0.2;
      loadingMessage = 'Searching analyst perspectives...';
      notifyListeners();

      // Start chart fetching and intelligence in parallel with AI analysis for speed
      final chartFuture = _prefetchCharts(cleanTicker);
      final intelFuture = fetchTickerIntelligence(cleanTicker);

      loadingProgress = 0.35;
      loadingMessage = 'Fetching financial statements...';
      notifyListeners();

      // DYNAMIC PROGRESS SIMULATION (Smoother UX)
      double simulatedProgress = 0.35;
      progressTimer =
          Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (loadingProgress >= 0.98) {
          timer.cancel();
          return;
        }
        // Quadratic slowdown as we approach 98% to account for AI variability
        double increment = 0.012 * (1.0 - loadingProgress);
        simulatedProgress += increment;
        loadingProgress = simulatedProgress;
        notifyListeners();
      });

      final analysis = await _sigmaService
          .analyzeStock(
        cleanTicker,
        language: language ?? 'EN',
      )
          .timeout(
        const Duration(seconds: 180), // 3 minutes max
        onTimeout: () {
          throw TimeoutException(
            language == 'FR'
                ? 'L\'analyse a pris trop de temps. Veuillez rÃ©essayer.'
                : 'Analysis timed out. Please try again.',
          );
        },
      );

      progressTimer.cancel();

      // VÃ©rifier si l'analyse est valide (pas un fallback d'erreur)
      if (analysis.confidence == 0.0 && analysis.sigmaScore == 50.0) {
        // Fallback analysis: keep it visible instead of hard-failing the screen.
        dev.log(
          'âš ï¸ Fallback analysis detected for $cleanTicker, displaying degraded result.',
          name: 'SigmaProvider',
        );
      }

      // Save to cache
      await _saveAnalysisToCache(analysis);

      loadingProgress = 0.75;
      loadingMessage = 'Building institutional research view...';
      notifyListeners();

      // Wait for charts (already running in parallel, should be done)
      try {
        loadingProgress = 0.85;
        loadingMessage = 'Generating price charts...';
        notifyListeners();

        await chartFuture;
        if (chartHistory.isEmpty) {
          for (final fallbackRange in ['6M', '1M', '5D']) {
            await fetchChartData(fallbackRange);
            if (chartHistory.isNotEmpty) break;
          }
        }
      } catch (e) {
        dev.log('Chart Generation Error: $e', name: 'SigmaProvider');
      }

      if (currentTicker != cleanTicker) return;

      loadingProgress = 0.95;
      loadingMessage = 'Compiling intelligence report...';
      notifyListeners();

      currentAnalysis = analysis;
      notifyListeners();

      // Index analysis in RAG for semantic memory
      _ragService?.indexAnalysis(analysis);

      // Index high-signal news articles
      if (analysis.companyNews.isNotEmpty) {
        for (final news in analysis.companyNews) {
          _ragService?.indexNews(analysis.ticker, news);
        }
      }

      // Run backtest + streaming synthesis in parallel for speed
      _streamSynthesis(analysis, language ?? 'EN');
      updateBacktestPeriod('MAX', analysis: analysis).catchError((_) {});

      // Warm up range analyses silenty
      _prewarmPeriodAnalyses(analysis);
    } catch (e) {
      dev.log('âŒ Analysis Error for $cleanTicker: $e', name: 'SigmaProvider');
      if (currentTicker == cleanTicker) {
        final currentLanguage = language ?? 'EN';
        try {
          currentAnalysis = await _buildRawFallbackAnalysis(
            cleanTicker,
            currentLanguage,
          );
        } catch (fallbackError) {
          dev.log(
            'âš ï¸ Raw fallback analysis also failed for $cleanTicker: $fallbackError',
            name: 'SigmaProvider',
          );
          currentAnalysis = AnalysisData.fromJson({
            'ticker': cleanTicker,
            'companyName': cleanTicker,
            'companyProfile': currentLanguage == 'FR'
                ? 'Analyse en mode secours: certaines sources sont indisponibles.'
                : 'Fallback analysis mode: some sources are currently unavailable.',
            'lastUpdated': DateTime.now().toIso8601String(),
            'price': 'N/A',
            'verdict': currentLanguage == 'FR' ? 'ATTENDRE' : 'HOLD',
            'verdictReasons': [
              currentLanguage == 'FR'
                  ? 'Connexion instable aux fournisseurs de donnees.'
                  : 'Unstable connection to data providers.'
            ],
            'riskLevel': currentLanguage == 'FR' ? 'MOYEN' : 'MEDIUM',
            'sigmaScore': 50,
            'confidence': 0.0,
            'summary': currentLanguage == 'FR'
                ? 'Le moteur principal a echoue avant consolidation complete. Ce resultat de secours est affiche pour eviter un ecran vide; relancez pour recuperer le rapport complet.'
                : 'The primary engine failed before full consolidation. This fallback result is shown to avoid a blank screen; retry to get a complete report.',
            'pros': [],
            'cons': [],
            'hiddenSignals': [],
            'catalysts': [],
            'volatility': {
              'ivRank': 'N/A',
              'beta': 'N/A',
              'interpretation': 'N/A',
            },
            'fearAndGreed': {
              'score': 50,
              'label': currentLanguage == 'FR' ? 'NEUTRE' : 'NEUTRAL',
              'interpretation': 'N/A',
            },
            'marketSentiment': {
              'score': 50,
              'label': currentLanguage == 'FR' ? 'NEUTRE' : 'NEUTRAL',
            },
            'tradeSetup': {
              'entryZone': 'N/A',
              'targetPrice': 'N/A',
              'stopLoss': 'N/A',
              'riskRewardRatio': 'N/A',
            },
            'institutionalActivity': {
              'smartMoneySentiment': 0.5,
              'retailSentiment': 0.5,
              'darkPoolInterpretation': 'N/A',
            },
            'technicalAnalysis': [],
            'projectedTrend': [],
            'financialMatrix': [],
            'sectorPeers': [],
            'topSources': [],
            'analystRecommendations': {},
            'actionPlan': [
              currentLanguage == 'FR'
                  ? 'Relancer l\'analyse quand les APIs sont stables.'
                  : 'Retry analysis when APIs are stable.'
            ],
          });
        }
        error = null;
      }
    } finally {
      progressTimer?.cancel();
      if (currentTicker == cleanTicker) {
        isAnalysisLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _streamSynthesis(AnalysisData analysis, String lang) async {
    try {
      isSynthesisStreaming = true;
      notifyListeners();

      final stream = _sigmaService.streamAnalysisSynthesis(
        analysis: analysis,
        language: lang,
      );
      final guardedStream = stream.timeout(
        // 119B model TTFT ≈ 50-90s + generation time. Guard raised to 180s.
        const Duration(seconds: 180),
        onTimeout: (sink) {
          sink.close();
        },
      );

      // Throttle UI rebuilds: only notify every 8 chunks to avoid
      // marking InheritedWidget dependents dirty while a layout pass
      // (from a prior rebuild) is still executing, which caused the
      // !_debugDoingThisLayout cascade on Consumer<SigmaProvider> inside
      // layout-builder subtrees.
      String fullText = '';
      int chunkCount = 0;
      await for (final chunk in guardedStream) {
        if (currentTicker != analysis.ticker) break;
        fullText += chunk;
        chunkCount++;
        if (currentAnalysis != null && chunkCount % 8 == 0) {
          currentAnalysis = currentAnalysis!.copyWith(summary: fullText);
          notifyListeners();
        }
      }
      // Final flush with complete text.
      if (currentAnalysis != null && fullText.isNotEmpty) {
        currentAnalysis = currentAnalysis!.copyWith(summary: fullText);
        notifyListeners();
      }
    } catch (e) {
      dev.log('Streaming synthesis failed: $e', name: 'SigmaProvider');
    } finally {
      isSynthesisStreaming = false;
      notifyListeners();
    }
  }

  /// Pre-fetch chart data in parallel with the AI analysis call to save time
  Future<void> _prefetchCharts(String ticker) async {
    try {
      await fetchChartData('1Y');
    } catch (e) {
      dev.log('Prefetch charts error: $e', name: 'SigmaProvider');
    }
  }

  Future<void> fetchMarketOverview({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        marketOverview != null &&
        _lastMarketFetch != null &&
        DateTime.now().difference(_lastMarketFetch!) < _marketCacheTtl) {
      return;
    }
    isMarketLoading = true;
    notifyListeners();
    try {
      final overview = await _sigmaService.getMarketOverview(
        language: language ?? 'EN',
        favoriteTickers: favoriteTickers,
      );
      final bool isNewDataEmpty =
          overview.sectors.isEmpty && (overview.insiderTrades?.isEmpty ?? true);

      if (marketOverview != null && isNewDataEmpty) {
        dev.log('âš ï¸ Network overview is empty, preserving existing data.',
            name: 'SigmaProvider');
      } else {
        if (marketOverview != null &&
            overview.news.isEmpty &&
            marketOverview!.news.isNotEmpty) {
          // Preserve latest valid news feed when refresh returns partial payload.
          marketOverview = MarketOverview(
            marketRegime: overview.marketRegime,
            regimeDescription: overview.regimeDescription,
            vixLevel: overview.vixLevel,
            sectors: overview.sectors,
            lastUpdated: overview.lastUpdated,
            sentiment: overview.sentiment,
            sentimentValue: overview.sentimentValue,
            globalNews: overview.globalNews,
            vixValue: overview.vixValue,
            vixChange: overview.vixChange,
            vixChangePercent: overview.vixChangePercent,
            news: marketOverview!.news,
            macroIndicators: overview.macroIndicators,
            economicCalendar: overview.economicCalendar,
            topGainers: overview.topGainers,
            topLosers: overview.topLosers,
            yahooSummary: overview.yahooSummary,
            upcomingIpos: overview.upcomingIpos,
            notableEvents: overview.notableEvents,
            indicators: overview.indicators,
            sentimentNews: overview.sentimentNews,
            sentimentHistory: overview.sentimentHistory,
            insiderTrades: overview.insiderTrades,
            backtest: overview.backtest,
            sentimentComponents: overview.sentimentComponents,
            sectorSentiment: overview.sectorSentiment,
          );
        } else {
          marketOverview = overview;
        }
        await _saveMarketToCache(overview);
      }
      _lastMarketFetch = DateTime.now();
      error = null;

      // Parallel fetch for deep sentiment data (Radar)
      fetchSentiment(forceRefresh: forceRefresh);

      refreshMacroIndicators();

      // DÃ©clencher l'enrichissement Neural UNIQUEMENT si non prÃ©sent
      if (marketIntelligence == null || forceRefresh) {
        _enrichNewsWithNeural(overview);
      }
    } catch (e) {
      dev.log('Market Overview Error: $e', name: 'SigmaProvider');
      // Do not override analysis rendering with a global market-sync error
      // when a ticker analysis is already available.
      if (currentAnalysis == null && !isAnalysisLoading) {
        error = "MARKET DATA SYNC FAILED: $e";
      }
    } finally {
      isMarketLoading = false;
      notifyListeners();
    }
  }

  /// Enrichit les news avec News Intelligence (NVIDIA > Neural > OpenRouter)
  Future<void> _enrichNewsWithNeural(MarketOverview overview) async {
    if (overview.news.isEmpty) return;

    isNewsEnriching = true;
    notifyListeners();

    try {
      final intelService = NewsIntelligenceService.tryCreate();
      if (intelService == null) return;

      final sp500Change = overview.yahooSummary
              ?.firstWhere((s) => s.symbol == '^GSPC',
                  orElse: () => YahooIndexSummary(
                        symbol: '',
                        name: '',
                        price: 0,
                        change: 0,
                        changePercent: 0,
                      ))
              .changePercent ??
          0.0;

      final intel = await intelService
          .analyzeMarketNews(
            news: overview.news,
            date: overview.lastUpdated,
            vix: double.tryParse(overview.vixLevel) ?? 0,
            sp500Change: sp500Change,
            language: language ?? 'EN',
          )
          .timeout(const Duration(seconds: 45));

      marketIntelligence = intel;
      dev.log('â—† News Intelligence done (${intel.enrichedNews.length} items)',
          name: 'SigmaProvider');
    } catch (e) {
      dev.log('Ollama enrichment error: $e', name: 'SigmaProvider');
    } finally {
      isNewsEnriching = false;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String lang) async {
    if (language == lang) return;

    // Clear all language-dependent caches
    _analysisCache.clear();
    marketOverview = null;
    _lastMarketFetch = null;

    language = lang;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);

    // Explicitly clear disk cache if needed (optional but safer)
    final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }

    if (currentTicker != null) {
      final ticker = currentTicker!;
      currentTicker = null;
      await analyzeTicker(ticker, forceRefresh: true);
    } else {
      await fetchMarketOverview(forceRefresh: true);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await prefs.setString('theme_mode', val);
  }

  Future<void> refreshMacroIndicators() async {
    try {
      final macroData = await _sigmaService.marketDataService.getMacroData();
      if (macroData.isNotEmpty && marketOverview != null) {
        final newMacro = MacroIndicators(
          treasury10Y: (macroData['tnx']?['price'] as num?)?.toDouble() ??
              marketOverview!.macroIndicators?.treasury10Y ??
              0.0,
          dollarIndex: (macroData['dxy']?['price'] as num?)?.toDouble() ??
              marketOverview!.macroIndicators?.dollarIndex ??
              0.0,
          goldPrice: (macroData['gold']?['price'] as num?)?.toDouble() ??
              marketOverview!.macroIndicators?.goldPrice ??
              0.0,
          oilPrice: (macroData['oil']?['price'] as num?)?.toDouble() ??
              marketOverview!.macroIndicators?.oilPrice ??
              0.0,
        );

        marketOverview = MarketOverview(
          marketRegime: marketOverview!.marketRegime,
          regimeDescription: marketOverview!.regimeDescription,
          vixLevel: marketOverview!.vixLevel,
          sectors: marketOverview!.sectors,
          lastUpdated: DateTime.now().toIso8601String(),
          news: marketOverview!.news,
          macroIndicators: newMacro,
          topGainers: marketOverview!.topGainers,
          topLosers: marketOverview!.topLosers,
          yahooSummary: marketOverview!.yahooSummary,
          economicCalendar: marketOverview!.economicCalendar,
          upcomingIpos: marketOverview!.upcomingIpos,
          sentiment: marketOverview!.sentiment,
          sentimentValue: marketOverview!.sentimentValue,
          globalNews: marketOverview!.globalNews,
          vixValue: marketOverview!.vixValue,
          vixChange: marketOverview!.vixChange,
          vixChangePercent: marketOverview!.vixChangePercent,
          notableEvents: marketOverview!.notableEvents,
          indicators: marketOverview!.indicators,
          sentimentNews: marketOverview!.sentimentNews,
          sentimentHistory: marketOverview!.sentimentHistory,
          insiderTrades: marketOverview!.insiderTrades,
        );
        notifyListeners();
      }
    } catch (e) {
      dev.log('Error refreshing macro indicators: $e', name: 'SigmaProvider');
    }
  }

  Future<void> updateBacktestPeriod(
    String period, {
    AnalysisData? analysis,
  }) async {
    final targetAnalysis = analysis ?? currentAnalysis;
    if (targetAnalysis == null) return;

    final ticker = targetAnalysis.ticker;
    isBacktestLoading = true;
    notifyListeners();

    try {
      const reader = YahooFinanceDailyReader();
      DateTime? startDate;
      final now = DateTime.now();

      if (period == '1Y') {
        startDate = DateTime(now.year - 1, now.month, now.day);
      } else if (period == '2Y') {
        startDate = DateTime(now.year - 2, now.month, now.day);
      } else if (period == '5Y') {
        startDate = DateTime(now.year - 5, now.month, now.day);
      }

      final response = await reader.getDailyDTOs(ticker, startDate: startDate);
      if (response.candlesData.isEmpty) return;

      final List<YahooFinanceCandleData> prices = response.candlesData;
      chartCandles = prices;

      if (prices.length > 1) {
        final first = prices.first;
        final last = prices.last;

        final years = prices.length / 252.0;
        final totalReturn = (last.close / first.close);
        final cagrCount =
            (math.pow(totalReturn.toDouble(), 1.0 / (years > 0 ? years : 1.0)) -
                    1) *
                100;

        double maxMdd = 0;
        double peakValue = 0;
        for (var candle in prices) {
          if (candle.close > peakValue) peakValue = candle.close.toDouble();
          final dd =
              peakValue > 0 ? (peakValue - candle.close) / peakValue : 0.0;
          if (dd > maxMdd) maxMdd = dd.toDouble();
        }

        targetAnalysis.backtest = TechnicalBacktest(
          cagr: cagrCount.toDouble(),
          maxDrawdown: maxMdd * 100,
          totalReturn: (totalReturn.toDouble() - 1) * 100,
          period: period,
        );
      }
    } catch (e) {
      dev.log('Error calculating backtest: $e', name: 'SigmaProvider');
    } finally {
      isBacktestLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchChartData(String range) async {
    if (currentTicker == null) return;

    final requestedTicker = currentTicker!.toUpperCase();

    chartRange = range;
    isChartLoading = true;
    notifyListeners();

    try {
      final interval = _getIntervalForRange(range);
      final apiRange = _getApiRange(range);

      final data = await _sigmaService.marketDataService.getHistoricalOHLCV(
        requestedTicker,
        apiRange,
      );

      if (currentTicker?.toUpperCase() != requestedTicker) return;
      chartHistory = data;

      if (currentAnalysis != null &&
          currentAnalysis!.ticker.toUpperCase() == requestedTicker &&
          _periodAnalysesCache['${requestedTicker}_$range'] == null) {
        _fetchAndAnalyzeRange(currentAnalysis!, range);
      }
    } catch (e) {
      dev.log('Chart Fetch Error: $e', name: 'SigmaProvider');
      chartHistory = [];
    } finally {
      isChartLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchChartDataForTicker(String ticker, String range) async {
    final cleanTicker = ticker.trim().toUpperCase();
    if (cleanTicker.isEmpty) return;
    currentTicker = cleanTicker;
    await fetchChartData(range);
  }

  String _getIntervalForRange(String range) {
    switch (range) {
      case '1D':
        return '5m';
      case '5D':
        return '15m';
      case '1M':
      case '3M':
      case '6M':
      case 'YTD':
      case '1Y':
        return '1d';
      case '5Y':
        return '1wk';
      case 'MAX':
        return '1mo';
      default:
        return '1d';
    }
  }

  String _getApiRange(String range) {
    switch (range) {
      case '1M':
        return '1mo';
      case '6M':
        return '6mo';
      case 'MAX':
        return 'max';
      case '1D':
        return '1d';
      case '5D':
        return '5d';
      default:
        return range.toLowerCase();
    }
  }

  /// Update only price and charts for a ticker (expensive AI analysis skipped)
  Future<void> _updatePriceAndCharts(String ticker) async {
    try {
      // 1. Update price from Sigma API
      final quote = await _sigmaService.marketDataService.getQuoteMap(ticker);
      if (quote.isNotEmpty &&
          currentAnalysis != null &&
          currentAnalysis!.ticker == ticker) {
        final newPrice = quote['price']?.toString() ?? currentAnalysis!.price;
        final newChange = (quote['changePercent'] as num?)?.toDouble() ??
            currentAnalysis!.changePercent;

        // Update model in memory/state
        currentAnalysis = currentAnalysis!.copyWith(
          price: newPrice,
          changePercent: newChange,
        );
        notifyListeners();
      }

      // 2. Update Charts
      await fetchChartData('1Y');
    } catch (e) {
      dev.log('Background update error: $e', name: 'SigmaProvider');
    }
  }

  /// Pre-calculate common period analyses for instant navigation
  Future<void> _prewarmPeriodAnalyses(AnalysisData contextData) async {
    final ranges = ['1M', '3M', '6M', 'YTD', '1Y'];
    for (final r in ranges) {
      if (_periodAnalysesCache.containsKey('${contextData.ticker}_$r'))
        continue;
      _fetchAndAnalyzeRange(contextData, r);
    }
  }

  Future<void> _fetchAndAnalyzeRange(
      AnalysisData contextData, String range) async {
    try {
      final interval = _getIntervalForRange(range);
      final apiRange = _getApiRange(range);

      final data = await _sigmaService.marketDataService
          .getHistoricalOHLCV(contextData.ticker, apiRange);
      if (data.isNotEmpty) {
        final analysis = await _sigmaService.analyzeHistoricalRange(
            contextData, data, range,
            language: (language ?? 'FR') == 'FR' ? 'FRANÃ‡AIS' : 'ENGLISH');
        _periodAnalysesCache['${contextData.ticker}_$range'] = analysis;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchTickerIntelligence(String ticker) async {
    try {
      isIntelligenceLoading = true;
      notifyListeners();

      currentIntelligence = await _engineService.getTickerIntelligence(ticker);
    } catch (e) {
      dev.log('Intelligence Fetch Error: $e', name: 'SigmaProvider');
    } finally {
      isIntelligenceLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDailyCreamReport() async {
    try {
      isDailyCreamLoading = true;
      notifyListeners();
      dailyCreamReport = await _engineService.generateDailyCreamReport();
    } catch (e) {
      dev.log('Daily Cream Fetch Error: $e', name: 'SigmaProvider');
    } finally {
      isDailyCreamLoading = false;
      notifyListeners();
    }
  }
}
