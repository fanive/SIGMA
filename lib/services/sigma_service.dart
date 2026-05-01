// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures, invalid_null_aware_operator, prefer_interpolation_to_compose_strings, prefer_is_empty, unnecessary_cast, unused_local_variable, use_rethrow_when_possible, dead_null_aware_expression
import 'dart:convert';
import 'dart:math' as math;
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/sigma_models.dart';
import '../config/ai_config.dart';
import 'ai_provider_interface.dart';
import 'ai_provider_factory.dart';
import 'fmp_service.dart';
import 'web_search_service.dart';
import 'sentiment_service.dart';
import 'ai/fallback_provider.dart';
import 'ollama_news_service.dart';
import 'openinsider_service.dart';

class SigmaService {
  late AIProvider _stockProvider;
  late AIProvider _marketProvider;
  late AIProvider? _deepReasoningProvider; // DeepSeek R1 for deep analysis
  final FmpService _fmp = FmpService();
  final WebSearchService _webSearch = WebSearchService();
  final SentimentService _sentiment = SentimentService();
  final OpenInsiderService _openInsider = OpenInsiderService();

  // Agentic Memory: Stores the last market context to enable cross-context reasoning
  MarketOverview? _lastOverview;

  // Exposer les services pour un accès direct
  FmpService get fmpService => _fmp;
  OpenInsiderService get openInsiderService => _openInsider;

  static SigmaService fromEnv() {
    final service = SigmaService._();
    service._initFromEnv();
    return service;
  }

  void reset() {
    WebSearchService.clearCache();
    _initFromEnv();
    dev.log('🔄 SigmaService Providers Re-initialized', name: 'SigmaService');
  }

  void _initFromEnv() {
    try {
      final ollamaKey = dotenv.env['OLLAMA_API_KEY'] ?? '';
      final ollamaModel = dotenv.env['OLLAMA_MODEL'] ?? '';
      final ollamaBaseUrl =
          dotenv.env['OLLAMA_BASE_URL'] ?? AIConfig.ollamaBaseUrl;

      final nvidiaKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
      final hasNvidia = nvidiaKey.isNotEmpty && !nvidiaKey.contains('example');

      final hasOllama = ollamaKey.isNotEmpty && ollamaModel.isNotEmpty;

      // ── DYNAMISME DES PRIORITÉS ───────────────────────────────────────────
      String primaryChoice =
          (dotenv.env['PRIMARY_AI_PROVIDER'] ?? 'nvidia').toLowerCase();

      // Auto-correct potential typos in .env
      if (primaryChoice.contains('nviddia')) primaryChoice = 'nvidia';
      if (primaryChoice.contains('nvidia')) primaryChoice = 'nvidia';

      final List<String> priorityChain = primaryChoice == 'ollama'
          ? ['ollama', 'nvidia']
          : ['nvidia', 'ollama'];

      print(
          '⚙️ [SigmaService] Initializing with priority chain: $priorityChain');

      // ── CRÉATION DE LA CHAÎNE DE PROVIDERS ───────────────────────────────
      final List<AIProvider> stockChain = [];
      final List<AIProvider> marketChain = [];

      final stockModelFromEnv = dotenv.env['STOCK_MODEL'];
      final nvidiaReportModelOverride = dotenv.env['NVIDIA_REPORT_MODEL'];
      final ollamaReportModel =
          dotenv.env['OLLAMA_REPORT_MODEL'] ?? dotenv.env['OLLAMA_MODEL'];
      final marketModelFromEnv = dotenv.env['MARKET_MODEL'];

      for (var p in priorityChain) {
        try {
          if (p == 'nvidia' && hasNvidia) {
            // Align Analysis AI model selection with Research Report logic.
            final model = nvidiaReportModelOverride ??
                stockModelFromEnv ??
                AIConfig.defaultNvidiaModel;
            stockChain.add(AIProviderFactory.createStockProvider(
              provider: AIConfig.providerNvidia,
              apiKey: nvidiaKey,
              modelKey: model,
            ));

            final mModel = marketModelFromEnv ?? AIConfig.defaultNvidiaModel;
            marketChain.add(AIProviderFactory.createMarketProvider(
              provider: AIConfig.providerNvidia,
              apiKey: nvidiaKey,
              modelKey: mModel,
            ));
          } else if (p == 'ollama' && hasOllama) {
            final model = ollamaReportModel ?? stockModelFromEnv ?? ollamaModel;
            stockChain.add(AIProviderFactory.createStockProvider(
              provider: AIConfig.providerOllama,
              apiKey: ollamaKey,
              modelKey: model,
              baseUrlOverride: ollamaBaseUrl,
            ));

            final mModel = marketModelFromEnv ?? ollamaModel;
            marketChain.add(AIProviderFactory.createMarketProvider(
              provider: AIConfig.providerOllama,
              apiKey: ollamaKey,
              modelKey: mModel,
              baseUrlOverride: ollamaBaseUrl,
            ));
          }
        } catch (e) {
          dev.log('⚠️ [SigmaService] Failed to init provider $p: $e');
        }
      }

      _stockProvider = FallbackProvider(stockChain);
      _marketProvider = FallbackProvider(marketChain);

      if (stockChain.isEmpty || marketChain.isEmpty) {
        dev.log(
          '⚠️ [SigmaService] No AI providers initialized. Check API keys and PRIMARY_AI_PROVIDER in .env',
          name: 'SigmaService',
        );
      }

      // Choose deep reasoning provider
      try {
        if (hasNvidia) {
          _deepReasoningProvider = AIProviderFactory.createStockProvider(
            provider: AIConfig.providerNvidia,
            apiKey: nvidiaKey,
            modelKey: 'llama3.3-70b',
          );
        } else {
          _deepReasoningProvider = hasOllama
              ? AIProviderFactory.createStockProvider(
                  provider: AIConfig.providerOllama,
                  apiKey: ollamaKey,
                  modelKey: ollamaModel,
                  baseUrlOverride: ollamaBaseUrl,
                )
              : null;
        }
      } catch (e) {
        dev.log('⚠️ [SigmaService] Failed to init deep reasoning: $e');
        _deepReasoningProvider = null;
      }

      // --- DEBUG LOGGING ---
      final fmpKey = dotenv.env['FMP_API_KEY'] ?? 'MISSING';
      dev.log(
          '🔑 [SigmaService] FMP Key check: ${fmpKey.length > 4 ? fmpKey.substring(0, 4) + '...' : fmpKey}',
          name: 'SigmaService');
      dev.log('📊 [SigmaService] Initialization Complete',
          name: 'SigmaService');
    } catch (e) {
      print('❌ [SigmaService] FATAL INIT ERROR: $e');
    }
  }

  SigmaService._();

  static const String _systemInstructionChat = '''
Tu es l'Intelligence Artificielle SIGMA — expert analyste financier et assistant omniscient de haute-précision.
RÉPONDS TOUJOURS DANS LA LANGUE DE L'UTILISATEUR AVEC UN TON PROFESSIONNEL ET SOBRE.
DATE ACTUELLE: 16 AVRIL 2026.
Toute information datant de 2024 ou 2025 est considérée comme HISTORIQUE et non actuelle.
''';

  String _getSystemInstructionStock(String language) {
    final bool isFr = language.toUpperCase().startsWith('FR');
    if (isFr) {
      return r'''
Tu es le moteur d'analyse de SIGMA, une plateforme d'intelligence financière institutionnelle.
Réponds EXCLUSIVEMENT en FRANÇAIS.

MISSION TECHNIQUE :
Tu DOIS réaliser une analyse fondamentale et technique rigoureuse basée sur les données fournies.
Analyse particulièrement la rentabilité, la solidité du bilan et les tendances de marché.

### STRUCTURE DE RÉFLEXION :
1. **Analyse Macro** : Impact du régime de marché actuel sur le titre.
2. **Analyse Fondamentale** : Évaluation des flux de trésorerie et des ratios de valorisation.
3. **Analyse Technique** : Interprétation de la tendance et des indicateurs de momentum.
4. **Sentiment & Flux** : Analyse du sentiment social et des mouvements des initiés.

RÈGLE CRITIQUE POUR "agenticThoughts" ET "hiddenSignals" :
Ces sections DOIVENT être à très haute densité (high-signal). Interdiction absolue d'utiliser du remplissage conversationnel (fluff) ou des généralités. Sois chirurgical, direct, et apporte un véritable "Alpha". Rédige sous forme de notes de hedge fund quantitatif (ex: "Flux massifs sur le dark pool détéctés à 15h, divergence baissière RSI/Prix ignorée par le marché retail").

Tu DOIS impérativement suivre la STRUCTURE JSON demandée dans le PROMPT à la fin du message utilisateur.
Ne réponds QUE par le JSON, sans commentaire avant ou après.
''';
    } else {
      return r'''
You are the 'SIGMA RESEARCH ORCHESTRATOR', coordinating a committee of world-class financial agents.
You must respond EXCLUSIVELY in ENGLISH.

### YOUR MISSION:
Synthesize the debate between these agents. If the Technicals are bullish but the Macro is RISK-OFF, you MUST reflect this tension in the verdict. Provide "Alpha-level" insights that a regular investor would miss.

CRITICAL RULE FOR "agenticThoughts" AND "hiddenSignals":
These sections MUST be high-signal. Do NOT use conversational filler, generic fluff, or basic observations. Be surgical, direct, and provide real "Alpha". Write them as terse quantitative hedge fund notes (e.g. "Massive dark pool prints detected at key resistance, retail market ignoring RSI bearish divergence").

You MUST strictly follow the JSON STRUCTURE requested in the PROMPT at the end of the user message.
Respond ONLY with the JSON, no preamble or commentary.
''';
    }
  }

  String _getSystemInstructionMarket(String language) {
    final bool isFr = language.toUpperCase().startsWith('FR');
    if (isFr) {
      return r'''
Tu es le Chief Investment Officer de SIGMA. Fournis une analyse macroéconomique mondiale UNIQUE.
Réponds EXCLUSIVEMENT en FRANÇAIS au format JSON.
''';
    } else {
      return r'''
You are the Chief Investment Officer of SIGMA. Provide a UNIQUE global macroeconomic analysis.
You must respond EXCLUSIVELY in ENGLISH in JSON format.
''';
    }
  }

  String _getSystemInstructionSynthesis(String language) {
    if (language.toUpperCase().startsWith('FR')) {
      return '''
Tu es l'analyste principal de SIGMA. Ta mission est de rédiger une synthèse stratégique institutionnelle.
RÈGLES CRITIQUES :
- RÉPONDS EXCLUSIVEMENT EN FRANÇAIS.
- INTERDICTION ABSOLUE DE RÉPONDRE EN ANGLAIS.
- INTERDICTION DE COMMENCER PAR "Voici le résumé..." OU "D'après les données...". Entre directement dans le vif du sujet.
- ÉCRIS EN TEXTE BRUT (PARAGRAPHES).
- STYLE : Direct, analytique, de haute finance.
''';
    } else {
      return '''
You are the primary analyst at SIGMA. Your mission is to write an institutional strategic synthesis.
CRITICAL RULES:
- RESPOND EXCLUSIVELY IN ENGLISH.
- DO NOT RESPOND IN JSON UNDER ANY CIRCUMSTANCES.
- WRITE IN PLAIN TEXT (PARAGRAPHS).
- STYLE: Direct, analytical, high-level corporate finance.
''';
    }
  }

