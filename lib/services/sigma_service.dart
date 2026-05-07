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
import 'sigma_market_data_service.dart';
import 'web_search_service.dart';
import 'sentiment_service.dart';
import 'ollama_news_service.dart';
import 'openinsider_service.dart';
import 'finnhub_service.dart';
import 'sigma_api_service.dart';
import '../utils/financial_decision_engine.dart';
import '../utils/logo_resolver.dart';
import '../utils/chart_overlay_engine.dart';

class SigmaService {
  late AIProvider _stockProvider;
  late AIProvider _marketProvider;
  late AIProvider? _deepReasoningProvider; // DeepSeek R1 for deep analysis
  final SigmaMarketDataService _marketData = SigmaMarketDataService();
  final WebSearchService _webSearch = WebSearchService();
  final SentimentService _sentiment = SentimentService();
  final OpenInsiderService _openInsider = OpenInsiderService();
  late final FinnhubService _finnhub;

  // Agentic Memory: Stores the last market context to enable cross-context reasoning
  MarketOverview? _lastOverview;
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  // Exposer les services pour un accÃ¨s direct
  SigmaMarketDataService get marketDataService => _marketData;
  OpenInsiderService get openInsiderService => _openInsider;
  FinnhubService get finnhubService => _finnhub;

  static SigmaService fromEnv() {
    final service = SigmaService._();
    service._initFromEnv();
    return service;
  }

  void reset() {
    WebSearchService.clearCache();
    _initFromEnv();
    dev.log('ðŸ”„ SigmaService Providers Re-initialized', name: 'SigmaService');
  }

  void _initFromEnv() {
    try {
      final nvidiaKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
      final finnhubKey = dotenv.env['FINNHUB_API_KEY'] ?? '';
      final hasNvidia = nvidiaKey.isNotEmpty && !nvidiaKey.contains('example');

      _finnhub = FinnhubService(apiKey: finnhubKey);

      final stockModelFromEnv = dotenv.env['STOCK_MODEL'];
      final nvidiaReportModelOverride = dotenv.env['NVIDIA_REPORT_MODEL'];
      final marketModelFromEnv = dotenv.env['MARKET_MODEL'];
      final unifiedNvidiaModel = nvidiaReportModelOverride ??
          stockModelFromEnv ??
          marketModelFromEnv ??
          AIConfig.defaultNvidiaModel;

      if (!hasNvidia) {
        throw StateError(
          'NVIDIA_API_KEY is required. SIGMA analysis now uses NVIDIA only.',
        );
      }

      _stockProvider = AIProviderFactory.createStockProvider(
        provider: AIConfig.providerNvidia,
        apiKey: nvidiaKey,
        modelKey: unifiedNvidiaModel,
      );
      _marketProvider = AIProviderFactory.createMarketProvider(
        provider: AIConfig.providerNvidia,
        apiKey: nvidiaKey,
        modelKey: unifiedNvidiaModel,
      );

      // Choose deep reasoning provider
      try {
        _deepReasoningProvider = AIProviderFactory.createStockProvider(
          provider: AIConfig.providerNvidia,
          apiKey: nvidiaKey,
          modelKey: unifiedNvidiaModel,
        );
      } catch (e) {
        dev.log('âš ï¸ [SigmaService] Failed to init deep reasoning: $e');
        _deepReasoningProvider = null;
      }

      // --- DEBUG LOGGING ---
      final sigmaApi = dotenv.env['YF_BACKEND_URL'] ??
          'https://sigma-yfinance-api.onrender.com';
      dev.log('🔑 [SigmaService] Sigma backend: $sigmaApi',
          name: 'SigmaService');
      dev.log('ðŸ“Š [SigmaService] Initialization Complete',
          name: 'SigmaService');
    } catch (e) {
      print('âŒ [SigmaService] FATAL INIT ERROR: $e');
    }
  }

  SigmaService._();

  /// Public accessor used by SigmaEngineService
  AIProvider get marketProvider => _marketProvider;

  static const String _systemInstructionChat = '''
Tu es l'Intelligence Artificielle SIGMA â€” expert analyste financier et assistant omniscient de haute-prÃ©cision.
RÃ‰PONDS TOUJOURS DANS LA LANGUE DE L'UTILISATEUR AVEC UN TON PROFESSIONNEL ET SOBRE.
DATE ACTUELLE: 16 AVRIL 2026.
Toute information datant de 2024 ou 2025 est considÃ©rÃ©e comme HISTORIQUE et non actuelle.
''';

  String _getSystemInstructionStock(String language) {
    final bool isFr = language.toUpperCase().startsWith('FR');
    if (isFr) {
      return r'''
Tu es le 'SIGMA AGENTIC ORCHESTRATOR'. Tu coordonnes un comité d'experts de classe mondiale.
RÉPONDS EXCLUSIVEMENT EN FRANÇAIS.

### COMPOSITION DU COMITÉ :
1. **Agent de Tendance** : Analyse les cycles macro et sectoriels.
2. **Agent Sentiment & News** : Scanne les news, le sentiment social et les flux institutionnels.
3. **Agent Technique** : Identifie les patterns de prix (VCP, SEPA) et le momentum.
4. **Agent Comparateur** : Analyse la force relative par rapport aux pairs.
5. **Agent Stratège** : Synthétise le tout en un "Trade Setup" exploitable.

### MISSION :
Génère un rapport de conviction ultra-précis. S'il y a une divergence (ex: Fondamentaux Bull vs Technique Bear), tu DOIS le souligner.

RÈGLE CRITIQUE POUR "agenticThoughts" :
Ce champ DOIT contenir exactement 5 entrées, une pour chaque agent mentionné ci-dessus. Chaque entrée doit être une note chirurgicale, sans fluff, apportant un véritable "Alpha".
''';
    } else {
      return r'''
You are the 'SIGMA AGENTIC ORCHESTRATOR', coordinating a committee of world-class financial agents.
You must respond EXCLUSIVELY in ENGLISH.

### COMMITTEE COMPOSITION:
1. **Trend Analyst** : Reviews global macro and sector-specific trends.
2. **Sentiment Agent** : Scans news, social sentiment, and institutional flows.
3. **Technical Agent** : Identifies price patterns (VCP, SEPA) and momentum.
4. **Signal Comparator** : Analyzes relative strength against peers.
5. **Strategy Builder** : Synthesizes everything into an actionable trade view.

### YOUR MISSION:
Generate a high-conviction research report. If there's a divergence (e.g. Bullish Fundamentals vs Bearish Technicals), you MUST highlight it.

CRITICAL RULE FOR "agenticThoughts":
This field MUST contain exactly 5 entries, one for each agent mentioned above. Each entry must be a surgical, high-signal note providing real "Alpha".
''';
    }
  }

