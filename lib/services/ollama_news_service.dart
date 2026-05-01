import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/ai_config.dart';
import 'ai_provider_factory.dart';
import 'ai_provider_interface.dart';
import 'ai/fallback_provider.dart';

class NewsIntelligenceService {
  static NewsIntelligenceService? _instance;
  final AIProvider _provider;

  static void reset() {
    _instance = null;
    dev.log('🗑️ NewsIntelligenceService instance reset', name: 'NewsIntelligenceService');
  }

  NewsIntelligenceService._(this._provider);

  static NewsIntelligenceService? tryCreate() {
    if (_instance != null) return _instance;

    final primaryChoice = (dotenv.env['PRIMARY_AI_PROVIDER'] ?? 'nvidia').toLowerCase();
    final marketModel = dotenv.env['MARKET_MODEL'] ?? AIConfig.defaultMarketModel;
    final nvKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
    final ollamaKey = dotenv.env['OLLAMA_API_KEY'] ?? '';

    final List<String> priorityChain =
        primaryChoice == 'ollama' ? ['ollama', 'nvidia'] : ['nvidia', 'ollama'];

    final List<AIProvider> chain = [];

    for (var p in priorityChain) {
      if (p == 'nvidia' && nvKey.isNotEmpty && !nvKey.contains('example')) {
        chain.add(AIProviderFactory.createMarketProvider(
          provider: AIConfig.providerNvidia,
          apiKey: nvKey,
          modelKey: marketModel,
        ));
      }

      if (p == 'ollama' && ollamaKey.isNotEmpty) {
        final model = dotenv.env['OLLAMA_NEWS_MODEL'] ?? dotenv.env['OLLAMA_MODEL'] ?? '';
        if (model.isNotEmpty) {
          chain.add(AIProviderFactory.createStockProvider(
            provider: AIConfig.providerOllama,
            apiKey: ollamaKey,
            modelKey: model,
            baseUrlOverride: dotenv.env['OLLAMA_BASE_URL'] ?? AIConfig.ollamaBaseUrl,
          ));
        }
      }
    }

    if (chain.isNotEmpty) {
      _instance = NewsIntelligenceService._(FallbackProvider(chain));
      return _instance;
    }

    return null;
  }

  Future<MarketIntelligence> analyzeMarketNews({
    required List<Map<String, String>> news,
    required String date,
    double vix = 0,
    double sp500Change = 0,
    String language = 'EN',
  }) async {
    if (news.isEmpty) {
      return MarketIntelligence.empty(date);
    }

    final isFr = language.toUpperCase() == 'FR';
    final langInstruction = isFr
        ? 'TU DOIS RÉPONDRE ENTIÈREMENT EN FRANÇAIS. '
          'Le champ "brief" doit être un résumé exécutif en français. '
          'CHAQUE "insight" dans "enrichedNews" DOIT ÊTRE UNE ANALYSE STRATÉGIQUE DE 3 LIGNES EN FRANÇAIS expliquant précisément l\'élément à en tirer.'
          'Les "keyThemes", "hotSectors", "riskAlerts" et "opportunities" doivent être en français. '
          'Les valeurs de "sentiment" restent BULLISH/BEARISH/NEUTRAL, '
          '"importance" reste HIGH/MEDIUM/LOW, et "regime" reste RISK-ON/RISK-OFF.'
        : 'Write all text fields in English.';

    final newsContext = news
        .take(10)
        .map((n) => '• [${n['source']}] ${n['title']} (${n['ticker'] ?? ''})')
        .join('\n');

    final newsCount = news.take(10).length;

    final prompt = '''
Today: $date
VIX: ${vix > 0 ? vix.toStringAsFixed(1) : 'N/A'}
S&P 500 Change: ${sp500Change != 0 ? '${sp500Change.toStringAsFixed(2)}%' : 'N/A'}

RECENT MARKET NEWS:
$newsContext

Provide a comprehensive market intelligence brief in JSON format.
Analyze ALL $newsCount news items above and output ONLY valid JSON.

CRITICAL RULES:
1. ZERO DUPLICATION: Never repeat the same point in 'brief' and 'enrichedNews'.
2. LENGTH LIMIT: Brief must be MAX 60 WORDS. 'insight' for news must be a dense summary of MAX 30 WORDS.
3. LISTS: For any numbered list (1, 2, 3...) or bullet points inside text, YOU MUST use clear line breaks (\\n) for each item.

JSON STRUCTURE:
{
  "brief": "${isFr ? 'Résumé exécutif dense de MAX 60 MOTS.' : 'Dense executive summary of MAX 60 WORDS.'}",
  "regime": "RISK-ON or RISK-OFF",
  "keyThemes": ["theme1", "theme2"],
  "hotSectors": ["sector1", "sector2"],
  "riskAlerts": ["alert1", "alert2"],
  "opportunities": ["opp1"],
  "enrichedNews": [
    {
      "title": "original title",
      "sentiment": "BULLISH or BEARISH or NEUTRAL",
      "importance": "HIGH or MEDIUM or LOW",
      "tickers": ["AAPL"],
      "insight": "${isFr ? 'EXPLICATION STRATÉGIQUE EN 3 LIGNES (FR).' : 'Strategic AI insight of MAX 30 WORDS.'}"
    }
  ]
}
''';

    try {
      final response = await _provider
          .generateContent(
            prompt: prompt,
            systemInstruction:
                'You are a senior sell-side market intelligence analyst. '
                'CRITICAL: TODAY IS APRIL 11, 2026. '
                '$langInstruction '
                'Institutional style. No repetitions. Max 6 lines per summary. '
                'Always respond with valid JSON only.',
            jsonMode: true,
            useThinking: false,
          )
          .timeout(const Duration(seconds: 60));

      return _parseIntelligence(response, news, date);
    } catch (e) {
      return MarketIntelligence.empty(date);
    }
  }

