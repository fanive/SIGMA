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
/// GÃ©nÃ¨re des rapports de recherche financiÃ¨re professionnels (style sell-side)
/// inspirÃ©s des standards Goldman Sachs, Morgan Stanley, JPMorgan.
///
/// Framework de rapport :
/// 1. EXECUTIVE SUMMARY (Investment thesis + verdict)
/// 2. COMPANY OVERVIEW (Business model, segments, compÃ©titeurs)
/// 3. INVESTMENT THESIS (Bull / Bear case)
/// 4. FINANCIAL ANALYSIS (P/E, Revenue, Marges, FCF, bilan)
/// 5. VALUATION (DCF simplifiÃ©, Price Target)
/// 6. RISK FACTORS (risques haussiers et baissiers)
/// 7. CATALYSTS (Ã©vÃ©nements Ã  surveiller)
/// 8. RECOMMENDATION (notation + objectif de cours)
/// ========================================================================
class FinancialReportService {
  final AIProvider _provider;

  FinancialReportService._(this._provider);

  String get providerName => _provider.providerName;
  String get modelName => _provider.modelName;

  factory FinancialReportService.fromEnv() {
    final nvidiaKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
    final stockModel = dotenv.env['STOCK_MODEL'] ?? AIConfig.defaultStockModel;
    final reportModelOverride = dotenv.env['NVIDIA_REPORT_MODEL'];

    if (nvidiaKey.isEmpty || nvidiaKey.contains('example')) {
      throw StateError(
        'NVIDIA_API_KEY is required. Financial reports now use NVIDIA only.',
      );
    }

    return FinancialReportService._(
      AIProviderFactory.createStockProvider(
        provider: AIConfig.providerNvidia,
        apiKey: nvidiaKey,
        modelKey: reportModelOverride ?? stockModel,
      ),
    );
  }