  String _getSystemInstructionMarket(String language) {
    final bool isFr = language.toUpperCase().startsWith('FR');
    if (isFr) {
      return r'''
Tu es le Chief Investment Officer de SIGMA. Fournis une analyse macroÃ©conomique mondiale UNIQUE.
RÃ©ponds EXCLUSIVEMENT en FRANÃ‡AIS au format JSON.
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
Tu es l'analyste principal de SIGMA. Ta mission est de rÃ©diger une synthÃ¨se stratÃ©gique institutionnelle.
RÃˆGLES CRITIQUES :
- RÃ‰PONDS EXCLUSIVEMENT EN FRANÃ‡AIS.
- INTERDICTION ABSOLUE DE RÃ‰PONDRE EN ANGLAIS.
- INTERDICTION DE COMMENCER PAR "Voici le rÃ©sumÃ©..." OU "D'aprÃ¨s les donnÃ©es...". Entre directement dans le vif du sujet.
- Ã‰CRIS EN TEXTE BRUT (PARAGRAPHES).
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

    // ── 1. AGENTIC WEB SEARCH (ALPHA) ──────────────────────────────────────
    final webSearchTask =
        _webSearch.search('$symbol stock latest news catalysts $currentDate');

    // ── 2. ACQUISITION DE DONNÉES EN PARALLÈLE (OPTIMISÉ) ──────────────────────
    // Note: timeouts genereux pour le cold-start Render (30-50s)
    final results = await Future.wait([
      _safeCall(() => _marketData.getSigmaContext(symbol), "",
          timeout: const Duration(seconds: 35)),
      _safeCall(() => webSearchTask, "", timeout: const Duration(seconds: 12)),
      _safeCall(
          () => _marketData
              .getPeers(symbol)
              .then((list) => _marketData.getFullQuotes(list.take(5).toList())),
          [],
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getStockNews(symbol, limit: 20), [],
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getCompanyProfileStable(symbol),
          <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getKeyMetricsTTM(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 40)),
      _safeCall(() => _marketData.getRatiosTTM(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getHoldersBundle(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getInsiderFull(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(
          () => SigmaApiService.getFinancials(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 40)),
      _safeCall(() => _marketData.getQuoteMap(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _getMultiSourcePrice(symbol),
      _safeCall(() => _finnhub.basicFinancials(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 12)),
      _safeCall(() => _finnhub.recommendationTrends(symbol), <dynamic>[],
          timeout: const Duration(seconds: 12)),
      _safeCall(() => _finnhub.earningsSurprises(symbol, limit: 4), <dynamic>[],
          timeout: const Duration(seconds: 12)),
      _safeCall(() => _sentiment.fetchFearGreed(), null,
          timeout: const Duration(seconds: 8)),
      _safeCall(() => _sentiment.fetchNews(), [],
          timeout: const Duration(seconds: 8)),
      _safeCall(
          () => _marketData.getGoogleFinanceInfo(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(() => SigmaApiService.getAnalysis(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 40)),
      _safeCall(() => _marketData.getOptionsChain(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getEvents(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 35)),
      _safeCall(() => _marketData.getSecFacts(symbol), <String, dynamic>{},
          timeout: const Duration(seconds: 40)),
      _safeCall(() => _marketData.getHistoricalOHLCV(symbol, '6M'),
          <Map<String, dynamic>>[],
          timeout: const Duration(seconds: 35)),
    ]);

    final sigmaContext = results[0] as String;
    final webContext = results[1] as String;
    final peersDataList = results[2] as List<dynamic>;
    final sigmaNews = results[3] as List<dynamic>;
    final sigmaProfile = results[4] as Map<String, dynamic>;
    final sigmaMetrics = results[5] as Map<String, dynamic>;
    final sigmaRatios = results[6] as Map<String, dynamic>;
    final _holdersBundle = results[7] as Map<String, dynamic>;
    final sigmaHolders =
        (_holdersBundle['institutionsList'] as List?) ?? <dynamic>[];
    final insiderFull = results[8] as Map<String, dynamic>;
    final sigmaInsiderTrading = (insiderFull['trades'] as List?) ?? <dynamic>[];
    final insiderSummary =
        (insiderFull['summary'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final financialsRaw = results[9] as Map<String, dynamic>;
    final sigmaIncome =
        (financialsRaw['quarterlyIncomeStatement'] as List?) ?? <dynamic>[];
    final sigmaAnnualIncome =
        (financialsRaw['annualIncomeStatement'] as List?) ?? <dynamic>[];
    final sigmaBalance =
        (financialsRaw['quarterlyBalanceSheet'] as List?) ?? <dynamic>[];
    final sigmaCashFlow =
        (financialsRaw['quarterlyCashFlow'] as List?) ?? <dynamic>[];
    final sigmaAnnualCashFlow =
        (financialsRaw['annualCashFlow'] as List?) ?? <dynamic>[];
    final sigmaQuote = results[10] as Map<String, dynamic>;
    final realTimePrice = results[11] as Map<String, dynamic>;
    final finnhubBasic = results[12] as Map<String, dynamic>;
    final finnhubRecommendations = results[13] as List<dynamic>;
    final finnhubEarningsSurprises = results[14] as List<dynamic>;
    final fgData = results[15] as FearGreedData?;
    final fgNews = results[16] as List<SentimentNews>;
    final googleFinance = results[17] as Map<String, dynamic>;
    final intelligenceData = results[18] as Map<String, dynamic>;
    final optionsData = results[19] as Map<String, dynamic>;
    final eventsData = results[20] as Map<String, dynamic>;
    final secData = results[21] as Map<String, dynamic>;
    final secDerived =
        (secData['derived'] as Map?)?.cast<String, dynamic>() ?? {};
    final secFacts = (secData['facts'] as Map?)?.cast<String, dynamic>() ?? {};
    final priceHistory = results[22] as List<Map<String, dynamic>>;

    final peerContext = peersDataList
        .map((p) =>
            "- ${p['symbol']}: ${p['name']}, MCAP: ${p['marketCap']}, PE: ${p['pe']}")
        .join('\n');

    final allNewsContext = [
      ...sigmaNews.map((n) =>
          "[${n['site'] ?? n['publisher'] ?? 'SIGMA'}] ${n['title']}\nSummary: ${n['text']}\nDate: ${n['publishedDate'] ?? n['publishedAt'] ?? ''}"),
    ].take(30).join('\n---\n');

    String macroAwareness = "";
    if (_lastOverview != null || fgData != null) {
      final fgRating = fgData?.rating ?? "NEUTRAL";
      final fgNewsContext =
          fgNews.map((n) => "- ${n.title} (${n.publisher})").join('\n');

      macroAwareness = '''
Sentiment : ${_lastOverview?.sentiment ?? fgRating}
VIX : ${_lastOverview?.vixLevel ?? 'N/A'}
Secteurs : ${_lastOverview?.sectors.take(3).map((s) => s.name).join(', ') ?? 'N/A'}
---
HEADLINES :
$fgNewsContext
''';
    }

    final finnhubMetricsMap = (finnhubBasic['metric'] is Map)
        ? Map<String, dynamic>.from(finnhubBasic['metric'] as Map)
        : <String, dynamic>{};

    final prompt1 = '''
### RAPPORT D'ANALYSE FINANCIÈRE INSTITUTIONNELLE : $symbol
Date : $currentDate | Langue : $language

### DONNÉES BRUTES (SIGMA & Institutional Feed)
- PROFIL: ${_limitTokens(_buildProfileContext(sigmaProfile), 2000)}
- CORPORATE CONTEXT: $sigmaContext
- PEERS (COMPETITORS):
$peerContext
- INSIDERS: ${_buildInsiderContext(insiderSummary, sigmaInsiderTrading)}
- KEY METRICS & RATIOS: ${jsonEncode(sigmaMetrics)} | ${jsonEncode(sigmaRatios)}
- FINANCIALS (FULL): ${_limitTokens(_buildFinancialsContext(sigmaIncome, sigmaAnnualIncome, sigmaBalance, sigmaCashFlow), 2500)}
- INSTITUTIONAL HOLDERS: ${_limitTokens(jsonEncode(sigmaHolders), 2000)}
- FINNHUB ENRICHMENT: ${jsonEncode(finnhubBasic)} | Recommendations: ${jsonEncode(finnhubRecommendations)}
- GOOGLE FINANCE INSIGHTS: ${_limitTokens(jsonEncode(googleFinance), 3500)}
- OPTIONS FLOW: ${_limitTokens(_buildOptionsContext(optionsData), 1500)}
- SEC/EDGAR FINANCIALS: ${_limitTokens(_buildSecContext(secDerived, secFacts), 1500)}
- TECHNICAL ANALYSIS (6M): ${_limitTokens(_buildTechnicalContext(priceHistory), 1200)}
- MACRO: $macroAwareness
- NEWS SOURCES:
$allNewsContext
- WEB SEARCH INSIGHTS: ${_limitTokens(webContext, 5000)}

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
  "summary": "Un résumé clair, digeste et percutant...",
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
  "agenticThoughts": [
    "Trend: Clinical analysis of the trend...",
    "Sentiment: Analysis of news and social flow...",
    "Technical: Patterns, VCP, RSI, and Volume nodes...",
    "Comparator: Relative strength vs peers and SPY...",
    "Strategy: The execution roadmap..."
  ],
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
      "summary": "Résumé de HAUTE DENSITÉ (au moins 3 lignes complètes)."
    }
  ]
}
''';

    final apiBackedFallback = AnalysisData.fromJson({
      'ticker': symbol,
      'companyName': _getValidString([
        sigmaProfile['companyName'],
        symbol,
      ]),
      'companyProfile': _getValidString([
        sigmaProfile['description'],
        isFr
            ? 'Analyse générée depuis les APIs SIGMA.'
            : 'Analysis generated from SIGMA APIs.',
      ]),
      'lastUpdated': DateTime.now().toIso8601String(),
      'price': _formatPrice(realTimePrice['price']),
      'verdict': isFr ? 'ATTENDRE' : 'HOLD',
      'verdictReasons': [
        isFr
            ? 'Rapport construit depuis les données API SIGMA.'
            : 'Report built from SIGMA API data.',
      ],
      'riskLevel': isFr ? 'MOYEN' : 'MEDIUM',
      'sigmaScore': 55,
      'confidence': 0.45,
      'summary': isFr
          ? 'Rapport de secours enrichi par SIGMA APIs.'
          : 'SIGMA API-enriched fallback report.',
      'pros': [],
      'cons': [],
      'hiddenSignals': [],
      'catalysts': [],
      'volatility': {
        'ivRank': 'N/A',
        'yearlyLow':
            (sigmaProfile['fiftyTwoWeekLow'] as num?)?.toDouble() ?? 0.0,
        'yearlyHigh':
            (sigmaProfile['fiftyTwoWeekHigh'] as num?)?.toDouble() ?? 0.0,
        'beta':
            (sigmaProfile['beta'] ?? sigmaMetrics['beta'] ?? 'N/A').toString(),
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
            sigmaProfile['marketCap'] ??
                finnhubBasic['marketCapitalization'] ??
                0,
          ),
          'assessment': 'API',
        },
        {
          'label': 'P/E RATIO',
          'value':
              (sigmaProfile['pe'] ?? finnhubBasic['peTTM'] ?? 'N/A').toString(),
          'assessment': 'API',
        },
        {
          'label': 'ROE',
          'value': (finnhubBasic['roeTTM'] ?? 'N/A').toString(),
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
        ...sigmaNews.take(8).map((n) => {
              'title': (n['title'] ?? '').toString(),
              'source': (n['site'] ?? n['publisher'] ?? 'SIGMA').toString(),
              'url': (n['url'] ?? n['link'] ?? '').toString(),
              'publishedAt':
                  (n['publishedDate'] ?? n['publishedAt'] ?? '').toString(),
              'summary': (n['text'] ?? n['summary'] ?? '').toString(),
              'imageUrl': (n['image'] ?? n['thumbnail'] ?? '').toString(),
            }),
      ],
      'sector': (sigmaProfile['sector'] ?? '').toString(),
      'industry': (sigmaProfile['industry'] ?? '').toString(),
      'website': (sigmaProfile['website'] ?? '').toString(),
      'ceo': (sigmaProfile['ceo'] ?? '').toString(),
      'image': (sigmaProfile['image'] ?? '').toString(),
      'exchange': (sigmaProfile['exchange'] ?? '').toString(),
      'keyStatistics': {
        'trailingPE': sigmaProfile['pe'],
        'eps': sigmaProfile['eps'],
        'beta': sigmaProfile['beta'],
        'dividendYield': sigmaProfile['dividendYield'],
        'marketCap': sigmaProfile['marketCap'],
        'fiftyTwoWeekHigh': sigmaProfile['fiftyTwoWeekHigh'],
        'fiftyTwoWeekLow': sigmaProfile['fiftyTwoWeekLow'],
        'volume': sigmaProfile['volume'],
      },
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
      dev.log('âš ï¸ Primary AI Stock Analysis failed, trying fallback: $e');
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
          dev.log('âŒ Fallback failed: $e2');
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

    // ── Intelligence data from /equities/{symbol}/intelligence ─────────────
    final sigmaProfileRaw = sigmaProfile;
    // analystPriceTargets → replaces yTargets
    final yTargets = (intelligenceData['analystPriceTargets'] as Map?)
            ?.cast<String, dynamic>() ??
        <String, dynamic>{};
    // upgradesDowngrades → replaces yUpgrades / yahooUpgradesEnriched
    final yUpgrades =
        (intelligenceData['upgradesDowngrades'] as List?) ?? <dynamic>[];
    final yahooUpgradesEnriched = {'upgradesDowngrades': yUpgrades};
    // recommendations → replaces yRecs / finnhubRecommendations fallback
    final yRecs = (intelligenceData['recommendations'] as List?) ?? <dynamic>[];
    // earningsHistory → replaces yahooEarningsHistory
    final yahooEarningsHistory =
        (intelligenceData['earningsHistory'] as List?) ?? <dynamic>[];
    // earningsEstimate / revenueEstimate
    final yahooEarningsEnriched = {
      'earningsEstimate': intelligenceData['earningsEstimate'] ?? [],
      'revenueEstimate': intelligenceData['revenueEstimate'] ?? [],
    };
    // Remaining legacy stubs (no source available)
    const Map<String, dynamic> ySummary = {};
    const List<dynamic> finnhubEarningsCalendar = [];
    // yInsiders: insider transactions from /ownership (fallback to sigmaInsiderTrading)
    final yInsiders =
        (_holdersBundle['insiderTransactions'] as List?)?.isNotEmpty == true
            ? _holdersBundle['insiderTransactions'] as List<dynamic>
            : sigmaInsiderTrading;
    // SEC annual revenue/net_income series → historicalEarnings
    final _secRevAnnual = (secFacts['revenue']?['annual'] as List?) ?? [];
    final _secNiAnnual = (secFacts['net_income']?['annual'] as List?) ?? [];
    // sigmaApiHistoricalFinancials: prefer /financials annual data (richer), fallback to /sec
    final sigmaApiHistoricalFinancials = sigmaAnnualIncome.isNotEmpty
        ? sigmaAnnualIncome
            .whereType<Map>()
            .map((e) => {
                  'date': (e['index'] as String?)?.substring(0, 10) ?? '',
                  'revenue': e['Total Revenue'],
                  'netIncome': e['Net Income'],
                  'ebitda': e['EBITDA'],
                  'operatingIncome': e['Operating Income'],
                  'grossProfit': e['Gross Profit'],
                  'eps': e['Diluted EPS'],
                  'rd': e['Research And Development'],
                  'sga': e['Selling General And Administration'],
                })
            .toList()
        : _secRevAnnual.isNotEmpty
            ? List<dynamic>.generate(_secRevAnnual.length, (i) {
                final r = _secRevAnnual[i] as Map;
                final ni = i < _secNiAnnual.length
                    ? (_secNiAnnual[i] as Map)['value']
                    : null;
                return {
                  'date': r['end'],
                  'revenue': r['value'],
                  'netIncome': ni,
                  'form': r['form']
                };
              })
            : <dynamic>[];
    const List<dynamic> yHistoricalFinancials = [];
    const Map<String, dynamic> yEsg = {};
    // yahooHolders: structured for HoldersData.fromJson (institutions + funds from /ownership)
    final yahooHolders =
        _holdersBundle.isNotEmpty ? _holdersBundle : <String, dynamic>{};
    const Map<String, dynamic> yahooStatsEnriched = {};
    const Map<String, dynamic> saRatings = {};
    const Map<String, dynamic> saMetrics = {};
    const Map<String, dynamic> alphaOverview = {};
    const List<dynamic> yahooConversations = [];
    const Map<String, dynamic> yahooProfile = {};
    const Map<String, dynamic> yahooTickerInfo = {};
    const Map<String, dynamic> yahooEsg = {};
    const Map<String, dynamic> yahooFinancialData = {};
    const Map<String, dynamic> yahooTechnical = {};
    const Map<String, dynamic> yahooYfinanceBundle = {};
    const Map<String, dynamic> yahooActions = {};

    // --- MERGE DES RÉSULTATS ---
    AnalysisData analysisData = data1.copyWith(
      historicalEarnings: sigmaIncome.cast<Map<String, dynamic>>(),
      price: _formatPrice(realTimePrice['price']),
      isWebEnhanced: webContext.length > 20,
      webIntelligence: data1.webIntelligence,
      // Inject Corporate Identity (SIGMA primary, AI final fallback)
      companyName: _getValidString(
          [data1.companyName, sigmaProfile['companyName'], symbol]),
      image: _getValidString([sigmaProfileRaw['image'], data1.image]),
      sector: _getValidString([sigmaProfile['sector'], data1.sector]),
      industry: _getValidString([sigmaProfile['industry'], data1.industry]),
      ceo: _getValidString([sigmaProfile['ceo'], data1.ceo]),
      website: _getValidString([sigmaProfile['website'], data1.website]),
      employees: AnalysisData.parseInt(sigmaProfile['fullTimeEmployees'] ??
          finnhubBasic['fullTimeEmployees'] ??
          0),
    );

    // LOGO RECOVERY
    if (analysisData.image == null ||
        analysisData.image!.isEmpty ||
        analysisData.image!.contains('eodhd.com') ||
        analysisData.image!.contains('financialmodelingprep.com')) {
      analysisData = analysisData.copyWith(
        image: LogoResolver.resolve(symbol, providedUrl: analysisData.image),
      );
    }

    // --- ENRICH DES DONNÃ‰ES BRUTES (YAHOO DIRECT - BATCH MODE) ---
    // yCalendar: from /events calendar (replaces empty ySummary stub)
    final yCalendar =
        (eventsData['calendar'] as Map?)?.cast<String, dynamic>() ?? {};
    final yEarningsTrend =
        (ySummary['earningsTrend'] as Map?)?.cast<String, dynamic>() ?? {};
    // yActions: dividends + splits from /events (replaces empty stubs)
    final _eventsDiv = (eventsData['dividends'] as List?) ?? [];
    final _eventsSplits = (eventsData['splits'] as List?) ?? [];
    final yActions = <String, dynamic>{
      if (_eventsDiv.isNotEmpty)
        'dividends': {
          for (final d in _eventsDiv.whereType<Map>())
            (d['date'] ?? d['exDate'] ?? '').toString(): d,
        },
      if (_eventsSplits.isNotEmpty) 'splits': _eventsSplits,
    };
    final yInstitutionalHolders =
        (ySummary['institutionHolders']?['holders'] as List?) ?? [];
    final yFullOwnership =
        (ySummary['insiderHolders'] as Map?)?.cast<String, dynamic>() ?? {};
    final finnhubRecLatest =
        finnhubRecommendations.isNotEmpty && finnhubRecommendations.first is Map
            ? Map<String, dynamic>.from(finnhubRecommendations.first as Map)
            : <String, dynamic>{};
    final finnhubEarningsCalendarMap = finnhubEarningsCalendar.isNotEmpty &&
            finnhubEarningsCalendar.first is Map
        ? <String, dynamic>{
            'Earnings Date':
                (finnhubEarningsCalendar.first as Map)['date']?.toString() ??
                    '',
            'Earnings Average':
                (finnhubEarningsCalendar.first as Map)['epsEstimate']
                        ?.toString() ??
                    '',
            'Revenue Estimate':
                (finnhubEarningsCalendar.first as Map)['revenueEstimate']
                        ?.toString() ??
                    '',
          }
        : <String, dynamic>{};

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
          : (finnhubRecLatest.isNotEmpty
              ? AnalystRecommendation.fromJson(finnhubRecLatest)
              : analysisData.analystRecommendations),
      historicalEarnings: sigmaApiHistoricalFinancials.isNotEmpty
          ? sigmaApiHistoricalFinancials
          : yHistoricalFinancials.isNotEmpty
              ? yHistoricalFinancials
              : (finnhubEarningsSurprises.isNotEmpty
                  ? finnhubEarningsSurprises
                  : sigmaIncome),
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
      // NEW â€” yfinance Intelligence Pipeline
      earningsCalendar: yCalendar.isNotEmpty
          ? yCalendar
          : (finnhubEarningsCalendarMap.isNotEmpty
              ? finnhubEarningsCalendarMap
              : null),
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
        "finnhubBasic": finnhubBasic,
        "finnhubRecommendations": finnhubRecommendations,
        "finnhubEarningsSurprises": finnhubEarningsSurprises,
        "optionsChain": {
          "expiration": optionsData['selectedExpiration'],
          "expirations": optionsData['expirations'],
          "calls": (optionsData['calls'] as List?)?.take(10).toList(),
          "puts": (optionsData['puts'] as List?)?.take(10).toList(),
        },
        "financials": {
          "latestQuarterIncome":
              sigmaIncome.isNotEmpty && sigmaIncome.first is Map
                  ? _pickFinancialFields(sigmaIncome.first as Map)
                  : null,
          "latestQuarterBalance":
              sigmaBalance.isNotEmpty && sigmaBalance.first is Map
                  ? _pickBalanceFields(sigmaBalance.first as Map)
                  : null,
          "latestQuarterCashFlow":
              sigmaCashFlow.isNotEmpty && sigmaCashFlow.first is Map
                  ? _pickCashFlowFields(sigmaCashFlow.first as Map)
                  : null,
          "annualIncomeLast3": sigmaAnnualIncome
              .take(3)
              .where((e) => e is Map)
              .map((e) => _pickFinancialFields(e as Map))
              .toList(),
          "annualCashFlowLast3": sigmaAnnualCashFlow
              .take(3)
              .where((e) => e is Map)
              .map((e) => _pickCashFlowFields(e as Map))
              .toList(),
        },
        "secEdgar": {
          "cik": secData['cik'],
          "entityName": secData['entityName'],
          "derived": secDerived,
          "revenueAnnual":
              (secFacts['revenue']?['annual'] as List?)?.take(5).toList(),
          "netIncomeAnnual":
              (secFacts['net_income']?['annual'] as List?)?.take(5).toList(),
          "assetsAnnual":
              (secFacts['total_assets']?['annual'] as List?)?.take(3).toList(),
          "equityAnnual": (secFacts['stockholders_equity']?['annual'] as List?)
              ?.take(3)
              .toList(),
        },
      }),
    );

    // Sequential Agentic Enrichment removed to improve performance.
    // Key insights now handled by primary model.

    // --- ENRICH DES DONNÃ‰ES BRUTES (YAHOO DIRECT) ---
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
    // On s'assure que les donnÃ©es rÃ©cupÃ©rÃ©es directement via Yahoo sont prioritaires
    // ou complÃ¨tent ce que l'IA a pu oublier ou mal formater.

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

    // Use real sigmaMetrics (FMP/yfinance) for financial matrix enrichment
    if (sigmaMetrics.isNotEmpty || sigmaProfile.isNotEmpty) {
      final pe = sigmaMetrics['trailingPE'] ?? sigmaProfile['pe'];
      if (pe != null) updateMetric('P/E Ratio', (pe as num).toStringAsFixed(2));
      final fwdPE = sigmaMetrics['forwardPE'];
      if (fwdPE != null)
        updateMetric('Forward P/E', (fwdPE as num).toStringAsFixed(2));
      final roe = sigmaMetrics['returnOnEquity'] ?? sigmaMetrics['roeTTM'];
      if (roe != null && (roe as num) != 0)
        updateMetric('ROE', '${((roe as num) * 100).toStringAsFixed(2)}%');
      final de =
          sigmaMetrics['debtToEquity'] ?? sigmaMetrics['debtToEquityTTM'];
      if (de != null) updateMetric('D/E Ratio', (de as num).toStringAsFixed(2));
      final rev = sigmaMetrics['revenue'];
      if (rev != null && (rev as num) != 0)
        updateMetric('Total Revenue', _formatLargeNumber(rev));
      final fcf = sigmaMetrics['freeCashflow'];
      if (fcf != null && (fcf as num) != 0)
        updateMetric('Free Cashflow', _formatLargeNumber(fcf));
      final pm = sigmaMetrics['profitMargins'];
      if (pm != null && (pm as num) != 0)
        updateMetric(
            'Profit Margins', '${((pm as num) * 100).toStringAsFixed(2)}%');
    }

    // 2.2 Key Stats Enforcement (Beta from sigmaProfile/sigmaMetrics)
    final betaVal = sigmaProfile['beta'] ?? sigmaMetrics['beta'];
    if (betaVal != null) {
      updateMetric('Beta (5Y)', (betaVal as num).toStringAsFixed(2));
    }

    analysisData = analysisData.copyWith(financialMatrix: updatedMatrix);

    // 3. Technical Enrichment from real OHLCV data (ChartOverlayEngine)
    if (priceHistory.length >= 5) {
      try {
        final overlays = ChartOverlayEngine.compute(priceHistory);
        final List<TechnicalIndicator> techIndicators = List.from(
          analysisData.technicalAnalysis,
        );

        void addTech(String label, String? val, String interp) {
          if (val != null &&
              val.isNotEmpty &&
              !techIndicators.any((ti) => ti.indicator == label)) {
            techIndicators.add(TechnicalIndicator(
              indicator: label,
              value: val,
              interpretation: interp,
            ));
          }
        }

        final rsiLast =
            overlays.rsi.lastWhere((v) => v != null, orElse: () => null);
        if (rsiLast != null) {
          final rsiInterp = rsiLast >= 70
              ? 'OVERBOUGHT'
              : rsiLast <= 30
                  ? 'OVERSOLD'
                  : 'NEUTRAL';
          addTech('RSI (14)', rsiLast.toStringAsFixed(1), rsiInterp);
        }

        final macdHist = overlays.latestMacdHist;
        if (macdHist != null) {
          addTech('MACD Histogram', macdHist.toStringAsFixed(4),
              macdHist > 0 ? 'BULLISH' : 'BEARISH');
        }

        final sma50 =
            overlays.sma50.lastWhere((v) => v != null, orElse: () => null);
        final sma200 =
            overlays.sma200.lastWhere((v) => v != null, orElse: () => null);
        final lastClose = (priceHistory.last['close'] as num?)?.toDouble();
        if (sma50 != null && lastClose != null) {
          addTech(
              'SMA 50',
              '\$${sma50.toStringAsFixed(2)}',
              lastClose > sma50
                  ? 'ABOVE SMA50 (BULLISH)'
                  : 'BELOW SMA50 (BEARISH)');
        }
        if (sma200 != null && lastClose != null) {
          addTech(
              'SMA 200',
              '\$${sma200.toStringAsFixed(2)}',
              lastClose > sma200
                  ? 'ABOVE SMA200 (BULLISH)'
                  : 'BELOW SMA200 (BEARISH)');
        }

        addTech('Market Regime', overlays.regime, overlays.regime);

        if (techIndicators.length > analysisData.technicalAnalysis.length) {
          analysisData =
              analysisData.copyWith(technicalAnalysis: techIndicators);
        }
      } catch (e) {
        dev.log('Warning: ChartOverlayEngine enrichment failed: $e');
      }
    }

    // ── VOLATILITY ENRICHMENT from /options ──────────────────────────────────
    if (optionsData.isNotEmpty) {
      final optCalls = (optionsData['calls'] as List?) ?? [];
      double ivSum = 0;
      int ivCount = 0;
      for (final c in optCalls) {
        final iv = (c as Map?)?.cast<String, dynamic>()['impliedVolatility'];
        final ivVal = (iv as num?)?.toDouble() ?? 0;
        if (ivVal > 0 && ivVal < 50) {
          ivSum += ivVal;
          ivCount++;
        }
      }
      if (ivCount > 0) {
        final avgIV = ivSum / ivCount * 100;
        final interp = avgIV > 60
            ? 'ELEVATED'
            : avgIV > 30
                ? 'NORMAL'
                : 'LOW';
        final beta = analysisData.volatility.beta;
        analysisData = analysisData.copyWith(
          volatility: VolatilityData(
            ivRank: '${avgIV.toStringAsFixed(0)}%',
            beta: beta,
            interpretation: interp,
          ),
        );
      }
    }

    try {
      // 1. ACTUALITÃ‰S MULTI-SOURCES â€" reuse already-fetched sigmaNews (no extra API call)
      try {
        List<Map<String, dynamic>> rawNews = sigmaNews
            .map((n) => <String, dynamic>{
                  'title': n['title'],
                  'source': n['site'] ?? n['publisher'] ?? 'SIGMA',
                  'url': n['url'] ?? n['link'] ?? '',
                  'publishedAt': n['publishedDate'] ?? n['publishedAt'] ?? '',
                  'summary': n['text'] ?? n['summary'] ?? n['title'],
                  'imageUrl': n['image'] ?? n['thumbnail'],
                })
            .toList();

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
                dev.log('ðŸ§  Enriching Individual News with AI ($symbol)...');
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

      // 2. KEY STATISTICS ENRICHMENT (SIGMA only)
      try {
        // Start with ALL real API data from sigmaMetrics (already has right field names)
        var keyStats = KeyStatistics.fromJson(sigmaMetrics);

        // Enrich with SIGMA for better data coverage
        dev.log('Information: Enriching Key Stats and Profile for $symbol...');
        try {
          // Priority 1: SIGMA profile (primary source)
          if (sigmaProfile.isNotEmpty) {
            final sigmaMktCap = AnalysisData.parseNum(
              sigmaProfile['marketCap'] ?? sigmaProfile['mktCap'],
            );
            final sigmaPe = AnalysisData.parseNum(
              sigmaProfile['pe'] ?? sigmaProfile['peRatio'],
            );
            final sigmaBeta = AnalysisData.parseNum(sigmaProfile['beta']);

            keyStats = keyStats.copyWith(
              marketCap:
                  keyStats.marketCap == 0 ? sigmaMktCap : keyStats.marketCap,
              trailingPE:
                  keyStats.trailingPE == 0 ? sigmaPe : keyStats.trailingPE,
              beta: keyStats.beta == 0 ? sigmaBeta : keyStats.beta,
            );

            // Enrich structured profile with SIGMA data
            analysisData = analysisData.copyWith(
              employees: analysisData.employees ??
                  AnalysisData.parseNum(
                    sigmaProfile['fullTimeEmployees'] ??
                        sigmaProfile['employees'],
                  ).toInt(),
              website:
                  analysisData.website ?? sigmaProfile['website'] as String?,
              sector: analysisData.sector ?? sigmaProfile['sector'] as String?,
              industry:
                  analysisData.industry ?? sigmaProfile['industry'] as String?,
              address:
                  analysisData.address ?? sigmaProfile['address'] as String?,
              city: analysisData.city ?? sigmaProfile['city'] as String?,
              state: analysisData.state ?? sigmaProfile['state'] as String?,
              country:
                  analysisData.country ?? sigmaProfile['country'] as String?,
              ipoDate: sigmaProfile['ipoDate'] as String?,
              phone: analysisData.phone ?? sigmaProfile['phone'] as String?,
              exchange: sigmaProfile['exchange'] as String?,
              exchangeFullName: sigmaProfile['exchangeFullName'] as String?,
              ceo: sigmaProfile['ceo'] as String?,
              image: sigmaProfile['image'] as String?,
              companyName: analysisData.companyName ??
                  sigmaProfile['companyName'] as String?,
            );
            // Update description if missing or short
            if (analysisData.companyProfile.length < 50) {
              if (sigmaProfile['description'] != null) {
                analysisData = analysisData.copyWith(
                  companyProfile: sigmaProfile['description'] as String,
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

          if (sigmaMetrics.isNotEmpty) {
            keyStats = keyStats.copyWith(
              returnOnEquity: keyStats.returnOnEquity == 0
                  ? AnalysisData.parseNum(sigmaMetrics['roeTTM'])
                  : keyStats.returnOnEquity,
              returnOnAssets: keyStats.returnOnAssets == 0
                  ? AnalysisData.parseNum(sigmaMetrics['roaTTM'])
                  : keyStats.returnOnAssets,
              debtToEquity: keyStats.debtToEquity == 0
                  ? AnalysisData.parseNum(sigmaMetrics['debtToEquityTTM'])
                  : keyStats.debtToEquity,
              currentRatio: keyStats.currentRatio == 0
                  ? AnalysisData.parseNum(sigmaMetrics['currentRatioTTM'])
                  : keyStats.currentRatio,
              profitMargins: keyStats.profitMargins == 0
                  ? AnalysisData.parseNum(sigmaMetrics['netProfitMarginTTM'])
                  : keyStats.profitMargins,
              pegRatio: keyStats.pegRatio == 0
                  ? AnalysisData.parseNum(sigmaMetrics['pegRatioTTM'])
                  : keyStats.pegRatio,
            );
          }
        } catch (e) {
          dev.log('Warning: SIGMA enrichment failed: $e');
        }

        dev.log('ðŸ“Š FINAL ENRICHMENT RESULTS for $symbol:');
        dev.log('   Market Cap: ${keyStats.marketCap}');
        dev.log('   PE: ${keyStats.trailingPE}');
        dev.log('   Beta: ${keyStats.beta}');
        dev.log('   ROE: ${keyStats.returnOnEquity}');

        analysisData = analysisData.copyWith(keyStatistics: keyStats);
      } catch (e) {
        dev.log('Warning: Failed to enrich KeyStatistics: $e');
      }

      // 2.5 HOLDERS & INSIDERS ENRICHMENT (SIGMA FALLBACK)
      try {
        if (analysisData.holders == null ||
            analysisData.holders!.topInstitutions.isEmpty) {
          if (sigmaHolders.isNotEmpty) {
            dev.log('Enriching holders with SIGMA data...');
            final institutions = sigmaHolders.map((h) {
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
                institutionsCount: sigmaHolders.length,
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
                  'âœ… Enriching insider transactions with OpenInsider data (${oiTransactions.length} txns)');
              analysisData = analysisData.copyWith(
                insiderTransactions: oiTransactions,
                insiderBuyRatio: oiData['insiderBuyRatio'] as double?,
              );
            }
          } catch (e) {
            dev.log('âš ï¸ OpenInsider ticker enrichment failed: $e');
          }

          // SECONDARY FALLBACK: SIGMA (limited free tier)
          if (analysisData.insiderTransactions.isEmpty &&
              sigmaInsiderTrading.isNotEmpty) {
            dev.log('Enriching insider transactions with SIGMA data...');
            final transactions = sigmaInsiderTrading.map((t) {
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
        dev.log('Warning: SIGMA Holders/Insiders enrichment failed: $e');
      }

      // 2.7 FINANCIAL MATRIX ENRICHMENT (SIGMA FALLBACK)
      try {
        if (sigmaMetrics.isNotEmpty || sigmaProfile.isNotEmpty) {
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
              if (label.contains('P/E') && sigmaProfile['pe'] != null) {
                updatedMatrix[i] = item.copyWith(
                  value: (sigmaProfile['pe'] as num).toStringAsFixed(2),
                );
                changed = true;
              } else if (label.contains('CAPITALISATION') &&
                  (sigmaProfile['mktCap'] != null ||
                      sigmaProfile['marketCap'] != null)) {
                updatedMatrix[i] = item.copyWith(
                  value: _formatLargeNumber(
                      sigmaProfile['mktCap'] ?? sigmaProfile['marketCap']),
                );
                changed = true;
              } else if (label.contains('BETA') &&
                  sigmaProfile['beta'] != null) {
                updatedMatrix[i] = item.copyWith(
                  value: (sigmaProfile['beta'] as num).toStringAsFixed(2),
                );
                changed = true;
              } else if (label.contains('DIVIDENDE') &&
                  sigmaProfile['lastDividend'] != null) {
                updatedMatrix[i] = item.copyWith(
                  value:
                      (sigmaProfile['lastDividend'] as num).toStringAsFixed(2),
                );
                changed = true;
              } else if (label.contains('ROE') &&
                  sigmaMetrics['roeTTM'] != null) {
                final roe = (sigmaMetrics['roeTTM'] as num).toDouble();
                updatedMatrix[i] = item.copyWith(
                  value: '${(roe * 100).toStringAsFixed(2)}%',
                );
                changed = true;
              } else if (label.contains('D/E') &&
                  sigmaMetrics['debtToEquityTTM'] != null) {
                final de = (sigmaMetrics['debtToEquityTTM'] as num).toDouble();
                updatedMatrix[i] = item.copyWith(value: de.toStringAsFixed(2));
                changed = true;
              } else if (label.contains('ROIC')) {
                final roic = sigmaMetrics['roicTTM'] ??
                    sigmaRatios['returnOnInvestedCapitalTTM'];
                if (roic != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((roic as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              } else if (label.contains('EPS')) {
                final eps = sigmaMetrics['netIncomePerShareTTM'] ??
                    (sigmaIncome.isNotEmpty
                        ? sigmaIncome[0]['Diluted EPS']
                        : null);
                if (eps != null) {
                  updatedMatrix[i] = item.copyWith(
                    value: (eps as num).toStringAsFixed(2),
                  );
                  changed = true;
                }
              } else if (label.contains('EBIT')) {
                final ebit = (sigmaIncome.isNotEmpty
                    ? (sigmaIncome[0]['Operating Income'] ??
                        sigmaIncome[0]['EBIT'])
                    : null);
                if (ebit != null) {
                  updatedMatrix[i] = item.copyWith(
                    value: _formatLargeNumber(ebit),
                  );
                  changed = true;
                }
              } else if (label.contains('MARGE BRUTE')) {
                final gm = sigmaMetrics['grossProfitMarginTTM'] ??
                    sigmaRatios['grossProfitMarginTTM'];
                if (gm != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((gm as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              } else if (label.contains('MARGE NETTE')) {
                final nm = sigmaMetrics['netProfitMarginTTM'] ??
                    sigmaRatios['netProfitMarginTTM'];
                if (nm != null) {
                  updatedMatrix[i] = item.copyWith(
                    value:
                        '${((nm as num).toDouble() * 100).toStringAsFixed(2)}%',
                  );
                  changed = true;
                }
              } else if (label.contains('RENDEMENT FCF') ||
                  label.contains('FCF YIELD')) {
                final fcfy = sigmaMetrics['freeCashFlowYieldTTM'];
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

      // ENRICHISSEMENT: ANALYSE TECHNIQUE (Sigma-only â€” AI-generated from analyzeStock)
      // TwelveData technical indicators (RSI, MACD, OBV) removed â€” SIGMA doesn't provide these directly.
      // Technical analysis is AI-generated from price context.

      // ENRICHISSEMENT: DONNÃ‰ES D'ACTIONNARIAT (SIGMA PRIMARY)
      try {
        List<MajorHolder> topInstitutions = [];
        List<MajorHolder> topFunds = [];
        double insidersPercent = 0.0;
        double institutionsPercent = 0.0;
        int institutionsCount = 0;

        // SIGMA Institutional Holders
        try {
          final sigmaHoldersData =
              await _marketData.getInstitutionalHolders(symbol);
          if (sigmaHoldersData.isNotEmpty) {
            topInstitutions = sigmaHoldersData.take(10).map((h) {
              return MajorHolder(
                organization: h['holder'] ?? 'Unknown',
                position: (h['shares'] as num?)?.toDouble() ?? 0,
                value: (h['totalValue'] as num?)?.toDouble() ?? 0,
                pctHeld: 0,
                reportDate: h['dateReported'] ?? '',
              );
            }).toList();
            institutionsCount = sigmaHoldersData.length;
          }
        } catch (e) {
          dev.log('Warning: SIGMA holders enrichment failed: $e');
        }

        final holdersData = HoldersData(
          insidersPercent: insidersPercent,
          institutionsPercent: institutionsPercent,
          institutionsCount: institutionsCount,
          topInstitutions: topInstitutions,
          topFunds: topFunds,
        );

        dev.log('ðŸ‘¥ HOLDERS ENRICHMENT for $symbol:');
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

      // ENRICHISSEMENT: Ã‰VÃ‰NEMENTS CORPORATIFS (YAHOO)
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
                event: 'RÃ‰SULTATS',
                description:
                    'EPS RÃ©el: ${earn['epsActual']} (Est: ${earn['epsEstimate']})',
              ),
            );
          }
        }

        // 3. Fallback Sigma API: Dividendes
        if (events.every((e) => e.event != 'DIVIDENDE')) {
          try {
            final sigmaDivs = await _marketData.getDividends(symbol);
            for (var div in sigmaDivs.take(3)) {
              events.add(
                CorporateEvent(
                  date: div['date']?.toString() ?? '',
                  event: 'DIVIDENDE',
                  description: 'Montant: \$${div['dividend'] ?? div['amount']}',
                ),
              );
            }
          } catch (e) {
            dev.log('Warning: SIGMA dividends enrichment failed: $e');
          }
        }

        // 4. Fallback Sigma API: Earnings
        if (events.every((e) => e.event != 'RÃ‰SULTATS')) {
          try {
            final sigmaEarn = await _marketData.getEarningsHistorical(symbol);
            for (var earn in sigmaEarn.take(2)) {
              events.add(
                CorporateEvent(
                  date: earn['date']?.toString() ?? '',
                  event: 'RÃ‰SULTATS',
                  description:
                      'EPS RÃ©el: ${earn['actualEps']} (Est: ${earn['epsEstimated']})',
                ),
              );
            }
          } catch (e) {
            dev.log('Warning: SIGMA earnings enrichment failed: $e');
          }
        }

        if (events.isNotEmpty) {
          analysisData = analysisData.copyWith(corporateEvents: events);
        }
      } catch (e) {
        dev.log('Warning: Failed to enrich Corporate Events: $e');
      }

      // â”€â”€ PHASE 3: REMOVED (Redundant after Agentic Web integration) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      // Previous Ollama phase removed to prioritize unified Intelligence Core.

      analysisData = _ensureEssentialSectionsData(analysisData, targetLanguage);
      final withPeers = await _enrichPeerData(analysisData);
      final calibrated = _applyDataDrivenCalibration(withPeers, targetLanguage);
      return calibrated.copyWith(
        rawInstitutionalData: jsonEncode(
            _buildPremiumInstitutionalReport(calibrated, targetLanguage)),
      );
    } catch (e) {
      dev.log('âŒ Enrichment Error: $e');
      final essential =
          _ensureEssentialSectionsData(analysisData, targetLanguage);
      final calibratedFallback =
          _applyDataDrivenCalibration(essential, targetLanguage);
      return calibratedFallback.copyWith(
        rawInstitutionalData: jsonEncode(_buildPremiumInstitutionalReport(
            calibratedFallback, targetLanguage)),
      );
    }
  }

  /// Enrichit les donnÃ©es des pairs avec des prix temps rÃ©el et valide les tickers
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

  AnalysisData _ensureEssentialSectionsData(
      AnalysisData data, String language) {
    final isFr = language.toUpperCase().startsWith('FR');

    bool hasMeaningful(String? value) {
      if (value == null) return false;
      final v = value.trim().toUpperCase();
      return v.isNotEmpty && v != 'N/A' && v != 'NA' && v != 'EN ATTENTE...';
    }

    final filteredFinancial = data.financialMatrix
        .where((m) => hasMeaningful(m.value) || hasMeaningful(m.assessment))
        .toList();

    final keyStats = data.keyStatistics;
    var matrix = filteredFinancial;
    if (matrix.isEmpty) {
      matrix = [
        FinancialMatrixItem(
          label: isFr ? 'CAPITALISATION BOURS.' : 'MARKET CAP',
          value: keyStats?.marketCap != null && keyStats!.marketCap > 0
              ? _formatLargeNumber(keyStats.marketCap)
              : 'N/A',
          assessment: 'API',
        ),
        FinancialMatrixItem(
          label: 'P/E RATIO',
          value: (keyStats?.trailingPE ?? 0) > 0
              ? keyStats!.trailingPE.toStringAsFixed(2)
              : 'N/A',
          assessment: 'API',
        ),
        FinancialMatrixItem(
          label: 'ROE',
          value: (keyStats?.returnOnEquity ?? 0) > 0
              ? '${((keyStats!.returnOnEquity) * 100).toStringAsFixed(2)}%'
              : 'N/A',
          assessment: 'API',
        ),
        FinancialMatrixItem(
          label: isFr ? 'MARGE NETTE' : 'NET MARGIN',
          value: (keyStats?.profitMargins ?? 0) > 0
              ? '${((keyStats!.profitMargins) * 100).toStringAsFixed(2)}%'
              : 'N/A',
          assessment: 'API',
        ),
      ].where((m) => hasMeaningful(m.value)).toList();
    }

    final filteredTechnical = data.technicalAnalysis
        .where((t) => hasMeaningful(t.value) || hasMeaningful(t.interpretation))
        .toList();

    var technical = filteredTechnical;
    if (technical.isEmpty) {
      final target = data.targetPriceValue;
      final current =
          double.tryParse(data.price.replaceAll(RegExp(r'[^\d\.]'), ''));
      if (current != null && current > 0 && target != null && target > 0) {
        final upside = ((target - current) / current) * 100;
        technical.add(
          TechnicalIndicator(
            indicator: isFr ? 'UPSIDE CIBLE' : 'TARGET UPSIDE',
            value: '${upside.toStringAsFixed(1)}%',
            interpretation: upside >= 0
                ? (isFr
                    ? 'Potentiel haussier implicite basÃ© sur le prix cible analyste.'
                    : 'Implied upside based on analyst target price.')
                : (isFr
                    ? 'DÃ©cote implicite par rapport Ã  la cible analyste.'
                    : 'Implied downside versus analyst target price.'),
          ),
        );
      }

      final beta = keyStats?.beta ?? 0;
      if (beta > 0) {
        technical.add(
          TechnicalIndicator(
            indicator: 'BETA',
            value: beta.toStringAsFixed(2),
            interpretation: beta >= 1.2
                ? (isFr
                    ? 'VolatilitÃ© supÃ©rieure au marchÃ©.'
                    : 'Above-market volatility profile.')
                : (isFr
                    ? 'VolatilitÃ© contenue vs marchÃ©.'
                    : 'Contained volatility versus market.'),
          ),
        );
      }

      final ivRangeParts =
          data.volatility.ivRank.split('-').map((s) => s.trim()).toList();
      if (ivRangeParts.length == 2 &&
          hasMeaningful(ivRangeParts[0]) &&
          hasMeaningful(ivRangeParts[1])) {
        technical.add(
          TechnicalIndicator(
            indicator: isFr ? 'RANGE 52W' : '52W RANGE',
            value: '${ivRangeParts[0]} - ${ivRangeParts[1]}',
            interpretation: isFr
                ? 'Amplitude 52 semaines issue des donnÃ©es marchÃ©.'
                : '52-week range extracted from market data.',
          ),
        );
      }
    }

    return data.copyWith(
      financialMatrix: matrix,
      technicalAnalysis: technical,
    );
  }

  AnalysisData _applyDataDrivenCalibration(AnalysisData data, String language) {
    final decision = FinancialDecisionEngine.evaluate(data, language: language);
    final calibratedReasons = <String>[
      ...decision.positives.take(3),
      ...decision.negatives.take(3),
    ];
    final pros = data.pros.isNotEmpty
        ? data.pros
        : decision.positives
            .take(4)
            .map((text) => ProCon(text: text, period: 'PRESENT'))
            .toList(growable: false);
    final cons = data.cons.isNotEmpty
        ? data.cons
        : decision.negatives
            .take(4)
            .map((text) => ProCon(text: text, period: 'PRESENT'))
            .toList(growable: false);

    return data.copyWith(
      sigmaScore: decision.score,
      confidence: decision.confidence,
      verdict: decision.verdict,
      riskLevel: decision.riskLevel,
      verdictReasons: calibratedReasons,
      pros: pros,
      cons: cons,
      summary: decision.summary,
      targetPriceValue: data.targetPriceValue ?? decision.targetPrice,
      recommendationSteps: decision.recommendationSteps,
      alphaRecommendation: decision.alphaRecommendation,
      scoreMethodology: decision.methodology,
    );
  }

  /// Formate un prix pour l'affichage
  String _formatPrice(dynamic price) {
    if (price == null || price == 0) return 'N/A';
    final numPrice = price is num
        ? price.toDouble()
        : double.tryParse(price.toString()) ?? 0;
    if (numPrice <= 0) return 'N/A';
    if (numPrice >= 1000) {
      return numPrice.toStringAsFixed(2);
    } else if (numPrice >= 1) {
      return numPrice.toStringAsFixed(2);
    } else {
      return numPrice.toStringAsFixed(4);
    }
  }

  /// RÃ©cupÃ¨re le prix temps rÃ©el avec fallback multi-source
  /// PrioritÃ©: YAHOO -> SIGMA -> Finnhub -> TwelveData
  /// GÃ¨re automatiquement les diffÃ©rents formats de symboles internationaux
  Future<Map<String, dynamic>> _getMultiSourcePrice(String symbol) async {
    // GÃ©nÃ©rer les variantes de symboles pour les marchÃ©s internationaux
    final symbolVariants = _getSymbolVariants(symbol);

    for (final variant in symbolVariants) {
      // 1. SIGMA (primary source)
      final sigmaPriceVal = await _safeCall<double>(
        () => _marketData.getRealTimePrice(variant),
        0.0,
      );
      if (sigmaPriceVal > 0) {
        dev.log('ðŸ’° Prix trouvÃ© via SIGMA ($variant): \$$sigmaPriceVal');
        // Try to get full quote data for richer response
        try {
          final quoteMap = await _marketData.getQuoteMap(variant);
          if (quoteMap.isNotEmpty) {
            return {
              'price': quoteMap['price'] ?? sigmaPriceVal,
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
              'source': 'SIGMA',
            };
          }
        } catch (_) {}
        return {
          'price': sigmaPriceVal,
          'change': 0,
          'changePercent': 0,
          'dayHigh': 0,
          'dayLow': 0,
          'previousClose': 0,
          'open': 0,
          'volume': 0,
          'source': 'SIGMA',
        };
      }
    }

    // 2. RÃ‰SOLUTION AVANCÃ‰E SIGMA (DERNIER RECOURS)
    dev.log(
      'âš ï¸ RÃ©solution standard Ã©chouÃ©e. Tentative de rÃ©solution SIGMA Exchange pour $symbol...',
    );
    try {
      final validVariants = await _marketData.searchExchangeVariants(symbol);
      for (final v in validVariants) {
        final String? newSymbol = v['symbol'];
        if (newSymbol == null || symbolVariants.contains(newSymbol)) continue;

        dev.log(
          'ðŸ” Test du symbole SIGMA dÃ©couvert: $newSymbol (${v['exchange']})',
        );

        final sigmaPriceVal = await _safeCall<double>(
          () => _marketData.getRealTimePrice(newSymbol),
          0.0,
        );
        if (sigmaPriceVal > 0) {
          dev.log(
            'ðŸ’° Prix trouvÃ© via SIGMA Resolution ($newSymbol): \$$sigmaPriceVal',
          );
          return {
            'price': sigmaPriceVal,
            'change': 0,
            'changePercent': 0,
            'source': 'SIGMA_RESOLVED',
          };
        }
      }
    } catch (e) {
      dev.log('Warning: SIGMA Advanced Resolution failed: $e');
    }

    dev.log('âŒ Aucune source n\'a pu fournir le prix pour $symbol');
    return {};
  }

  /// GÃ©nÃ¨re les variantes de symboles pour les diffÃ©rents formats d'Ã©change
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

  /// Limite la taille d'un texte pour Ã©viter de dÃ©passer les limites de contexte de l'IA
  String _limitTokens(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}... [DONNÃ‰ES TRONQUÃ‰ES POUR OPTIMISATION CONTEXTE]';
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
    // SIGMA : Indices majeurs (Yahoo removed)
    try {
      // ^GSPC=S&P500, ^DJI=Dow, ^IXIC=Nasdaq, ^RUT=Russell, EURUSD=X, BTC-USD
      final quotes = await _marketData.getQuotes([
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
      dev.log('âŒ SIGMA MarketSummary failed: $e');
    }
    return [];
  }

  Future<MarketOverview> getMarketOverview({
    String language = 'FRANÇAIS',
    List<String> favoriteTickers = const [],
  }) async {
    final bool isFr = language.toUpperCase().startsWith('FR');
    final String targetLanguage = isFr ? 'FRANÃ‡AIS' : 'ENGLISH';

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
      // â”€â”€ 0. AGENTIC SENTIMENT SEARCH (ALPHA) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      // On cherche les chiffres RÃ‰ELS du sentiment (Fear & Greed Index)
      final sentimentSearchTask = _webSearch.search(
          'current CNN Fear and Greed Index exact value, latest CBOE VIX price today, and current US stock market regime (Risk-On or Risk-Off) as of April 2026');

      // â”€â”€ 1. RÃ‰CUPÃ‰RATION DES DONNÃ‰ES EN PARALLÃˆLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final results = await Future.wait([
        _safeCall(
            () => _marketData.getGeneralNews(limit: 30), {'data': []}), // 0
        _safeCall(() => Future.value(null), null), // 1 (treasury â€” disabled)
        _safeCall(() => _marketData.getSectorPerformance(), []), // 2
        _safeCall(() => _marketData.getMergersAndAcquisitions(), []), // 3
        _safeCall(() => _marketData.getMarketArticles(''), []), // 4
        _safeCall(() => _marketData.getIndustryPerformance(), []), // 5
        _safeCall(() => Future.value({'data': []}),
            {'data': []}), // 6 (trending â€” disabled)
        _safeCall(() => _getMarketSummaryWithFallback(), []), // 7
        _safeCall(() => _marketData.getGainers(), []), // 8
        _safeCall(() => _marketData.getLosers(), []), // 9
        _safeCall(() => _finnhub.marketNews(category: 'general'), []), // 10
        _safeCall(
          () => _marketData.getQuotes(['^TNX', '^VIX', 'GLD', 'USO', 'UUP']),
          [],
        ), // 11
        _safeCall(() => _marketData.getGeneralNews(limit: 25), []), // 12
        _safeCall(() => _marketData.getGeneralNews(limit: 30), []), // 13
        _safeCall(() => _marketData.getGainers(), []), // 14
        _safeCall(() => _marketData.getLosers(), []), // 15
        _safeCall(
          () => _finnhub.earningsCalendar(
            from: DateTime.now()
                .subtract(const Duration(days: 30))
                .toIso8601String()
                .split('T')[0],
            to: DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String()
                .split('T')[0],
          ),
          [],
        ), // 16
        _safeCall(() => sentimentSearchTask, ""), // 17
        _safeCall(() => _sentiment.fetchFearGreed(), null), // 18
        _safeCall(() => _sentiment.fetchNews(), []), // 19
        _safeCall(() => _sentiment.fetchHistory(), []), // 20
        _safeCall(() => getGlobalInsiderTrades(), []), // 21
        _safeCall(() => _marketData.getEconomicCalendar(), []), // 22
      ]);

      // results[0] is List<dynamic> from getGeneralNews â€” treat as news list directly
      final List<dynamic> macroNewsList =
          (results[0] is List) ? results[0] as List<dynamic> : [];
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
            await _safeCall(() => _marketData.getQuotes(sectorTickers), []);
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
      final sigmaArticles = results[4] as List<dynamic>;
      final industryPerf = results[5] as List<dynamic>;
      final trending = results[6] as Map<String, dynamic>?;
      yahooMarketSummary = results[7] as List<Map<String, dynamic>>;
      final sigmaGainers = results[8] as List<dynamic>;
      final sigmaLosers = results[9] as List<dynamic>;

      final finnhubNews = results[10] as List<dynamic>;
      final macroQuotes = results[11] as List<dynamic>;
      final yahooNews = results[12] as List<dynamic>;
      final sigmaGeneralNews = results[13] as List<dynamic>;
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

          // Autoriser les indices (^), les commoditÃ©s (=), et les symboles US/Canada standard
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

      processMovers(sigmaGainers, uniqueGainers, true);
      processMovers(yahooGainersRaw, uniqueGainers, false);
      processMovers(sigmaLosers, uniqueLosers, true);
      processMovers(yahooLosersRaw, uniqueLosers, false);

      finalGainers = uniqueGainers.values.toList()
        ..sort((a, b) => (b['change'] as num).compareTo(a['change'] as num));
      finalLosers = uniqueLosers.values.toList()
        ..sort((a, b) => (a['change'] as num).compareTo(b['change'] as num));

      // Extraction des valeurs macro rÃ©elles (Sigma API)
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

      // Helper: extract a news item from any provider format (yfinance / Finnhub / Marketaux)
      Map<String, String> _mapNewsItem(dynamic n, String defaultSource) {
        if (n is! Map) return {};
        final m = Map<String, dynamic>.from(n);
        // Title: yfinance = 'title', Finnhub = 'headline', Marketaux = 'title'
        final title = (m['title'] ?? m['headline'] ?? '').toString();
        // Source: yfinance = 'publisher', Finnhub = 'source', SIGMA = 'site'
        final source =
            (m['publisher'] ?? m['source'] ?? m['site'] ?? defaultSource)
                .toString();
        // URL: yfinance = 'link', others = 'url'
        final url = (m['url'] ?? m['link'] ?? '').toString();
        // Ticker: yfinance may have 'symbols' list or 'relatedTickers'
        final relatedRaw =
            m['relatedTickers'] ?? m['symbols'] ?? m['related'] ?? '';
        String ticker = '';
        if (relatedRaw is List && relatedRaw.isNotEmpty) {
          ticker = relatedRaw[0]?.toString() ?? '';
        } else if (relatedRaw is String) {
          ticker = relatedRaw.split(',').first.trim();
        }
        ticker = m['symbol']?.toString() ?? ticker;
        // PublishedAt: yfinance = 'publishedAt', Finnhub = 'datetime', Marketaux = 'published_at'
        final publishedAt = (m['publishedAt'] ??
                m['publishedDate'] ??
                m['datetime']?.toString() ??
                m['published_at'] ??
                '')
            .toString();
        if (title.isEmpty) return {};
        return {
          'title': title,
          'source': source,
          'url': url,
          'ticker': ticker,
          'publishedAt': publishedAt,
        };
      }

      // results[0] â€” from getGeneralNews (yfinance /news/SPY)
      for (var n in macroNewsList.take(20)) {
        final item = _mapNewsItem(n, 'SIGMA');
        if (item.isNotEmpty) aggregatedNews.add(item);
      }

      // results[10] = finnhubNews (actually yfinance via SigmaMarketDataService)
      for (var n in finnhubNews.take(20)) {
        final item = _mapNewsItem(n, 'SIGMA');
        if (item.isNotEmpty) aggregatedNews.add(item);
      }

      // results[12] = yahooNews (actually yfinance)
      for (var n in yahooNews.take(15)) {
        final item = _mapNewsItem(n, 'YAHOO');
        if (item.isNotEmpty) aggregatedNews.add(item);
      }

      // Ajouter les articles SIGMA General
      if (sigmaGeneralNews.isNotEmpty) {
        for (var n in sigmaGeneralNews.take(15)) {
          aggregatedNews.add({
            'title': n['title']?.toString() ?? '',
            'source': n['site']?.toString() ?? 'SIGMA',
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

      // RÃ©cupÃ©rer les IPOs et le Calendrier Ã‰conomique pour le contexte
      final ipoResults = await Future.wait([
        _safeCall(() => _marketData.getIposCalendar(), []),
        _safeCall(() => _marketData.getEconomicCalendar(), []),
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
      final articleContext = sigmaArticles
          .take(3)
          .map((a) => "- ${a['title']} (${a['site']})")
          .join("\n");

      final yahooMarketContext = yahooMarketSummary
          .map(
            (i) =>
                "- ${i['shortName']} (${i['symbol']}): Price: ${i['price']}, Change: ${i['changePercent']}%",
          )
          .join("\n");

      final earningsContextYahoo = yahooEarningsCalendar.take(10).map((e) {
        if (e is! Map) return '- N/A';
        final symbol = e['symbol']?.toString() ?? '';
        final finnhubDate = e['date']?.toString();
        final yahooDate = e['earningsDate'] is List
            ? ((e['earningsDate'] as List).isNotEmpty
                ? (e['earningsDate'][0]?['fmt']?.toString())
                : null)
            : null;
        final date = finnhubDate ?? yahooDate ?? 'N/A';
        final hour = e['hour']?.toString();
        final hourSuffix = (hour != null && hour.isNotEmpty) ? ' ($hour)' : '';
        return '- $symbol: Date $date$hourSuffix';
      }).join("\n");

      final prompt = '''
