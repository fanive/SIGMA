// ignore_for_file: prefer_interpolation_to_compose_strings, unused_local_variable
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/sigma_models.dart';
import '../config/ai_config.dart';
import 'ai_provider_factory.dart';
import 'ai_provider_interface.dart';
import 'ai/fallback_provider.dart';
import 'sigma_api_service.dart';

/// ========================================================================
/// SIGMA Financial Report Service
/// ========================================================================
/// Génère des rapports de recherche financière professionnels (style sell-side)
/// inspirés des standards Goldman Sachs, Morgan Stanley, JPMorgan.
///
/// Framework de rapport :
/// 1. EXECUTIVE SUMMARY (Investment thesis + verdict)
/// 2. COMPANY OVERVIEW (Business model, segments, compétiteurs)
/// 3. INVESTMENT THESIS (Bull / Bear case)
/// 4. FINANCIAL ANALYSIS (P/E, Revenue, Marges, FCF, bilan)
/// 5. VALUATION (DCF simplifié, Price Target)
/// 6. RISK FACTORS (risques haussiers et baissiers)
/// 7. CATALYSTS (événements à surveiller)
/// 8. RECOMMENDATION (notation + objectif de cours)
/// ========================================================================
class FinancialReportService {
  final AIProvider _provider;

  FinancialReportService._(this._provider);

  String get providerName => _provider.providerName;
  String get modelName => _provider.modelName;

  factory FinancialReportService.fromEnv() {
    final primaryChoice = (dotenv.env['PRIMARY_AI_PROVIDER'] ?? 'nvidia').toLowerCase();

    final nvidiaKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
    final ollamaKey = dotenv.env['OLLAMA_API_KEY'] ?? '';
    final stockModel = dotenv.env['STOCK_MODEL'] ?? AIConfig.defaultStockModel;
    final reportModelOverride = dotenv.env['NVIDIA_REPORT_MODEL'];

    final List<AIProvider> chain = [];

    final List<String> priorityChain =
        primaryChoice == 'ollama' ? ['ollama', 'nvidia'] : ['nvidia', 'ollama'];

    for (var p in priorityChain) {
      if (p == 'nvidia' && nvidiaKey.isNotEmpty) {
        chain.add(AIProviderFactory.createStockProvider(
          provider: AIConfig.providerNvidia,
          apiKey: nvidiaKey,
          modelKey: reportModelOverride ?? stockModel,
        ));
      } else if (p == 'ollama' && ollamaKey.isNotEmpty) {
        final reportModel = dotenv.env['OLLAMA_REPORT_MODEL'] ?? dotenv.env['OLLAMA_MODEL'] ?? '';
        if (reportModel.isNotEmpty) {
          chain.add(AIProviderFactory.createStockProvider(
            provider: AIConfig.providerOllama,
            apiKey: ollamaKey,
            modelKey: reportModel,
            baseUrlOverride: dotenv.env['OLLAMA_BASE_URL'] ?? AIConfig.ollamaBaseUrl,
          ));
        }
      }
    }

    if (chain.isEmpty) {
      // Fallback ultime sur Ollama MiniMax
      return FinancialReportService._(AIProviderFactory.createStockProvider(
        provider: AIConfig.providerOllama,
        apiKey: ollamaKey,
        modelKey: 'minimax-m2.7:cloud',
      ));
    }

    return FinancialReportService._(FallbackProvider(chain));
  }

  static String _buildSystemPrompt(String language) {
    final langDirective = language == 'fr'
        ? 'LANGUE : Rédige l\'INTÉGRALITÉ du rapport EN FRANÇAIS. '
          'Chaque section, chaque phrase, chaque titre doit être en français.'
        : 'LANGUAGE: Write the ENTIRE report in English.';

    return '''
ROLE: Senior Equity Research Analyst (Goldman Sachs / Morgan Stanley level).
MANDATE: Generate a concise, data-driven institutional research report JSON.
STYLE: Professional, objective, data-driven. No filler. No hype.
RULES:
  - Return ONLY valid JSON. No text outside the JSON.
  - No markdown, no emojis inside field values.
  - Be concise: 1-2 sentences per narrative field.
  - Numbers: use institutional format (e.g., 12.5B, +4.5%, 2026-Q1).
$langDirective
''';
  }