  MarketIntelligence _parseIntelligence(
    String raw,
    List<Map<String, String>> originalNews,
    String date,
  ) {
    try {
      String cleaned = raw.trim();
      cleaned = cleaned.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
      cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
      cleaned = cleaned.replaceAll(RegExp(r'\s*```\s*$', multiLine: true), '');
      
      final firstBrace = cleaned.indexOf('{');
      if (firstBrace > 0) cleaned = cleaned.substring(firstBrace);
      
      final Map<String, dynamic> data = jsonDecode(cleaned);
      final enrichedRaw = data['enrichedNews'] as List? ?? [];
      final enriched = <EnrichedNewsItem>[];

      for (int i = 0; i < originalNews.length && i < enrichedRaw.length; i++) {
        final original = originalNews[i];
        final ai = enrichedRaw[i];
        enriched.add(EnrichedNewsItem(
          title: original['title'] ?? '',
          source: original['source'] ?? '',
          url: original['url'] ?? '',
          ticker: original['ticker'] ?? '',
          sentiment: ai['sentiment']?.toString() ?? 'NEUTRAL',
          importance: ai['importance']?.toString() ?? 'MEDIUM',
          tickers: List<String>.from(ai['tickers'] ?? []),
          insight: ai['insight']?.toString() ?? '',
          publishedAt: original['publishedAt'] ?? '',
        ));
      }

      return MarketIntelligence(
        date: date,
        brief: data['brief']?.toString() ?? '',
        regime: data['regime']?.toString() ?? 'NEUTRAL',
        keyThemes: List<String>.from(data['keyThemes'] ?? []),
        hotSectors: List<String>.from(data['hotSectors'] ?? []),
        riskAlerts: List<String>.from(data['riskAlerts'] ?? []),
        opportunities: List<String>.from(data['opportunities'] ?? []),
        enrichedNews: enriched,
      );
    } catch (e) {
      return MarketIntelligence.empty(date);
    }
  }
}

class MarketIntelligence {
  final String date;
  final String brief;
  final String regime;
  final List<String> keyThemes;
  final List<String> hotSectors;
  final List<String> riskAlerts;
  final List<String> opportunities;
  final List<EnrichedNewsItem> enrichedNews;

  const MarketIntelligence({
    required this.date,
    required this.brief,
    required this.regime,
    required this.keyThemes,
    required this.hotSectors,
    required this.riskAlerts,
    required this.opportunities,
    required this.enrichedNews,
  });

  factory MarketIntelligence.empty(String date) => MarketIntelligence(
        date: date,
        brief: '',
        regime: 'NEUTRAL',
        keyThemes: [],
        hotSectors: [],
        riskAlerts: [],
        opportunities: [],
        enrichedNews: [],
      );

  bool get hasInsights => brief.isNotEmpty || keyThemes.isNotEmpty;
}

class EnrichedNewsItem {
  final String title;
  final String source;
  final String url;
  final String ticker;
  final String sentiment;
  final String importance;
  final List<String> tickers;
  final String insight;
  final String publishedAt;

  const EnrichedNewsItem({
    required this.title,
    required this.source,
    required this.url,
    required this.ticker,
    required this.sentiment,
    required this.importance,
    required this.tickers,
    required this.insight,
    this.publishedAt = '',
  });
}