ANALYSE MACRO SIGMA : $currentDate
LANGUE DE RÃ‰PONSE : $targetLanguage
10Y TREASURY YIELD (RÃ‰EL): ${t10yReal.toStringAsFixed(2)}%
DOLLAR INDEX DXY (RÃ‰EL): ${dxyReal.toStringAsFixed(2)}
GOLD (RÃ‰EL): \$${goldReal.toStringAsFixed(2)}
OIL WTI (RÃ‰EL): \$${oilReal.toStringAsFixed(2)}
VIX VOLATILITY index (RÃ‰EL): ${vixReal.toStringAsFixed(2)}

RÃ‰SUMÃ‰ MARCHÃ‰S YAHOO FINANCE :
$yahooMarketContext

TENDANCES (ENTITÃ‰S Ã€ FORT VOLUMENÃ‰TIQUE) :
$trendingContext

SÃ‰CTEURS PERFORMANCE :
$sectorContext

INDUSTRIES PERFORMANCE (TOP 8) :
$industryContext

FUSIONS & ACQUISITIONS RÃ‰CENTES :
$mergerContext

UPCOMING IPOs (INTRODUCTIONS EN BOURSE) :
$ipoContext

CALENDRIER Ã‰CONOMIQUE :
$ecoContext

CALENDRIER EARNINGS (YAHOO) :
$earningsContextYahoo