  // =========================================================================
  // MÉTHODE PRINCIPALE : Génère un rapport complet
  // =========================================================================
  Future<FinancialReport> generateReport({
    required AnalysisData analysis,
    String language = 'fr',
  }) async {
    final ticker = analysis.ticker;
    dev.log('Generating financial report for $ticker...', name: 'FinancialReportService');

    final contextPrompt = _buildContextPrompt(analysis, language);

    try {
      // Direct call with timeout and internal fallback
      final rawContent = await _provider
          .generateContent(
            prompt: contextPrompt,
            systemInstruction: _buildSystemPrompt(language),
            jsonMode: true,
            useThinking: false, // For SPEED, the report doesn't need thinking trace
          )
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () => throw TimeoutException('Primary provider timed out.'),
          );

      final report = _parseReport(rawContent, analysis);
      await _syncPeerPrices(report);
      return report;
    } catch (e) {
      dev.log('Primary Report generation error: $e. Strategic Fallback initiated...', name: 'FinancialReportService');
      
      // HIGH SPEED INSTITUTIONAL FALLBACK (MiniMax)
      try {
        final fallbackProvider = AIProviderFactory.createStockProvider(
          provider: AIConfig.providerOllama,
          apiKey: dotenv.env['OLLAMA_API_KEY'] ?? '',
          modelKey: 'minimax-m2.7:cloud',
        );
        
        final fallbackContent = await fallbackProvider.generateContent(
          prompt: contextPrompt,
          systemInstruction: _buildSystemPrompt(language),
          jsonMode: true,
          useThinking: false, // Thinking not needed for reports
        ).timeout(const Duration(seconds: 90));
        
        final fallbackReport = _parseReport(fallbackContent, analysis);
        await _syncPeerPrices(fallbackReport);
        return fallbackReport;
      } catch (f) {
        dev.log('Total report failure: $f', name: 'FinancialReportService');
        rethrow;
      }
    }
  }

  /// Version streaming du rapport pour une réactivité instantanée
  Stream<String> streamReport({
    required AnalysisData analysis,
    String language = 'fr',
  }) {
    final ticker = analysis.ticker;
    final contextPrompt = _buildContextPrompt(analysis, language);
    
    final langDirective = language == 'fr'
        ? 'LANGUE : Rédige l\'INTÉGRALITÉ du rapport EN FRANÇAIS. '
        : 'LANGUAGE: Write the ENTIRE report in English.';

    final systemPrompt = '''
ROLE : You are a Senior Equity Research Analyst.
MANDATE : Generate a deep institutional financial report for $ticker.
STYLE : "Quiet Luxury" - Professional, sophisticated.
FORMATTING : USE MARKDOWN (headers ###, bold, bullet points). 
STREAMING : You are being streamed live. Start immediately with the Executive Summary.
STRICT RULE: DO NOT OUTPUT JSON. OUTPUT MARKDOWN TEXT ONLY.
$langDirective
''';
    
    return _provider.generateStream(
      prompt: contextPrompt,
      systemInstruction: systemPrompt,
      jsonMode: false,
    );
  }

  // =========================================================================
  // Construction du prompt contextualisé avec les données financières réelles
  // =========================================================================
  String _buildContextPrompt(AnalysisData analysis, String language) {
    final ticker = analysis.ticker;
    final company = analysis.companyName ?? ticker;
    final price = analysis.price;
    final verdict = analysis.verdict;
    final score = analysis.sigmaScore.toInt();
    final sector = analysis.sector ?? 'Technology';
    final industry = analysis.industry ?? '';
    final summary = analysis.summary;
    final riskLevel = analysis.riskLevel;
    final targetPrice = analysis.targetPriceValue;

    // Données financières clés
    final financials = analysis.financialMatrix
        .map((f) => '  - ${f.label}: ${f.value}')
        .join('\n');

    // Ratios analystes
    final analystRec = analysis.analystRecommendations;
    final analystConsensus =
        '${analystRec.consensusLabel} | Buy: ${analystRec.strongBuy + analystRec.buy} '
        '| Hold: ${analystRec.hold} | Sell: ${analystRec.sell + analystRec.strongSell}';

    // Catalyseurs
    final catalysts = analysis.catalysts
        .map((c) => '  • [${c.date}] ${c.event} (impact: ${c.impact})')
        .join('\n');

    // Risques
    final cons = analysis.cons.map((c) => '  • ${c.text}').join('\n');
    final pros = analysis.pros.map((p) => '  • ${p.text}').join('\n');

    // Signaux techniques
    final techSignals = analysis.technicalAnalysis
        .take(5)
        .map((t) => '  - ${t.indicator}: ${t.value} → ${t.interpretation}')
        .join('\n');

    // Données historiques réelles (Revenus & Earnings)
    final historicalData = (analysis.historicalEarnings ?? [])
        .take(4)
        .map((e) {
          final date = e['date']?.toString().split('-')[0] ?? 'N/A';
          final rev = (e['revenue'] ?? 0) / 1e9; // En Billions
          final earn = (e['netIncome'] ?? 0) / 1e9; // En Billions
          return '  - Year $date: Revenue \$${rev.toStringAsFixed(2)}B, Net Income \$${earn.toStringAsFixed(2)}B';
        })
        .join('\n');

    final langInstruction = language == 'fr'
        ? 'Write the ENTIRE JSON in French.'
        : 'Write the ENTIRE JSON in English.';

    return '''$langInstruction

Generate a concise institutional equity research JSON for $company ($ticker).
Current Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}

===== MARKET DATA =====
Ticker: $ticker | Company: $company | Price: $price
Sector: $sector | Industry: $industry
SIGMA Score: $score/100 | Verdict: $verdict | Risk: $riskLevel
${targetPrice != null ? 'SIGMA Price Target: \$$targetPrice' : ''}

===== HISTORICAL PERFORMANCE (ACTUALS) =====
$historicalData

===== KEY FINANCIALS =====
$financials

===== BULL/BEAR =====
Pros: $pros
Cons: $cons

===== WEB INTELLIGENCE =====
${analysis.webIntelligence ?? "N/A"}

===== ANALYSTS =====
$analystConsensus

===== TECHNICALS =====
$techSignals

===== RAW INSTITUTIONAL DATA (SEEKING ALPHA, MBOUM, ALPHA VANTAGE) =====
${analysis.rawInstitutionalData != null ? (analysis.rawInstitutionalData!.length > 4000 ? analysis.rawInstitutionalData!.substring(0, 4000) : analysis.rawInstitutionalData!) : "N/A"}

===== OUTPUT: STRICT VALID JSON ONLY — NO TEXT OUTSIDE JSON — NO MARKDOWN INSIDE VALUES =====
IMPORTANT: "historical_financials" MUST contain the EXACT values from "HISTORICAL PERFORMANCE (ACTUALS)" provided above. Use Billions (\$) as unit.
IMPORTANT: "valuation_table" MUST be BASE on actual historical growth and current price of $price.
IMPORTANT: "price_target" MUST be your OWN calculated fair-value estimate based on the data above. Do NOT copy the example value. Analyze financials, growth, comps, and risk to derive a realistic target.
{
  "rating": "BUY or SELL or HOLD",
  "price_target": 0.0,
  "executive_summary": "1-2 sentence thesis.",
  "company_overview": "2-3 sentence business description: what the company does, key segments, and competitive position.",
  "kpis": [
    {"label": "P/E Ratio", "value": "25.4", "trend": "up"},
    {"label": "Gross Margin", "value": "45%", "trend": "stable"},
    {"label": "Revenue Growth", "value": "12%", "trend": "up"},
    {"label": "Debt/Equity", "value": "0.8", "trend": "down"}
  ],
  "analyst_consensus": {"strong_buy": 8, "buy": 12, "hold": 5, "sell": 2, "strong_sell": 0},
  "historical_financials": {
    "revenue": [
      {"period": "2022", "value": 10.5},
      {"period": "2023", "value": 12.0},
      {"period": "2024", "value": 14.5}
    ],
    "earnings": [
      {"period": "2022", "value": 1.2},
      {"period": "2023", "value": 1.5},
      {"period": "2024", "value": 2.1}
    ]
  },
  "valuation_table": {
    "columns": ["Scenario", "Revenue (B)", "EPS", "Target"],
    "rows": [
      ["Bear", "...", "...", "..."],
      ["Base", "...", "...", "..."],
      ["Bull", "...", "...", "..."]
    ]
  },
  "risk_factors": ["Risk 1...", "Risk 2..."],
  "decision_reasoning": "1-2 sentence final rating rationale.",
  "confidence_score": 85,
  "bull_case": ["Catalyst 1...", "Catalyst 2..."],
  "bear_case": ["Headwind 1...", "Risk 2..."],
  "catalysts": ["Event 1...", "Event 2..."],
  "sector_peers": [
    {"ticker": "MSFT", "name": "Microsoft Corp", "price": "420.50", "verdict": "BUY"},
    {"ticker": "GOOG", "name": "Alphabet Inc", "price": "175.30", "verdict": "HOLD"}
  ],
  "ticker_image_url": "https://financialmodelingprep.com/image-stock/$ticker.png"
}
${language == 'fr' ? '\nLe JSON doit être intégralement en FRANÇAIS.' : ''}''';
  }


  // =========================================================================
  // Parse la réponse en FinancialReport structuré
  // =========================================================================
  FinancialReport _parseReport(String rawContent, AnalysisData analysis) {
    
    // Clean potential markdown blocks like ```json ... ```
    String cleanJson = rawContent;
    if (cleanJson.contains('```json')) {
      final startIndex = cleanJson.indexOf('```json') + 7;
      final endIndex = cleanJson.lastIndexOf('```');
      if (endIndex > startIndex) {
        cleanJson = cleanJson.substring(startIndex, endIndex);
      }
    }
    
    Map<String, dynamic> jsonContent = {};
    try {
      jsonContent = AnalysisData.parseMap(jsonDecode(cleanJson));
    } catch (e) {
      dev.log('Failed to parse JSON Report: $e', name: 'FinancialReportService');
    }

    return FinancialReport(
      ticker: analysis.ticker,
      companyName: analysis.companyName ?? analysis.ticker,
      generatedAt: DateTime.now(),
      rating: jsonContent['rating']?.toString().toUpperCase() ?? analysis.verdict,
      priceTarget: double.tryParse(jsonContent['price_target']?.toString() ?? '') ?? analysis.targetPriceValue,
      currentPrice: analysis.price,
      jsonContent: jsonContent,
      tickerImageUrl: jsonContent['ticker_image_url']?.toString(),
      providerName: _provider.providerName,
      modelName: _provider.modelName,
      confidenceScore: (jsonContent['confidence_score'] ?? 0).toDouble(),
    );
  }

  /// Synchronise les prix des concurrents avec des données réelles
  Future<void> _syncPeerPrices(FinancialReport report) async {
    try {
      final peers = report.jsonContent['sector_peers'] as List?;
      if (peers == null || peers.isEmpty) return;

      final List<String> tickers = [];
      for (var p in peers) {
        if (p is Map && p['ticker'] != null) {
          tickers.add(p['ticker'].toString().toUpperCase());
        }
      }

      if (tickers.isEmpty) return;

      final quotes = await SigmaApiService.getMultiQuote(tickers);
      final Map<String, String> priceMap = {};

      for (var q in quotes) {
        final sym = q['symbol']?.toString().toUpperCase();
        final price = q['price'];
        if (sym != null && price != null) {
          priceMap[sym] = '\$${(price as num).toStringAsFixed(2)}';
        }
      }

      // Update the peers in jsonContent
      for (var p in peers) {
        if (p is Map) {
          final sym = p['ticker']?.toString().toUpperCase();
          if (sym != null && priceMap.containsKey(sym)) {
            // Use a mutable copy if necessary, but Dart Maps from jsonDecode are mutable
            p['price'] = priceMap[sym];
          }
        }
      }
    } catch (e) {
      dev.log('Peer price sync failed: $e', name: 'FinancialReportService');
    }
  }
}

// ============================================================================
// MODEL : Rapport financier structuré
// ============================================================================
class FinancialReport {
  final String ticker;
  final String companyName;
  final DateTime generatedAt;
  final String rating;        // BUY / HOLD / SELL
  final double? priceTarget;
  final String currentPrice;
  final Map<String, dynamic> jsonContent;
  final String? tickerImageUrl;
  final String providerName;
  final String modelName;
  final double confidenceScore;

  FinancialReport({
    required this.ticker,
    required this.companyName,
    required this.generatedAt,
    required this.rating,
    this.priceTarget,
    required this.currentPrice,
    required this.jsonContent,
    this.tickerImageUrl,
    required this.providerName,
    required this.modelName,
    required this.confidenceScore,
  });

  /// Extrait le texte brut (executive summary) pour l'affichage simplifié
  String get plainText => jsonContent['executive_summary']?.toString() ?? 'Rapport généré avec succès.';

  /// Titre du rapport formaté
  String get title =>
      'Research Report — $companyName ($ticker)';

  /// Date formatée
  String get dateFormatted =>
      '${generatedAt.day.toString().padLeft(2, '0')}/'
      '${generatedAt.month.toString().padLeft(2, '0')}/'
      '${generatedAt.year}';
}