  static String _buildSystemPrompt(String language) {
    final langDirective = language == 'fr'
        ? 'LANGUE : RÃ©dige l\'INTÃ‰GRALITÃ‰ du rapport EN FRANÃ‡AIS. '
          'Chaque section, chaque phrase, chaque titre doit Ãªtre en franÃ§ais.'
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
  // MÃ‰THODE PRINCIPALE : GÃ©nÃ¨re un rapport complet
  // =========================================================================
  Future<FinancialReport> generateReport({
    required AnalysisData analysis,
    String language = 'fr',
  }) async {
    final ticker = analysis.ticker;
    dev.log('Generating financial report for $ticker...', name: 'FinancialReportService');

    final endpointData = await _fetchEndpointData(ticker);
    final contextPrompt = _buildContextPrompt(analysis, language, endpointData);

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
            // 119B model takes ~50s just to start responding.
            // A full report (2000+ tokens) can take 2–3 min total.
            const Duration(seconds: 240),
            onTimeout: () => throw TimeoutException('Primary provider timed out.'),
          );

      final report = _parseReport(rawContent, analysis);
      _enrichReportWithEndpointData(report, analysis, endpointData);
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
        _enrichReportWithEndpointData(fallbackReport, analysis, endpointData);
        await _syncPeerPrices(fallbackReport);
        return fallbackReport;
      } catch (f) {
        dev.log('Total report failure: $f', name: 'FinancialReportService');
        rethrow;
      }
    }
  }

  /// Version streaming du rapport pour une rÃ©activitÃ© instantanÃ©e
  Stream<String> streamReport({
    required AnalysisData analysis,
    String language = 'fr',
  }) {
    final ticker = analysis.ticker;
    final contextPrompt = _buildContextPrompt(analysis, language, const {
      'snapshot': <String, dynamic>{},
      'analysis': <String, dynamic>{},
      'events': <String, dynamic>{},
      'ownership': <String, dynamic>{},
      'news': <Map<String, dynamic>>[],
      'financials': <String, dynamic>{},
      'logo': <String, dynamic>{},
    });
    
    final langDirective = language == 'fr'
        ? 'LANGUE : RÃ©dige l\'INTÃ‰GRALITÃ‰ du rapport EN FRANÃ‡AIS. '
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
  // Construction du prompt contextualisÃ© avec les donnÃ©es financiÃ¨res rÃ©elles
  // =========================================================================
  String _buildContextPrompt(
    AnalysisData analysis,
    String language,
    Map<String, dynamic> endpointData,
  ) {
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

    // DonnÃ©es financiÃ¨res clÃ©s
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
        .map((c) => '  â€¢ [${c.date}] ${c.event} (impact: ${c.impact})')
        .join('\n');

    // Risques
    final cons = analysis.cons.map((c) => '  â€¢ ${c.text}').join('\n');
    final pros = analysis.pros.map((p) => '  â€¢ ${p.text}').join('\n');

    // Signaux techniques
    final techSignals = analysis.technicalAnalysis
        .take(5)
        .map((t) => '  - ${t.indicator}: ${t.value} â†’ ${t.interpretation}')
        .join('\n');

    // â”€â”€ EXTENDED QUANTITATIVE DATA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final ks = analysis.keyStatistics;
    String fmtN(double? v) => (v == null || v == 0) ? 'N/A' : v.toStringAsFixed(2);
    String fmtPct(double? v) => (v == null || v == 0) ? 'N/A' : '${(v * 100).toStringAsFixed(1)}%';
    String fmtBn(double? v) => (v == null || v == 0) ? 'N/A' : '\$${(v / 1e9).toStringAsFixed(2)}B';

    final keyStatsBlock = ks != null ? [
      '  Market Cap: ${fmtBn(ks.marketCap)} | EV: ${fmtBn(ks.enterpriseValue)}',
      '  P/E (TTM): ${fmtN(ks.trailingPE)} | Fwd P/E: ${fmtN(ks.forwardPE)} | PEG: ${fmtN(ks.pegRatio)}',
      '  P/S: ${fmtN(ks.priceToSales)} | P/B: ${fmtN(ks.priceToBook)} | EV/EBITDA: ${fmtN(ks.enterpriseToEbitda)}',
      '  ROE: ${fmtPct(ks.returnOnEquity)} | ROA: ${fmtPct(ks.returnOnAssets)} | Net Margin: ${fmtPct(ks.profitMargins)}',
      '  Op. Margin: ${fmtPct(ks.operatingMargins)} | Earnings Growth (YoY): ${fmtPct(ks.earningsGrowth)} | Rev Growth: ${fmtPct(ks.revenueGrowth)}',
      '  Revenue: ${fmtBn(ks.revenue)} | FCF: ${fmtBn(ks.freeCashflow)} | Op CF: ${fmtBn(ks.operatingCashflow)}',
      '  Cash: ${fmtBn(ks.totalCash)} | Total Debt: ${fmtBn(ks.totalDebt)} | D/E: ${fmtN(ks.debtToEquity)}',
      '  Current Ratio: ${fmtN(ks.currentRatio)} | Quick Ratio: ${fmtN(ks.quickRatio)}',
      '  Beta: ${fmtN(ks.beta)} | Short %: ${fmtPct(ks.shortPercentOfFloat)} | Avg Vol: ${fmtN(ks.averageVolume)}',
      '  52W High: ${fmtN(ks.fiftyTwoWeekHigh)} | 52W Low: ${fmtN(ks.fiftyTwoWeekLow)}',
      '  50D MA: ${fmtN(ks.fiftyDayAverage)} | 200D MA: ${fmtN(ks.twoHundredDayAverage)}',
      '  EPS TTM: ${fmtN(ks.trailingEps)} | Fwd EPS: ${fmtN(ks.forwardEps)}',
      if (ks.dividendYield > 0) '  Dividend Yield: ${fmtPct(ks.dividendYield)} | Payout Ratio: ${fmtPct(ks.payoutRatio)}',
    ].join('\n') : '  N/A';

    // Insider transactions
    final insiderBuyPct = analysis.insiderBuyRatio != null
        ? '${(analysis.insiderBuyRatio! * 100).toStringAsFixed(1)}%'
        : 'N/A';
    final insiderLines = analysis.insiderTransactions.take(5).map((t) {
      final ch = double.tryParse(t.change.replaceAll(RegExp(r'[^\-\d.]'), '')) ?? 0;
      return '  - [${t.transactionDate}] ${t.name}: ${ch >= 0 ? "BUY" : "SELL"} ${t.change.replaceAll("-", "")} shares @ \$${t.transactionPrice}';
    }).join('\n');

    // Trade setup
    final tsSetup = analysis.tradeSetup;
    final tradeBlock =
        'Entry: ${tsSetup.cleanEntryZone} | Target: ${tsSetup.cleanTargetPrice} | Stop: ${tsSetup.cleanStopLoss} | R/R: ${tsSetup.riskRewardRatio}';

    // ESG
    final esgBlock = analysis.esgScore != null
        ? 'Score: ${analysis.esgScore!.toStringAsFixed(0)} | Controversy: ${analysis.controversyScore ?? "N/A"}'
        : 'N/A';

    // Earnings forward estimates
    final earnTrend = analysis.earningsTrend;
    String earnFwdBlock = 'N/A';
    if (earnTrend != null && earnTrend.isNotEmpty) {
      final trend0 = earnTrend['trend0'] as Map?;
      final period0 = earnTrend['period0']?.toString() ?? '';
      final epsEst0 = trend0?['earningsEstimate']?['avg']?.toString() ?? 'N/A';
      final revEst0 = trend0?['revenueEstimate']?['avg']?.toString() ?? 'N/A';
      earnFwdBlock = '  Next ($period0): EPS est. $epsEst0, Rev est. $revEst0';
      final trend1 = earnTrend['trend1'] as Map?;
      if (trend1 != null) {
        final period1 = earnTrend['period1']?.toString() ?? '';
        final epsEst1 = trend1['earningsEstimate']?['avg']?.toString() ?? 'N/A';
        final revEst1 = trend1['revenueEstimate']?['avg']?.toString() ?? 'N/A';
        earnFwdBlock += '\n  Following ($period1): EPS est. $epsEst1, Rev est. $revEst1';
      }
    }

    // Institutional holders top 5
    final topHoldersLines = ((analysis.institutionalHolders ?? []).take(5)).map((h) {
      final name = h['Holder'] ?? h['holder'] ?? h['name'] ?? 'Unknown';
      final pct = h['% Out'] ?? h['pHeld'] ?? h['pctHeld'] ?? '';
      final shares = h['Shares'] ?? h['shares'] ?? '';
      return '  - $name: $pct ($shares shares)';
    }).join('\n');

    // Volatility
    final vol = analysis.volatility;
    final volBlock = 'Beta: ${vol.beta} | IV Rank: ${vol.ivRank} | Regime: ${vol.interpretation}';

    final endpointFinancials =
      endpointData['financials'] as Map<String, dynamic>? ?? {};
    final endpointAnnualIncome =
      (endpointFinancials['annualIncomeStatement'] as List?) ?? [];

    // DonnÃ©es historiques rÃ©elles (Revenus & Earnings)
    final historicalData = (endpointAnnualIncome.isNotEmpty
        ? endpointAnnualIncome
        : (analysis.historicalEarnings ?? []))
      .take(4)
      .whereType<Map>()
      .map((e) {
        final row = Map<String, dynamic>.from(e);
        final rawDate = row['index'] ?? row['date'] ?? 'N/A';
        final date = rawDate.toString().split('-').first;
        final revenue = (row['TotalRevenue'] ?? row['revenue'] ?? 0) as num;
        final earnings =
          (row['NetIncome'] ?? row['NetIncomeLoss'] ?? row['netIncome'] ?? 0)
            as num;
        final rev = revenue / 1e9;
        final earn = earnings / 1e9;
        return '  - Year $date: Revenue \$${rev.toStringAsFixed(2)}B, Net Income \$${earn.toStringAsFixed(2)}B';
      })
      .join('\n');

      final endpointAddon = _buildEndpointPromptAddon(endpointData);

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

===== LIVE ENDPOINT PAYLOADS (GROUND TRUTH) =====
$endpointAddon

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

===== KEY STATISTICS (FUNDAMENTALS â€” USE FOR KPIs & VALUATION) =====
$keyStatsBlock

===== INSIDER TRANSACTIONS (BUY RATIO: $insiderBuyPct) =====
$insiderLines

===== TRADE SETUP =====
$tradeBlock

===== EARNINGS FORWARD ESTIMATES =====
$earnFwdBlock

===== INSTITUTIONAL TOP HOLDERS =====
$topHoldersLines

===== VOLATILITY & ESG =====
$volBlock
ESG: $esgBlock

===== RAW INSTITUTIONAL DATA (SEEKING ALPHA, MBOUM, ALPHA VANTAGE) =====
${analysis.rawInstitutionalData != null ? (analysis.rawInstitutionalData!.length > 4000 ? analysis.rawInstitutionalData!.substring(0, 4000) : analysis.rawInstitutionalData!) : "N/A"}

===== OUTPUT: STRICT VALID JSON ONLY â€” NO TEXT OUTSIDE JSON â€” NO MARKDOWN INSIDE VALUES =====
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
  "technical_indicators": [
    {"name": "RSI (14)", "value": "62.4", "signal": "NEUTRAL"},
    {"name": "MACD", "value": "+0.45", "signal": "BUY"},
    {"name": "50D MA vs 200D MA", "value": "ABOVE", "signal": "BULLISH"}
  ],
  "insider_activity": {
    "buy_ratio": 0.65,
    "net_direction": "ACCUMULATION",
    "summary": "Recent insider activity with net buying signal."
  },
  "trade_setup": {
    "entry": "entry zone from data",
    "target": "price target from analysis",
    "stop": "support level",
    "rr_ratio": "2.0:1"
  },
  "earnings_forward": {
    "next_eps_estimate": "2.45",
    "next_revenue_estimate": "95.2B",
    "next_date": "2025-Q2",
    "analyst_count": 15
  },
  "ownership_breakdown": {
    "institutional_pct": "72.4%",
    "insider_pct": "5.2%",
    "top_holders": [
      {"name": "Vanguard Group", "pct": "8.1%"},
      {"name": "BlackRock Inc", "pct": "7.3%"}
    ]
  },
  "esg_rating": {
    "score": 72,
    "controversy": 2,
    "label": "LOW RISK"
  },
  "ticker_image_url": "https://financialmodelingprep.com/image-stock/$ticker.png"
}
${language == 'fr' ? '\nLe JSON doit Ãªtre intÃ©gralement en FRANÃ‡AIS.' : ''}''';
  }

  Future<Map<String, dynamic>> _fetchEndpointData(String ticker) async {
    try {
      final results = await Future.wait([
        SigmaApiService.getSnapshot(ticker).catchError((_) => <String, dynamic>{}),
        SigmaApiService.getAnalysis(ticker).catchError((_) => <String, dynamic>{}),
        SigmaApiService.getEvents(ticker).catchError((_) => <String, dynamic>{}),
        SigmaApiService.getOwnership(ticker).catchError((_) => <String, dynamic>{}),
        SigmaApiService.getNews(ticker).catchError((_) => <Map<String, dynamic>>[]),
        SigmaApiService.getFinancials(ticker).catchError((_) => <String, dynamic>{}),
        SigmaApiService.getLogo(ticker).catchError((_) => <String, dynamic>{}),
      ]);

      return {
        'snapshot': results[0] as Map<String, dynamic>,
        'analysis': results[1] as Map<String, dynamic>,
        'events': results[2] as Map<String, dynamic>,
        'ownership': results[3] as Map<String, dynamic>,
        'news': results[4] as List<Map<String, dynamic>>,
        'financials': results[5] as Map<String, dynamic>,
        'logo': results[6] as Map<String, dynamic>,
      };
    } catch (e) {
      dev.log('Endpoint context fetch failed: $e', name: 'FinancialReportService');
      return {
        'snapshot': <String, dynamic>{},
        'analysis': <String, dynamic>{},
        'events': <String, dynamic>{},
        'ownership': <String, dynamic>{},
        'news': <Map<String, dynamic>>[],
        'financials': <String, dynamic>{},
        'logo': <String, dynamic>{},
      };
    }
  }

  String _buildEndpointPromptAddon(Map<String, dynamic> endpointData) {
    final snapshot = endpointData['snapshot'] as Map<String, dynamic>? ?? {};
    final analysis = endpointData['analysis'] as Map<String, dynamic>? ?? {};
    final events = endpointData['events'] as Map<String, dynamic>? ?? {};
    final ownership = endpointData['ownership'] as Map<String, dynamic>? ?? {};
    final news = endpointData['news'] as List? ?? [];
    final financials = endpointData['financials'] as Map<String, dynamic>? ?? {};

    final quote = (snapshot['quote'] as Map?)?.cast<String, dynamic>() ?? {};
    final target = (analysis['analystPriceTargets'] as Map?)?.cast<String, dynamic>() ?? {};
    final recs = (analysis['recommendations'] as List?) ?? [];
    final latestRec = recs.isNotEmpty && recs.first is Map
        ? Map<String, dynamic>.from(recs.first)
        : <String, dynamic>{};
    final calendar = (events['calendar'] as Map?)?.cast<String, dynamic>() ?? {};
    final inst = (ownership['institutionalHolders'] as List?) ?? [];
    final major = (ownership['majorHolders'] as List?) ?? [];
    final annualIncome = (financials['annualIncomeStatement'] as List?) ?? [];

    final newsLines = news.take(5).map((n) {
      final title = (n['title'] ?? '').toString();
      final date = (n['publishedAt'] ?? n['publishedDate'] ?? '').toString();
      return '  - [$date] $title';
    }).join('\n');

    final histLines = annualIncome.take(4).whereType<Map>().map((row) {
      final m = Map<String, dynamic>.from(row);
      final period = (m['index'] ?? '').toString();
      final revenue = m['TotalRevenue'] ?? m['revenue'];
      final net = m['NetIncome'] ?? m['NetIncomeLoss'] ?? m['netIncome'];
      return '  - $period | Revenue: $revenue | NetIncome: $net';
    }).join('\n');

    return '''
SNAPSHOT_QUOTE:
  price: ${quote['price'] ?? quote['lastPrice']}
  marketCap: ${quote['marketCap']}
  pe: ${quote['pe']}
  eps: ${quote['eps']}

ANALYST_TARGETS:
  current: ${target['current']}
  mean: ${target['mean']}
  high: ${target['high']}
  low: ${target['low']}

ANALYST_CONSENSUS_LATEST:
  strongBuy: ${latestRec['strongBuy']}
  buy: ${latestRec['buy']}
  hold: ${latestRec['hold']}
  sell: ${latestRec['sell']}
  strongSell: ${latestRec['strongSell']}

EVENTS_CALENDAR:
  earningsDate: ${calendar['Earnings Date']}
  earningsAvg: ${calendar['Earnings Average']}
  revenueAvg: ${calendar['Revenue Average']}
  dividendDate: ${calendar['Dividend Date']}

OWNERSHIP:
  institutionalCount: ${inst.length}
  majorHoldersRows: ${major.length}

LATEST_NEWS:
$newsLines

ANNUAL_FINANCIALS:
$histLines
''';
  }

  void _enrichReportWithEndpointData(
    FinancialReport report,
    AnalysisData analysis,
    Map<String, dynamic> endpointData,
  ) {
    final j = report.jsonContent;

    final snapshot = endpointData['snapshot'] as Map<String, dynamic>? ?? {};
    final quote = (snapshot['quote'] as Map?)?.cast<String, dynamic>() ??
        (snapshot['price'] is Map
            ? (snapshot['price'] as Map).cast<String, dynamic>()
            : <String, dynamic>{});

    final analysisData = endpointData['analysis'] as Map<String, dynamic>? ?? {};
    final target =
        (analysisData['analystPriceTargets'] as Map?)?.cast<String, dynamic>() ?? {};
    final recommendations = (analysisData['recommendations'] as List?) ?? [];
    final latestRec = recommendations.isNotEmpty && recommendations.first is Map
        ? Map<String, dynamic>.from(recommendations.first)
        : <String, dynamic>{};

    final events = endpointData['events'] as Map<String, dynamic>? ?? {};
    final calendar = (events['calendar'] as Map?)?.cast<String, dynamic>() ?? {};

    final news = endpointData['news'] as List<Map<String, dynamic>>? ?? [];
    final financials = endpointData['financials'] as Map<String, dynamic>? ?? {};
    final logo = endpointData['logo'] as Map<String, dynamic>? ?? {};

    // Ensure KPI strip is always populated from real endpoint values.
    final generatedKpis = [
      {
        'label': 'PRICE',
        'value': (quote['price'] ?? analysis.price).toString(),
        'trend': 'stable',
      },
      {
        'label': 'MARKET CAP',
        'value': (quote['marketCap'] ?? '').toString(),
        'trend': 'stable',
      },
      {
        'label': 'P/E',
        'value': (quote['pe'] ?? '').toString(),
        'trend': 'stable',
      },
      {
        'label': 'EPS',
        'value': (quote['eps'] ?? '').toString(),
        'trend': 'stable',
      },
    ].where((k) => (k['value'] ?? '').toString().isNotEmpty).toList();

    if ((j['kpis'] as List?) == null || (j['kpis'] as List).isEmpty) {
      j['kpis'] = generatedKpis;
    }

    // Always override analyst consensus with real endpoint data
    final hasRealConsensus = (latestRec['strongBuy'] ?? 0) != 0 ||
        (latestRec['buy'] ?? 0) != 0 ||
        (latestRec['hold'] ?? 0) != 0;
    if (hasRealConsensus || j['analyst_consensus'] == null ||
        (j['analyst_consensus'] is Map &&
            (j['analyst_consensus'] as Map).isEmpty)) {
      j['analyst_consensus'] = {
        'strong_buy': latestRec['strongBuy'] ?? 0,
        'buy': latestRec['buy'] ?? 0,
        'hold': latestRec['hold'] ?? 0,
        'sell': latestRec['sell'] ?? 0,
        'strong_sell': latestRec['strongSell'] ?? 0,
      };
    }

    // Historical financials from /financials endpoint always win when available.
    final annualIncome = (financials['annualIncomeStatement'] as List?) ?? [];
    final revenue = <Map<String, dynamic>>[];
    final earnings = <Map<String, dynamic>>[];
    for (final row in annualIncome.take(4)) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      final period = (m['index'] ?? m['date'] ?? '').toString();
      final year = period.isNotEmpty ? period.split('-').first : 'N/A';
      final rev = (m['TotalRevenue'] ?? m['revenue'] ?? 0) as num;
      final ni =
          (m['NetIncome'] ?? m['NetIncomeLoss'] ?? m['netIncome'] ?? 0) as num;
      revenue.add({'period': year, 'value': rev / 1e9});
      earnings.add({'period': year, 'value': ni / 1e9});
    }
    if (revenue.isNotEmpty || earnings.isNotEmpty) {
      j['historical_financials'] = {
        'revenue': revenue,
        'earnings': earnings,
      };
    }

    // Catalysts / risks grounded in endpoint events + news.
    if ((j['catalysts'] as List?) == null || (j['catalysts'] as List).isEmpty) {
      final catalysts = <String>[];
      final earningsDate = calendar['Earnings Date'];
      if (earningsDate != null) {
        catalysts.add('Upcoming earnings date: $earningsDate');
      }
      if (calendar['Dividend Date'] != null) {
        catalysts.add('Dividend date: ${calendar['Dividend Date']}');
      }
      for (final n in news.take(2)) {
        final title = (n['title'] ?? '').toString();
        if (title.isNotEmpty) catalysts.add(title);
      }
      if (catalysts.isNotEmpty) j['catalysts'] = catalysts;
    }

    if ((j['risk_factors'] as List?) == null || (j['risk_factors'] as List).isEmpty) {
      final risks = <String>[];
      final low = (target['low'] as num?)?.toDouble();
      final high = (target['high'] as num?)?.toDouble();
      if (low != null && high != null && high > 0) {
        final dispersion = ((high - low) / high) * 100;
        risks.add('Analyst target dispersion is ${dispersion.toStringAsFixed(1)}%, indicating valuation uncertainty.');
      }
      if ((latestRec['sell'] ?? 0) > 0 || (latestRec['strongSell'] ?? 0) > 0) {
        risks.add('Sell-side recommendations include active Sell/Strong Sell ratings.');
      }
      if (risks.isNotEmpty) j['risk_factors'] = risks;
    }

    // Ensure price target reflects endpoint target if model omitted it.
    if ((j['price_target'] == null || j['price_target'].toString().isEmpty) &&
        target['mean'] != null) {
      j['price_target'] = target['mean'];
    }

    // Always use real current price from endpoint
    if (quote['price'] != null) {
      j['current_price'] = quote['price'];
    } else if (j['current_price'] == null || j['current_price'].toString().isEmpty) {
      j['current_price'] = analysis.price;
    }

    // Ensure peers exist if analysis screen had them.
    if ((j['sector_peers'] as List?) == null || (j['sector_peers'] as List).isEmpty) {
      final peers = analysis.sectorPeers.take(6).map((p) => {
            'ticker': p.ticker,
            'name': p.name,
            'price': p.price,
            'verdict': p.verdict,
          }).toList();
      if (peers.isNotEmpty) j['sector_peers'] = peers;
    }

    // Logo from /logo endpoint if model response omitted it.
    final logoUrls = (logo['logoUrls'] as Map?)?.cast<String, dynamic>();
    final realLogoUrl =
        logo['logoUrl'] ?? logoUrls?['primary'] ?? logoUrls?['parqet'];
    if (realLogoUrl != null && realLogoUrl.toString().isNotEmpty) {
      j['ticker_image_url'] = realLogoUrl;
    }

    // â”€â”€ NEW SECTIONS: deterministic fill from AnalysisData â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    // Technical indicators from analysis.technicalAnalysis
    if ((j['technical_indicators'] as List?) == null ||
        (j['technical_indicators'] as List).isEmpty) {
      final techList = analysis.technicalAnalysis.take(8).map((t) => {
            'name': t.indicator,
            'value': t.value,
            'signal': t.interpretation,
          }).toList();
      if (techList.isNotEmpty) j['technical_indicators'] = techList;
    }

    // Insider activity
    if (j['insider_activity'] == null ||
        (j['insider_activity'] is Map &&
            (j['insider_activity'] as Map).isEmpty)) {
      final txns = analysis.insiderTransactions;
      if (txns.isNotEmpty || analysis.insiderBuyRatio != null) {
        final last = txns.isNotEmpty ? txns.first : null;
        String lastTxStr = '';
        if (last != null) {
          final ch = double.tryParse(
                  last.change.replaceAll(RegExp(r'[^\-\d.]'), '')) ??
              0;
          lastTxStr =
              '${last.name} ${ch >= 0 ? "bought" : "sold"} ${last.change.replaceAll("-", "")} shares @ \$${last.transactionPrice}';
        }
        final ratio = analysis.insiderBuyRatio ?? 0.5;
        j['insider_activity'] = {
          'buy_ratio': ratio,
          'net_direction': ratio >= 0.6
              ? 'ACCUMULATION'
              : (ratio <= 0.4 ? 'DISTRIBUTION' : 'NEUTRAL'),
          'summary': lastTxStr.isNotEmpty
              ? lastTxStr
              : 'No significant insider transactions.',
        };
      }
    }

    // Trade setup from analysis.tradeSetup
    if (j['trade_setup'] == null) {
      final ts = analysis.tradeSetup;
      if (ts.entryZone != 'N/A' || ts.targetPrice != 'N/A') {
        j['trade_setup'] = {
          'entry': ts.cleanEntryZone,
          'target': ts.cleanTargetPrice,
          'stop': ts.cleanStopLoss,
          'rr_ratio': ts.riskRewardRatio,
        };
      }
    }

    // Earnings forward estimates from analysis.earningsTrend
    if (j['earnings_forward'] == null) {
      final et = analysis.earningsTrend;
      if (et != null && et.isNotEmpty) {
        final trend0 = et['trend0'] as Map?;
        final period0 = et['period0']?.toString() ?? '';
        if (trend0 != null) {
          j['earnings_forward'] = {
            'next_eps_estimate':
                trend0['earningsEstimate']?['avg']?.toString() ?? 'N/A',
            'next_revenue_estimate':
                trend0['revenueEstimate']?['avg']?.toString() ?? 'N/A',
            'next_date': period0,
            'analyst_count':
                trend0['earningsEstimate']?['numberOfAnalysts'] ?? 0,
          };
        }
      }
    }

    // Ownership breakdown from analysis.holders + institutionalHolders
    if (j['ownership_breakdown'] == null) {
      final holdersData = analysis.holders;
      final instList = analysis.institutionalHolders ?? [];
      if (holdersData != null || instList.isNotEmpty) {
        final topList = instList.take(5).map((h) {
          final name =
              (h['Holder'] ?? h['holder'] ?? h['name'] ?? 'Unknown').toString();
          final pct =
              (h['% Out'] ?? h['pHeld'] ?? h['pctHeld'] ?? '').toString();
          return {'name': name, 'pct': pct};
        }).toList();
        // Also add from HoldersData.topInstitutions if available
        if (topList.isEmpty && holdersData != null) {
          for (final inst in holdersData.topInstitutions.take(5)) {
            topList.add({'name': inst.organization, 'pct': '${(inst.pctHeld * 100).toStringAsFixed(2)}%'});
          }
        }
        j['ownership_breakdown'] = {
          'institutional_pct': holdersData != null
              ? '${(holdersData.institutionsPercent * 100).toStringAsFixed(1)}%'
              : 'N/A',
          'insider_pct': holdersData != null
              ? '${(holdersData.insidersPercent * 100).toStringAsFixed(1)}%'
              : 'N/A',
          'institutions_count': holdersData?.institutionsCount ?? instList.length,
          'top_holders': topList,
        };
      }
    }

    // ESG rating
    if (j['esg_rating'] == null && analysis.esgScore != null) {
      final score = analysis.esgScore!;
      final controversy = analysis.controversyScore ?? 0;
      final label = score >= 70
          ? 'LOW RISK'
          : (score >= 50 ? 'MEDIUM RISK' : 'HIGH RISK');
      j['esg_rating'] = {
        'score': score.toInt(),
        'controversy': controversy,
        'label': label,
      };
    }

    // Always override KPIs with real KeyStatistics data when available
    // (AI-generated KPIs may use example values from the prompt template)
    if (analysis.keyStatistics != null) {
      final ks = analysis.keyStatistics!;
      String nv(double v) => v == 0 ? '-' : v.toStringAsFixed(2);
      String pv(double v) => v == 0 ? '-' : '${(v * 100).toStringAsFixed(1)}%';
      String bv(double v) => v == 0 ? '-' : '\$${(v / 1e9).toStringAsFixed(2)}B';
      final enrichedKpis = <Map<String, dynamic>>[
        if (ks.trailingPE > 0) {'label': 'P/E (TTM)', 'value': nv(ks.trailingPE), 'trend': 'stable'},
        if (ks.forwardPE > 0) {'label': 'P/E (Fwd)', 'value': nv(ks.forwardPE), 'trend': 'stable'},
        if (ks.pegRatio > 0) {'label': 'PEG Ratio', 'value': nv(ks.pegRatio), 'trend': 'stable'},
        if (ks.priceToBook > 0) {'label': 'P/B', 'value': nv(ks.priceToBook), 'trend': 'stable'},
        if (ks.enterpriseToEbitda > 0) {'label': 'EV/EBITDA', 'value': nv(ks.enterpriseToEbitda), 'trend': 'stable'},
        if (ks.profitMargins > 0) {'label': 'Net Margin', 'value': pv(ks.profitMargins), 'trend': 'up'},
        if (ks.operatingMargins > 0) {'label': 'Op. Margin', 'value': pv(ks.operatingMargins), 'trend': 'up'},
        if (ks.returnOnEquity > 0) {'label': 'ROE', 'value': pv(ks.returnOnEquity), 'trend': 'up'},
        if (ks.returnOnAssets > 0) {'label': 'ROA', 'value': pv(ks.returnOnAssets), 'trend': 'up'},
        if (ks.debtToEquity > 0) {'label': 'D/E Ratio', 'value': nv(ks.debtToEquity), 'trend': 'down'},
        if (ks.currentRatio > 0) {'label': 'Current Ratio', 'value': nv(ks.currentRatio), 'trend': 'up'},
        if (ks.revenueGrowth != 0) {'label': 'Rev Growth YoY', 'value': pv(ks.revenueGrowth), 'trend': ks.revenueGrowth > 0 ? 'up' : 'down'},
        if (ks.earningsGrowth != 0) {'label': 'EPS Growth YoY', 'value': pv(ks.earningsGrowth), 'trend': ks.earningsGrowth > 0 ? 'up' : 'down'},
        if (ks.freeCashflow != 0) {'label': 'Free Cash Flow', 'value': bv(ks.freeCashflow), 'trend': ks.freeCashflow > 0 ? 'up' : 'down'},
        if (ks.beta > 0) {'label': 'Beta', 'value': nv(ks.beta), 'trend': 'stable'},
        if (ks.dividendYield > 0) {'label': 'Div. Yield', 'value': pv(ks.dividendYield), 'trend': 'stable'},
        if (ks.shortPercentOfFloat > 0) {'label': 'Short Float %', 'value': pv(ks.shortPercentOfFloat), 'trend': 'stable'},
        if (ks.fiftyTwoWeekHigh > 0) {'label': '52W High', 'value': '\$${nv(ks.fiftyTwoWeekHigh)}', 'trend': 'stable'},
        if (ks.fiftyTwoWeekLow > 0) {'label': '52W Low', 'value': '\$${nv(ks.fiftyTwoWeekLow)}', 'trend': 'stable'},
      ];
      if (enrichedKpis.isNotEmpty) {
        j['kpis'] = enrichedKpis;
      }
    }
  }


  // =========================================================================
  // Parse la rÃ©ponse en FinancialReport structurÃ©
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
      currentPrice: jsonContent['current_price']?.toString() ?? analysis.price,
      jsonContent: jsonContent,
      tickerImageUrl: jsonContent['ticker_image_url']?.toString(),
      providerName: _provider.providerName,
      modelName: _provider.modelName,
      confidenceScore: (jsonContent['confidence_score'] ?? 0).toDouble(),
    );
  }

  /// Synchronise les prix des concurrents avec des donnÃ©es rÃ©elles
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
// MODEL : Rapport financier structurÃ©
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

  /// Extrait le texte brut (executive summary) pour l'affichage simplifiÃ©
  String get plainText => jsonContent['executive_summary']?.toString() ?? 'Rapport gÃ©nÃ©rÃ© avec succÃ¨s.';

  /// Titre du rapport formatÃ©
  String get title =>
      'Research Report â€” $companyName ($ticker)';

  /// Date formatÃ©e
  String get dateFormatted =>
      '${generatedAt.day.toString().padLeft(2, '0')}/'
      '${generatedAt.month.toString().padLeft(2, '0')}/'
      '${generatedAt.year}';
}