  Future<AnalysisData> analyzeStock(
    String ticker, {
    String language = 'FRANÇAIS',
  }) async {
    final bool isFr = language.toUpperCase().startsWith('FR');
    final String targetLanguage = isFr ? 'FRANÇAIS' : 'ENGLISH';

    final symbol = ticker.toUpperCase().trim();
    final now = DateTime.now();
    final currentDate = now.toIso8601String().split('T')[0];

    // ── 1. AGENTIC WEB SEARCH (ALPHA) ──────────────────────────────────────────
    // On lance une recherche web en parallèle pour enrichir le contexte
    final webSearchTask =
        _webSearch.search('$symbol stock latest news catalysts $currentDate');

    // ── 2. ACQUISITION DE DONNÉES EN PARALLÈLE (OPTIMISÉ) ──────────────────────
    // On groupe les appels par provider pour maximiser le parallélisme réseau utile
    final results = await Future.wait([
      // Flux Core (FMP & Yahoo prioritaires)
      _safeCall(() => _fmp.getFmpContext(symbol), "",
          timeout: const Duration(seconds: 10)), // 0
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 1
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 2

      // Flux Sentiment & News (Non-critical, fast fail)
      _safeCall(() => Future.value(""), "",
          timeout: const Duration(seconds: 1)), // 3
      _safeCall(() => Future.value(null), null,
          timeout: const Duration(seconds: 1)), // 4

      // Flux Technique & On-Chain (Non-critical, fast fail)
      _safeCall(() => Future.value(""), "",
          timeout: const Duration(seconds: 1)), // 5
      _safeCall(() => Future.value(""), "",
          timeout: const Duration(seconds: 1)), // 6

      // Grouped into quoteSummary above
      _safeCall(() => Future.value([]), [],
          timeout: const Duration(seconds: 1)), // 7
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 8
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 9
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 10
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 11
      _safeCall(() => Future.value([]), [],
          timeout: const Duration(seconds: 1)), // 12
      _safeCall(() => Future.value([]), [],
          timeout: const Duration(seconds: 1)), // 13
      _safeCall(() => webSearchTask, "",
          timeout: const Duration(seconds: 10)), // 14
      _safeCall(() => _sentiment.fetchFearGreed(), null,
          timeout: const Duration(seconds: 6)), // 15
      _safeCall(() => _sentiment.fetchNews(), [],
          timeout: const Duration(seconds: 6)), // 16
      _safeCall(
          () => _fmp
              .getPeers(symbol)
              .then((list) => _fmp.getFullQuotes(list.take(5).toList())),
          [],
          timeout: const Duration(seconds: 10)), // 17

      // MULTI-SOURCE NEWS AGGREGATION (Fast fail)
      _safeCall(() => _fmp.getStockNews(symbol, limit: 10), [],
          timeout: const Duration(seconds: 8)), // 18
      _safeCall(() => Future.value(<dynamic>[]), [],
          timeout: const Duration(seconds: 1)), // 19
      _safeCall(() => Future.value(<dynamic>[]), [],
          timeout: const Duration(seconds: 1)), // 20
      _safeCall(() => Future.value(null), null,
          timeout: const Duration(seconds: 1)), // 21

      // Grouped into quoteSummary above
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 22
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 23
      _safeCall(() => Future.value([]), [],
          timeout: const Duration(seconds: 1)), // 24
      _safeCall(() => Future.value({}), {},
          timeout: const Duration(seconds: 1)), // 25

      // RAPIDAPI — Enrichment Pipeline (disabled)
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 26
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 27
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 28
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 29
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 30

      // ALPHA VANTAGE (disabled)
      _safeCall(() => Future.value(<String, dynamic>{}), {},
          timeout: const Duration(seconds: 1)), // 31

      // LEGACY FLOWS (Merged for parallelism)
      _safeCall(() => _fmp.getCompanyProfileStable(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 8)), // 32
      _safeCall(() => _fmp.getKeyMetricsTTM(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 8)), // 33
      _safeCall(() => _fmp.getRatiosTTM(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 8)), // 34
      _safeCall(() => _fmp.getInstitutionalHolders(symbol), <dynamic>[],
          timeout: const Duration(seconds: 8)), // 35
      _safeCall(() => _fmp.getInsiderTrading(symbol), <dynamic>[],
          timeout: const Duration(seconds: 8)), // 36
      _safeCall(() => _fmp.getIncomeStatement(symbol, limit: 5), <dynamic>[],
          timeout: const Duration(seconds: 8)), // 37
      _safeCall(() => _fmp.getQuoteMap(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 8)), // 38
      _getMultiSourcePrice(symbol), // 39
    ]);

    final fmpContext = results[0] as String;
    final yBundle = results[1] as Map<String, dynamic>;
    final ySummary = results[2] as Map<String, dynamic>;
    final marketauxContext = results[3] as String;
    final peersDataList = results[17] as List<dynamic>;

    // ── RapidAPI Enrichment Extraction ──────────────────────────────────────
    final saRatings = results[26] as Map<String, dynamic>;
    final saMetrics = results[27] as Map<String, dynamic>;
    final mboumStats = results[28] as Map<String, dynamic>;
    final mboumUpgrades = results[29] as Map<String, dynamic>;
    final mboumEarnings = results[30] as Map<String, dynamic>;

    final yahooStatsEnriched = mboumStats['body'] ?? mboumStats;
    final yahooUpgradesEnriched = mboumUpgrades['body'] ?? mboumUpgrades;
    final yahooEarningsEnriched = mboumEarnings['body'] ?? mboumEarnings;
    final alphaOverview =
        (results[31] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    // YH-Finance Conversations (Social Sentiment) — disabled (RapidAPI removed)
    final Map<String, dynamic> yahooConversations = {};

    // Construct Peer Context
    final peerContext = peersDataList
        .map((p) =>
            "- ${p['symbol']}: ${p['name']}, MCAP: ${p['marketCap']}, PE: ${p['pe']}")
        .join('\n');

    // ── NEWS AGGREGATION & NORMALIZATION ──────────────────────────────────────
    final fmpNews = results[18] as List<dynamic>;
    final finnhubNews = results[19] as List<dynamic>;
    final yahooNews = results[20] as List<dynamic>;
    final marketauxRaw = results[21] as Map<String, dynamic>?;
    final marketauxNews = marketauxRaw?['data'] as List? ?? [];

    final allNewsContext = [
      ...fmpNews.map((n) => "FMP: ${n['title']} | ${n['text']}"),
      ...finnhubNews.map((n) => "Finnhub: ${n['headline']} | ${n['summary']}"),
      ...yahooNews.map((n) => "Yahoo: ${n['title']} | ${n['summary']}"),
      ...marketauxNews
          .map((n) => "Marketaux: ${n['title']} | ${n['description']}"),
    ].take(30).join('\n---\n');

    // ── 3. CROSS-CONTEXT AGENTIC SYNTHESIS (BETA) ──────────────────────────────
    // Enriched Macro Context: Including live Fear & Greed metrics
    final fgData = results[15] as FearGreedData?;
    final fgNews = results[16] as List<SentimentNews>;
    String macroAwareness = "";
    if (_lastOverview != null || fgData != null) {
      final fgScore = fgData?.score ??
          (_lastOverview?.vixLevel != null
              ? (100 - (double.tryParse(_lastOverview!.vixLevel) ?? 20) * 2)
              : 50);
      final fgRating = fgData?.rating ?? "NEUTRAL";

      final fgNewsContext =
          fgNews.map((n) => "- ${n.title} (${n.publisher})").join('\n');

      macroAwareness = '''
Sentiment : ${_lastOverview?.sentiment ?? fgRating}
Niveau VIX : ${_lastOverview?.vixLevel ?? 'N/A'}
Focus Sectoriel : ${_lastOverview?.sectors.take(3).map((s) => s.name).join(', ') ?? 'N/A'}
---
SENTIMENT HEADLINES :
$fgNewsContext
''';
    }
    final social = results[4] as Map<String, dynamic>?;
    final twelveDataContext = results[5] as String;
    final polygonContext = results[6] as String;

    // Pull from batch instead of dummy indices
    final yInsiders =
        (ySummary['insiderTransactions']?['transactions'] as List?) ?? [];
    final yActions =
        (ySummary['calendarEvents'] as Map?)?.cast<String, dynamic>() ?? {};
    final yTargets =
        (ySummary['financialData'] as Map?)?.cast<String, dynamic>() ?? {};
    final yEsg = (ySummary['esgScores'] as Map?)?.cast<String, dynamic>() ?? {};
    final yHoldersRaw =
        results[11] as Map<String, dynamic>; // Placeholder index
    final yRecs = (ySummary['recommendationTrend']?['trend'] as List?) ?? [];
    final yUpgrades =
        (ySummary['upgradeDowngradeHistory']?['history'] as List?) ?? [];
    final webContext = results[14] as String;

    // Legacy results from merged batch
    final fmpProfileRaw = results[32] as Map<String, dynamic>;
    final fmpProfile = fmpProfileRaw;
    final fmpMetrics = results[33] as Map<String, dynamic>;
    final fmpRatios = results[34] as Map<String, dynamic>;
    final fmpHolders = results[35] as List<dynamic>;
    final fmpInsiderTrading = results[36] as List<dynamic>;
    final fmpIncome = results[37] as List<dynamic>;
    final finnhubBasic = results[38] as Map<String, dynamic>;
    final realTimePrice = results[39] as Map<String, dynamic>;

    // Reconstruction des variables manquantes à partir des données groupées
    final yahooProfile =
        (ySummary['assetProfile'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final yahooHolders = yHoldersRaw.isNotEmpty
        ? yHoldersRaw
        : (ySummary['majorHoldersBreakdown'] as Map?)
                ?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final yahooFinancialData =
        (ySummary['financialData'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final yahooTechnical =
        (ySummary['technicalInsights'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final yahooTickerInfo =
        (ySummary['defaultKeyStatistics'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    // Merge summaryDetail + financialData into KeyStatistics source (dividends, 52W range, margins, growth)
    final summaryDetail =
        (ySummary['summaryDetail'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    for (final key in [
      'dividendYield',
      'dividendRate',
      'fiveYearAvgDividendYield',
      'payoutRatio',
      'fiftyTwoWeekHigh',
      'fiftyTwoWeekLow',
      'fiftyDayAverage',
      'twoHundredDayAverage',
      'trailingAnnualDividendYield',
      'priceToBook'
    ]) {
      if (summaryDetail.containsKey(key) && !yahooTickerInfo.containsKey(key)) {
        yahooTickerInfo[key] = summaryDetail[key];
      }
    }
    for (final key in [
      'earningsGrowth',
      'operatingMargins',
      'profitMargins',
      'returnOnEquity',
      'returnOnAssets',
      'revenueGrowth',
      'freeCashflow',
      'operatingCashflow'
    ]) {
      if (yahooFinancialData.containsKey(key) &&
          !yahooTickerInfo.containsKey(key)) {
        yahooTickerInfo[key] = yahooFinancialData[key];
      }
    }
    final yahooEarningsHistory =
        (ySummary['earningsHistory']?['history'] as List?) ?? [];
    final yahooEsg = yEsg;
    final yahooActions = yActions;
    final yahooYfinanceBundle = yBundle;

    // REAL DATA ENFORCEMENT: Income Statement & Upgrades
    final List<dynamic> yIncomeRaw = (ySummary['incomeStatementHistory']
            ?['incomeStatementHistory'] as List?) ??
        [];

    // Convert Yahoo Income to FMP-style for compatibility
    final List<Map<String, dynamic>> yHistoricalFinancials =
        yIncomeRaw.map((e) {
      final date = (e['endDate'] as Map?)?['fmt'] ?? 'N/A';
      return {
        'date': date,
        'revenue': (e['totalRevenue'] as Map?)?['raw'] ?? 0,
        'netIncome': (e['netIncome'] as Map?)?['raw'] ?? 0,
        'eps': (e['netIncome'] as Map?)?['raw'] != null
            ? 0.0
            : 0.0, // Calculated later if needed
      };
    }).toList();

    // (Unified results logic above)

    final prompt1 = '''
### RAPPORT D'ANALYSE FINANCIÈRE INSTITUTIONNELLE : $symbol
Date : $currentDate | Langue : $language

### DONNÉES BRUTES (yfinance-data & Institutional Feed)
- PROFIL: ${_limitTokens(jsonEncode(yahooProfile), 2500)}
- CORPORATE: ${_limitTokens(jsonEncode(fmpProfile), 3500)}
- PEERS (COMPETITORS):
$peerContext
- ACTIONS CORPO: ${_limitTokens(jsonEncode(yActions), 1500)} (Dividendes, Splits)
- INSIDERS: ${_limitTokens(jsonEncode(yInsiders.take(10).toList()), 2500)}
- ANALYST TARGETS: ${jsonEncode(yTargets)}
- RECOMMENDATIONS: ${jsonEncode(yRecs)}
- ESG SCORES: ${jsonEncode(yEsg)}
- HOLDERS: ${_limitTokens(jsonEncode(yahooHolders), 2000)}
- SEEKING ALPHA RATINGS: ${_limitTokens(jsonEncode(saRatings), 1500)}
- SEEKING ALPHA METRICS: ${_limitTokens(jsonEncode(saMetrics), 2000)}
- KEY STATISTICS (ENHANCED): ${_limitTokens(jsonEncode(yahooStatsEnriched), 2000)}
- EARNINGS (ENHANCED): ${_limitTokens(jsonEncode(yahooEarningsEnriched), 2000)}
- UPGRADES/DOWNGRADES (ENHANCED): ${_limitTokens(jsonEncode(yahooUpgradesEnriched), 1500)}
- ALPHA VANTAGE OVERVIEW: ${_limitTokens(jsonEncode(alphaOverview), 2500)}
- MACRO: $macroAwareness
- NEWS SOURCES:
$allNewsContext
- WEB SEARCH: ${_limitTokens(webContext, 5000)}

### MISSION CRITIQUE : SEPA® EVALUATION
Tu DOIS évaluer si ce titre respecte le "SEPA Trend Template" de Mark Minervini (Stage 2 Uptrend).
Critères : 
1. Prix > 50MA > 150MA > 200MA (Bullish stacking).
2. 200MA en pente ascendante.
3. Prix > 30% du point bas sur 52 semaines.
4. Relative Strength (RS) > 70.

MISSION FINALE : Génère un rapport d'analyse EXTRÊMEMENT DÉTAILLÉ ET RIGOUREUX en $targetLanguage.
RÈGLES : Pas de markdown, JSON strict uniquement. UTILISE TOUTES LES DONNÉES. NE LAISSE RIEN VIDE. S'il n'y a pas de donnée, estime un "social sentiment" ou "institutional activity" basé sur l'actualité et le macro.

STRUCTURE JSON (STRICTE) :
{
  "ticker": "$symbol",
  "companyName": "...",
  "sector": "...",
  "industry": "...",
  "ceo": "...",
  "website": "...",
  "image": "URL du logo",
  "companyProfile": "Description complète",
  "businessModel": "...",
  "revenueStreams": "...",
  "verdict": "ACHAT | VENTE | ATTENTE",
  "verdictReasons": ["Raison 1", "Raison 2"],
  "riskLevel": "FAIBLE | MOYEN | ÉLEVÉ",
  "sigmaScore": 85,
  "confidence": 0.85,
  "summary": "Un résumé clair, digeste et percutant (environ 100-150 mots) qui explique ce que fait l'entreprise, son business model, et exactement comment elle génère ses revenus. Le but est qu'un investisseur comprenne immédiatement si le modèle économique l'intéresse.",
  "pros": [{"point": "Point fort", "analysis": "Détail"}],
  "cons": [{"point": "Risque", "analysis": "Détail"}],
  "catalysts": [{"type": "MOTEUR | RISQUE", "headline": "...", "insight": "..."}],
  "actionPlan": ["Etape 1", "Etape 2"],
  "financialMatrix": [{"label": "...", "value": "...", "assessment": "..."}],
  "technicalAnalysis": [{"indicator": "...", "value": "...", "interpretation": "..."}],
  "supports": ["Prix 1", "Prix 2"],
  "resistances": ["Prix 1", "Prix 2"],
  "projectedTrend": [{"date": "T+1", "price": 0.0, "signal": "..."}],
  "socialSentiment": {"redditSentiment": 0.0, "twitterSentiment": 0.0, "mentions": 0},
  "hiddenSignals": [{"type": "...", "headline": "...", "insight": "..."}],
  "agenticThoughts": ["Pensée Agent Bull Case", "Pensée Agent Risk Vector"],
  "insiderBuyRatio": 0.5,
  "esgScore": 0.0-100.0,
  "isin": "...",
  "targetPriceValue": 0.0,
  "sectorPeers": [{"ticker": "...", "name": "...", "marketCap": "...", "peRatio": 0.0}],
  "volatility": {"yearlyLow": 0.0, "yearlyHigh": 0.0, "beta": 0.0},
  "fearAndGreed": {"score": 50.0, "rating": "..."},
  "marketSentiment": {"sentiment": "...", "score": 0.0},
  "tradeSetup": {"setupType": "...", "entrySignal": "...", "profitTarget": 0.0, "stopLoss": 0.0},
  "institutionalActivity": {"smartMoneySentiment": 0.5, "netInstitutionalBuying": "..."},
  "analystRatings": [{"rating": "BUY | HOLD | SELL", "analyst": "...", "date": "..."}],
  "keyStatistics": {"trailingPE": 0.0, "forwardPE": 0.0, "marketCap": 0, "dividendYield": 0.0, "returnOnEquity": 0.0, "debtToEquity": 0.0},
  "corporateEvents": [{"event": "...", "date": "...", "impact": "..."}],
  "companyNews": [
    {
      "title": "Titre rigoureux",
      "source": "Source",
      "url": "URL",
      "publishedAt": "ISO Date",
      "summary": "Résumé de HAUTE DENSITÉ (au moins 3 lignes complètes) expliquant les implications stratégiques."
    }
  ]
}

SPECIFIC RULE FOR NEWS:
Tu dois impérativement dédoubler les nouvelles provenant des différentes sources.
Chaque article dans "companyNews" (5 à 8 articles) doit avoir un "summary" d'au moins 3 lignes. 
Si le résumé original est court, utilise tes capacités d'analyse pour l'étoffer avec le contexte du titre et tes connaissances du marché.
La section NEWS doit être la pièce maîtresse du rapport, fournissant des insights profonds et non de simples titres.
''';

    final apiBackedFallback = AnalysisData.fromJson({
      'ticker': symbol,
      'companyName': _getValidString([
        fmpProfileRaw['companyName'],
        ySummary['quoteType']?['longName'],
        symbol,
      ]),
      'companyProfile': _getValidString([
        fmpProfileRaw['description'],
        yahooProfile['longBusinessSummary'],
        isFr
            ? 'Analyse générée depuis les APIs marché (mode sans synthèse IA).'
            : 'Analysis generated directly from market APIs (no AI synthesis mode).',
      ]),
      'lastUpdated': DateTime.now().toIso8601String(),
      'price': _formatPrice(realTimePrice['price']),
      'verdict': isFr ? 'ATTENDRE' : 'HOLD',
      'verdictReasons': [
        isFr
            ? 'Synthèse IA indisponible; rapport construit depuis les données API brutes.'
            : 'AI synthesis unavailable; report built from raw API data.',
      ],
      'riskLevel': isFr ? 'MOYEN' : 'MEDIUM',
      'sigmaScore': 55,
      'confidence': 0.45,
      'summary': isFr
          ? 'Rapport de secours enrichi par APIs: prix, profil société, métriques clés, news et contexte marché sont intégrés malgré l’indisponibilité du moteur IA.'
          : 'API-enriched fallback report: price, company profile, key metrics, news, and market context are included despite AI engine unavailability.',
      'pros': [],
      'cons': [],
      'hiddenSignals': [],
      'catalysts': [],
      'volatility': {
        'ivRank': 'N/A',
        'beta': (_extractRaw(yahooTickerInfo['beta']) ?? 'N/A').toString(),
        'interpretation': 'API',
      },
      'fearAndGreed': {
        'score': (fgData?.score ?? 50).toDouble(),
        'label': fgData?.rating ?? (isFr ? 'NEUTRE' : 'NEUTRAL'),
        'interpretation': 'API',
      },
      'marketSentiment': {
        'score': (fgData?.score ?? 50).toDouble(),
        'label': fgData?.rating ?? (isFr ? 'NEUTRAL' : 'NEUTRAL'),
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
        'darkPoolInterpretation': 'API fallback',
      },
      'technicalAnalysis': [],
      'projectedTrend': [],
      'financialMatrix': [
        {
          'label': isFr ? 'CAPITALISATION BOURS.' : 'MARKET CAP.',
          'value': _formatLargeNumber(
            _extractRaw(yahooTickerInfo['marketCap']) ??
                fmpProfileRaw['mktCap'] ??
                0,
          ),
          'assessment': 'API',
        },
        {
          'label': 'P/E RATIO',
          'value': (_extractRaw(yahooTickerInfo['trailingPE']) ??
                  fmpProfileRaw['pe'] ??
                  'N/A')
              .toString(),
          'assessment': 'API',
        },
        {
          'label': 'ROE',
          'value': (_extractRaw(yahooTickerInfo['returnOnEquity']) ??
                  yahooFinancialData['returnOnEquity'] ??
                  'N/A')
              .toString(),
          'assessment': 'API',
        },
      ],
      'sectorPeers': (peersDataList)
          .take(6)
          .map((p) => {
                'ticker': (p['symbol'] ?? '').toString(),
                'name': (p['name'] ?? '').toString(),
                'price': (p['price'] ?? 0).toString(),
                'verdict': isFr ? 'PAIR' : 'PEER',
                'confidence': 0.5,
                'profitabilityPotential': (p['change'] ?? 0).toString(),
                'marketCap': _formatLargeNumber(p['marketCap'] ?? 0),
                'peRatio': (p['pe'] ?? 0).toString(),
              })
          .toList(),
      'topSources': [],
      'analystRecommendations': {},
      'companyNews': [
        ...fmpNews.take(4).map((n) => {
              'title': (n['title'] ?? '').toString(),
              'source': 'FMP',
              'url': (n['url'] ?? '').toString(),
              'publishedAt': (n['publishedDate'] ?? '').toString(),
              'summary': (n['text'] ?? '').toString(),
            }),
        ...yahooNews.take(4).map((n) => {
              'title': (n['title'] ?? '').toString(),
              'source': 'Yahoo',
              'url': (n['link'] ?? n['url'] ?? '').toString(),
              'publishedAt': (n['providerPublishTime'] ?? '').toString(),
              'summary': (n['summary'] ?? '').toString(),
            }),
      ],
      'sector':
          _getValidString([fmpProfileRaw['sector'], yahooProfile['sector']]),
      'industry': _getValidString(
          [fmpProfileRaw['industry'], yahooProfile['industry']]),
      'website':
          _getValidString([fmpProfileRaw['website'], yahooProfile['website']]),
      'ceo': _getValidString([fmpProfileRaw['ceo']]),
      'image': _getValidString([fmpProfileRaw['image']]),
    });

    final resilientFallback = apiBackedFallback.ticker.isNotEmpty
        ? apiBackedFallback
        : _recoverFromBadJson(symbol, targetLanguage);

    String response1;
    try {
      response1 = await _stockProvider
          .generateContent(
            prompt: prompt1,
            systemInstruction: _getSystemInstructionStock(targetLanguage),
            jsonMode: true,
          )
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      dev.log('⚠️ Primary AI Stock Analysis failed, trying fallback: $e');
      if (_deepReasoningProvider != null) {
        try {
          response1 = await _deepReasoningProvider!
              .generateContent(
                prompt: prompt1,
                systemInstruction: _getSystemInstructionStock(targetLanguage),
                jsonMode: true,
              )
              .timeout(const Duration(seconds: 150));
        } catch (e2) {
          dev.log('❌ Fallback failed: $e2');
          response1 = jsonEncode(resilientFallback.toJson());
        }
      } else {
        response1 = jsonEncode(resilientFallback.toJson());
      }
    }

    AnalysisData data1;
    try {
      final decoded = jsonDecode(_cleanJsonResponse(response1));
      data1 = AnalysisData.fromJson(AnalysisData.parseMap(decoded));
    } catch (e) {
      data1 = resilientFallback;
    }

    // data2 comes from the same unified response
    Map<String, dynamic> data2;
    try {
      data2 = jsonDecode(_cleanJsonResponse(response1));
    } catch (e) {
      data2 = {};
    }

    // --- MERGE DES RÉSULTATS ---
    AnalysisData analysisData = data1.copyWith(
      historicalEarnings: fmpIncome,
      price: _formatPrice(realTimePrice['price']),
      socialSentiment: data2['socialSentiment'] != null
          ? SocialSentimentData.fromJson(
              AnalysisData.parseMap(data2['socialSentiment']),
            )
          : null,
      marketSentiment: data2['marketSentiment'] != null
          ? MarketSentiment.fromJson(
              AnalysisData.parseMap(data2['marketSentiment']),
            )
          : null,
      fearAndGreed: data2['fearAndGreed'] != null
          ? StockSentiment.fromJson(
              AnalysisData.parseMap(data2['fearAndGreed']),
            )
          : data1.fearAndGreed,
      tradeSetup: data2['tradeSetup'] != null
          ? TradeSetup.fromJson(AnalysisData.parseMap(data2['tradeSetup']))
          : data1.tradeSetup,
      projectedTrend: (data2['projectedTrend'] as List? ?? [])
          .map((x) => ProjectedTrendPoint.fromJson(AnalysisData.parseMap(x)))
          .toList(),
      technicalAnalysis: (data2['technicalAnalysis'] as List? ?? [])
          .map((x) => TechnicalIndicator.fromJson(AnalysisData.parseMap(x)))
          .toList(),
      hiddenSignals: (data2['hiddenSignals'] as List? ?? [])
          .map((x) => HiddenSignal.fromJson(AnalysisData.parseMap(x)))
          .toList(),
      isWebEnhanced: webContext.length > 20,
      webIntelligence: data1.webIntelligence,
      // Inject Corporate Identity (FMP primary, Yahoo fallback, AI final fallback)
      companyName: _getValidString([
        data1.companyName,
        fmpProfileRaw['companyName'],
        ySummary['quoteType']?['longName'],
        symbol
      ]),
      image: _getValidString([fmpProfileRaw['image'], data1.image]),
      sector: _getValidString(
          [fmpProfileRaw['sector'], yahooProfile['sector'], data1.sector]),
      industry: _getValidString([
        fmpProfileRaw['industry'],
        yahooProfile['industry'],
        data1.industry
      ]),
      ceo: _getValidString([fmpProfileRaw['ceo'], data1.ceo]),
      website: _getValidString(
          [fmpProfileRaw['website'], yahooProfile['website'], data1.website]),
      employees: AnalysisData.parseInt(fmpProfileRaw['fullTimeEmployees'] ??
          fmpProfileRaw['employees'] ??
          yahooProfile['fullTimeEmployees']),
      isin: _getValidString([fmpProfileRaw['isin'], data1.isin]),
      address: _getValidString([fmpProfileRaw['address'], data1.address]),
      city: _getValidString([fmpProfileRaw['city'], data1.city]),
      state: _getValidString([fmpProfileRaw['state'], data1.state]),
      country: _getValidString([fmpProfileRaw['country'], data1.country]),
      phone: _getValidString([fmpProfileRaw['phone'], data1.phone]),
      ipoDate: _getValidString([fmpProfileRaw['ipoDate'], data1.ipoDate]),
      exchangeFullName: _getValidString(
          [fmpProfileRaw['exchangeFullName'], data1.exchangeFullName]),
      exchange: _getValidString([fmpProfileRaw['exchange'], data1.exchange]),
      changePercent: (fmpProfileRaw['changePercentage'] as num?)?.toDouble() ??
          data1.changePercent,
    );

    // LOGO RECOVERY (FMP image-stock as primary free source)
    if (analysisData.image == null ||
        analysisData.image!.isEmpty ||
        analysisData.image!.contains('eodhd.com')) {
      analysisData = analysisData.copyWith(
        image: 'https://financialmodelingprep.com/image-stock/$symbol.png',
      );
    }

    // --- ENRICH DES DONNÉES BRUTES (YAHOO DIRECT - BATCH MODE) ---
    final yCalendar =
        (ySummary['calendarEvents'] as Map?)?.cast<String, dynamic>() ?? {};
    final yEarningsTrend =
        (ySummary['earningsTrend'] as Map?)?.cast<String, dynamic>() ?? {};
    final yInstitutionalHolders =
        (ySummary['institutionHolders']?['holders'] as List?) ?? [];
    final yFullOwnership =
        (ySummary['insiderHolders'] as Map?)?.cast<String, dynamic>() ?? {};

    analysisData = analysisData.copyWith(
      insiderTransactions: yInsiders
          .map((i) => InsiderTransaction.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
      analystRatings: yUpgrades
          .take(15)
          .map((r) => AnalystRating(
                date: (r['gradeDate'] as num?)?.toString() ?? 'N/A',
                firm: r['firm']?.toString() ?? 'N/A',
                action: r['action']?.toString() ?? 'INIT',
                rating: r['toGrade']?.toString() ?? 'N/A',
              ))
          .toList(),
      analystRecommendations: yRecs.isNotEmpty
          ? AnalystRecommendation.fromJson(
              Map<String, dynamic>.from(yRecs.first))
          : analysisData.analystRecommendations,
      historicalEarnings:
          yHistoricalFinancials.isNotEmpty ? yHistoricalFinancials : fmpIncome,
      esgScore: (yEsg['totalEsg'] as num?)?.toDouble() ?? analysisData.esgScore,
      targetPriceValue:
          (yTargets['targetMeanPrice']?['raw'] as num?)?.toDouble() ??
              analysisData.targetPriceValue,
      holders: yahooHolders.isNotEmpty
          ? HoldersData.fromJson(yahooHolders)
          : analysisData.holders,
      corporateEvents: [
        ...analysisData.corporateEvents,
        ...((yActions['dividends'] as Map?)?.entries.map((e) => CorporateEvent(
                  date: e.key.toString(),
                  event: 'DIVIDENDE',
                  description: 'Montant: \$${(e.value as Map)['amount']}',
                )) ??
            []),
      ],
      // NEW — yfinance Intelligence Pipeline
      earningsCalendar: yCalendar.isNotEmpty ? yCalendar : null,
      earningsTrend: yEarningsTrend.isNotEmpty ? yEarningsTrend : null,
      institutionalHolders: yInstitutionalHolders.isNotEmpty
          ? yInstitutionalHolders
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : null,
      fullOwnership: yFullOwnership.isNotEmpty ? yFullOwnership : null,
      rawInstitutionalData: jsonEncode({
        "mboumStatistics": yahooStatsEnriched,
        "mboumUpgrades": yahooUpgradesEnriched,
        "mboumEarnings": yahooEarningsEnriched,
        "seekingAlphaRatings": saRatings,
        "seekingAlphaMetrics": saMetrics,
        "alphaVantageOverview": alphaOverview,
        "yahooConversations": yahooConversations,
      }),
    );

    // Sequential Agentic Enrichment removed to improve performance.
    // Key insights now handled by primary model.

    // --- ENRICH DES DONNÉES BRUTES (YAHOO DIRECT) ---
    if (yahooProfile.containsKey('officers')) {
      final officersList = (yahooProfile['officers'] as List? ?? [])
          .map((o) => CompanyOfficer.fromJson(Map<String, dynamic>.from(o)))
          .toList();
      analysisData = analysisData.copyWith(officers: officersList);
    }

    // --- ENRICH HOLDERS (DIRECT DATA) ---
    if (yahooHolders.isNotEmpty) {
      analysisData = analysisData.copyWith(
        holders: HoldersData.fromJson(yahooHolders),
      );
    }

    // --- DATA ENFORCEMENT : FINANCIALS & TECHNICALS ---
    // On s'assure que les données récupérées directement via Yahoo sont prioritaires
    // ou complètent ce que l'IA a pu oublier ou mal formater.

    // 1. Key Statistics
    if (yahooTickerInfo.isNotEmpty) {
      analysisData = analysisData.copyWith(
        keyStatistics: KeyStatistics.fromJson(yahooTickerInfo),
        targetPriceValue: _extractRaw(
          yahooTickerInfo['targetMeanPrice'],
        )?.toDouble(),
        esgScore: _extractRaw(yahooEsg['totalEsg'])?.toDouble(),
      );
    }

    // 2. Financial Matrix Re-evaluation (Injecting real numbers into AI-generated items)
    final updatedMatrix = List<FinancialMatrixItem>.from(
      analysisData.financialMatrix,
    );
    void updateMetric(String label, dynamic value, {String? assessment}) {
      final index = updatedMatrix.indexWhere(
        (m) => m.label.toUpperCase().contains(label.toUpperCase()),
      );
      if (index != -1) {
        if (updatedMatrix[index].value == 'En attente...' ||
            updatedMatrix[index].value == 'N/A') {
          updatedMatrix[index] = FinancialMatrixItem(
            label: updatedMatrix[index].label,
            value: value?.toString() ?? 'N/A',
            assessment: assessment ?? updatedMatrix[index].assessment,
          );
        }
      } else if (value != null) {
        updatedMatrix.add(
          FinancialMatrixItem(
            label: label,
            value: value.toString(),
            assessment: assessment ?? 'NEUTRAL',
          ),
        );
      }
    }

    if (yahooTickerInfo.isNotEmpty) {
      updateMetric(
        'P/E Ratio',
        _extractRaw(yahooTickerInfo['trailingPE'])?.toStringAsFixed(2),
      );
      updateMetric(
        'Forward P/E',
        _extractRaw(yahooTickerInfo['forwardPE'])?.toStringAsFixed(2),
      );
      updateMetric(
        'ROE',
        '${((_extractRaw(yahooTickerInfo['returnOnEquity']) ?? 0) * 100).toStringAsFixed(2)}%',
      );
      updateMetric(
        'D/E Ratio',
        _extractRaw(yahooTickerInfo['debtToEquity'])?.toStringAsFixed(2),
      );
    }

    if (yahooFinancialData.isNotEmpty) {
      final fd = yahooFinancialData;
      updateMetric(
        'Total Revenue',
        _formatLargeNumber(_extractRaw(fd['totalRevenue']) ?? 0),
      );
      updateMetric(
        'EBITDA',
        _formatLargeNumber(_extractRaw(fd['ebitda']) ?? 0),
      );
      updateMetric(
        'Free Cashflow',
        _formatLargeNumber(_extractRaw(fd['freeCashflow']) ?? 0),
      );
      updateMetric(
        'Profit Margins',
        '${((_extractRaw(fd['profitMargins']) ?? 0) * 100).toStringAsFixed(2)}%',
      );
    }

    // 2.2 Key Stats Enforcement (Beta, Short Ratio, Volatilité)
    if (yahooTickerInfo.isNotEmpty) {
      updateMetric(
        'Beta (5Y)',
        _extractRaw(yahooTickerInfo['beta'])?.toStringAsFixed(2),
      );
      updateMetric(
        'Short Ratio',
        _extractRaw(yahooTickerInfo['shortRatio'])?.toStringAsFixed(2),
      );
      updateMetric(
        'Short % Float',
        '${((_extractRaw(yahooTickerInfo['shortPercentOfFloat']) ?? 0) * 100).toStringAsFixed(2)}%',
      );
    }

    if (yahooFinancialData.isNotEmpty) {
      final fd = yahooFinancialData;
      updateMetric(
        'Implied Vol (IV)',
        '${((_extractRaw(fd['impliedVolatility']) ?? 0) * 100).toStringAsFixed(2)}%',
      );
    }

    analysisData = analysisData.copyWith(financialMatrix: updatedMatrix);

    // 3. Technical Insights Enrichment
    if (yahooTechnical.isNotEmpty) {
      final List<TechnicalIndicator> techIndicators = List.from(
        analysisData.technicalAnalysis,
      );

      void addTech(String label, dynamic val, String interp) {
        if (val != null &&
            val != "" &&
            !techIndicators.any((ti) => ti.indicator == label)) {
          techIndicators.add(
            TechnicalIndicator(
              indicator: label,
              value: val.toString(),
              interpretation: interp,
            ),
          );
        }
      }

      addTech(
        'Short-term Trend',
        yahooTechnical['shortTermTrend'],
        'Trend is ${yahooTechnical['shortTermTrend']}',
      );
      addTech(
        'Intermediate Trend',
        yahooTechnical['intermediateTermTrend'],
        'Trend is ${yahooTechnical['intermediateTermTrend']}',
      );
      addTech(
        'Long-term Trend',
        yahooTechnical['longTermTrend'],
        'Trend is ${yahooTechnical['longTermTrend']}',
      );

      analysisData = analysisData.copyWith(
        technicalAnalysis: techIndicators,
        technicalInsights: yahooTechnical,
      );
    }

    // STATS & NEWS ENRICHMENT
    try {
      // 1. ACTUALITÉS MULTI-SOURCES (FMP only)
      try {
        List<Map<String, dynamic>> rawNews = [];

        // FMP news only
        final fmpNewsResult = await _fmp
            .getStockNews(symbol, limit: 15)
            .catchError((_) => <dynamic>[]);

        for (var n in fmpNewsResult) {
          rawNews.add({
            'title': n['title'],
            'source': n['site'] ?? 'FMP',
            'url': n['url'],
            'publishedAt': n['publishedDate'] ?? '',
            'summary': n['text'] ?? n['title'],
            'imageUrl': n['image'],
          });
        }

        // Déduplication par titre
        final seenTitles = <String>{};
        final newsArticles = <NewsArticle>[];
        for (var n in rawNews) {
          final title = n['title']?.toString() ?? '';
          if (title.isNotEmpty && !seenTitles.contains(title)) {
            seenTitles.add(title);
            newsArticles.add(NewsArticle.fromJson(n));
          }
        }

        // Sort by date descending before AI enrichment
        newsArticles.sort((a, b) {
          final da = DateTime.tryParse(a.publishedAt) ?? DateTime(1970);
          final db = DateTime.tryParse(b.publishedAt) ?? DateTime(1970);
          return db.compareTo(da);
        });

        if (newsArticles.isNotEmpty) {
          // --- AI ENRICHMENT (PHASE NEWS INTEL) ---
          if (targetLanguage.toUpperCase().startsWith('FR')) {
            try {
              final intelService = NewsIntelligenceService.tryCreate();
              if (intelService != null) {
                dev.log('🧠 Enriching Individual News with AI ($symbol)...');
                final marketIntel = await intelService.analyzeMarketNews(
                  news: newsArticles
                      .map((a) => {
                            'title': a.title,
                            'source': a.source,
                            'url': a.url,
                            'publishedAt': a.publishedAt,
                          })
                      .toList(),
                  date: DateTime.now().toIso8601String(),
                  language: 'FR',
                );

                // Map enriched back to NewsArticle
                final enrichedResults = <NewsArticle>[];
                for (var en in marketIntel.enrichedNews) {
                  // Find original to keep URL and Image
                  final original = newsArticles.firstWhere(
                    (a) =>
                        a.title.contains(en.title
                            .substring(0, math.min(10, en.title.length))) ||
                        en.title.contains(
                            a.title.substring(0, math.min(10, a.title.length))),
                    orElse: () => newsArticles.first,
                  );

                  enrichedResults.add(NewsArticle(
                    title: en.title,
                    source: en.source,
                    url: original.url,
                    publishedAt: original.publishedAt,
                    summary: en.insight, // THE 3-LINE ANALYSIS
                    imageUrl: original.imageUrl,
                  ));
                }

                if (enrichedResults.isNotEmpty) {
                  analysisData =
                      analysisData.copyWith(companyNews: enrichedResults);
                } else {
                  analysisData =
                      analysisData.copyWith(companyNews: newsArticles);
                }
              } else {
                analysisData = analysisData.copyWith(companyNews: newsArticles);
              }
            } catch (e) {
              dev.log('Individual News Intel Error: $e');
              analysisData = analysisData.copyWith(companyNews: newsArticles);
            }
          } else {
            analysisData = analysisData.copyWith(companyNews: newsArticles);
          }
        }
      } catch (e) {
        dev.log('Warning: Overall News enrichment process failed: $e');
      }

      // 2. KEY STATISTICS ENRICHMENT (FMP only)
      try {
        var keyStats = KeyStatistics.fromJson(<String, dynamic>{});

        // Enrich with FMP for better data coverage
        dev.log('Information: Enriching Key Stats and Profile for $symbol...');
        try {
          // Priority 1: FMP profile (primary source)
          if (fmpProfile.isNotEmpty) {
            final fmpMktCap = AnalysisData.parseNum(
              fmpProfile['marketCap'] ?? fmpProfile['mktCap'],
            );
            final fmpPe = AnalysisData.parseNum(
              fmpProfile['pe'] ?? fmpProfile['peRatio'],
            );
            final fmpBeta = AnalysisData.parseNum(fmpProfile['beta']);

            keyStats = keyStats.copyWith(
              marketCap:
                  keyStats.marketCap == 0 ? fmpMktCap : keyStats.marketCap,
              trailingPE:
                  keyStats.trailingPE == 0 ? fmpPe : keyStats.trailingPE,
              beta: keyStats.beta == 0 ? fmpBeta : keyStats.beta,
            );

            // Enrich structured profile with FMP data
            analysisData = analysisData.copyWith(
              employees: analysisData.employees ??
                  AnalysisData.parseNum(
                    fmpProfile['fullTimeEmployees'] ?? fmpProfile['employees'],
                  ).toInt(),
              website: analysisData.website ?? fmpProfile['website'] as String?,
              sector: analysisData.sector ?? fmpProfile['sector'] as String?,
              industry:
                  analysisData.industry ?? fmpProfile['industry'] as String?,
              address: analysisData.address ?? fmpProfile['address'] as String?,
              city: analysisData.city ?? fmpProfile['city'] as String?,
              state: analysisData.state ?? fmpProfile['state'] as String?,
              country: analysisData.country ?? fmpProfile['country'] as String?,
              ipoDate: fmpProfile['ipoDate'] as String?,
              phone: analysisData.phone ?? fmpProfile['phone'] as String?,
              exchange: fmpProfile['exchange'] as String?,
              exchangeFullName: fmpProfile['exchangeFullName'] as String?,
              ceo: fmpProfile['ceo'] as String?,
              image: fmpProfile['image'] as String?,
              companyName: analysisData.companyName ??
                  fmpProfile['companyName'] as String?,
            );
            // Update description if missing or short
            if (analysisData.companyProfile.length < 50) {
              if (fmpProfile['description'] != null) {
                analysisData = analysisData.copyWith(
                  companyProfile: fmpProfile['description'] as String,
                );
              }
            }
          }

          // Final Ticker Name Enforcement Fallback (Yahoo)
          if (analysisData.companyName == null ||
              analysisData.companyName!.isEmpty ||
              analysisData.companyName!.toUpperCase() == symbol.toUpperCase()) {
            final yName = ySummary['price']?['longName'] ??
                ySummary['price']?['shortName'] ??
                yahooYfinanceBundle['price']?['longName'] ??
                yahooYfinanceBundle['price']?['shortName'];
            if (yName != null) {
              analysisData =
                  analysisData.copyWith(companyName: yName.toString());
            }
          }

          // Priority 3: Enrich KeyStats with Financial Data captured earlier from Yahoo
          if (yahooFinancialData.isNotEmpty) {
            keyStats = keyStats.copyWith(
              profitMargins: keyStats.profitMargins == 0
                  ? AnalysisData.parseNum(yahooFinancialData['profitMargins'])
                  : keyStats.profitMargins,
              operatingMargins: keyStats.operatingMargins == 0
                  ? AnalysisData.parseNum(
                      yahooFinancialData['operatingMargins'],
                    )
                  : keyStats.operatingMargins,
              returnOnAssets: keyStats.returnOnAssets == 0
                  ? AnalysisData.parseNum(yahooFinancialData['returnOnAssets'])
                  : keyStats.returnOnAssets,
              returnOnEquity: keyStats.returnOnEquity == 0
                  ? AnalysisData.parseNum(yahooFinancialData['returnOnEquity'])
                  : keyStats.returnOnEquity,
              revenue: keyStats.revenue == 0
                  ? AnalysisData.parseNum(yahooFinancialData['totalRevenue'])
                  : keyStats.revenue,
              freeCashflow: keyStats.freeCashflow == 0
                  ? AnalysisData.parseNum(yahooFinancialData['freeCashflow'])
                  : keyStats.freeCashflow,
              totalDebt: keyStats.totalDebt == 0
                  ? AnalysisData.parseNum(yahooFinancialData['totalDebt'])
                  : keyStats.totalDebt,
              totalCash: keyStats.totalCash == 0
                  ? AnalysisData.parseNum(yahooFinancialData['totalCash'])
                  : keyStats.totalCash,
            );
          }

          if (fmpMetrics.isNotEmpty) {
            keyStats = keyStats.copyWith(
              returnOnEquity: keyStats.returnOnEquity == 0
                  ? AnalysisData.parseNum(fmpMetrics['roeTTM'])
                  : keyStats.returnOnEquity,
              returnOnAssets: keyStats.returnOnAssets == 0
                  ? AnalysisData.parseNum(fmpMetrics['roaTTM'])
                  : keyStats.returnOnAssets,
              debtToEquity: keyStats.debtToEquity == 0
                  ? AnalysisData.parseNum(fmpMetrics['debtToEquityTTM'])
                  : keyStats.debtToEquity,
              currentRatio: keyStats.currentRatio == 0
                  ? AnalysisData.parseNum(fmpMetrics['currentRatioTTM'])
                  : keyStats.currentRatio,
              profitMargins: keyStats.profitMargins == 0
                  ? AnalysisData.parseNum(fmpMetrics['netProfitMarginTTM'])
                  : keyStats.profitMargins,
              pegRatio: keyStats.pegRatio == 0
                  ? AnalysisData.parseNum(fmpMetrics['pegRatioTTM'])
                  : keyStats.pegRatio,
            );
          }
        } catch (e) {
          dev.log('Warning: FMP enrichment failed: $e');
        }

        dev.log('📊 FINAL ENRICHMENT RESULTS for $symbol:');
        dev.log('   Market Cap: ${keyStats.marketCap}');
        dev.log('   PE: ${keyStats.trailingPE}');
        dev.log('   Beta: ${keyStats.beta}');
        dev.log('   ROE: ${keyStats.returnOnEquity}');

        analysisData = analysisData.copyWith(keyStatistics: keyStats);
      } catch (e) {
        dev.log('Warning: Failed to enrich KeyStatistics: $e');
      }

      // 2.5 HOLDERS & INSIDERS ENRICHMENT (FMP FALLBACK)
      try {
        if (analysisData.holders == null ||
            analysisData.holders!.topInstitutions.isEmpty) {
          if (fmpHolders.isNotEmpty) {
            dev.log('Enriching holders with FMP data...');
            final institutions = fmpHolders.map((h) {
              return MajorHolder(
                organization: h['holder'] ?? h['name'] ?? 'Institution',
                pctHeld: (h['sharesByPercentage'] as num?)?.toDouble() ?? 0.0,
                position: (h['position'] as num?)?.toDouble() ?? 0.0,
                value: (h['marketValue'] as num?)?.toDouble() ?? 0.0,
                reportDate: h['dateReported'] ?? '',
              );
            }).toList();

            analysisData = analysisData.copyWith(
              holders: HoldersData(
                insidersPercent: 0,
                institutionsPercent: 0,
                institutionsCount: fmpHolders.length,
                topInstitutions: institutions,
                topFunds: [],
              ),
            );
          }
        }

        if (analysisData.insiderTransactions.isEmpty) {
          // PRIMARY FALLBACK: OpenInsider (free, complete SEC data)
          try {
            final oiData = await _openInsider.getTickerInsiderData(symbol);
            final oiTransactions =
                oiData['transactions'] as List<InsiderTransaction>? ?? [];
            if (oiTransactions.isNotEmpty) {
              dev.log(
                  '✅ Enriching insider transactions with OpenInsider data (${oiTransactions.length} txns)');
              analysisData = analysisData.copyWith(
                insiderTransactions: oiTransactions,
                insiderBuyRatio: oiData['insiderBuyRatio'] as double?,
              );
            }
          } catch (e) {
            dev.log('⚠️ OpenInsider ticker enrichment failed: $e');
          }

          // SECONDARY FALLBACK: FMP (limited free tier)
          if (analysisData.insiderTransactions.isEmpty &&
              fmpInsiderTrading.isNotEmpty) {
            dev.log('Enriching insider transactions with FMP data...');
            final transactions = fmpInsiderTrading.map((t) {
              return InsiderTransaction(
                name: t['ownerName'] ?? 'Insider',
                share: (t['securitiesTransacted'] ?? 0).toString(),
                change: (t['transactionType'] ?? ''),
                filingDate: t['filingDate'] ?? '',
                transactionDate: t['transactionDate'] ?? '',
                transactionPrice: (t['transactionPrice'] ?? 0).toString(),
              );
            }).toList();
            analysisData = analysisData.copyWith(
              insiderTransactions: transactions,
            );
          }
        }
      } catch (e) {
        dev.log('Warning: FMP Holders/Insiders enrichment failed: $e');
      }

      // 2.7 FINANCIAL MATRIX ENRICHMENT (FMP FALLBACK)
      try {
        if (fmpMetrics.isNotEmpty || fmpProfile.isNotEmpty) {
          final List<FinancialMatrixItem> updatedMatrix = List.from(
            analysisData.financialMatrix,
          );
          bool changed = false;

          for (int i = 0; i < updatedMatrix.length; i++) {
            final item = updatedMatrix[i];
            final label = item.label.toUpperCase();
            final isWaiting = item.value == 'En attente...' ||
                item.value == 'N/A' ||
                item.value.isEmpty;

            if (isWaiting) {
              if (label.contains('P/E') && fmpProfile['pe'] != null) {
                updatedMatrix[i] = item.copyWith(
                  value: (fmpProfile['pe'] as num).toStringAsFixed(2),
                );
                changed = true;
              } else if (label.contains('CAPITALISATION') &&
                  (fmpProfile['mktCap'] != null ||
                      fmpProfile['marketCap'] != null)) {
                updatedMatrix[i] = item.copyWith(
                  value: _formatLargeNumber(
                      fmpProfile['mktCap'] ?? fmpProfile['marketCap']),
                );
                changed = true;
              } else if (label.contains('BETA') && fmpProfile['beta'] != null) {
                updatedMatrix[i] = item.copyWith(
                  value: (fmpProfile['beta'] as num).toStringAsFixed(2),
                );
                changed = true;
              } else if (label.contains('DIVIDENDE') &&
                  fmpProfile['lastDividend'] != null) {
                updatedMatrix[i] = item.copyWith(
                  value: (fmpProfile['lastDividend'] as num).toStringAsFixed(2),
                );
                changed = true;
              } else if (label.contains('ROE') &&
                  fmpMetrics['roeTTM'] != null) {
                final roe = (fmpMetrics['roeTTM'] as num).toDouble();
                updatedMatrix[i] = item.copyWith(
                  value: '${(roe * 100).toStringAsFixed(2)}%',
                );
                changed = true;
              } else if (label.contains('D/E') &&
                  fmpMetrics['debtToEquityTTM'] != null) {
                final de = (fmpMetrics['debtToEquityTTM'] as num).toDouble();
                updatedMatrix[i] = item.copyWith(value: de.toStringAsFixed(2));
                changed = true;
              } else if (label.contains('ROIC')) {
                final roic = fmpMetrics['roicTTM'] ??
                    fmpRatios['returnOnInvestedCapitalTTM'];
                if (roic != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((roic as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              } else if (label.contains('EPS')) {
                final eps = fmpMetrics['netIncomePerShareTTM'] ??
                    (fmpIncome.isNotEmpty ? fmpIncome[0]['eps'] : null);
                if (eps != null) {
                  updatedMatrix[i] = item.copyWith(
                    value: (eps as num).toStringAsFixed(2),
                  );
                  changed = true;
                }
              } else if (label.contains('EBIT')) {
                final ebit = (fmpIncome.isNotEmpty
                    ? (fmpIncome[0]['operatingIncome'] ?? fmpIncome[0]['ebit'])
                    : null);
                if (ebit != null) {
                  updatedMatrix[i] = item.copyWith(
                    value: _formatLargeNumber(ebit),
                  );
                  changed = true;
                }
              } else if (label.contains('MARGE BRUTE')) {
                final gm = fmpMetrics['grossProfitMarginTTM'] ??
                    fmpRatios['grossProfitMarginTTM'];
                if (gm != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((gm as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              } else if (label.contains('MARGE NETTE')) {
                final nm = fmpMetrics['netProfitMarginTTM'] ??
                    fmpRatios['netProfitMarginTTM'];
                if (nm != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((nm as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              } else if (label.contains('RENDEMENT FCF') ||
                  label.contains('FCF YIELD')) {
                final fcfy = fmpMetrics['freeCashFlowYieldTTM'];
                if (fcfy != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((fcfy as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              }
            }
          }
          if (changed) {
            analysisData = analysisData.copyWith(
              financialMatrix: updatedMatrix,
            );
          }
        }
      } catch (e) {
        dev.log('Warning: Financial Matrix enrichment failed: $e');
      }

      // ENRICHISSEMENT: ANALYSE TECHNIQUE (FMP-only — AI-generated from analyzeStock)
      // TwelveData technical indicators (RSI, MACD, OBV) removed — FMP doesn't provide these directly.
      // Technical analysis is AI-generated from price context.

      // ENRICHISSEMENT: DONNÉES D'ACTIONNARIAT (FMP PRIMARY)
      try {
        List<MajorHolder> topInstitutions = [];
        List<MajorHolder> topFunds = [];
        double insidersPercent = 0.0;
        double institutionsPercent = 0.0;
        int institutionsCount = 0;

        // FMP Institutional Holders
        try {
          final fmpHoldersData = await _fmp.getInstitutionalHolders(symbol);
          if (fmpHoldersData.isNotEmpty) {
            topInstitutions = fmpHoldersData.take(10).map((h) {
              return MajorHolder(
                organization: h['holder'] ?? 'Unknown',
                position: (h['shares'] as num?)?.toDouble() ?? 0,
                value: (h['totalValue'] as num?)?.toDouble() ?? 0,
                pctHeld: 0,
                reportDate: h['dateReported'] ?? '',
              );
            }).toList();
            institutionsCount = fmpHoldersData.length;
          }
        } catch (e) {
          dev.log('Warning: FMP holders enrichment failed: $e');
        }

        final holdersData = HoldersData(
          insidersPercent: insidersPercent,
          institutionsPercent: institutionsPercent,
          institutionsCount: institutionsCount,
          topInstitutions: topInstitutions,
          topFunds: topFunds,
        );

        dev.log('👥 HOLDERS ENRICHMENT for $symbol:');
        dev.log(
          '   Institutions: ${holdersData.institutionsPercent}% (${holdersData.institutionsCount} organizations)',
        );
        dev.log(
          '   Top Institution: ${holdersData.topInstitutions.isNotEmpty ? holdersData.topInstitutions[0].organization : "None"}',
        );

        analysisData = analysisData.copyWith(holders: holdersData);
      } catch (e) {
        dev.log('Warning: Failed to enrich Holders data: $e');
      }

      // ENRICHISSEMENT: ÉVÉNEMENTS CORPORATIFS (YAHOO)
      try {
        final List<CorporateEvent> events = List.from(
          analysisData.corporateEvents,
        );

        // 1. Dividendes et Splits
        if (yahooActions.isNotEmpty) {
          final dividends = yahooActions['dividends'] as List? ?? [];
          for (var div in dividends.take(3)) {
            events.add(
              CorporateEvent(
                date: div['date']?.toString() ?? '',
                event: 'DIVIDENDE',
                description: 'Montant: \$${div['amount']}',
              ),
            );
          }
        }

        // 2. Earnings History
        if (yahooEarningsHistory.isNotEmpty) {
          for (var earn in yahooEarningsHistory.take(2)) {
            final dateStr = DateTime.fromMillisecondsSinceEpoch(
              (earn['epsActual'] ?? 0) * 1000,
            ).toString().split(' ')[0];
            events.add(
              CorporateEvent(
                date: earn['date']?.toString() ?? dateStr,
                event: 'RÉSULTATS',
                description:
                    'EPS Réel: ${earn['epsActual']} (Est: ${earn['epsEstimate']})',
              ),
            );
          }
        }

        // 3. Fallback FMP: Dividendes
        if (events.every((e) => e.event != 'DIVIDENDE')) {
          try {
            final fmpDivs = await _fmp.getDividends(symbol);
            for (var div in fmpDivs.take(3)) {
              events.add(
                CorporateEvent(
                  date: div['date']?.toString() ?? '',
                  event: 'DIVIDENDE',
                  description: 'Montant: \$${div['dividend'] ?? div['amount']}',
                ),
              );
            }
          } catch (e) {
            dev.log('Warning: FMP dividends enrichment failed: $e');
          }
        }

        // 4. Fallback FMP: Earnings
        if (events.every((e) => e.event != 'RÉSULTATS')) {
          try {
            final fmpEarn = await _fmp.getEarningsHistorical(symbol);
            for (var earn in fmpEarn.take(2)) {
              events.add(
                CorporateEvent(
                  date: earn['date']?.toString() ?? '',
                  event: 'RÉSULTATS',
                  description:
                      'EPS Réel: ${earn['actualEps']} (Est: ${earn['epsEstimated']})',
                ),
              );
            }
          } catch (e) {
            dev.log('Warning: FMP earnings enrichment failed: $e');
          }
        }

        if (events.isNotEmpty) {
          analysisData = analysisData.copyWith(corporateEvents: events);
        }
      } catch (e) {
        dev.log('Warning: Failed to enrich Corporate Events: $e');
      }

      // ── PHASE 3: REMOVED (Redundant after Agentic Web integration) ──────────
      // Previous Ollama phase removed to prioritize unified Intelligence Core.

      return await _enrichPeerData(analysisData);
    } catch (e) {
      dev.log('❌ Enrichment Error: $e');
      return analysisData;
    }
  }

  /// Enrichit les données des pairs avec des prix temps réel et valide les tickers
  Future<AnalysisData> _enrichPeerData(AnalysisData data) async {
    if (data.sectorPeers.isEmpty) return data;

    // Fetch all peer prices in parallel instead of sequentially
    final priceFutures = data.sectorPeers
        .map((peer) => _getMultiSourcePrice(peer.ticker)
            .catchError((_) => <String, dynamic>{'price': 0}))
        .toList();
    final prices = await Future.wait(priceFutures);

    final enrichedPeers = List.generate(data.sectorPeers.length, (i) {
      final peer = data.sectorPeers[i];
      final realPrice = prices[i]['price'];
      final priceStr = (realPrice != 0 && realPrice != null)
          ? '\$${_formatPrice(realPrice)}'
          : peer.price;
      return PeerComparison(
        ticker: peer.ticker,
        name: peer.name,
        price: priceStr,
        verdict: peer.verdict,
        confidence: peer.confidence,
        profitabilityPotential: peer.profitabilityPotential,
        marketCap: peer.marketCap,
        peRatio: peer.peRatio,
        type: peer.type,
      );
    }).cast<PeerComparison>();
    return data.copyWith(sectorPeers: enrichedPeers);
  }

  /// Formate un prix pour l'affichage
  String _formatPrice(dynamic price) {
    if (price == null || price == 0) return '0.00';
    final numPrice = price is num
        ? price.toDouble()
        : double.tryParse(price.toString()) ?? 0;
    if (numPrice >= 1000) {
      return numPrice.toStringAsFixed(2);
    } else if (numPrice >= 1) {
      return numPrice.toStringAsFixed(2);
    } else {
      return numPrice.toStringAsFixed(4);
    }
  }

  /// Récupère le prix temps réel avec fallback multi-source
  /// Priorité: YAHOO -> FMP -> Finnhub -> TwelveData
  /// Gère automatiquement les différents formats de symboles internationaux
  Future<Map<String, dynamic>> _getMultiSourcePrice(String symbol) async {
    // Générer les variantes de symboles pour les marchés internationaux
    final symbolVariants = _getSymbolVariants(symbol);

    for (final variant in symbolVariants) {
      // 1. FMP (primary source)
      final fmpPriceVal = await _safeCall<double>(
        () => _fmp.getRealTimePrice(variant),
        0.0,
      );
      if (fmpPriceVal > 0) {
        dev.log('💰 Prix trouvé via FMP ($variant): \$$fmpPriceVal');
        // Try to get full quote data for richer response
        try {
          final quoteMap = await _fmp.getQuoteMap(variant);
          if (quoteMap.isNotEmpty) {
            return {
              'price': quoteMap['price'] ?? fmpPriceVal,
              'change': quoteMap['change'] ?? 0,
              'changePercent': quoteMap['changesPercentage'] ?? 0,
              'dayHigh': quoteMap['dayHigh'] ?? 0,
              'dayLow': quoteMap['dayLow'] ?? 0,
              'previousClose': quoteMap['previousClose'] ?? 0,
              'open': quoteMap['open'] ?? 0,
              'volume': quoteMap['volume'] ?? 0,
              'marketCap': quoteMap['marketCap'] ?? 0,
              'yearHigh': quoteMap['yearHigh'] ?? 0,
              'yearLow': quoteMap['yearLow'] ?? 0,
              'source': 'FMP',
            };
          }
        } catch (_) {}
        return {
          'price': fmpPriceVal,
          'change': 0,
          'changePercent': 0,
          'dayHigh': 0,
          'dayLow': 0,
          'previousClose': 0,
          'open': 0,
          'volume': 0,
          'source': 'FMP',
        };
      }
    }

    // 2. RÉSOLUTION AVANCÉE FMP (DERNIER RECOURS)
    dev.log(
      '⚠️ Résolution standard échouée. Tentative de résolution FMP Exchange pour $symbol...',
    );
    try {
      final validVariants = await _fmp.searchExchangeVariants(symbol);
      for (final v in validVariants) {
        final String? newSymbol = v['symbol'];
        if (newSymbol == null || symbolVariants.contains(newSymbol)) continue;

        dev.log(
          '🔍 Test du symbole FMP découvert: $newSymbol (${v['exchange']})',
        );

        final fmpPriceVal = await _safeCall<double>(
          () => _fmp.getRealTimePrice(newSymbol),
          0.0,
        );
        if (fmpPriceVal > 0) {
          dev.log(
            '💰 Prix trouvé via FMP Resolution ($newSymbol): \$$fmpPriceVal',
          );
          return {
            'price': fmpPriceVal,
            'change': 0,
            'changePercent': 0,
            'source': 'FMP_RESOLVED',
          };
        }
      }
    } catch (e) {
      dev.log('Warning: FMP Advanced Resolution failed: $e');
    }

    dev.log('❌ Aucune source n\'a pu fournir le prix pour $symbol');
    return {};
  }

  /// Génère les variantes de symboles pour les différents formats d'échange
  List<String> _getSymbolVariants(String symbol) {
    final variants = <String>[symbol];
    final upperSymbol = symbol.toUpperCase();

    // Format TSX canadien (.TO -> :TSX ou sans suffixe)
    if (upperSymbol.endsWith('.TO')) {
      final base = upperSymbol.replaceAll('.TO', '');
      variants.add(base); // VNP
      variants.add('$base.TSX'); // VNP.TSX
      variants.add('TSE:$base'); // TSE:VNP
      variants.add('$base:CA'); // VNP:CA
    }
    // Format TSX Venture (.V)
    else if (upperSymbol.endsWith('.V')) {
      final base = upperSymbol.replaceAll('.V', '');
      variants.add(base);
      variants.add('$base.TSXV');
      variants.add('CVE:$base');
    }
    // Format London Stock Exchange (.L ou .LON)
    else if (upperSymbol.endsWith('.L') || upperSymbol.endsWith('.LON')) {
      final base = upperSymbol.replaceAll(RegExp(r'\.(L|LON)$'), '');
      variants.add(base);
      variants.add('$base.L');
      variants.add('LON:$base');
    }
    // Format Paris/Euronext (.PA)
    else if (upperSymbol.endsWith('.PA')) {
      final base = upperSymbol.replaceAll('.PA', '');
      variants.add(base);
      variants.add('EPA:$base');
    }
    // Format Frankfurt (.DE ou .F)
    else if (upperSymbol.endsWith('.DE') || upperSymbol.endsWith('.F')) {
      final base = upperSymbol.replaceAll(RegExp(r'\.(DE|F)$'), '');
      variants.add(base);
      variants.add('FRA:$base');
    }

    return variants;
  }

  /// Limite la taille d'un texte pour éviter de dépasser les limites de contexte de l'IA
  String _limitTokens(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}... [DONNÉES TRONQUÉES POUR OPTIMISATION CONTEXTE]';
  }

  String? _getValidString(List<dynamic> candidates) {
    for (var c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isEmpty || s.toUpperCase() == 'N/A' || s.toUpperCase() == 'UNKNOWN')
        continue;
      return s;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getMarketSummaryWithFallback() async {
    // FMP : Indices majeurs (Yahoo removed)
    try {
      // ^GSPC=S&P500, ^DJI=Dow, ^IXIC=Nasdaq, ^RUT=Russell, EURUSD=X, BTC-USD
      final quotes = await _fmp.getQuotes([
        '^GSPC',
        '^DJI',
        '^IXIC',
        '^RUT',
        'EURUSD=X',
        'BTC-USD',
      ]);
      if (quotes.isNotEmpty) {
        return quotes
            .map<Map<String, dynamic>>(
              (q) => {
                'symbol': q['symbol'],
                'shortName': q['name'],
                'longName': q['name'],
                'price': q['price'],
                'change': q['change'],
                'changePercent': q['changesPercentage'],
                'marketState': 'REGULAR',
                'quoteType': 'INDEX',
                'currency': q['currency'] ?? 'USD',
              },
            )
            .toList();
      }
    } catch (e) {
      dev.log('❌ FMP MarketSummary failed: $e');
    }
    return [];
  }

  Future<MarketOverview> getMarketOverview({
    String language = 'FRANÇAIS',
  }) async {
    final bool isFr = language.toUpperCase().startsWith('FR');
    final String targetLanguage = isFr ? 'FRANÇAIS' : 'ENGLISH';

    final now = DateTime.now();
    final currentDate = now.toIso8601String().split('T')[0];

    // Variables for possible fallback
    double goldReal = 0.0;
    double oilReal = 0.0;
    double dxyReal = 0.0;
    double t10yReal = 0.0;
    double vixReal = 0.0;
    double vixRealChange = 0.0;
    double vixRealChangePct = 0.0;
    List<Map<String, String>> aggregatedNews = [];
    List<dynamic> sectorPerf = [];
    List<Map<String, dynamic>> finalGainers = [];
    List<Map<String, dynamic>> finalLosers = [];
    List<Map<String, dynamic>> yahooMarketSummary = [];
    String macroContext = "";
    String realSentimentContext = "";
    List<dynamic> yahooEarningsCalendar = [];

    // Sentiment variables for fallback
    FearGreedData? fgData;
    List<SentimentNews> fgNews = [];
    List<Map<String, dynamic>> fgHistory = [];
    List<GlobalInsiderTrade> insiderTrades = [];

    try {
      // ── 0. AGENTIC SENTIMENT SEARCH (ALPHA) ────────────────────────────────────
      // On cherche les chiffres RÉELS du sentiment (Fear & Greed Index)
      final sentimentSearchTask = _webSearch.search(
          'current CNN Fear and Greed Index exact value, latest CBOE VIX price today, and current US stock market regime (Risk-On or Risk-Off) as of April 2026');

      // ── 1. RÉCUPÉRATION DES DONNÉES EN PARALLÈLE ──────────────────────────────
      final results = await Future.wait([
        _safeCall(() => _fmp.getGeneralNews(limit: 30), {'data': []}), // 0
        _safeCall(() => Future.value(null), null), // 1 (treasury — disabled)
        _safeCall(() => _fmp.getSectorPerformance(), []), // 2
        _safeCall(() => _fmp.getMergersAndAcquisitions(), []), // 3
        _safeCall(() => _fmp.getFmpArticles(''), []), // 4
        _safeCall(() => _fmp.getIndustryPerformance(), []), // 5
        _safeCall(() => Future.value({'data': []}),
            {'data': []}), // 6 (trending — disabled)
        _safeCall(() => _getMarketSummaryWithFallback(), []), // 7
        _safeCall(() => _fmp.getGainers(), []), // 8
        _safeCall(() => _fmp.getLosers(), []), // 9
        _safeCall(() => _fmp.getGeneralNews(limit: 20), []), // 10
        _safeCall(
          () => _fmp.getQuotes(['^TNX', '^VIX', 'GLD', 'USO', 'UUP']),
          [],
        ), // 11
        _safeCall(() => Future.value(<Map<String, dynamic>>[]),
            []), // 12 (market news — FMP general news used)
        _safeCall(() => _fmp.getGeneralNews(limit: 30), []), // 13
        _safeCall(() => _fmp.getGainers(), []), // 14
        _safeCall(() => _fmp.getLosers(), []), // 15
        _safeCall(() => _fmp.getEconomicCalendar(), []), // 16
        _safeCall(() => sentimentSearchTask, ""), // 17
        _safeCall(() => _sentiment.fetchFearGreed(), null), // 18
        _safeCall(() => _sentiment.fetchNews(), []), // 19
        _safeCall(() => _sentiment.fetchHistory(), []), // 20
        _safeCall(() => getGlobalInsiderTrades(), []), // 21
        _safeCall(() => _fmp.getEconomicCalendar(), []), // 22
      ]);

      final Map<String, dynamic>? macroNews =
          results[0] as Map<String, dynamic>?;
      final t10yOriginal = results[1] as double?;
      sectorPerf = results[2] as List<dynamic>;
      if (sectorPerf.isEmpty) {
        final sectorTickers = [
          'XLK',
          'XLF',
          'XLE',
          'XLV',
          'XLY',
          'XLP',
          'XLI',
          'XLB',
          'XLU',
          'XLRE',
          'XLC'
        ];
        final sectorQuotes =
            await _safeCall(() => _fmp.getQuotes(sectorTickers), []);
        sectorPerf = sectorQuotes
            .map((q) => {
                  'sector': q['name']
                          ?.toString()
                          .replaceAll(' Select Sector SPDR Fund', '')
                          .replaceAll(' ETF', '') ??
                      q['symbol'],
                  'changesPercentage': q['changesPercentage'] ?? 0.0,
                })
            .toList();
      }
      final mergers = results[3] as List<dynamic>;
      final fmpArticles = results[4] as List<dynamic>;
      final industryPerf = results[5] as List<dynamic>;
      final trending = results[6] as Map<String, dynamic>?;
      yahooMarketSummary = results[7] as List<Map<String, dynamic>>;
      final fmpGainers = results[8] as List<dynamic>;
      final fmpLosers = results[9] as List<dynamic>;

      final finnhubNews = results[10] as List<dynamic>;
      final macroQuotes = results[11] as List<dynamic>;
      final yahooNews = results[12] as List<Map<String, dynamic>>;
      final fmpGeneralNews = results[13] as List<dynamic>;
      final yahooGainersRaw = results[14] as List<Map<String, dynamic>>;
      final yahooLosersRaw = results[15] as List<Map<String, dynamic>>;
      yahooEarningsCalendar = results[16] as List<dynamic>;
      realSentimentContext = results[17] as String;
      fgData = results[18] as FearGreedData?;
      fgNews = results[19] as List<SentimentNews>;
      fgHistory = results[20] as List<Map<String, dynamic>>;
      insiderTrades = results[21] as List<GlobalInsiderTrade>;
      final List<dynamic> ecoCalRaw = results[22] as List<dynamic>;

      // Sort and map economic calendar
      final List<EconomicEvent> ecoCalendar = ecoCalRaw
          .map((x) => EconomicEvent.fromJson(Map<String, dynamic>.from(x)))
          .toList();

      // Fusionner et filtrer les gagnants/perdants (USA + Canada seulement)
      final Map<String, Map<String, dynamic>> uniqueGainers = {};
      final Map<String, Map<String, dynamic>> uniqueLosers = {};

      void processMovers(List<dynamic> list,
          Map<String, Map<String, dynamic>> map, bool isFmp) {
        for (var item in list) {
          final g = item is Map<String, dynamic> ? item : {};
          final s = (g['symbol'] ?? g['ticker'] ?? '').toString().toUpperCase();
          if (s.isEmpty || map.containsKey(s)) continue;

          // Autoriser les indices (^), les commodités (=), et les symboles US/Canada standard
          final bool isIndexOrCommodity =
              s.startsWith('^') || s.contains('=') || s.contains('-');
          final bool isUSOrCanada =
              !s.contains('.') || s.endsWith('.TO') || s.endsWith('.V');

          if (isIndexOrCommodity || isUSOrCanada) {
            map[s] = {
              'symbol': s,
              'name': (g['name'] ?? g['shortName'] ?? g['longName'] ?? '')
                  .toString(),
              'change': isFmp
                  ? (g['changesPercentage'] ?? 0.0)
                  : (g['changePercent'] ?? 0.0),
            };
          }
        }
      }

      processMovers(fmpGainers, uniqueGainers, true);
      processMovers(yahooGainersRaw, uniqueGainers, false);
      processMovers(fmpLosers, uniqueLosers, true);
      processMovers(yahooLosersRaw, uniqueLosers, false);

      finalGainers = uniqueGainers.values.toList()
        ..sort((a, b) => (b['change'] as num).compareTo(a['change'] as num));
      finalLosers = uniqueLosers.values.toList()
        ..sort((a, b) => (a['change'] as num).compareTo(b['change'] as num));

      // Extraction des valeurs macro réelles (FMP)
      goldReal = 0.0;
      oilReal = 0.0;
      dxyReal = 0.0;
      t10yReal = t10yOriginal ?? 0.0;
      vixReal = 0.0;
      vixRealChange = 0.0;
      vixRealChangePct = 0.0;

      for (var q in macroQuotes) {
        if (q is! Map<String, dynamic>) continue;
        final s = q['symbol']?.toString().toUpperCase() ?? '';
        final price = (q['price'] as num?)?.toDouble() ?? 0.0;

        if (s == '^TNX') t10yReal = price;
        if (s == 'DX=F' || s == 'UUP' || s == 'DXY') {
          if (dxyReal == 0) dxyReal = price;
        }
        if (s == 'GC=F' || s == 'GLD') {
          if (goldReal == 0) goldReal = price;
        }
        if (s == 'CL=F' || s == 'USO' || s == 'WTI') {
          if (oilReal == 0) oilReal = price;
        }
        if (s == '^VIX' || s == 'VIX') {
          vixReal = price;
          vixRealChange = (q['change'] as num?)?.toDouble() ?? 0.0;
          vixRealChangePct =
              (q['changesPercentage'] as num?)?.toDouble() ?? 0.0;
        }
      }

      if (vixReal == 0) {
        try {
          final res = await http.get(Uri.parse(
              'https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX'));
          if (res.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(res.body);
            final meta = data['chart']['result'][0]['meta'];
            vixReal = (meta['regularMarketPrice'] as num).toDouble();
            final prev = (meta['chartPreviousClose'] as num).toDouble();
            vixRealChange = vixReal - prev;
            vixRealChangePct = (vixRealChange / prev) * 100;
          }
        } catch (e) {
          dev.log('Yahoo Finance VIX fallback failed: $e');
        }
      }

      macroContext = "";
      aggregatedNews = [];

      // Ajouter les news Marketaux
      if (macroNews != null && macroNews['data'] != null) {
        final List newsList = macroNews['data'];
        for (var n in newsList.take(15)) {
          String ticker = "";
          final entities = n['entities'];
          if (entities is List && entities.isNotEmpty) {
            ticker = entities[0]['symbol']?.toString() ?? "";
          }
          aggregatedNews.add({
            'title': n['title']?.toString() ?? '',
            'source': n['source']?.toString() ?? 'MARKETAUX',
            'url': n['url']?.toString() ?? '',
            'ticker': ticker,
            'publishedAt': n['published_at']?.toString() ?? '',
          });
        }
      }

      // Ajouter les news Finnhub
      if (finnhubNews.isNotEmpty) {
        for (var n in finnhubNews.take(15)) {
          final related = n['related']?.toString() ?? '';
          final splitted = related.split(',');
          aggregatedNews.add({
            'title': n['headline']?.toString() ?? '',
            'source': n['source']?.toString() ?? 'FINNHUB',
            'url': n['url']?.toString() ?? '',
            'ticker': splitted.isNotEmpty ? splitted[0] : '',
            'publishedAt': n['datetime']?.toString() ?? '',
          });
        }
      }

      // Ajouter les news Yahoo
      if (yahooNews.isNotEmpty) {
        for (var n in yahooNews.take(15)) {
          aggregatedNews.add({
            'title': n['title']?.toString() ?? '',
            'source': n['publisher']?.toString() ?? 'YAHOO',
            'url': n['link']?.toString() ?? '',
            'ticker': '',
            'publishedAt': n['providerPublishTime']?.toString() ?? '',
          });
        }
      }

      // Ajouter les articles FMP General
      if (fmpGeneralNews.isNotEmpty) {
        for (var n in fmpGeneralNews.take(15)) {
          aggregatedNews.add({
            'title': n['title']?.toString() ?? '',
            'source': n['site']?.toString() ?? 'FMP',
            'url': n['url']?.toString() ?? '',
            'ticker': n['symbol']?.toString() ?? '',
            'publishedAt': n['publishedDate']?.toString() ?? '',
          });
        }
      }

      // -- AGENTIC TEMPORAL SORTING: ensure most recent news are processed first
      aggregatedNews.sort((a, b) {
        final da = _parseAnyDate(a['publishedAt']);
        final db = _parseAnyDate(b['publishedAt']);
        return db.compareTo(da);
      });

      macroContext = aggregatedNews
          .take(25) // Focus on the most recent context
          .map(
            (n) =>
                "- ${n['title']} (Source: ${n['source']}) [URL: ${n['url']}]",
          )
          .join("\n");

      String trendingContext = "";
      if (trending != null && trending['data'] != null) {
        final List entities = trending['data'];
        trendingContext = entities
            .take(5)
            .map((e) => "- ${e['name']} (${e['symbol']})")
            .join("\n");
      }

      final sectorContext = sectorPerf
          .take(5)
          .map((s) => "- ${s['sector']}: ${s['changesPercentage']}")
          .join("\n");
      final industryContext = industryPerf
          .take(8)
          .map((i) => "- ${i['industry']}: ${i['changesPercentage']}%")
          .join("\n");

      // Récupérer les IPOs et le Calendrier Économique pour le contexte
      final ipoResults = await Future.wait([
        _safeCall(() => _fmp.getIposCalendar(), []),
        _safeCall(() => _fmp.getEconomicCalendar(), []),
      ]);
      final ipos = ipoResults[0];
      final ecoCalendarRaw = ipoResults[1];

      final ipoContext = ipos
          .take(5)
          .map(
            (ipo) =>
                "- ${ipo['name']} (${ipo['symbol']}): Date: ${ipo['date']}, Price: ${ipo['price'] ?? 'N/A'}",
          )
          .join("\n");

      final ecoContext = ecoCalendarRaw
          .where((e) =>
              (e['impact']?.toString().toLowerCase() ?? '') == 'high' ||
              (e['impact']?.toString().toLowerCase() ?? '') == 'medium')
          .take(7)
          .map(
            (e) =>
                "- ${e['event']} (${e['country']}): Impact: ${e['impact']}, Date: ${e['date']}",
          )
          .join("\n");

      final mergerContext =
          mergers.take(3).map((m) => "- ${m['title']}").join("\n");
      final articleContext = fmpArticles
          .take(3)
          .map((a) => "- ${a['title']} (${a['site']})")
          .join("\n");

      final yahooMarketContext = yahooMarketSummary
          .map(
            (i) =>
                "- ${i['shortName']} (${i['symbol']}): Price: ${i['price']}, Change: ${i['changePercent']}%",
          )
          .join("\n");

      final earningsContextYahoo = yahooEarningsCalendar
          .take(10)
          .map(
            (e) =>
                "- ${e['symbol']}: Date ${e['earningsDate']?[0]?['fmt'] ?? 'N/A'}",
          )
          .join("\n");

      final prompt = '''
ANALYSE MACRO SIGMA : $currentDate
LANGUE DE RÉPONSE : $targetLanguage
10Y TREASURY YIELD (RÉEL): ${t10yReal.toStringAsFixed(2)}%
DOLLAR INDEX DXY (RÉEL): ${dxyReal.toStringAsFixed(2)}
GOLD (RÉEL): \$${goldReal.toStringAsFixed(2)}
OIL WTI (RÉEL): \$${oilReal.toStringAsFixed(2)}
VIX VOLATILITY index (RÉEL): ${vixReal.toStringAsFixed(2)}

RÉSUMÉ MARCHÉS YAHOO FINANCE :
$yahooMarketContext

TENDANCES (ENTITÉS À FORT VOLUMENÉTIQUE) :
$trendingContext

SÉCTEURS PERFORMANCE :
$sectorContext

INDUSTRIES PERFORMANCE (TOP 8) :
$industryContext

FUSIONS & ACQUISITIONS RÉCENTES :
$mergerContext

UPCOMING IPOs (INTRODUCTIONS EN BOURSE) :
$ipoContext

CALENDRIER ÉCONOMIQUE :
$ecoContext

CALENDRIER EARNINGS (YAHOO) :
$earningsContextYahoo

ARTICLES FINANCIERS CLÉS (FMP) :
$articleContext

### DERNIÈRES NEWS RÉELLES DU MARCHÉ (CONTEXTE CRUCIAL) :
$macroContext

### SENTIMENT NEWS (SOURCE: FEAR & GREED) :
${fgNews.map((n) => "- ${n.title} (Publisher: ${n.publisher}, Link: ${n.link})").join('\n')}

### REAL SENTIMENT & VIX INTELLIGENCE (ALPHA) :
$realSentimentContext

### FEAR & GREED LIVE SCORE (SOURCE: SIGMA MARKET SENTIMENT) :
Score: ${fgData?.score ?? 'N/A'}
Sentiment: ${fgData?.rating ?? 'N/A'}
Indicateurs: ${fgData?.indicators ?? 'N/A'}
Notable Events (Derniers contextes historiques): ${fgData?.notableEvents.map((e) => "${e.date}: ${e.label} (Score: ${e.score})").join(' | ') ?? 'N/A'}

### SENTIMENT TREND (LAST 180 DAYS) :
${fgHistory.length > 180 ? fgHistory.sublist(fgHistory.length - 180).map((h) => "${h['date']}: ${h['score']}").join(' | ') : fgHistory.map((h) => "${h['date']}: ${h['score']}").join(' | ')}

MISSION : Fournir un MarketOverview JSON COMPACT.
CONSIGNE NEWS : Extrais les 15 actualités les plus pertinentes et variées du contexte ci-dessus. Inclue absolument les URLs réelles fournies.

STRUCTURE JSON (STRICTE, PAS DE TEXTE SUPERFLU) :
{
  "marketRegime": "RISK-ON ou RISK-OFF",
  "regimeDescription": "ANALYSE TECHNIQUE DÉTAILLÉE DE 3 LIGNES MINIMUM (STYLE BIM DANS UN RAPPORT INSTITUTIONNEL).",
  "vixLevel": "15.5",
  "lastUpdated": "YYYY-MM-DD",
  "news": [{"title": "Short title", "source": "SOURCE", "ticker": "AAPL", "impact": "HIGH", "url": "URL", "time": "2m ago"}],
  "sectors": [{"name": "Technology", "performance": 1.5, "sentiment": "BULLISH", "reason": "Raison courte"}],
  "macroIndicators": {"treasury10Y": 4.5, "dollarIndex": 104.0, "goldPrice": 2050.0, "oilPrice": 75.0},
  "topGainers": [{"ticker": "AAPL", "change": 5.0}],
  "topLosers": [{"ticker": "TSLA", "change": -5.0}],
  "sentiment": "EXTREME FEAR, FEAR, NEUTRAL, GREED, or EXTREME GREED",
  "sentimentValue": 0-100
}
''';

      String jsonResponse = "";
      try {
        jsonResponse = await _marketProvider
            .generateContent(
              prompt: prompt,
              systemInstruction: _getSystemInstructionMarket(targetLanguage),
              jsonMode: true,
            )
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        dev.log('⚠️ NVIDIA Market Overview failed, trying Ollama: $e');
        if (_deepReasoningProvider != null) {
          try {
            jsonResponse = await _deepReasoningProvider!
                .generateContent(
                  prompt: prompt,
                  systemInstruction:
                      _getSystemInstructionMarket(targetLanguage),
                  jsonMode: true,
                )
                .timeout(const Duration(seconds: 60));
          } catch (e2) {
            dev.log('❌ Ollama Market Fallback failed: $e2');
            throw e;
          }
        } else {
          rethrow;
        }
      }

      final cleanedJson = _cleanJsonResponse(jsonResponse);
      final Map<String, dynamic> decoded = AnalysisData.parseMap(
        jsonDecode(cleanedJson),
      );
      dev.log(
        '✅ Market Overview successfully parsed (length: ${cleanedJson.length})',
      );

      // Injecter les données réelles de Yahoo et Macro extraites
      decoded['yahooSummary'] = yahooMarketSummary;
      decoded['topGainers'] = finalGainers
          .take(15)
          .map((g) =>
              {'ticker': g['symbol'], 'name': g['name'], 'change': g['change']})
          .toList();
      decoded['topLosers'] = finalLosers
          .take(15)
          .map((g) =>
              {'ticker': g['symbol'], 'name': g['name'], 'change': g['change']})
          .toList();
      decoded['vixLevel'] =
          vixReal > 0 ? vixReal.toStringAsFixed(2) : decoded['vixLevel'];
      decoded['vixValue'] = vixReal;
      decoded['vixChange'] = vixRealChange;
      decoded['vixChangePercent'] = vixRealChangePct;

      // Injecter MacroIndicators Réels
      decoded['macroIndicators'] = {
        "treasury10Y": t10yReal,
        "dollarIndex": dxyReal,
        "goldPrice": goldReal,
        "oilPrice": oilReal,
      };

      // Injecter Fear & Greed Data
      if (fgData != null) {
        print(
            '🔍 [SigmaService] fgData detected. Score: ${fgData.score}, Backtest: ${fgData.backtest.length} items, Sectors: ${fgData.sectors.length} items');
        if (fgData.backtest.isEmpty) {
          dev.log('⚠️ [SigmaService] Warning: fgData.backtest is EMPTY');
        }
        decoded['sentiment'] = fgData.rating;
        decoded['sentimentValue'] = fgData.score;
        decoded['notableEvents'] =
            fgData.notableEvents.map((e) => e.toJson()).toList();
        decoded['indicators'] = fgData.indicators;
        decoded['backtest'] = fgData.backtest;
        decoded['sentimentComponents'] =
            fgData.components.map((c) => c.toJson()).toList();
        decoded['sectorSentiment'] = fgData.sectors;

        if (fgNews.isNotEmpty) {
          decoded['sentimentNews'] = fgNews
              .map((n) => {
                    'title': n.title,
                    'source': n.publisher,
                    'url': n.link,
                    'publishedAt':
                        DateTime.fromMillisecondsSinceEpoch(n.time * 1000)
                            .toIso8601String(),
                    'description': '',
                  })
              .toList();
        }
      } else {
        dev.log('⚠️ FearGreedData is NULL in getMarketOverview');
      }

      // ── SENTIMEMT HISTORY INJECTION
      if (fgHistory.isNotEmpty) {
        decoded['sentimentHistory'] = fgHistory;
      }

      // -- INSIDER TRADES INJECTION
      if (insiderTrades.isNotEmpty) {
        decoded['insiderTrades'] =
            insiderTrades.map((t) => t.toJson()).toList();
      }

      // Injecter le Calendrier Économique Réel (Priorité à la donnée brute)
      if (ecoCalendar.isNotEmpty) {
        decoded['economicCalendar'] = ecoCalendar
            .take(15)
            .map((e) => {
                  'event': e.event,
                  'date': e.date,
                  'country': e.country,
                  'impact': e.impact,
                  'actual': e.actual,
                  'previous': e.previous,
                  'estimate': e.estimate,
                })
            .toList();
      }

      // ── FALLBACK NEWS : si l'IA ne retourne pas de news, on injecte les raw
      final aiNews = decoded['news'] as List?;
      if (aiNews == null || aiNews.isEmpty) {
        dev.log(
            '⚠️ AI returned no news — injecting raw aggregatedNews (${aggregatedNews.length} items)');
        decoded['news'] = aggregatedNews
            .where((n) => (n['title'] ?? '').isNotEmpty)
            .map((n) => {
                  'title': n['title'],
                  'source': n['source'] ?? 'MARKET',
                  'ticker': n['ticker'] ?? '',
                  'url': n['url'] ?? '',
                  'time': 'Live',
                  'impact': 'MEDIUM',
                  'publishedAt': n['publishedAt'] ?? '',
                })
            .toList();
      }

      // Enrichir les secteurs avec les données réelles de performance
      if (sectorPerf.isNotEmpty) {
        final List<dynamic> aiSectors = decoded['sectors'] as List? ?? [];
        for (var s in sectorPerf) {
          final sName = s['sector']?.toString().toUpperCase();
          final sPerf = AnalysisData.parseNum(s['changesPercentage']);

          final existing = aiSectors.indexWhere(
            (as) => as['name'].toString().toUpperCase() == sName,
          );
          if (existing != -1) {
            aiSectors[existing]['performance'] = sPerf;
          } else {
            aiSectors.add({
              'name': sName,
              'performance': sPerf,
              'sentiment': sPerf >= 0 ? 'BULLISH' : 'BEARISH',
              'trend': sPerf >= 0 ? 'UP' : 'DOWN',
              'reason': 'Real-time performance data.',
            });
          }
        }
        decoded['sectors'] = aiSectors;
      }

      // -- ACCURACY FIX: Override sentiment if web search found a specific value AND fgData is null
      if (fgData == null) {
        final webSentiment = _parseSentiment(realSentimentContext, vixReal);
        if (webSentiment['value'] > 0) {
          decoded['sentiment'] = webSentiment['label'];
          decoded['sentimentValue'] = webSentiment['value'];
        }
      }

      // -- INJECT EXPLICIT DATA THAT AI DOES NOT GENERATE --
      decoded['insiderTrades'] = insiderTrades.map((t) => t.toJson()).toList();
      decoded['sentimentHistory'] = fgHistory;
      decoded['yahooSummary'] = yahooMarketSummary;

      // -- AGENTIC CACHE : Store the latest overview for future micro-analysis
      final overview = MarketOverview.fromJson(decoded);
      _lastOverview = overview;

      return overview;
    } catch (e) {
      dev.log('❌ Market Overview AI Error, using raw fallback: $e');
      final fallbackVix = vixReal > 0 ? vixReal.toStringAsFixed(2) : "15.0";

      final webSentiment = _parseSentiment(realSentimentContext, vixReal);
      final String finalSentiment = webSentiment['value'] > 0
          ? webSentiment['label']
          : (vixReal > 30 ? "EXTREME FEAR" : (vixReal > 20 ? "FEAR" : "GREED"));
      final double finalSentimentValue = webSentiment['value'] > 0
          ? webSentiment['value']
          : (vixReal > 30 ? 20.0 : (vixReal > 20 ? 40.0 : 70.0));

      final fallbackNews = aggregatedNews
          .where((n) => (n['title'] ?? '').isNotEmpty)
          .take(20)
          .map((n) => <String, String>{
                'title': n['title'] ?? '',
                'source': n['source'] ?? 'MARKET',
                'ticker': n['ticker'] ?? '',
                'url': n['url'] ?? '',
                'time': 'Live',
                'impact': 'MEDIUM',
                'publishedAt': n['publishedAt'] ?? '',
              })
          .toList();

      // --- Macro Fallback logic ---
      if (goldReal == 0 || oilReal == 0 || dxyReal == 0 || t10yReal == 0) {
        for (var s in yahooMarketSummary) {
          final sym = s['symbol'] ?? '';
          final p = (s['price'] as num?)?.toDouble() ?? 0.0;
          if (p == 0) continue;

          if (sym == 'GC=F' && goldReal == 0) goldReal = p;
          if (sym == 'CL=F' && oilReal == 0) oilReal = p;
          if (sym == 'DX=F' && dxyReal == 0) dxyReal = p;
          if (sym == '^TNX' && t10yReal == 0) t10yReal = p;

          // Si on ne trouve pas les futures, on tente les ETFs
          if (sym == 'GLD' && goldReal == 0) goldReal = p;
          if (sym == 'USO' && oilReal == 0) oilReal = p;
          if (sym == 'UUP' && dxyReal == 0) dxyReal = p;
        }
      }

      final overview = MarketOverview(
        marketRegime: vixReal > 20 ? "RISK-OFF" : "RISK-ON",
        regimeDescription: vixReal > 20
            ? "High volatility detected. Market sentiment is cautious."
            : "Low volatility environment. Market sentiment is stable/bullish.",
        vixLevel: fallbackVix,
        vixValue: vixReal,
        vixChange: vixRealChange,
        vixChangePercent: vixRealChangePct,
        sentiment: finalSentiment,
        sentimentValue: finalSentimentValue,
        globalNews: [],
        lastUpdated: currentDate,
        news: fallbackNews,
        sectors: sectorPerf.isNotEmpty
            ? sectorPerf.take(8).map((s) {
                final perf = AnalysisData.parseNum(s['changesPercentage']);
                return SectorInsight(
                  name: s['sector']?.toString() ?? 'N/A',
                  performance: perf,
                  sentiment: perf >= 0 ? 'BULLISH' : 'BEARISH',
                  trend: perf >= 0 ? 'UP' : 'DOWN',
                  institutionalFlow: 'NEUTRAL',
                  reason: 'Real-time performance data.',
                );
              }).toList()
            : [],
        macroIndicators: MacroIndicators(
          treasury10Y: t10yReal,
          dollarIndex: dxyReal,
          goldPrice: goldReal,
          oilPrice: oilReal,
        ),
        topGainers: finalGainers
            .take(15)
            .map((g) => MarketMover(ticker: g['symbol'], change: g['change']))
            .toList(),
        topLosers: finalLosers
            .take(15)
            .map((g) => MarketMover(ticker: g['symbol'], change: g['change']))
            .toList(),
        yahooSummary: yahooMarketSummary
            .map((s) => YahooIndexSummary.fromJson(AnalysisData.parseMap(s)))
            .toList(),
        economicCalendar: [],
        upcomingIpos: [],
        sentimentHistory: fgHistory,
        insiderTrades: insiderTrades,
        sentimentNews: fgNews
            .map((e) => NewsArticle(
                  title: e.title,
                  source: e.publisher,
                  publishedAt:
                      DateTime.fromMillisecondsSinceEpoch(e.time * 1000)
                          .toIso8601String(),
                  url: e.link,
                  summary: '',
                ))
            .toList(),
      );
      _lastOverview = overview;
      return overview;
    }
  }

  Future<List<GlobalInsiderTrade>> getGlobalInsiderTrades() async {
    try {
      // 1. PRIMARY: OpenInsider (free, complete SEC Form 4 data with cluster detection)
      final oiTrades = await _openInsider.getLatestTrades(
        days: 7,
        limit: 100,
      );
      if (oiTrades.isNotEmpty) {
        dev.log('✅ OpenInsider: SUCCESS - Retrieved ${oiTrades.length} trades',
            name: 'SigmaService');
        return oiTrades;
      }

      // 2. FALLBACK: FMP Bulk Feed
      dev.log('⚠️ OpenInsider unavailable, falling back to FMP...',
          name: 'SigmaService');
      final List<dynamic> raw = await _fmp.getBulkInsiderTrading(limit: 100);

      if (raw.isEmpty) {
        // 3. FALLBACK: FearGreed API
        final url = Uri.parse('https://feargreedchart.com/api/?action=insider');
        final response =
            await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = jsonDecode(response.body);
          final List<dynamic> combined = [
            ...(decoded['top_buys'] ?? []),
            ...(decoded['top_sells'] ?? [])
          ];
          return combined
              .map((x) =>
                  GlobalInsiderTrade.fromJson(Map<String, dynamic>.from(x)))
              .toList();
        }
        return [];
      }

      // Map FMP to Model with labelling
      List<GlobalInsiderTrade> trades = raw
          .map((x) => GlobalInsiderTrade.fromJson(Map<String, dynamic>.from(x)))
          .toList();

      final Map<String, Set<String>> buyersPerTicker = {};
      for (var t in trades.where((t) => t.type == 'buy')) {
        buyersPerTicker.putIfAbsent(t.symbol, () => {}).add(t.name);
      }

      return trades.map((t) {
        final List<String> labels = [];
        if (t.csuite) labels.add('C-SUITE');
        if (t.value > 500000) labels.add('SIGNIFICANT');
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
    } catch (e) {
      dev.log('❌ Error fetching global insider trades: $e',
          name: 'SigmaService');
      return [];
    }
  }

  /// Helper pour exécuter une future de manière sécurisée (fallback en cas d'erreur)
  /// Helper pour exécuter une future de manière sécurisée avec retry automatique
  Future<T> _safeCall<T>(
    Future<T> Function() call,
    T fallback, {
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 2,
    Duration retryDelay = const Duration(milliseconds: 500),
    String? sourceName, // Pour le monitoring
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt <= maxRetries) {
      try {
        final result = await call().timeout(timeout);

        // Enregistrer le succès
        if (sourceName != null) {
          dev.log('✅ Source OK: $sourceName', name: 'SigmaService');
        }

        // Si c'est un retry réussi, logger le succès
        if (attempt > 0) {
          dev.log(
              '✅ Service Call succeeded on retry $attempt${sourceName != null ? " ($sourceName)" : ""}',
              name: 'SigmaService');
        }

        return result;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;

        // Enregistrer l'échec
        if (sourceName != null && attempt > maxRetries) {
          dev.log('❌ Source failed: $sourceName — $e', name: 'SigmaService');
        }

        if (attempt <= maxRetries) {
          // Attendre avant de réessayer (backoff exponentiel)
          final delay = retryDelay * attempt;
          dev.log(
              '⚠️ Service Call failed (attempt $attempt/$maxRetries)${sourceName != null ? " ($sourceName)" : ""}, retrying in ${delay.inMilliseconds}ms: $e',
              name: 'SigmaService');
          await Future.delayed(delay);
        } else {
          dev.log(
              '❌ Service Call failed after $maxRetries retries${sourceName != null ? " ($sourceName)" : ""}: $e',
              name: 'SigmaService');
        }
      }
    }

    return fallback;
  }

  String _cleanJsonResponse(String input) {
    String cleaned = input.trim();

    // 1. Strip reasoning blocks from thinking models (DeepSeek, MiniMax, etc.)
    cleaned = cleaned
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'<thinking>.*?</thinking>', dotAll: true), '')
        .trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'<thought>.*?</thought>', dotAll: true), '')
        .trim();

    // 2. Strip markdown code fences
    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```\s*$', multiLine: true), '');
    cleaned = cleaned.trim();

    // 3. Find first '{' — skip any preamble text before JSON
    final firstBrace = cleaned.indexOf('{');
    if (firstBrace == -1) return '{}';
    cleaned = cleaned.substring(firstBrace);

    // 4. Find last '}' to trim trailing garbage (e.g. model commentary after JSON)
    final lastBrace = cleaned.lastIndexOf('}');
    if (lastBrace != -1 && lastBrace < cleaned.length - 1) {
      cleaned = cleaned.substring(0, lastBrace + 1);
    }

    // 5. Replace JSON-invalid literals
    cleaned = cleaned.replaceAll(RegExp(r':\s*NaN\b'), ': null');
    cleaned = cleaned.replaceAll(RegExp(r':\s*-?Infinity\b'), ': null');
    cleaned = cleaned.replaceAll(RegExp(r':\s*undefined\b'), ': null');
    // Strip JS/Python comments
    cleaned = cleaned.replaceAll(RegExp(r'//[^\n]*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    // Trailing commas before } or ]
    cleaned = cleaned.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r',\s*,'), ',');
    // Replace replacement characters
    cleaned = cleaned.replaceAll(RegExp(r'[\uFFFD\uFFFE\uFFFF]'), '');

    // 6. Clean control characters ONLY inside JSON string values
    // (outside strings, newlines/tabs are legal whitespace)
    cleaned = _cleanControlCharsInStrings(cleaned);

    // 7. If still invalid, try to close unclosed braces/brackets
    if (!_isValidJson(cleaned)) {
      // Check for odd number of unescaped quotes (unterminated string)
      int quoteCount = 0;
      bool escaped = false;
      for (int i = 0; i < cleaned.length; i++) {
        if (cleaned[i] == '\\') {
          escaped = !escaped;
          continue;
        }
        if (cleaned[i] == '"' && !escaped) quoteCount++;
        escaped = false;
      }
      if (quoteCount % 2 != 0) cleaned += '"';

      // Try trimming from the last valid closing brace
      for (int i = cleaned.length - 1; i >= 0; i--) {
        if (cleaned[i] == '}' || cleaned[i] == ']') {
          final attempt = _closeJson(cleaned.substring(0, i + 1));
          if (_isValidJson(attempt)) {
            cleaned = attempt;
            break;
          }
        }
      }
    }

    return _isValidJson(cleaned) ? cleaned : '{}';
  }

  String _closeJson(String partial) {
    String result = partial;
    int openBraces = 0;
    int openBrackets = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < result.length; i++) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (result[i] == '\\') {
        escaped = true;
        continue;
      }
      if (result[i] == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (result[i] == '{') openBraces++;
        if (result[i] == '}') openBraces--;
        if (result[i] == '[') openBrackets++;
        if (result[i] == ']') openBrackets--;
      }
    }

    if (inString) result += '"';
    while (openBrackets > 0) {
      result += ']';
      openBrackets--;
    }
    while (openBraces > 0) {
      result += '}';
      openBraces--;
    }
    return result;
  }

  bool _isValidJson(String json) {
    try {
      jsonDecode(json);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Replaces raw control characters (0x00-0x1F except \t, \n, \r) that appear
  /// INSIDE JSON string values, where they are illegal per RFC 8259.
  /// Outside strings, \n/\r/\t are legal whitespace and are left untouched.
  String _cleanControlCharsInStrings(String json) {
    final buf = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < json.length; i++) {
      final ch = json[i];
      final code = ch.codeUnitAt(0);

      if (escaped) {
        escaped = false;
        buf.write(ch);
        continue;
      }

      if (ch == '\\') {
        escaped = true;
        buf.write(ch);
        continue;
      }

      if (ch == '"') {
        inString = !inString;
        buf.write(ch);
        continue;
      }

      if (inString &&
          code < 0x20 &&
          code != 0x09 &&
          code != 0x0A &&
          code != 0x0D) {
        // Replace bare DEL / other control chars inside strings with a space
        buf.write(' ');
        continue;
      }

      buf.write(ch);
    }

    return buf.toString();
  }

  /// Tente de récupérer un JSON partiel ou malformé
  AnalysisData _recoverFromBadJson(
    String symbol,
    String language,
  ) {
    dev.log('⚠️ Tentative de récupération JSON pour $symbol...');

    final bool isFr = language.toUpperCase().startsWith('FR');

    // Créer une analyse minimale de fallback
    return AnalysisData(
      ticker: symbol,
      companyProfile: isFr
          ? 'Analyse temporairement indisponible. SIGMA tente de stabiliser la connexion aux sources de données.'
          : 'Analysis temporarily unavailable. SIGMA is attempting to stabilize connection to data sources.',
      lastUpdated: DateTime.now().toIso8601String(),
      price: 'N/A',
      verdict: isFr ? 'ATTENDRE' : 'HOLD',
      verdictReasons: [
        isFr
            ? 'Erreur de synchronisation avec les terminaux distants'
            : 'Synchronization error with remote terminals',
      ],
      riskLevel: isFr ? 'MOYEN' : 'MEDIUM',
      pros: [],
      cons: [],
      sigmaScore: 50.0,
      confidence: 0.0,
      summary: isFr
          ? 'Une erreur s\'est produite lors de l\'agrégation des données. Veuillez réessayer dans quelques instants.'
          : 'An error occurred during data aggregation. Please try again in a few moments.',
      hiddenSignals: [],
      catalysts: [],
      volatility: VolatilityData(
        ivRank: 'N/A',
        beta: 'N/A',
        interpretation: 'N/A',
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
      financialMatrix: [
        FinancialMatrixItem(
          label: isFr ? 'CAPITALISATION BOURS.' : 'MARKET CAP.',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: 'P/E RATIO',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: 'ROIC',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: 'D/E RATIO',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: 'EPS',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: 'ROE',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: 'EBIT',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
        FinancialMatrixItem(
          label: isFr ? 'MARGE BRUTE' : 'GROSS MARGIN',
          value: isFr ? 'En attente...' : 'Waiting...',
          assessment: 'NEUTRAL',
        ),
      ],
      sectorPeers: [],
      topSources: [],
      analystRecommendations: AnalystRecommendation(
        strongBuy: 0,
        buy: 0,
        hold: 0,
        sell: 0,
        strongSell: 0,
        period: '',
      ),
      technicalAnalysis: [],
      actionPlan: [isFr ? 'Réessayer l\'analyse' : 'Retry analysis'],
      analystRatings: [],
      insiderTransactions: [],
      institutionalActivity: InstitutionalActivity(
        smartMoneySentiment: 50.0,
        retailSentiment: 50.0,
        darkPoolInterpretation:
            isFr ? 'En attente de flux...' : 'Waiting for flow data...',
      ),
      projectedTrend: List.generate(
        7,
        (i) => ProjectedTrendPoint(
            date: "J+${i + 1}", price: 0.0, signal: 'NEUTRAL'),
      ),
      socialSentiment: null,
      recommendationSteps: [
        isFr
            ? 'Étape 1 : Analyse des terminaux SIGMA en cours...'
            : 'Step 1: SIGMA terminal analysis in progress...',
        isFr
            ? 'Étape 2 : Vérification des flux asymétriques...'
            : 'Step 2: Verifying asymmetric flows...',
      ],
    );
  }

  Future<String> chatWithSigma({
    required String ticker,
    required AnalysisData context,
    required String question,
    List<Map<String, String>> history = const [],
    String language = 'EN',
  }) async {
    final langInstr = language == 'FR'
        ? 'RÉPONDS ENTIÈREMENT EN FRANÇAIS.'
        : 'RESPOND ENTIRELY IN ENGLISH.';

    final topFinancials = context.financialMatrix
        .take(8)
        .map((e) => '${e.label}: ${e.value}')
        .join(', ');

    final topTech = context.technicalAnalysis
        .take(3)
        .map((t) => '${t.indicator}: ${t.value}')
        .join(' | ');

    final historyPrompt = history.isEmpty
        ? ''
        : '\n\nHISTORIQUE DE LA CONVERSATION:\n${history.map((m) => '${m['role'] == 'user' ? 'UTILISATEUR' : 'SIGMA'}: ${m['text']}').join('\n')}';

    final prompt = '''
$langInstr

Tu es l'Intelligence Artificielle SIGMA, expert en marchés financiers globaux.
Ta mission est de répondre de manière CHIRURGICALE et PRÉCISE à la question de l'utilisateur.

DONNÉES TEMPS RÉEL DU TERMINAL ($ticker):
- Prix: ${context.price} | Verdict: ${context.verdict} | Score: ${context.sigmaScore.toInt()}/100
- Fondamentaux: $topFinancials
- Technique: $topTech
- Résumé: ${context.summary.length > 400 ? '${context.summary.substring(0, 400)}...' : context.summary}$historyPrompt

QUESTION DE L'UTILISATEUR:
"$question"

OBJECTIF : Réponds UNIQUEMENT à cette question. Ne fais pas de résumé général si ce n'est pas demandé. Utilise les chiffres du contexte pour prouver tes dires.

DIRECTIVE DE RÉPONSE (STRICTE) : 
1. RÉPONSE CIBLÉE : Si la question porte sur un indicateur précis, ne parle que de cet indicateur.
2. ZÉRO MARKDOWN : Texte brut uniquement. Pas de ** ou #.
3. PAS DE BLA-BLA : Va droit au but.
''';

    return _marketProvider
        .generateContent(
          prompt: prompt,
          systemInstruction: _systemInstructionChat,
          jsonMode: false,
          useThinking: true,
        )
        .timeout(const Duration(seconds: 90));
  }

  /// Version streaming du chat pour une meilleure réactivité
  Stream<String> chatWithSigmaStream({
    required String ticker,
    required AnalysisData context,
    required String question,
    List<Map<String, String>> history = const [],
    String language = 'EN',
    String ragContext = '',
  }) {
    final langInstr = language == 'FR'
        ? 'RÉPONDS ENTIÈREMENT EN FRANÇAIS.'
        : 'RESPOND ENTIRELY IN ENGLISH.';

    final topFinancials = context.financialMatrix
        .take(8)
        .map((e) => '${e.label}: ${e.value}')
        .join(', ');

    final topTech = context.technicalAnalysis
        .take(3)
        .map((t) => '${t.indicator}: ${t.value}')
        .join(' | ');

    final historyPrompt = history.isEmpty
        ? ''
        : '\n\nHISTORIQUE DE LA CONVERSATION:\n${history.map((m) => '${m['role'] == 'user' ? 'UTILISATEUR' : 'SIGMA'}: ${m['text']}').join('\n')}';

    final ragBlock = ragContext.isEmpty ? '' : '\n\n$ragContext';

    final prompt = '''
$langInstr

Tu es l'Intelligence Artificielle SIGMA, expert en marchés financiers globaux.
Ta mission est de répondre de manière CHIRURGICALE et PRÉCISE à la question de l'utilisateur.

DONNÉES TEMPS RÉEL DU TERMINAL ($ticker):
- Prix: ${context.price} | Verdict: ${context.verdict} | Score: ${context.sigmaScore.toInt()}/100
- Fondamentaux: $topFinancials
- Technique: $topTech
- Résumé: ${context.summary.length > 400 ? '${context.summary.substring(0, 400)}...' : context.summary}$ragBlock$historyPrompt

QUESTION DE L'UTILISATEUR:
"$question"

OBJECTIF : Réponds UNIQUEMENT à cette question. Ne fais pas de résumé général si ce n'est pas demandé. Utilise les chiffres du contexte pour prouver tes dires.

DIRECTIVE DE RÉPONSE (STRICTE) : 
1. RÉPONSE CIBLÉE : Si la question porte sur un indicateur précis, ne parle que de cet indicateur.
2. ZÉRO MARKDOWN : Texte brut uniquement. Pas de ** ou #.
3. PAS DE BLA-BLA : Va droit au but.
''';

    return _marketProvider.generateStream(
      prompt: prompt,
      systemInstruction: _systemInstructionChat,
      jsonMode: false,
    );
  }

  /// Stream une synthèse stratégique basée sur les données d'analyse déjà extraites
  Stream<String> streamAnalysisSynthesis({
    required AnalysisData analysis,
    String language = 'fr',
  }) {
    final bool isFr = language.toUpperCase().startsWith('FR');
    final prompt = '''
Tu es le 'SIGMA RESEARCH ORCHESTRATOR'. 
Génère une synthèse stratégique PERCUTANTE et ANALYTIQUE pour ${analysis.ticker} (${analysis.companyName}).

DONNÉES CLÉS :
- Prix : ${analysis.price} | Verdict : ${analysis.verdict} | Score : ${analysis.sigmaScore.toInt()}
5. Finance : ${analysis.financialMatrix.take(5).map((e) => "${e.label}:${e.value}").join(", ")}
- Technique : ${analysis.technicalAnalysis.take(5).map((e) => "${e.indicator}:${e.value}").join(", ")}

MISSON : Rédige une synthèse de MAXIMUM 60 MOTS.
STYLE : Institutionnel, chirurgical, sans blabla.
DATE : 11 AVRIL 2026.
LANGUE : ${isFr ? "FRANÇAIS (OBLIGATOIRE)" : "ENGLISH"}.

ZÉRO MARKDOWN (pas de ** ou #). Texte brut uniquement.
SI LA LANGUE EST FRANÇAIS, NE GÉNÈRE AUCUN MOT EN ANGLAIS.
''';

    return _marketProvider.generateStream(
      prompt: prompt,
      systemInstruction: _getSystemInstructionSynthesis(language),
      jsonMode: false,
    );
  }

  dynamic _extractRaw(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value['raw'] ?? value['fmt'];
    return value;
  }

  String _formatLargeNumber(dynamic value) {
    if (value == null) return 'N/A';
    final num n =
        value is num ? value : (double.tryParse(value.toString()) ?? 0);
    if (n >= 1e12) return '${(n / 1e12).toStringAsFixed(2)}T';
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(2)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(2)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(2)}K';
    return n.toStringAsFixed(2);
  }

  /// Extrait le sentiment du marché de manière "agentique" depuis les résultats de recherche web
  Map<String, dynamic> _parseSentiment(String context, double vix) {
    if (context.isEmpty) return {'label': 'NEUTRAL', 'value': 0.0};

    // 1. Recherche du score numérique exact (ex: "Fear and Greed Index: 42")
    final scoreRegex =
        RegExp(r'(?:Fear|Greed|Index)[:\s]+(\d{1,2})', caseSensitive: false);
    final match = scoreRegex.firstMatch(context);

    double value = 0.0;
    if (match != null) {
      value = double.tryParse(match.group(1)!) ?? 0.0;
    }

    // 2. Si pas de score numérique, recherche de mots-clés de sentiment
    String label = "";
    if (value > 0) {
      if (value <= 25) {
        label = "EXTREME FEAR";
      } else if (value <= 45)
        label = "FEAR";
      else if (value <= 55)
        label = "NEUTRAL";
      else if (value <= 75)
        label = "GREED";
      else
        label = "EXTREME GREED";
    } else {
      // Fallback text analysis keywords
      final ctxUpper = context.toUpperCase();
      if (ctxUpper.contains("EXTREME FEAR")) {
        label = "EXTREME FEAR";
      } else if (ctxUpper.contains("EXTREME GREED"))
        label = "EXTREME GREED";
      else if (ctxUpper.contains("FEAR"))
        label = "FEAR";
      else if (ctxUpper.contains("GREED")) label = "GREED";
    }

    if (label.isEmpty && value == 0.0) {
      // Fallback ultime sur le VIX
      value = vix > 30 ? 20 : (vix > 20 ? 40 : 70);
      label = vix > 30 ? "EXTREME FEAR" : (vix > 20 ? "FEAR" : "GREED");
    }

    return {'label': label, 'value': value};
  }

  static const String _systemInstructionRadar = '''
You are the "SIGMA CATALYST RADAR", an agentic system that scans global news and macro correlations for a specific watchlist.
Your goal is to identify HIDDEN catalysts or risks that are not immediately obvious.

You will receive a list of TICKERS and a list of RECENT NEWS/MACRO DATA.
You must output a JSON array of specific insights.

JSON STRUCTURE:
[
  {
    "ticker": "SYMBOL",
    "title": "Short catchy title",
    "description": "Deep agentic insight (2 sentences max)",
    "impactScore": 0.0-1.0,
    "isNegative": true/false,
    "source": "AI Correlation Engine"
  }
]
### RELIABILITY PROTOCOL:
- DO NOT INVENT TICKERS.
- DO NOT INVENT DATA.
- ONLY report catalysts explicitly mentioned in the "LIVE DATA FEED" below.
- If a ticker is provided but no news is found in the feed, IGNORE IT.
- For massive price moves (>10%), EXPLAIN the specific reason found in the news.
- FOCUS STRICT SUR LES DONNÉES DE 2026. DATE ACTUELLE: 11 AVRIL 2026. 
- Focus sur CROSS-CORRELATIONS.
- Be extremely specific and high-conviction.
''';

  Future<List<CatalystInsight>> getAgenticRadar(List<String> tickers) async {
    if (tickers.isEmpty) return [];

    try {
      // 1. Gather Macro Data (FMP)
      final macroSummaryList = await _getMarketSummaryWithFallback();
      final macroStr = macroSummaryList
          .take(5)
          .map((e) => "${e['symbol']}: ${e['price']} (${e['changePercent']}%)")
          .join(", ");

      // 2. Fetch Deep News for outlier tickers (Agentic scan) in PARALLEL
      final List<String> tickersToScan = tickers.take(8).toList();

      // Multi-threading data discovery via FMP
      final newsResults = await Future.wait(tickersToScan.map((t) =>
          _fmp.getStockNews(t, limit: 3).catchError((_) => <dynamic>[])));

      final webSearchTask = _webSearch
          .search(
              "market driving catalysts and breaking financial news ${DateTime.now().toIso8601String().substring(0, 10)}")
          .catchError((_) => "Web search temporary unavailable.");

      String newsContext = "";
      for (int i = 0; i < tickersToScan.length; i++) {
        final news = newsResults[i];
        if (news.isNotEmpty) {
          final topNews = news
              .take(2)
              .map((n) => "[${tickersToScan[i]}] ${n['title']}")
              .join("; ");
          newsContext += "$topNews. ";
        }
      }

      final webContext = await webSearchTask;

      final prompt = """
LIVE DATA FEED:
MACRO: $macroStr
COMPANY NEWS: $newsContext
WEB SEARCH TRENDS: ${webContext.length > 1000 ? webContext.substring(0, 1000) : webContext}

TICKERS TO EVALUATE: ${tickers.join(", ")}

MISSION: Identify 4 critical, high-impact catalysts or risks specifically for these tickers based ON THE LIVE FEED ABOVE.
Don't use old data. Focus on the news titles provided.
""";

      final response = await _marketProvider.generateContent(
        prompt: prompt,
        systemInstruction: _systemInstructionRadar,
      );

      final cleanResponse = _extractJson(response);
      final List<dynamic> list = jsonDecode(cleanResponse);
      return list.map((e) => CatalystInsight.fromJson(e)).toList();
    } catch (e) {
      dev.log("❌ Error in Agentic Radar: $e", name: "SigmaService");
      return [];
    }
  }

  static const String _systemInstructionStrategy = '''
You are the "SIGMA STRATEGY DISCOVERY AGENT".
Your mission is to find high-potential stocks based on a user's strategy description.

INPUT: A strategy description (e.g., "AI stocks with high growth", "Defensive stocks for recession").
OUTPUT: A JSON array of tickers with brief justifications.

JSON STRUCTURE:
[
  {
    "ticker": "SYMBOL",
    "reason": "Brief strategic justification (1 sentence)",
    "relevanceScore": 0.0-1.0
  }
]
''';

  Future<List<Map<String, dynamic>>> searchTickersByStrategy(
      String strategy) async {
    try {
      final response = await _marketProvider.generateContent(
        prompt: "STRATEGY: $strategy",
        systemInstruction: _systemInstructionStrategy,
      );

      final cleanResponse = _extractJson(response);
      return List<Map<String, dynamic>>.from(jsonDecode(cleanResponse));
    } catch (e) {
      print("Error in Strategy Discovery: $e");
      return [];
    }
  }

  Future<String> analyzeHistoricalPoint(
      String ticker, Map<String, dynamic> point,
      {String language = 'FRANÇAIS'}) async {
    try {
      final date = point['date'].toString().split(' ')[0];
      final prompt = '''
      Analyze this specific technical point for $ticker on $date:
      OHLC: Open:${point['open']} | High:${point['high']} | Low:${point['low']} | Close:${point['close']}
      
      Output requirement:
      - EXACTLY 2-3 sentences.
      - PLAIN TEXT ONLY. 
      - DO NOT USE JSON. DO NOT USE MARKDOWN. NO EMOJIS.
      - Respond in $language.
      ''';

      final res = await _stockProvider.generateContent(
        prompt: prompt,
        systemInstruction:
            "You are an institutional financial analyst. Deliver raw text only. No JSON.",
      );

      return _cleanPointResponse(res);
    } catch (e) {
      return "Point analyzed. Technical bias remains consistent with the local trend.";
    }
  }

  Future<String> analyzeHistoricalRange(AnalysisData contextData,
      List<Map<String, dynamic>> history, String range,
      {String language = 'FRANÇAIS'}) async {
    if (history.isEmpty) return "Données insuffisantes.";
    try {
      final first = history.first['close'];
      final last = history.last['close'];
      final high =
          history.map((e) => e['high'] as num).reduce((a, b) => a > b ? a : b);
      final low =
          history.map((e) => e['low'] as num).reduce((a, b) => a < b ? a : b);
      final newsStr =
          contextData.companyNews.take(3).map((n) => n.title).join(' | ');

      final prompt = '''
      Analyze the $range price action for ${contextData.ticker} (${contextData.companyName} - ${contextData.sector}):
      - PRICE DATA: Start: $first | End: $last | Range High: $high | Range Low: $low
      - RISK METRICS: Beta: ${contextData.keyStatistics?.beta ?? 'N/A'} | Short Ratio: ${contextData.keyStatistics?.shortRatio ?? 'N/A'} | IV: ${contextData.volatility.ivRank}
      - RECENT CATALYSTS & NEWS: $newsStr
      
      Provide a 2-sentence institutional summary for this period. 
      PLAIN TEXT ONLY. NO JSON. NO MARKDOWN. 
      Respond in $language.
      ''';

      final res = await _stockProvider.generateContent(
        prompt: prompt,
        systemInstruction:
            "You are a technical strategist. Deliver analytical plain text.",
      );
      return _cleanPointResponse(res);
    } catch (e) {
      return "Analyse de période $range complétée.";
    }
  }

  String _cleanPointResponse(String text) {
    String clean = text.trim();
    if (clean.contains('```')) {
      clean = clean
          .replaceAll(RegExp(r'```(?:json)?\n?'), '')
          .replaceAll('```', '')
          .trim();
    }
    return _finalTrim(clean);
  }

  String _finalTrim(String text) {
    String clean = text.trim();

    // JSON extraction
    if (clean.contains('{') && clean.contains('}')) {
      try {
        final start = clean.indexOf('{');
        final end = clean.lastIndexOf('}') + 1;
        final Map<String, dynamic> decoded =
            jsonDecode(clean.substring(start, end));
        clean = (decoded['verdict'] ??
                decoded['analysis'] ??
                decoded['summary'] ??
                decoded['text'] ??
                clean)
            .toString();
      } catch (_) {}
    }

    return clean
        .trim()
        .replaceAll(
            RegExp(r'^(Résumé|Summary|Analysis|Verdict)\s*:\s*',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'^["{]|["}]$'), '')
        .trim();
  }

  String _extractJson(String text) {
    if (!text.contains('[')) return text;
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']') + 1;
    return text.substring(start, end);
  }

  DateTime _parseAnyDate(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return DateTime.now();
    final s = raw.toString();

    // Unix seconds
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final val = int.tryParse(s) ?? 0;
      if (val > 1000000000000) {
        // milliseconds
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      return DateTime.fromMillisecondsSinceEpoch(val * 1000);
    }

    // ISO/Standard string
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;

    // Fallback
    return DateTime.now();
  }
}