ARTICLES FINANCIERS CLÃ‰S (SIGMA API) :
$articleContext

### DERNIÃˆRES NEWS RÃ‰ELLES DU MARCHÃ‰ (CONTEXTE CRUCIAL) :
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
CONSIGNE NEWS : Extrais les 15 actualitÃ©s les plus pertinentes et variÃ©es du contexte ci-dessus. Inclue absolument les URLs rÃ©elles fournies.

STRUCTURE JSON (STRICTE, PAS DE TEXTE SUPERFLU) :
{
  "marketRegime": "RISK-ON ou RISK-OFF",
  "regimeDescription": "ANALYSE TECHNIQUE DÃ‰TAILLÃ‰E DE 3 LIGNES MINIMUM (STYLE BIM DANS UN RAPPORT INSTITUTIONNEL).",
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
        dev.log('âš ï¸ NVIDIA Market Overview failed, trying Ollama: $e');
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
            dev.log('âŒ Ollama Market Fallback failed: $e2');
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
        'âœ… Market Overview successfully parsed (length: ${cleanedJson.length})',
      );

      // Injecter les donnÃ©es rÃ©elles de Yahoo et Macro extraites
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

      // Injecter MacroIndicators RÃ©els
      decoded['macroIndicators'] = {
        "treasury10Y": t10yReal,
        "dollarIndex": dxyReal,
        "goldPrice": goldReal,
        "oilPrice": oilReal,
      };

      // Injecter Fear & Greed Data
      if (fgData != null) {
        print(
            'ðŸ” [SigmaService] fgData detected. Score: ${fgData.score}, Backtest: ${fgData.backtest.length} items, Sectors: ${fgData.sectors.length} items');
        if (fgData.backtest.isEmpty) {
          dev.log('âš ï¸ [SigmaService] Warning: fgData.backtest is EMPTY');
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
        dev.log('âš ï¸ FearGreedData is NULL in getMarketOverview');
      }

      // â”€â”€ SENTIMEMT HISTORY INJECTION
      if (fgHistory.isNotEmpty) {
        decoded['sentimentHistory'] = fgHistory;
      }

      // -- INSIDER TRADES INJECTION
      if (insiderTrades.isNotEmpty) {
        decoded['insiderTrades'] =
            insiderTrades.map((t) => t.toJson()).toList();
      }

      // Injecter le Calendrier Ã‰conomique RÃ©el (PrioritÃ© Ã  la donnÃ©e brute)
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

      // â”€â”€ FALLBACK NEWS : si l'IA ne retourne pas de news, on injecte les raw
      final aiNews = decoded['news'] as List?;
      if (aiNews == null || aiNews.isEmpty) {
        dev.log(
            'âš ï¸ AI returned no news â€” injecting raw aggregatedNews (${aggregatedNews.length} items)');
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

      // Enrichir les secteurs avec les donnÃ©es rÃ©elles de performance
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
      dev.log('âŒ Market Overview AI Error, using raw fallback: $e');
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
        dev.log(
            'âœ… OpenInsider: SUCCESS - Retrieved ${oiTrades.length} trades',
            name: 'SigmaService');
        return oiTrades;
      }

      // 2. FALLBACK: SIGMA Bulk Feed
      dev.log('âš ï¸ OpenInsider unavailable, falling back to Sigma API...',
          name: 'SigmaService');
      final List<dynamic> raw =
          await _marketData.getBulkInsiderTrading(limit: 100);

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

      // Map SIGMA to Model with labelling
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
      dev.log('âŒ Error fetching global insider trades: $e',
          name: 'SigmaService');
      return [];
    }
  }

  /// Helper pour exÃ©cuter une future de maniÃ¨re sÃ©curisÃ©e (fallback en cas d'erreur)
  /// Helper pour exÃ©cuter une future de maniÃ¨re sÃ©curisÃ©e avec retry automatique
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

        // Enregistrer le succÃ¨s
        if (sourceName != null) {
          dev.log('âœ… Source OK: $sourceName', name: 'SigmaService');
        }

        // Si c'est un retry rÃ©ussi, logger le succÃ¨s
        if (attempt > 0) {
          dev.log(
              'âœ… Service Call succeeded on retry $attempt${sourceName != null ? " ($sourceName)" : ""}',
              name: 'SigmaService');
        }

        return result;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;

        // Enregistrer l'Ã©chec
        if (sourceName != null && attempt > maxRetries) {
          dev.log('âŒ Source failed: $sourceName â€” $e',
              name: 'SigmaService');
        }

        if (attempt <= maxRetries) {
          // Attendre avant de rÃ©essayer (backoff exponentiel)
          final delay = retryDelay * attempt;
          dev.log(
              'âš ï¸ Service Call failed (attempt $attempt/$maxRetries)${sourceName != null ? " ($sourceName)" : ""}, retrying in ${delay.inMilliseconds}ms: $e',
              name: 'SigmaService');
          await Future.delayed(delay);
        } else {
          dev.log(
              'âŒ Service Call failed after $maxRetries retries${sourceName != null ? " ($sourceName)" : ""}: $e',
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

    // 3. Find first '{' â€” skip any preamble text before JSON
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

  /// Tente de rÃ©cupÃ©rer un JSON partiel ou malformÃ©
  AnalysisData _recoverFromBadJson(
    String symbol,
    String language,
  ) {
    dev.log('âš ï¸ Tentative de rÃ©cupÃ©ration JSON pour $symbol...');

    final bool isFr = language.toUpperCase().startsWith('FR');

    // CrÃ©er une analyse minimale de fallback
    return AnalysisData(
      ticker: symbol,
      companyProfile: isFr
          ? 'Analyse temporairement indisponible. SIGMA tente de stabiliser la connexion aux sources de donnÃ©es.'
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
          ? 'Une erreur s\'est produite lors de l\'agrÃ©gation des donnÃ©es. Veuillez rÃ©essayer dans quelques instants.'
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
      actionPlan: [isFr ? 'RÃ©essayer l\'analyse' : 'Retry analysis'],
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
            ? 'Ã‰tape 1 : Analyse des terminaux SIGMA en cours...'
            : 'Step 1: SIGMA terminal analysis in progress...',
        isFr
            ? 'Ã‰tape 2 : VÃ©rification des flux asymÃ©triques...'
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
        ? 'RÃ‰PONDS ENTIÃˆREMENT EN FRANÃ‡AIS.'
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

Tu es l'Intelligence Artificielle SIGMA, expert en marchÃ©s financiers globaux.
Ta mission est de rÃ©pondre de maniÃ¨re CHIRURGICALE et PRÃ‰CISE Ã  la question de l'utilisateur.

DONNÃ‰ES TEMPS RÃ‰EL DU TERMINAL ($ticker):
- Prix: ${context.price} | Verdict: ${context.verdict} | Score: ${context.sigmaScore.toInt()}/100
- Fondamentaux: $topFinancials
- Technique: $topTech
- RÃ©sumÃ©: ${context.summary.length > 400 ? '${context.summary.substring(0, 400)}...' : context.summary}$historyPrompt

QUESTION DE L'UTILISATEUR:
"$question"

OBJECTIF : RÃ©ponds UNIQUEMENT Ã  cette question. Ne fais pas de rÃ©sumÃ© gÃ©nÃ©ral si ce n'est pas demandÃ©. Utilise les chiffres du contexte pour prouver tes dires.

DIRECTIVE DE RÃ‰PONSE (STRICTE) : 
1. RÃ‰PONSE CIBLÃ‰E : Si la question porte sur un indicateur prÃ©cis, ne parle que de cet indicateur.
2. ZÃ‰RO MARKDOWN : Texte brut uniquement. Pas de ** ou #.
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

  /// Version streaming du chat pour une meilleure rÃ©activitÃ©
  Stream<String> chatWithSigmaStream({
    required String ticker,
    required AnalysisData context,
    required String question,
    List<Map<String, String>> history = const [],
    String language = 'EN',
    String ragContext = '',
  }) {
    final langInstr = language == 'FR'
        ? 'RÃ‰PONDS ENTIÃˆREMENT EN FRANÃ‡AIS.'
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

Tu es l'Intelligence Artificielle SIGMA, expert en marchÃ©s financiers globaux.
Ta mission est de rÃ©pondre de maniÃ¨re CHIRURGICALE et PRÃ‰CISE Ã  la question de l'utilisateur.

DONNÃ‰ES TEMPS RÃ‰EL DU TERMINAL ($ticker):
- Prix: ${context.price} | Verdict: ${context.verdict} | Score: ${context.sigmaScore.toInt()}/100
- Fondamentaux: $topFinancials
- Technique: $topTech
- RÃ©sumÃ©: ${context.summary.length > 400 ? '${context.summary.substring(0, 400)}...' : context.summary}$ragBlock$historyPrompt

QUESTION DE L'UTILISATEUR:
"$question"

OBJECTIF : RÃ©ponds UNIQUEMENT Ã  cette question. Ne fais pas de rÃ©sumÃ© gÃ©nÃ©ral si ce n'est pas demandÃ©. Utilise les chiffres du contexte pour prouver tes dires.

DIRECTIVE DE RÃ‰PONSE (STRICTE) : 
1. RÃ‰PONSE CIBLÃ‰E : Si la question porte sur un indicateur prÃ©cis, ne parle que de cet indicateur.
2. ZÃ‰RO MARKDOWN : Texte brut uniquement. Pas de ** ou #.
3. PAS DE BLA-BLA : Va droit au but.
''';

    return _marketProvider.generateStream(
      prompt: prompt,
      systemInstruction: _systemInstructionChat,
      jsonMode: false,
    );
  }

  /// Stream une synthÃ¨se stratÃ©gique basÃ©e sur les donnÃ©es d'analyse dÃ©jÃ  extraites
  Stream<String> streamAnalysisSynthesis({
    required AnalysisData analysis,
    String language = 'fr',
  }) {
    final bool isFr = language.toUpperCase().startsWith('FR');
    final prompt = '''
Tu es le 'SIGMA RESEARCH ORCHESTRATOR'. 
GÃ©nÃ¨re une synthÃ¨se stratÃ©gique PERCUTANTE et ANALYTIQUE pour ${analysis.ticker} (${analysis.companyName}).

DONNÃ‰ES CLÃ‰S :
- Prix : ${analysis.price} | Verdict : ${analysis.verdict} | Score : ${analysis.sigmaScore.toInt()}
5. Finance : ${analysis.financialMatrix.take(5).map((e) => "${e.label}:${e.value}").join(", ")}
- Technique : ${analysis.technicalAnalysis.take(5).map((e) => "${e.indicator}:${e.value}").join(", ")}

MISSON : RÃ©dige une synthÃ¨se de MAXIMUM 60 MOTS.
STYLE : Institutionnel, chirurgical, sans blabla.
DATE : 11 AVRIL 2026.
LANGUE : ${isFr ? "FRANÃ‡AIS (OBLIGATOIRE)" : "ENGLISH"}.

ZÃ‰RO MARKDOWN (pas de ** ou #). Texte brut uniquement.
SI LA LANGUE EST FRANÃ‡AIS, NE GÃ‰NÃˆRE AUCUN MOT EN ANGLAIS.
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

  /// Extrait le sentiment du marchÃ© de maniÃ¨re "agentique" depuis les rÃ©sultats de recherche web
  Map<String, dynamic> _parseSentiment(String context, double vix) {
    if (context.isEmpty) return {'label': 'NEUTRAL', 'value': 0.0};

    // 1. Recherche du score numÃ©rique exact (ex: "Fear and Greed Index: 42")
    final scoreRegex =
        RegExp(r'(?:Fear|Greed|Index)[:\s]+(\d{1,2})', caseSensitive: false);
    final match = scoreRegex.firstMatch(context);

    double value = 0.0;
    if (match != null) {
      value = double.tryParse(match.group(1)!) ?? 0.0;
    }

    // 2. Si pas de score numÃ©rique, recherche de mots-clÃ©s de sentiment
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
- FOCUS STRICT SUR LES DONNÃ‰ES DE 2026. DATE ACTUELLE: 11 AVRIL 2026. 
- Focus sur CROSS-CORRELATIONS.
- Be extremely specific and high-conviction.
''';

  Future<List<CatalystInsight>> getAgenticRadar(List<String> tickers) async {
    if (tickers.isEmpty) return [];

    try {
      // 1. Gather macro data (Sigma API)
      final macroSummaryList = await _getMarketSummaryWithFallback();
      final macroStr = macroSummaryList
          .take(5)
          .map((e) => "${e['symbol']}: ${e['price']} (${e['changePercent']}%)")
          .join(", ");

      // 2. Fetch Deep News for outlier tickers (Agentic scan) in PARALLEL
      final List<String> tickersToScan = tickers.take(8).toList();

      // Multi-threading data discovery via SIGMA
      final newsResults = await Future.wait(tickersToScan.map((t) => _marketData
          .getStockNews(t, limit: 3)
          .catchError((_) => <dynamic>[])));

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
      dev.log("âŒ Error in Agentic Radar: $e", name: "SigmaService");
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

  /// Search symbols using a single-source-of-truth approach.
  /// Prioritizes the SIGMA backend and only uses Finnhub as a sequential fallback if no results are found.
  Future<List<Map<String, dynamic>>> searchTickerSymbolsUnified(
      String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    if (_searchCache.containsKey(q)) {
      return _searchCache[q]!;
    }

    try {
      // 1. Primary: SIGMA backend
      List<Map<String, dynamic>> results =
          await _marketData.searchTickerSymbols(q).catchError((e) {
        dev.log('Sigma search error: $e', name: 'SigmaService');
        return <Map<String, dynamic>>[];
      });

      // 2. Secondary: Finnhub fallback (only if primary is empty to avoid confusion)
      if (results.isEmpty && _finnhub.isConfigured) {
        results = await _finnhub.searchSymbols(q).catchError((e) {
          dev.log('Finnhub search error: $e', name: 'SigmaService');
          return <Map<String, dynamic>>[];
        });
      }

      // Map and sort results consistently
      final isPrimary = results.isNotEmpty &&
          results.any((r) => r['source'] == 'SIGMA' || r['source'] == null);

      final out = results.map((raw) {
        final symbol = (raw['symbol'] ?? raw['displaySymbol'] ?? '')
            .toString()
            .toUpperCase();
        final directLogo =
            (raw['logoUrl'] ?? raw['logo'] ?? raw['image'])?.toString().trim();
        final logo = LogoResolver.resolve(symbol, providedUrl: directLogo);
        return {
          ...raw,
          'symbol': symbol,
          'name': raw['name'] ?? raw['description'] ?? symbol,
          'description': raw['description'] ?? raw['name'] ?? symbol,
          'logoUrl': logo,
          'logo': logo,
          'source': raw['source'] ?? (isPrimary ? 'SIGMA' : 'FINNHUB'),
        };
      }).toList();

      // Ensure the exact match is always first
      out.sort((a, b) {
        final sa = (a['symbol'] ?? '').toString().toUpperCase();
        final sb = (b['symbol'] ?? '').toString().toUpperCase();
        final qa = sa == q.toUpperCase()
            ? 0
            : (sa.startsWith(q.toUpperCase()) ? 1 : 2);
        final qb = sb == q.toUpperCase()
            ? 0
            : (sb.startsWith(q.toUpperCase()) ? 1 : 2);
        if (qa != qb) return qa.compareTo(qb);
        return sa.compareTo(sb);
      });

      _searchCache[q] = out;
      return out;
    } catch (e) {
      dev.log('Search failure: $e', name: 'SigmaService');
      return [];
    }
  }

  Future<String> analyzeHistoricalPoint(
      String ticker, Map<String, dynamic> point,
      {String language = 'FRANÃ‡AIS'}) async {
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
      // ── Compute full technical overlays ──────────────────────────────────
      final overlays = ChartOverlayEngine.compute(history);
      final closes =
          history.map((e) => (e['close'] as num?)?.toDouble() ?? 0.0).toList();
      final volumes =
          history.map((e) => (e['volume'] as num?)?.toDouble() ?? 0.0).toList();

      final firstClose = closes.first;
      final lastClose = closes.last;
      final high = history
          .map((e) => (e['high'] as num?)?.toDouble() ?? 0.0)
          .reduce((a, b) => a > b ? a : b);
      final low = history
          .map((e) => (e['low'] as num?)?.toDouble() ?? 0.0)
          .reduce((a, b) => a < b ? a : b);
      final pctChange =
          firstClose > 0 ? ((lastClose - firstClose) / firstClose * 100) : 0.0;

      // Volume trend
      final recentVolAvg = volumes.length >= 10
          ? volumes.sublist(volumes.length - 10).reduce((a, b) => a + b) / 10
          : volumes.last;
      final prevVolAvg = volumes.length >= 20
          ? volumes
                  .sublist(volumes.length - 20, volumes.length - 10)
                  .reduce((a, b) => a + b) /
              10
          : recentVolAvg;
      final volTrend = prevVolAvg > 0
          ? (recentVolAvg / prevVolAvg >= 1.15
              ? 'Expanding'
              : recentVolAvg / prevVolAvg <= 0.85
                  ? 'Contracting'
                  : 'Stable')
          : 'N/A';

      // SMA positions
      final sma50Last =
          overlays.sma50.lastWhere((v) => v != null, orElse: () => null);
      final sma200Last =
          overlays.sma200.lastWhere((v) => v != null, orElse: () => null);
      final smaContext = [
        if (sma50Last != null)
          'SMA${overlays.fastPeriod}: \$${sma50Last.toStringAsFixed(2)} (${lastClose > sma50Last ? "above" : "below"})',
        if (sma200Last != null)
          'SMA${overlays.slowPeriod}: \$${sma200Last.toStringAsFixed(2)} (${lastClose > sma200Last ? "above" : "below"})',
      ].join(' | ');

      // RSI
      final rsiVal =
          overlays.rsi.lastWhere((v) => v != null, orElse: () => null);
      final rsiStr = rsiVal == null
          ? 'N/A'
          : '${rsiVal.toStringAsFixed(1)} (${rsiVal >= 70 ? "Overbought" : rsiVal <= 30 ? "Oversold" : "Neutral"})';

      // MACD
      final macdHist = overlays.latestMacdHist;
      final macdStr = macdHist == null
          ? 'N/A'
          : '${macdHist > 0 ? "Bullish" : "Bearish"} (hist: ${macdHist.toStringAsFixed(3)})';

      // Cross events
      final crossStr = overlays.crossEvents.isEmpty
          ? 'None'
          : overlays.crossEvents.reversed
              .take(2)
              .map((c) =>
                  '${c.isGolden ? "Golden" : "Death"} Cross @ \$${c.price.toStringAsFixed(2)} [${c.isStrong ? "confirmed" : "weak"}]')
              .join(', ');

      // OBV
      final obvStr = overlays.isObvBullish
          ? 'Bullish (accumulation)'
          : 'Bearish (distribution)';

      // Price position in range
      final rangePos = high > low
          ? ((lastClose - low) / (high - low) * 100).toStringAsFixed(0)
          : 'N/A';

      // News catalysts
      final newsStr =
          contextData.companyNews.take(4).map((n) => '• ${n.title}').join('\n');

      // Fundamental context
      final mktCap = contextData.keyStatistics?.marketCap ?? 'N/A';
      final pe = contextData.keyStatistics?.trailingPE ?? 'N/A';
      final eps = contextData.keyStatistics?.trailingEps ?? 'N/A';

      final prompt =
          '''Analyze the $range price action for ${contextData.ticker} (${contextData.companyName}, ${contextData.sector}):

PRICE ACTION:
- Period: $range | Sessions: ${history.length} | Price: \$${firstClose.toStringAsFixed(2)} → \$${lastClose.toStringAsFixed(2)} (${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(1)}%)
- High: \$${high.toStringAsFixed(2)} | Low: \$${low.toStringAsFixed(2)} | Position in range: $rangePos%
- Regime: ${overlays.regime}

TECHNICAL INDICATORS:
- RSI(14): $rsiStr
- MACD: $macdStr
- OBV: $obvStr
- Moving Averages: ${smaContext.isNotEmpty ? smaContext : 'N/A'}
- Volume trend: $volTrend
- Cross events: $crossStr

FUNDAMENTAL CONTEXT:
- MarketCap: $mktCap | P/E: $pe | EPS: $eps
- Beta: ${contextData.keyStatistics?.beta ?? 'N/A'} | IV: ${contextData.volatility.ivRank}

RECENT NEWS & CATALYSTS:
$newsStr

Provide a 3-4 sentence institutional technical summary for this $range timeframe.
Identify the dominant trend, key technical signal, and one key risk or opportunity.
PLAIN TEXT ONLY. NO JSON. NO MARKDOWN. NO BULLET POINTS.
Respond in $language.''';

      final res = await _stockProvider.generateContent(
        prompt: prompt,
        systemInstruction:
            "You are a senior technical analyst at a prime brokerage. Deliver precise, institutional-grade price action commentary.",
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
            RegExp(r'^(RÃ©sumÃ©|Summary|Analysis|Verdict)\s*:\s*',
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

  // ---------------------------------------------------------------------------
  // 🐂 BULL VS 🐻 BEAR DEBATE
  // ---------------------------------------------------------------------------
  Future<Map<String, String>> generateBullBearDebate(AnalysisData data) async {
    final ticker = data.ticker.toUpperCase();
    final bool isFr = data.summary.toLowerCase().contains('le') ||
        data.summary.toLowerCase().contains('est');

    final dataContext = '''
Ticker: $ticker
Company: ${data.companyName ?? ticker}
Current Price: ${data.price}
SIGMA Score: ${data.sigmaScore}/100
Verdict: ${data.verdict}
Institutional Sentiment: ${data.institutionalActivity.darkPoolInterpretation}
Pros: ${data.pros.map((e) => e.text).join(' | ')}
Cons: ${data.cons.map((e) => e.text).join(' | ')}
Financials: ${data.financialMatrix.map((e) => '${e.label}: ${e.value}').join(', ')}
''';

    final bearPrompt = """
You are a Bear Analyst making the case against investing in the stock. Your goal is to present a well-reasoned argument emphasizing risks, challenges, and negative indicators. Leverage the provided research and data to highlight potential downsides and counter bullish arguments effectively.

Key points to focus on:
- Risks and Challenges: Highlight factors like market saturation, financial instability, or macroeconomic threats that could hinder the stock's performance.
- Competitive Weaknesses: Emphasize vulnerabilities such as weaker market positioning, declining innovation, or threats from competitors.
- Negative Indicators: Use evidence from financial data, market trends, or recent adverse news to support your position.
- Bull Counterpoints: Critically analyze the bull argument with specific data and sound reasoning, exposing weaknesses or over-optimistic assumptions.
- Engagement: Present your argument in a conversational style, directly engaging with the bull analyst's points and debating effectively rather than simply listing facts.

RESPOND IN ${isFr ? 'FRENCH' : 'ENGLISH'}.
""";

    final bullPrompt = """
You are a Bull Analyst advocating for investing in the stock. Your task is to build a strong, evidence-based case emphasizing growth potential, competitive advantages, and positive market indicators. Leverage the provided research and data to address concerns and counter bearish arguments effectively.

Key points to focus on:
- Growth Potential: Highlight the company's market opportunities, revenue projections, and scalability.
- Competitive Advantages: Emphasize factors like unique products, strong branding, or dominant market positioning.
- Positive Indicators: Use financial health, industry trends, and recent positive news as evidence.
- Bear Counterpoints: Critically analyze the bear argument with specific data and sound reasoning, addressing concerns thoroughly and showing why the bull perspective holds stronger merit.
- Engagement: Present your argument in a conversational style, engaging directly with the bear analyst's points and debating effectively rather than just listing data.

RESPOND IN ${isFr ? 'FRENCH' : 'ENGLISH'}.
""";

    try {
      final provider = _deepReasoningProvider ?? _stockProvider;

      final results = await Future.wait([
        provider.generateContent(
          prompt: "$bearPrompt\n\nMarket Data:\n$dataContext",
          systemInstruction:
              "You are the Bear Analyst. Be critical, data-driven, and persuasive.",
        ),
        provider.generateContent(
          prompt: "$bullPrompt\n\nMarket Data:\n$dataContext",
          systemInstruction:
              "You are the Bull Analyst. Be optimistic, growth-oriented, and data-driven.",
        ),
      ]);

      return {
        'bear': _isUsableDebateText(results[0])
            ? results[0]
            : _fallbackBearCase(data),
        'bull': _isUsableDebateText(results[1])
            ? results[1]
            : _fallbackBullCase(data),
      };
    } catch (e) {
      dev.log('❌ Error generating debate: $e');
      return {
        'bear': _fallbackBearCase(data),
        'bull': _fallbackBullCase(data),
      };
    }
  }

  bool _isUsableDebateText(String value) {
    final clean = value.trim().toLowerCase();
    if (clean.length < 24) return false;
    if (clean.contains('failed to generate')) return false;
    if (clean == '{}' || clean == '[]') return false;
    return true;
  }

  String _fallbackBullCase(AnalysisData data) {
    final decision = FinancialDecisionEngine.evaluate(data, language: 'FR');
    final points = data.pros.map((p) => p.text).where(_hasDebatePoint).take(3);
    final positives = points.isNotEmpty ? points : decision.positives.take(3);
    final buffer = StringBuffer()
      ..write('${data.ticker.toUpperCase()} conserve un angle constructif si ')
      ..write('le marche reconnait la qualite relative du dossier. ');
    if (data.targetPriceValue != null && data.targetPriceValue! > 0) {
      buffer.write(
          'L objectif disponible de \$${data.targetPriceValue!.toStringAsFixed(2)} fournit un repere de valorisation. ');
    }
    if (positives.isNotEmpty) {
      buffer.write('Les principaux arguments favorables sont: ');
      buffer.write(positives.join(' '));
    } else {
      buffer.write(decision.summary);
    }
    return buffer.toString();
  }

  String _fallbackBearCase(AnalysisData data) {
    final decision = FinancialDecisionEngine.evaluate(data, language: 'FR');
    final points = data.cons.map((p) => p.text).where(_hasDebatePoint).take(3);
    final negatives = points.isNotEmpty ? points : decision.negatives.take(3);
    final buffer = StringBuffer()
      ..write('Le risque principal sur ${data.ticker.toUpperCase()} vient de ')
      ..write(
          'la sensibilite du dossier aux donnees encore incompletes et a la discipline de prix. ');
    if (negatives.isNotEmpty) {
      buffer.write('Les points de vigilance sont: ');
      buffer.write(negatives.join(' '));
    } else {
      buffer.write(
          'La these doit etre invalidee si le momentum, les marges ou le consensus se deteriorent apres les prochaines publications.');
    }
    return buffer.toString();
  }

  bool _hasDebatePoint(String value) {
    final clean = value.trim().toLowerCase();
    return clean.isNotEmpty &&
        clean != 'n/a' &&
        clean != 'na' &&
        !clean.contains('failed to generate') &&
        !clean.contains('donnees insuffisantes') &&
        !clean.contains('données insuffisantes');
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

  /// Builds a narrative-driven, mobile-first institutional report JSON.
  /// Schema: hook · executive_summary · key_charts · key_tables ·
  ///         analysis_sections · risks · appendix · ui_hints · quality_flags
  Map<String, dynamic> _buildPremiumInstitutionalReport(
    AnalysisData data,
    String language,
  ) {
    final isFr = language.toUpperCase().startsWith('FR');
    final qualityFlags = <Map<String, dynamic>>[];
    final qualityFlagKeys = <String>{};

    // ── Helpers ────────────────────────────────────────────────────────────

    void flag(String field, String reason) {
      if (!qualityFlagKeys.add('$field:$reason')) return;
      qualityFlags.add({'field': field, 'reason': reason});
    }

    Map<String, dynamic> num_(
      String label,
      dynamic rawValue,
      String unit, {
      String trend = 'neutral',
      dynamic delta,
    }) {
      final raw = rawValue == null ? null : AnalysisData.parseNum(rawValue);
      if (raw == null || raw == 0) flag(label, 'missing_or_zero');
      return {
        'label': label,
        'raw_value': raw == 0 ? null : raw,
        'formatted_value':
            (raw == null || raw == 0) ? null : _formatReportValue(raw, unit),
        'unit': unit,
        'trend': trend,
        'delta': delta,
      };
    }

    String trend_(num? value) {
      if (value == null || value == 0) return 'neutral';
      return value > 0 ? 'positive' : 'negative';
    }

    String severity_(String riskLevel) {
      final u = riskLevel.toUpperCase();
      if (u.contains('HIGH') || u.contains('ELEV') || u.contains('FORT')) {
        return 'high';
      }
      if (u.contains('LOW') || u.contains('FAIB')) return 'low';
      return 'medium';
    }

    // ── Source data ────────────────────────────────────────────────────────

    final keyStats = data.keyStatistics;
    if (keyStats == null) flag('fundamentals.key_statistics', 'missing');

    final currentPrice = () {
      final v = AnalysisData.parseNum(data.price);
      if (v == 0) flag('price.current', 'missing_or_zero');
      return v == 0 ? null : v;
    }();

    final targetPrice =
        (data.targetPriceValue != null && data.targetPriceValue! > 0)
            ? data.targetPriceValue
            : null;
    if (targetPrice == null) flag('valuation.target_price', 'missing');

    final upside =
        (currentPrice != null && targetPrice != null && currentPrice > 0)
            ? ((targetPrice - currentPrice) / currentPrice) * 100
            : null;
    if (upside == null) {
      flag('valuation.upside', 'requires_price_and_target');
    }

    final revenue = keyStats?.revenue ?? 0;
    final revenueGrowth =
        keyStats == null ? 0.0 : (keyStats.revenueGrowth * 100);
    final netMargin = keyStats == null ? 0.0 : (keyStats.profitMargins * 100);
    final roe = keyStats == null ? 0.0 : (keyStats.returnOnEquity * 100);
    final trailingPE = keyStats?.trailingPE ?? 0.0;

    // ── Hook (strong opening sentence) ─────────────────────────────────────

    final String hook;
    final name = data.companyName ?? data.ticker;
    if (upside != null && upside.abs() >= 5) {
      final direction = upside >= 0
          ? (isFr ? 'un potentiel haussier de' : 'upside of')
          : (isFr ? 'un risque baissier de' : 'downside risk of');
      hook = isFr
          ? '$name affiche $direction ${upside.abs().toStringAsFixed(1)}% — voici pourquoi ce dossier merite attention.'
          : '$name presents $direction ${upside.abs().toStringAsFixed(1)}% — here\'s why this name deserves a close read.';
    } else if (data.sigmaScore >= 75) {
      hook = isFr
          ? '$name obtient un score SIGMA de ${data.sigmaScore.toStringAsFixed(0)}/100 — signal de conviction fort.'
          : '$name scores ${data.sigmaScore.toStringAsFixed(0)}/100 on SIGMA — a high-conviction signal.';
    } else if (data.verdict == 'ACHAT' || data.verdict == 'BUY') {
      hook = isFr
          ? '$name : verdict ACHAT. Trois arguments structurels justifient ce positionnement aujourd\'hui.'
          : '$name: BUY verdict. Three structural arguments support this positioning today.';
    } else {
      hook = isFr
          ? '$name (${data.ticker}) est au coeur d\'une dynamique sectorielle que nous decryptons ci-dessous.'
          : '$name (${data.ticker}) sits at the center of a sector dynamic we break down below.';
    }

    // ── Executive summary — 3 insight-oriented points max ──────────────────

    final execPoints = <Map<String, dynamic>>[];

    // Point 1: Verdict + upside
    if (upside != null) {
      final direction = upside >= 0
          ? (isFr ? 'potentiel' : 'upside')
          : (isFr ? 'risque' : 'downside');
      execPoints.add({
        'rank': 1,
        'label': isFr ? 'Verdict & objectif' : 'Verdict & target',
        'text': isFr
            ? '${data.verdict} — objectif ${targetPrice!.toStringAsFixed(2)} USD, soit ${upside.abs().toStringAsFixed(1)}% de $direction par rapport au cours actuel de ${currentPrice!.toStringAsFixed(2)} USD.'
            : '${data.verdict} — target \$${targetPrice!.toStringAsFixed(2)}, implying ${upside.abs().toStringAsFixed(1)}% $direction from current \$${currentPrice!.toStringAsFixed(2)}.',
        'tone': trend_(upside),
      });
    } else {
      execPoints.add({
        'rank': 1,
        'label': isFr ? 'Verdict' : 'Verdict',
        'text':
            '${data.verdict}. ${data.summary.isNotEmpty ? data.summary.split('.').first + '.' : ''}',
        'tone': data.verdict == 'ACHAT' || data.verdict == 'BUY'
            ? 'positive'
            : data.verdict == 'VENTE' || data.verdict == 'SELL'
                ? 'negative'
                : 'neutral',
      });
    }

    // Point 2: Financial quality (highest signal)
    if (revenueGrowth != 0 || netMargin != 0) {
      execPoints.add({
        'rank': 2,
        'label': isFr ? 'Qualite financiere' : 'Financial quality',
        'text': isFr
            ? 'Croissance des revenus de ${revenueGrowth.toStringAsFixed(1)}%, marge nette de ${netMargin.toStringAsFixed(1)}% — ${netMargin >= 15 ? 'rentabilite au-dessus de la mediane sectorielle.' : netMargin > 0 ? 'marge positive, a surveiller.' : 'pression persistante sur les marges.'}'
            : 'Revenue growth ${revenueGrowth.toStringAsFixed(1)}%, net margin ${netMargin.toStringAsFixed(1)}% — ${netMargin >= 15 ? 'profitability above sector median.' : netMargin > 0 ? 'positive margin, watch trend.' : 'persistent margin pressure.'}',
        'tone': trend_(netMargin),
      });
    } else if (data.summary.isNotEmpty) {
      execPoints.add({
        'rank': 2,
        'label': isFr ? 'Contexte' : 'Context',
        'text': data.summary.split('.').take(2).join('.') + '.',
        'tone': 'neutral',
      });
    }

    // Point 3: Top catalyst or strength
    if (data.catalysts.isNotEmpty) {
      final topCat = data.catalysts.first;
      execPoints.add({
        'rank': 3,
        'label': isFr ? 'Catalyseur cle' : 'Key catalyst',
        'text':
            '${topCat.headline}. ${topCat.insight.isNotEmpty ? topCat.insight.split('.').first + '.' : ''}',
        'tone':
            topCat.type.toUpperCase().contains('RIS') ? 'negative' : 'positive',
      });
    } else if (data.pros.isNotEmpty) {
      execPoints.add({
        'rank': 3,
        'label': isFr ? 'Atout principal' : 'Main strength',
        'text': data.pros.first.text.split('.').first + '.',
        'tone': 'positive',
      });
    }

    // ── Key charts — each answers a specific question ───────────────────────

    final keyCharts = <Map<String, dynamic>>[];

    // Chart 1: Current price vs 52w range vs target
    if (currentPrice != null) {
      final hi = keyStats?.fiftyTwoWeekHigh ?? 0.0;
      final lo = keyStats?.fiftyTwoWeekLow ?? 0.0;
      keyCharts.add({
        'id': 'price_range',
        'question': isFr
            ? 'Ou se situe le titre dans son corridor 52 semaines?'
            : 'Where does the stock sit in its 52-week range?',
        'insight': isFr
            ? (hi > 0 && lo > 0)
                ? 'Le titre se negocie a ${((currentPrice - lo) / (hi - lo) * 100).toStringAsFixed(0)}% de son corridor 52 semaines.'
                : 'Donnees de fourchette 52 semaines indisponibles.'
            : (hi > 0 && lo > 0)
                ? 'The stock trades at ${((currentPrice - lo) / (hi - lo) * 100).toStringAsFixed(0)}% of its 52-week range.'
                : '52-week range data unavailable.',
        'type': 'range_bar',
        'unit': 'USD',
        'data': {
          'low': num_('52w_low', lo == 0 ? null : lo, 'USD'),
          'current': num_('current_price', currentPrice, 'USD'),
          'target':
              num_('target_price', targetPrice, 'USD', trend: trend_(upside)),
          'high': num_('52w_high', hi == 0 ? null : hi, 'USD'),
        },
      });
    }

    // Chart 2: Projected price path (if data available)
    final priceSeries = data.projectedTrend
        .where((pt) => pt.price > 0)
        .map((pt) => {
              'x': pt.date,
              'y': num_('price', pt.price, 'USD',
                  trend: pt.signal.toUpperCase().contains('BEAR')
                      ? 'negative'
                      : pt.signal.toUpperCase().contains('BULL')
                          ? 'positive'
                          : 'neutral'),
              'signal': pt.signal,
            })
        .toList();
    if (priceSeries.isNotEmpty) {
      keyCharts.add({
        'id': 'projected_path',
        'question': isFr
            ? 'Quel est le scenario de prix attendu a horizon 12M?'
            : 'What is the expected 12M price path?',
        'insight': isFr
            ? 'Trajectoire projetee issue des signaux techniques et fondamentaux consolides.'
            : 'Projected path derived from consolidated technical and fundamental signals.',
        'type': 'line',
        'unit': 'USD',
        'series': [
          {'name': data.ticker, 'data': priceSeries},
        ],
        'x_axis': 'date',
        'y_axis': 'price',
        'time_range': '12M',
      });
    }

    // Chart 3: Revenue trend (if historical income available)
    if (data.historicalEarnings != null &&
        (data.historicalEarnings!).isNotEmpty) {
      final revData = data.historicalEarnings!
          .take(5)
          .map((e) {
            final m =
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
            final rev =
                AnalysisData.parseNum(m['totalRevenue'] ?? m['revenue'] ?? 0);
            final yr = m['fiscalDateEnding']?.toString() ??
                m['date']?.toString() ??
                '';
            return rev > 0 ? {'x': yr, 'y': num_('revenue', rev, 'USD')} : null;
          })
          .whereType<Map<String, dynamic>>()
          .toList()
          .reversed
          .toList();
      if (revData.isNotEmpty) {
        keyCharts.add({
          'id': 'revenue_trend',
          'question': isFr
              ? 'La croissance du chiffre d\'affaires est-elle durable?'
              : 'Is revenue growth sustainable?',
          'insight': revenueGrowth != 0
              ? (isFr
                  ? 'Croissance annuelle de ${revenueGrowth.toStringAsFixed(1)}% — ${revenueGrowth >= 10 ? 'dynamique soutenue.' : revenueGrowth >= 0 ? 'progression moderee.' : 'contraction a surveiller.'}'
                  : 'Annual growth of ${revenueGrowth.toStringAsFixed(1)}% — ${revenueGrowth >= 10 ? 'strong momentum.' : revenueGrowth >= 0 ? 'moderate progression.' : 'contraction to monitor.'}')
              : (isFr
                  ? 'Tendance de revenus sur 5 ans.'
                  : '5-year revenue trend.'),
          'type': 'bar',
          'unit': 'USD',
          'series': [
            {'name': isFr ? 'Revenus' : 'Revenue', 'data': revData},
          ],
          'x_axis': 'year',
          'y_axis': 'revenue',
        });
      }
    }

    // ── Key tables ──────────────────────────────────────────────────────────

    final keyTables = <Map<String, dynamic>>[];

    // Table 1: Valuation snapshot (compact, 5 rows max)
    keyTables.add({
      'id': 'valuation_snapshot',
      'intro': isFr
          ? 'La valorisation se lit en un coup d\'oeil — les cases rouges signalent un premium excessif.'
          : 'Valuation at a glance — red cells flag excessive premium.',
      'title': isFr ? 'Valorisation rapide' : 'Valuation snapshot',
      'columns': [
        isFr ? 'Metrique' : 'Metric',
        isFr ? 'Valeur' : 'Value',
        isFr ? 'Signal' : 'Signal',
      ],
      'rows': [
        {
          'metric': isFr ? 'Capitalisation' : 'Market cap',
          'value': num_('market_cap', keyStats?.marketCap, 'USD'),
          'signal': 'neutral',
        },
        {
          'metric': 'P/E (TTM)',
          'value':
              num_('trailing_pe', trailingPE == 0 ? null : trailingPE, 'x'),
          'signal': trailingPE > 35
              ? 'negative'
              : trailingPE > 0
                  ? 'neutral'
                  : 'na',
        },
        {
          'metric': 'P/S',
          'value': num_('price_to_sales', keyStats?.priceToSales, 'x'),
          'signal': 'neutral',
        },
        {
          'metric': 'P/B',
          'value': num_('price_to_book', keyStats?.priceToBook, 'x'),
          'signal': 'neutral',
        },
        {
          'metric': isFr ? 'Objectif consensus' : 'Consensus target',
          'value':
              num_('target_price', targetPrice, 'USD', trend: trend_(upside)),
          'signal': trend_(upside),
        },
      ],
      'footnotes': [
        isFr
            ? 'Sources: SIGMA API, SEC facts. Valeurs null = donnee indisponible.'
            : 'Sources: SIGMA API, SEC facts. Null = data unavailable.',
      ],
    });

    // Table 2: Peer comparison (if available)
    if (data.sectorPeers.isNotEmpty) {
      final peerRows = data.sectorPeers
          .take(5)
          .map((peer) => {
                'ticker': peer.ticker,
                'name': peer.name,
                'mkt_cap': peer.marketCap,
                'pe': num_('${peer.ticker}.pe', peer.peRatio, 'x'),
                'verdict': peer.verdict,
              })
          .toList();
      keyTables.add({
        'id': 'peer_comparison',
        'intro': isFr
            ? '${data.ticker} face a ses comparables directs — meme secteur, meme cycle.'
            : '${data.ticker} versus direct comparables — same sector, same cycle.',
        'title': isFr ? 'Comparatif pairs' : 'Peer comparison',
        'columns': [
          'Ticker',
          isFr ? 'Nom' : 'Name',
          isFr ? 'Capitalisation' : 'Mkt cap',
          'P/E',
          'Verdict'
        ],
        'rows': peerRows,
        'footnotes': [
          isFr ? 'Source: SIGMA quote feed.' : 'Source: SIGMA quote feed.',
        ],
      });
    }

    // ── Analysis sections ────────────────────────────────────────────────────
    // Each section has: id, title (insight-oriented), paragraphs (2-3 sentences max), kpis

    final analysisSections = <Map<String, dynamic>>[];

    // Section: Business model / thesis
    if (data.companyProfile.isNotEmpty || data.businessModel != 'N/A') {
      final profile = data.companyProfile.isNotEmpty
          ? data.companyProfile
          : data.businessModel;
      final sentences =
          profile.split('.').where((s) => s.trim().isNotEmpty).toList();
      analysisSections.add({
        'id': 'thesis',
        'title': isFr
            ? 'Pourquoi ce modele genere-t-il de la valeur?'
            : 'Why does this business model create value?',
        'paragraphs': [
          sentences.take(3).join('.') + '.',
        ],
        'kpis': [],
      });
    }

    // Section: Fundamentals
    if (revenue > 0 || revenueGrowth != 0 || netMargin != 0) {
      final fcfStr = keyStats != null && keyStats.freeCashflow > 0
          ? _formatLargeNumber(keyStats.freeCashflow)
          : null;
      final para1 = isFr
          ? 'Revenus ${_formatLargeNumber(revenue)}, croissance ${revenueGrowth.toStringAsFixed(1)}%, marge nette ${netMargin.toStringAsFixed(1)}%.'
          : 'Revenue ${_formatLargeNumber(revenue)}, growth ${revenueGrowth.toStringAsFixed(1)}%, net margin ${netMargin.toStringAsFixed(1)}%.';
      final para2 = roe != 0
          ? (isFr
              ? 'ROE de ${roe.toStringAsFixed(1)}%${fcfStr != null ? ', FCF $fcfStr' : ''} — ${roe >= 15 ? 'rentabilite des capitaux propres solide.' : 'a comparer avec les pairs sectoriels.'}'
              : 'ROE ${roe.toStringAsFixed(1)}%${fcfStr != null ? ', FCF $fcfStr' : ''} — ${roe >= 15 ? 'solid return on equity.' : 'benchmark against sector peers.'}')
          : null;
      analysisSections.add({
        'id': 'fundamentals',
        'title': isFr
            ? 'Les chiffres racontent-ils une histoire de croissance rentable?'
            : 'Do the numbers tell a story of profitable growth?',
        'paragraphs': [
          para1,
          if (para2 != null) para2,
        ],
        'kpis': [
          num_('revenue', revenue == 0 ? null : revenue, 'USD'),
          num_('revenue_growth', revenueGrowth == 0 ? null : revenueGrowth, '%',
              trend: trend_(revenueGrowth)),
          num_('net_margin', netMargin == 0 ? null : netMargin, '%',
              trend: trend_(netMargin)),
          num_('roe', roe == 0 ? null : roe, '%', trend: trend_(roe)),
          num_('debt_to_equity', keyStats?.debtToEquity, 'x'),
        ],
      });
    }

    // Section: Catalysts (only if present)
    if (data.catalysts.isNotEmpty) {
      analysisSections.add({
        'id': 'catalysts',
        'title': isFr
            ? 'Quels declencheurs peuvent repriser le cours dans 12M?'
            : 'What triggers could re-rate the stock in 12M?',
        'paragraphs': [
          isFr
              ? '${data.catalysts.length} catalyseur(s) identifie(s). Le plus significatif: ${data.catalysts.first.headline.split('.').first}.'
              : '${data.catalysts.length} catalyst(s) identified. The most significant: ${data.catalysts.first.headline.split('.').first}.',
        ],
        'items': data.catalysts
            .take(5)
            .map((c) => {
                  'label': c.headline,
                  'detail': c.insight,
                  'tone': c.type.toUpperCase().contains('RIS')
                      ? 'negative'
                      : 'positive',
                  'horizon': '12M',
                })
            .toList(),
        'kpis': [],
      });
    }

    // Section: Ownership & flows (if holders data available)
    if (data.holders != null || data.institutionalHolders != null) {
      final instHolders = data.institutionalHolders;
      analysisSections.add({
        'id': 'ownership',
        'title': isFr
            ? 'Qui detient et que font les institutionnels?'
            : 'Who owns it and what are institutions doing?',
        'paragraphs': [
          isFr
              ? 'La structure actionnariale reflète la conviction institutionnelle autour du dossier.'
              : 'The ownership structure reflects institutional conviction around this name.',
        ],
        'kpis': [
          if (data.insiderBuyRatio != null)
            num_('insider_buy_ratio', (data.insiderBuyRatio! * 100), '%',
                trend: trend_(data.insiderBuyRatio! - 0.5)),
        ],
        'top_holders': instHolders
                ?.take(4)
                .map((h) => {
                      'name': h['Holder'] ?? h['name'] ?? '',
                      'shares': h['Shares'] ?? h['shares'] ?? '',
                      'pct_held': h['% Out'] ?? h['pct_held'] ?? '',
                    })
                .toList() ??
            [],
      });
    }

    // ── Risks ────────────────────────────────────────────────────────────────

    final riskItems = data.cons
        .take(5)
        .map((c) => {
              'label': c.text.split('.').first + '.',
              'detail': c.text.length > 80
                  ? c.text.substring(0, 80).trimRight() + '...'
                  : c.text,
              'severity': severity_(data.riskLevel),
              'period': c.period,
            })
        .toList();

    if (riskItems.isEmpty) {
      flag('risks.items', 'no_cons_data');
    }

    final invalidationTriggers = data.actionPlan.isNotEmpty
        ? data.actionPlan.take(3).toList()
        : [
            isFr
                ? 'Degradation durable des marges sur deux trimestres consecutifs.'
                : 'Sustained margin deterioration over two consecutive quarters.',
            isFr
                ? 'Perte de parts de marche dans le segment principal.'
                : 'Market share loss in the core segment.',
            isFr
                ? 'Surprise negative majeure lors des prochains resultats trimestriels.'
                : 'Major negative earnings surprise in the next quarterly results.',
          ];

    // ── Appendix (secondary, deep-dive data) ────────────────────────────────

    final appendixSections = <Map<String, dynamic>>[];

    // Technical analysis
    if (data.technicalAnalysis.isNotEmpty) {
      appendixSections.add({
        'id': 'technical_analysis',
        'title': isFr ? 'Analyse technique' : 'Technical analysis',
        'rows': data.technicalAnalysis
            .take(8)
            .map((t) => {
                  'indicator': t.indicator,
                  'value': t.value,
                  'interpretation': t.interpretation,
                })
            .toList(),
        'supports': data.supports.take(3).toList(),
        'resistances': data.resistances.take(3).toList(),
      });
    }

    // Corporate calendar
    if (data.corporateEvents.isNotEmpty) {
      appendixSections.add({
        'id': 'corporate_calendar',
        'title': isFr ? 'Agenda corporatif' : 'Corporate calendar',
        'intro': isFr
            ? 'Prochains evenements susceptibles de creer de la volatilite.'
            : 'Upcoming events likely to create price volatility.',
        'rows': data.corporateEvents
            .take(6)
            .map((e) => {
                  'date': e.date,
                  'event': e.event,
                  'description': e.description,
                })
            .toList(),
      });
    }

    // Financial matrix deep dive
    if (data.financialMatrix.isNotEmpty) {
      appendixSections.add({
        'id': 'financial_matrix',
        'title': isFr
            ? 'Tableau de bord financier complet'
            : 'Full financial dashboard',
        'intro': isFr
            ? 'Ensemble des indicateurs financiers consolides disponibles via SIGMA API.'
            : 'All available consolidated financial indicators via SIGMA API.',
        'rows': data.financialMatrix
            .take(10)
            .map((item) => {
                  'metric': item.label,
                  'value': item.value,
                  'assessment': item.assessment,
                })
            .toList(),
      });
    }

    // Recent news
    if (data.companyNews.isNotEmpty) {
      appendixSections.add({
        'id': 'recent_news',
        'title': isFr ? 'Actualites recentes' : 'Recent news',
        'intro': isFr
            ? 'Dernieres publications selectionnees pour leur pertinence institutionnelle.'
            : 'Latest publications selected for institutional relevance.',
        'rows': data.companyNews
            .take(6)
            .map((n) => {
                  'date': n.publishedAt,
                  'source': n.source,
                  'headline': n.title,
                  'url': n.url,
                })
            .toList(),
      });
    }

    // ── Assemble final payload ───────────────────────────────────────────────

    return {
      'symbol': data.ticker,
      'company_name': data.companyName,
      'generated_at': DateTime.now().toIso8601String(),
      'language': isFr ? 'fr' : 'en',
      'schema_version': '2.0',

      // 1. Hook — strong opening sentence
      'hook': hook,

      // 2. Executive summary — 3 insight-driven points max
      'executive_summary': {
        'rating': data.verdict,
        'sigma_score': num_('sigma_score', data.sigmaScore, 'score'),
        'confidence': num_('confidence', data.confidence * 100, '%'),
        'price': num_('current_price', currentPrice, 'USD'),
        'target':
            num_('target_price', targetPrice, 'USD', trend: trend_(upside)),
        'upside': num_('upside', upside, '%', trend: trend_(upside)),
        'points': execPoints.take(3).toList(),
      },

      // 3. Key charts — each answers a specific question
      'key_charts': keyCharts,

      // 4. Key tables — compact, each preceded by intro sentence
      'key_tables': keyTables,

      // 5. Analysis sections — insight titles, 2-3 sentence paragraphs
      'analysis_sections': analysisSections,

      // 6. Risks — with severity and invalidation triggers
      'risks': {
        'level': data.riskLevel,
        'level_tone': severity_(data.riskLevel),
        'items': riskItems,
        'invalidation_triggers': invalidationTriggers,
      },

      // 7. Appendix — secondary data moved out of main read
      'appendix': {
        'title': isFr ? 'Deep Dive' : 'Deep Dive',
        'sections': appendixSections,
      },

      // 8. UI hints for Flutter renderer
      'ui_hints': {
        'mobile_scroll_order': [
          'hook',
          'executive_summary',
          'key_charts',
          'key_tables',
          'analysis_sections',
          'risks',
          'appendix',
        ],
        'density': 'premium_editorial',
        'card_style': 'ghost_border',
        'chart_style': 'institutional_monochrome',
        'typography': 'lora_serif',
        'accent_color': 'gold',
        'highlight_tone_map': {
          'positive': 'emerald',
          'negative': 'crimson',
          'neutral': 'slate',
        },
      },

      'quality_flags': qualityFlags,
    };
  }

  String _formatReportValue(double value, String unit) {
    if (unit == 'USD') return _formatLargeNumber(value);
    if (unit == '%') return '${value.toStringAsFixed(1)}%';
    if (unit == 'x') return '${value.toStringAsFixed(2)}x';
    if (unit == 'score') return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  /// Builds a compact options-flow summary string for the AI prompt.
  String _buildOptionsContext(Map<String, dynamic> options) {
    if (options.isEmpty) return 'N/A';

    final calls = (options['calls'] as List?) ?? [];
    final puts = (options['puts'] as List?) ?? [];
    final expiry = options['selectedExpiration']?.toString() ?? '';

    if (calls.isEmpty && puts.isEmpty) return 'N/A';

    // Total open interest
    double callOI = 0, putOI = 0, callVol = 0, putVol = 0;
    double ivSum = 0;
    int ivCount = 0;

    for (final c in calls) {
      if (c is! Map) continue;
      callOI += (c['openInterest'] as num? ?? 0).toDouble();
      callVol += (c['volume'] as num? ?? 0).toDouble();
      final iv = (c['impliedVolatility'] as num?)?.toDouble() ?? 0;
      if (iv > 0) {
        ivSum += iv;
        ivCount++;
      }
    }
    for (final p in puts) {
      if (p is! Map) continue;
      putOI += (p['openInterest'] as num? ?? 0).toDouble();
      putVol += (p['volume'] as num? ?? 0).toDouble();
    }

    final pcRatio = callOI > 0 ? (putOI / callOI) : 0.0;
    final avgIV = ivCount > 0 ? (ivSum / ivCount * 100) : 0.0;
    final sentiment = pcRatio > 1.2
        ? 'BEARISH (put/call > 1.2)'
        : pcRatio < 0.7
            ? 'BULLISH (put/call < 0.7)'
            : 'NEUTRAL';

    // Top call strikes by OI
    final sortedCalls = [...calls];
    sortedCalls.sort((a, b) => ((b as Map)['openInterest'] as num? ?? 0)
        .compareTo((a as Map)['openInterest'] as num? ?? 0));
    final topCalls = sortedCalls
        .take(3)
        .map((c) =>
            '\$${(c as Map)['strike']} (OI:${c['openInterest']}, IV:${((c['impliedVolatility'] as num? ?? 0) * 100).toStringAsFixed(0)}%)')
        .join(', ');

    final sortedPuts = [...puts];
    sortedPuts.sort((a, b) => ((b as Map)['openInterest'] as num? ?? 0)
        .compareTo((a as Map)['openInterest'] as num? ?? 0));
    final topPuts = sortedPuts
        .take(3)
        .map((c) => '\$${(c as Map)['strike']} (OI:${c['openInterest']})')
        .join(', ');

    return '''Expiry: $expiry | Put/Call OI: ${pcRatio.toStringAsFixed(2)} → $sentiment
Avg IV: ${avgIV.toStringAsFixed(0)}% | Call Vol: ${callVol.toInt()} | Put Vol: ${putVol.toInt()}
Top Calls (OI): $topCalls
Top Puts (OI): $topPuts''';
  }

  /// Formats SEC/EDGAR derived metrics + top annual facts for the AI prompt.
  String _buildSecContext(
      Map<String, dynamic> derived, Map<String, dynamic> facts) {
    if (derived.isEmpty && facts.isEmpty) return 'N/A';

    final latest =
        (derived['latest_values'] as Map?)?.cast<String, dynamic>() ?? {};
    final rev = latest['revenue'];
    final ni = latest['net_income'];
    final assets = latest['total_assets'];
    final equity = latest['stockholders_equity'];
    final shares = latest['shares_outstanding'];

    final revGrowth = derived['revenue_yoy_growth_pct'];
    final niGrowth = derived['net_income_yoy_growth_pct'];
    final opMargin = derived['operating_margin_pct'];
    final netMargin = derived['net_margin_pct'];
    final debtEq = derived['debt_to_equity'];

    String fmt(dynamic v) {
      if (v == null) return 'N/A';
      final n = (v as num).abs();
      final sign = (v as num) < 0 ? '-' : '';
      if (n >= 1e9) return '$sign\$${(n / 1e9).toStringAsFixed(2)}B';
      if (n >= 1e6) return '$sign\$${(n / 1e6).toStringAsFixed(1)}M';
      return '$sign\$${n.toStringAsFixed(0)}';
    }

    // Last 3 annual revenue for trend
    final revAnnual = (facts['revenue']?['annual'] as List?)
            ?.take(3)
            .map((e) =>
                '${(e as Map)['end']?.toString().substring(0, 4)}: ${fmt(e['value'])}')
            .join(' | ') ??
        '';

    return '''SEC EDGAR FUNDAMENTALS:
Revenue: ${fmt(rev)} (YoY: ${revGrowth?.toStringAsFixed(1) ?? 'N/A'}%) | Net Income: ${fmt(ni)} (YoY: ${niGrowth?.toStringAsFixed(1) ?? 'N/A'}%)
Operating Margin: ${opMargin?.toStringAsFixed(1) ?? 'N/A'}% | Net Margin: ${netMargin?.toStringAsFixed(1) ?? 'N/A'}%
Total Assets: ${fmt(assets)} | Equity: ${fmt(equity)} | Debt/Equity: ${debtEq?.toStringAsFixed(3) ?? 'N/A'}
Shares Outstanding: ${shares != null ? (shares as num) ~/ 1 : 'N/A'}
Annual Revenue Trend: $revAnnual''';
  }

  /// Picks key fields from a raw yfinance income statement entry.
  Map<String, dynamic> _pickFinancialFields(Map e) => {
        'date': e['index'],
        'revenue': e['Total Revenue'],
        'grossProfit': e['Gross Profit'],
        'operatingIncome': e['Operating Income'],
        'netIncome': e['Net Income'],
        'ebitda': e['EBITDA'],
        'eps': e['Diluted EPS'],
        'rd': e['Research And Development'],
        'sga': e['Selling General And Administration'],
      };

  /// Picks key fields from a raw yfinance balance sheet entry.
  Map<String, dynamic> _pickBalanceFields(Map e) => {
        'date': e['index'],
        'totalAssets': e['Total Assets'],
        'totalLiabilities': e['Total Liabilities Net Minority Interest'],
        'equity': e['Stockholders Equity'],
        'workingCapital': e['Working Capital'],
        'cash': e['Cash And Cash Equivalents'],
        'totalDebt': e['Total Debt'],
        'retainedEarnings': e['Retained Earnings'],
      };

  /// Picks key fields from a raw yfinance cash flow entry.
  Map<String, dynamic> _pickCashFlowFields(Map e) => {
        'date': e['index'],
        'operatingCashFlow': e['Operating Cash Flow'],
        'freeCashFlow': e['Free Cash Flow'],
        'capex': e['Capital Expenditure'],
        'investingCashFlow': e['Investing Cash Flow'],
        'financingCashFlow': e['Financing Cash Flow'],
        'stockBasedComp': e['Stock Based Compensation'],
      };

  /// Formats full quarterly + annual financials for the AI prompt.
  String _buildFinancialsContext(
    List<dynamic> qIncome,
    List<dynamic> aIncome,
    List<dynamic> qBalance,
    List<dynamic> qCashFlow,
  ) {
    String fmt(dynamic v) {
      if (v == null) return 'N/A';
      final n = (v as num).abs();
      final sign = (v as num) < 0 ? '-' : '';
      if (n >= 1e9) return '$sign\$${(n / 1e9).toStringAsFixed(2)}B';
      if (n >= 1e6) return '$sign\$${(n / 1e6).toStringAsFixed(1)}M';
      return '$sign\$${n.toStringAsFixed(0)}';
    }

    final lines = <String>[];

    // Last 4 quarterly income
    if (qIncome.isNotEmpty) {
      lines.add('QUARTERLY INCOME (last 4):');
      for (final e in qIncome.whereType<Map>().take(4)) {
        final d = (e['index'] as String?)?.substring(0, 10) ?? '?';
        lines.add(
            '  $d | Rev: ${fmt(e['Total Revenue'])} | GP: ${fmt(e['Gross Profit'])} | OpInc: ${fmt(e['Operating Income'])} | NI: ${fmt(e['Net Income'])} | EPS: ${e['Diluted EPS'] ?? 'N/A'} | R&D: ${fmt(e['Research And Development'])}');
      }
    }

    // Last 3 annual income
    if (aIncome.isNotEmpty) {
      lines.add('ANNUAL INCOME (last 3):');
      for (final e in aIncome.whereType<Map>().take(3)) {
        final d = (e['index'] as String?)?.substring(0, 10) ?? '?';
        lines.add(
            '  $d | Rev: ${fmt(e['Total Revenue'])} | EBITDA: ${fmt(e['EBITDA'])} | NI: ${fmt(e['Net Income'])} | EPS: ${e['Diluted EPS'] ?? 'N/A'}');
      }
    }

    // Latest quarterly balance sheet
    if (qBalance.isNotEmpty && qBalance.first is Map) {
      final b = qBalance.first as Map;
      final d = (b['index'] as String?)?.substring(0, 10) ?? '?';
      lines.add(
          'BALANCE SHEET ($d): Assets: ${fmt(b['Total Assets'])} | Liabilities: ${fmt(b['Total Liabilities Net Minority Interest'])} | Equity: ${fmt(b['Stockholders Equity'])} | Cash: ${fmt(b['Cash And Cash Equivalents'])} | Debt: ${fmt(b['Total Debt'])} | WC: ${fmt(b['Working Capital'])}');
    }

    // Latest quarterly cash flow
    if (qCashFlow.isNotEmpty && qCashFlow.first is Map) {
      final c = qCashFlow.first as Map;
      final d = (c['index'] as String?)?.substring(0, 10) ?? '?';
      lines.add(
          'CASH FLOW ($d): OCF: ${fmt(c['Operating Cash Flow'])} | FCF: ${fmt(c['Free Cash Flow'])} | Capex: ${fmt(c['Capital Expenditure'])} | SBC: ${fmt(c['Stock Based Compensation'])}');
    }

    return lines.join('\n');
  }

  /// Formats /profile data into a concise AI-readable summary.

  String _buildProfileContext(Map<String, dynamic> p) {
    if (p.isEmpty) return 'N/A';
    final mcap = p['marketCap'] as num?;
    final mcapStr = mcap == null
        ? 'N/A'
        : mcap >= 1e12
            ? '\$${(mcap / 1e12).toStringAsFixed(2)}T'
            : mcap >= 1e9
                ? '\$${(mcap / 1e9).toStringAsFixed(2)}B'
                : '\$${(mcap / 1e6).toStringAsFixed(0)}M';
    return '''Company: ${p['companyName'] ?? 'N/A'} | Exchange: ${p['exchange'] ?? 'N/A'} | Employees: ${p['fullTimeEmployees'] ?? 'N/A'}
Sector: ${p['sector'] ?? 'N/A'} | Industry: ${p['industry'] ?? 'N/A'} | CEO: ${p['ceo'] ?? 'N/A'}
Price: \$${p['price'] ?? 'N/A'} | Change: ${p['changePercent'] != null ? '${(p['changePercent'] as num).toStringAsFixed(2)}%' : 'N/A'} | Volume: ${p['volume'] ?? 'N/A'}
MarketCap: $mcapStr | PE: ${p['pe'] ?? 'N/A'} | EPS: ${p['eps'] ?? 'N/A'} | Beta: ${p['beta'] ?? 'N/A'}
52W High: \$${p['fiftyTwoWeekHigh'] ?? 'N/A'} | 52W Low: \$${p['fiftyTwoWeekLow'] ?? 'N/A'} | Dividend Yield: ${p['dividendYield'] ?? 'N/A'}
Website: ${p['website'] ?? 'N/A'}
Description: ${(p['description'] as String? ?? '').length > 400 ? (p['description'] as String).substring(0, 400) + '...' : p['description'] ?? 'N/A'}''';
  }

  String _buildInsiderContext(
      Map<String, dynamic> summary, List<dynamic> trades) {
    final buf = StringBuffer();
    if (summary.isNotEmpty) {
      final sentiment = summary['sentiment'] ?? 'N/A';
      final buyCount = summary['buy_count'] ?? 0;
      final sellCount = summary['sell_count'] ?? 0;
      final netValue = summary['net_value_usd'] as num?;
      final netStr = netValue == null
          ? 'N/A'
          : netValue >= 0
              ? '+\$${(netValue / 1e6).toStringAsFixed(1)}M'
              : '-\$${(netValue.abs() / 1e6).toStringAsFixed(1)}M';
      buf.writeln(
          'Insider Sentiment: $sentiment | Buys: $buyCount | Sells: $sellCount | Net: $netStr');
      final topInsiders = (summary['top_insiders'] as List?)?.take(3) ?? [];
      for (final ti in topInsiders) {
        if (ti is Map) {
          buf.writeln(
              '  Top Insider: ${ti['insider_name']} (${ti['title']}) — \$${((ti['total_value'] as num?)?.abs() ?? 0) ~/ 1000}K over ${ti['trade_count']} trades');
        }
      }
    }
    for (final t in trades.take(8)) {
      if (t is! Map) continue;
      final name =
          t['insider_name'] ?? t['ownerName'] ?? t['reportingName'] ?? 'N/A';
      final type = t['transaction_type'] ?? t['transactionType'] ?? 'N/A';
      final value = (t['value'] as num?)?.abs();
      final valStr =
          value == null ? '' : ' \$${(value / 1e3).toStringAsFixed(0)}K';
      final date = t['trade_date'] ?? t['transactionDate'] ?? '';
      buf.writeln('  $date | $name | $type$valStr');
    }
    return _limitTokens(buf.toString(), 1500);
  }

  String _buildTechnicalContext(List<Map<String, dynamic>> ohlcv) {
    if (ohlcv.length < 5) return 'N/A';

    final overlays = ChartOverlayEngine.compute(ohlcv);
    final closes =
        ohlcv.map((e) => (e['close'] as num?)?.toDouble() ?? 0.0).toList();
    final volumes =
        ohlcv.map((e) => (e['volume'] as num?)?.toDouble() ?? 0.0).toList();
    final lastClose = closes.last;
    final firstClose = closes.first;
    final pctChange =
        firstClose > 0 ? ((lastClose - firstClose) / firstClose * 100) : 0.0;

    // Price momentum: recent 5d vs previous 5d
    final last5Avg = closes.length >= 5
        ? closes.sublist(closes.length - 5).reduce((a, b) => a + b) / 5
        : lastClose;
    final prev5Avg = closes.length >= 10
        ? closes
                .sublist(closes.length - 10, closes.length - 5)
                .reduce((a, b) => a + b) /
            5
        : lastClose;
    final shortMomentum =
        prev5Avg > 0 ? ((last5Avg - prev5Avg) / prev5Avg * 100) : 0.0;

    // Avg volume last 20 bars vs previous 20
    final recentVolAvg = volumes.length >= 20
        ? volumes.sublist(volumes.length - 20).reduce((a, b) => a + b) / 20
        : volumes.last;
    final prevVolAvg = volumes.length >= 40
        ? volumes
                .sublist(volumes.length - 40, volumes.length - 20)
                .reduce((a, b) => a + b) /
            20
        : recentVolAvg;
    final volRatio = prevVolAvg > 0 ? recentVolAvg / prevVolAvg : 1.0;

    // SMA positions
    final sma50Last =
        overlays.sma50.lastWhere((v) => v != null, orElse: () => null);
    final sma200Last =
        overlays.sma200.lastWhere((v) => v != null, orElse: () => null);

    // RSI
    final rsiLast =
        overlays.rsi.lastWhere((v) => v != null, orElse: () => null);
    String rsiSignal = 'N/A';
    if (rsiLast != null) {
      if (rsiLast >= 70)
        rsiSignal = 'Overbought (${rsiLast.toStringAsFixed(1)})';
      else if (rsiLast <= 30)
        rsiSignal = 'Oversold (${rsiLast.toStringAsFixed(1)})';
      else
        rsiSignal = '${rsiLast.toStringAsFixed(1)} (Neutral)';
    }

    // MACD
    final macdHist = overlays.latestMacdHist;
    final macdSignal = macdHist == null
        ? 'N/A'
        : macdHist > 0
            ? 'Bullish (hist: ${macdHist.toStringAsFixed(3)})'
            : 'Bearish (hist: ${macdHist.toStringAsFixed(3)})';

    // Recent cross events (last 2)
    final recentCrosses = overlays.crossEvents.reversed.take(2).map((c) {
      final type = c.isGolden ? 'Golden Cross' : 'Death Cross';
      final strength = c.isStrong ? 'CONFIRMED' : 'weak';
      return '$type @ \$${c.price.toStringAsFixed(2)} ($strength${c.macdConfirmed ? ', MACD' : ''}${c.obvConfirmed ? ', OBV' : ''})';
    }).join('; ');

    final buf = StringBuffer();
    buf.writeln(
        'Period: ${ohlcv.length} sessions | Range: \$${firstClose.toStringAsFixed(2)} → \$${lastClose.toStringAsFixed(2)} (${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(1)}%)');
    buf.writeln(
        'Regime: ${overlays.regime} | Short momentum (5d): ${shortMomentum >= 0 ? '+' : ''}${shortMomentum.toStringAsFixed(1)}%');
    buf.writeln('RSI(14): $rsiSignal | MACD: $macdSignal');
    buf.writeln(
        'OBV: ${overlays.isObvBullish ? "Bullish (accumulation)" : "Bearish (distribution)"}');
    if (sma50Last != null)
      buf.writeln(
          'SMA${overlays.fastPeriod}: \$${sma50Last.toStringAsFixed(2)} (price ${lastClose > sma50Last ? "ABOVE ▲" : "BELOW ▼"})');
    if (sma200Last != null)
      buf.writeln(
          'SMA${overlays.slowPeriod}: \$${sma200Last.toStringAsFixed(2)} (price ${lastClose > sma200Last ? "ABOVE ▲" : "BELOW ▼"})');
    buf.writeln(
        'Volume trend: ${volRatio >= 1.1 ? "Expanding (${volRatio.toStringAsFixed(1)}x avg)" : volRatio <= 0.9 ? "Contracting (${volRatio.toStringAsFixed(1)}x avg)" : "Normal"}');
    if (recentCrosses.isNotEmpty) buf.writeln('Cross events: $recentCrosses');

    // High/Low 52w equivalent (full window)
    final high = closes.reduce(math.max);
    final low = closes.reduce(math.min);
    buf.writeln(
        'Period High: \$${high.toStringAsFixed(2)} | Period Low: \$${low.toStringAsFixed(2)} | Position: ${((lastClose - low) / (high - low) * 100).toStringAsFixed(0)}% of range');

    return buf.toString();
  }
}
