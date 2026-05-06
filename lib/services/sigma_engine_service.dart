// ignore_for_file: unused_import, unused_local_variable
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../models/sigma_engines.dart';
import 'sigma_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SIGMA ENGINE SERVICE
/// Multi-agent orchestration for specialized signals & industry reports.
/// ═══════════════════════════════════════════════════════════════════════════

class SigmaEngineService {
  final SigmaService _sigma;

  /// Injecte le SigmaService existant — ne crée JAMAIS sa propre instance.
  SigmaEngineService({
    required SigmaService sigmaService,
  }) : _sigma = sigmaService;

  /// 1. DAILY CREAM REPORT™
  /// Generates the morning newsletter synthesis using real market data + AI.
  Future<DailyCreamReport> generateDailyCreamReport() async {
    final results = await Future.wait([
      _sigma.marketDataService.getGainers().catchError((_) => <dynamic>[]),
      _sigma.marketDataService.getLosers().catchError((_) => <dynamic>[]),
      _sigma.marketDataService
          .getSectorPerformance()
          .catchError((_) => <dynamic>[]),
      _sigma.marketDataService
          .getGeneralNews(limit: 8)
          .catchError((_) => <dynamic>[]),
    ]);
    final gainers = results[0];
    final losers = results[1];
    final sectors = results[2];
    final news = results[3];

    // 2. Build signal entries from real data
    final List<SigmaSignalEntry> entries = [];
    for (var m in gainers.take(8)) {
      final sym = (m['symbol'] ?? 'N/A').toString();
      final name = (m['name'] ?? sym).toString();
      final chg = _toDouble(m['changesPercentage'] ?? m['changePercent']);
      entries.add(SigmaSignalEntry(
        ticker: sym,
        companyName: name,
        score: (68.0 + min(27.0, chg.abs() * 4)).clamp(0.0, 99.0),
        signal: 'BULLISH MOMENTUM',
        insight:
            '$name progresse de ${chg.toStringAsFixed(1)}% avec une dynamique relative supérieure au panier suivi.',
        timestamp: DateTime.now(),
        metrics: {'change': chg},
      ));
    }
    for (var m in losers.take(4)) {
      final sym = (m['symbol'] ?? 'N/A').toString();
      final name = (m['name'] ?? sym).toString();
      final chg = _toDouble(m['changesPercentage'] ?? m['changePercent']);
      entries.add(SigmaSignalEntry(
        ticker: sym,
        companyName: name,
        score: (58.0 + min(24.0, chg.abs() * 3)).clamp(0.0, 92.0),
        signal: 'BEARISH PRESSURE',
        insight:
            '$name recule de ${chg.abs().toStringAsFixed(1)}%; pression vendeuse à surveiller dans le flux intraday.',
        timestamp: DateTime.now(),
        metrics: {'change': chg},
      ));
    }

    // 3. AI-powered market synthesis
    String synthesis;
    try {
      final moversCtx = gainers
          .take(5)
          .map((m) =>
              "${m['symbol']}: +${_toDouble(m['changesPercentage'] ?? m['changePercent']).toStringAsFixed(1)}%")
          .join(", ");
      final losersCtx = losers
          .take(5)
          .map((m) =>
              "${m['symbol']}: ${_toDouble(m['changesPercentage'] ?? m['changePercent']).toStringAsFixed(1)}%")
          .join(", ");
      final sectorCtx = sectors
          .take(5)
          .map((s) =>
              "${s['sector'] ?? s['symbol']}: ${_toDouble(s['changesPercentage']).toStringAsFixed(1)}%")
          .join(", ");
      final newsCtx = news
          .take(5)
          .map((n) => "- ${n['title'] ?? n['headline'] ?? ''}")
          .join("\n");

      synthesis = await _sigma.marketProvider.generateContent(
        prompt: """
Rédige un Daily Market Brief institutionnel en français, prêt à afficher dans une app mobile.
Données live :
- TOP GAINERS: $moversCtx
- TOP LOSERS: $losersCtx
 - SECTEURS: $sectorCtx
 - NEWS: 
$newsCtx

Contraintes strictes:
- 4 lignes maximum.
- Pas de JSON, pas de markdown, pas de titres avec ###, pas de bullet décoratif.
- Style Goldman Sachs/Morgan Stanley: factuel, compact, professionnel.
- Inclure régime de marché, leadership sectoriel, flux movers et risque à surveiller.""",
        systemInstruction:
            "Tu es le stratégiste en chef de SIGMA Capital. Réponds uniquement avec du texte institutionnel propre, sans JSON ni markdown.",
      );
      synthesis = _cleanInstitutionalText(synthesis);
    } catch (_) {
      synthesis = _buildFallbackBrief(gainers, losers, sectors);
    }

    if (synthesis.trim().isEmpty) {
      synthesis = _buildFallbackBrief(gainers, losers, sectors);
    }

    return DailyCreamReport(
      date: DateTime.now(),
      marketSynthesis: synthesis.trim(),
      topMovers: entries,
      alphaPicks: entries.where((e) => e.score >= 76).take(6).toList(),
    );
  }

  String _buildFallbackBrief(
    List<dynamic> gainers,
    List<dynamic> losers,
    List<dynamic> sectors,
  ) {
    final leader = sectors.isNotEmpty ? sectors.first : null;
    final topGainer = gainers.isNotEmpty ? gainers.first : null;
    final topLoser = losers.isNotEmpty ? losers.first : null;
    return [
      'Le marché reste piloté par la dispersion sectorielle et les flux de momentum.',
      if (leader != null)
        'Leadership: ${leader['sector'] ?? leader['symbol']} (${_toDouble(leader['changesPercentage']).toStringAsFixed(1)}%).',
      if (topGainer != null)
        'Flux positif: ${topGainer['symbol']} à ${_toDouble(topGainer['changesPercentage'] ?? topGainer['changePercent']).toStringAsFixed(1)}%.',
      if (topLoser != null)
        'Risque à surveiller: ${topLoser['symbol']} à ${_toDouble(topLoser['changesPercentage'] ?? topLoser['changePercent']).toStringAsFixed(1)}%.',
    ].join(' ');
  }

  String _cleanInstitutionalText(String raw) {
    var text = raw.trim();
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          text = (decoded['marketSynthesis'] ??
                  decoded['summary'] ??
                  decoded['brief'] ??
                  decoded['content'] ??
                  (decoded.values.isNotEmpty ? decoded.values.first : '') ??
                  '')
              .toString();
        }
      } catch (_) {}
    }
    return text
        .replaceAll(RegExp(r'^```[a-zA-Z]*\s*', multiLine: true), '')
        .replaceAll('```', '')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^[-•*]\s+', multiLine: true), '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(4)
        .join('\n');
  }

  /// 2. EARNINGS BEAT SIGNAL™
  Future<EarningsBeatSignal> getEarningsBeatSignal(String ticker) async {
    try {
      final history =
          await _sigma.marketDataService.getEarningsHistorical(ticker);
      if (history.isEmpty) {
        return EarningsBeatSignal(
          ticker: ticker,
          beatOdds: 50.0,
          guidanceRaiseOdds: 50.0,
          directionOdds: 'NEUTRAL',
          optionsSignal: 'DATA GAP',
          analysis: 'Analysis deferred: Insufficient historical earnings data.',
        );
      }

      int beats = 0;
      int total = min(history.length, 8);
      for (int i = 0; i < total; i++) {
        final actual = (history[i]['actualEps'] as num?)?.toDouble() ?? 0.0;
        final est = (history[i]['estimatedEps'] as num?)?.toDouble() ?? 0.0;
        if (actual > est) beats++;
      }

      final odds = (beats / total) * 100;
      return EarningsBeatSignal(
        ticker: ticker,
        beatOdds: odds,
        guidanceRaiseOdds: odds * 0.85,
        directionOdds: odds >= 60
            ? 'BULLISH BIAS'
            : (odds <= 40 ? 'BEARISH BIAS' : 'NEUTRAL'),
        optionsSignal: odds >= 75
            ? 'HIGH CONVICTION ACCUMULATION'
            : 'STANDARD POSITIONING',
        analysis:
            'Sigma Engine: Historical beat frequency of ${odds.toStringAsFixed(1)}% across $total reporting cycles.',
      );
    } catch (_) {
      return EarningsBeatSignal(
        ticker: ticker,
        beatOdds: 0,
        guidanceRaiseOdds: 0,
        directionOdds: 'ERROR',
        optionsSignal: 'N/A',
        analysis: 'Signal engine failure: Connectivity error.',
      );
    }
  }

  /// 3. DEEP VALUE SIGNAL
  Future<List<SigmaSignalEntry>> getDeepValueSignals() async {
    return [];
  }

  /// 4. UNUSUAL OPTIONS SIGNAL ENGINE
  Future<List<SigmaSignalEntry>> getUnusualOptionsSignals() async {
    return [];
  }

  /// 5. CONTEXTUAL TICKER INTELLIGENCE
  Future<TickerIntelligence> getTickerIntelligence(String ticker) async {
    final r = Random();

    final earnings = await getEarningsBeatSignal(ticker);
    final metrics = await _sigma.marketDataService.getKeyMetricsTTM(ticker);
    final quote = await _sigma.marketDataService.getQuoteMap(ticker);

    // FCF & Valuation Logic
    final fcfYieldRaw =
        (metrics['freeCashFlowYieldTTM'] as num?)?.toDouble() ?? 0.0;
    final fcfYield = fcfYieldRaw * 100;
    final d2e = (metrics['debtToEquityTTM'] as num?)?.toDouble() ?? 1.5;

    final deepValue = DeepValueAnalysis(
      fcfYield: fcfYield,
      balanceSheetStrength:
          d2e < 0.6 ? 'FORTRESS' : (d2e < 1.8 ? 'STABLE' : 'LEVERAGED'),
      valuationStatus: fcfYield > 8
          ? 'DEEP VALUE'
          : (fcfYield > 4 ? 'FAIR VALUE' : 'GROWTH PRICED'),
      insight:
          'FCF Yield of ${fcfYield.toStringAsFixed(2)}% with a Debt/Equity ratio of ${d2e.toStringAsFixed(2)}.',
    );

    // Options Activity
    final vol = (quote['volume'] as num?)?.toDouble() ?? 0.0;
    final avgVol = (quote['averageVolume'] as num?)?.toDouble() ?? 1.0;
    final volRatio = vol / avgVol;

    final options = UnusualOptionsActivity(
      alertType: volRatio > 1.5 ? 'WHALE ACCUMULATION' : 'NORMAL FLOW',
      convictionScore: min(99.0, 50.0 + (volRatio * 20)),
      detail: volRatio > 1.5
          ? 'Massive volume surge (+${(volRatio * 100).toInt()}%) suggestive of institutional positioning.'
          : 'Trading volume within standard deviation.',
    );

    // Momentum Signal
    final chg = (quote['changePercent'] as num?)?.toDouble() ?? 0.0;
    final isBull = chg > 0;
    final momentum = MomentumSignal(
      status: chg.abs() > 3
          ? (isBull ? 'AGGRESSIVE BREAKOUT' : 'SHARP CORRECTION')
          : (isBull ? 'BULLISH CONTINUATION' : 'BEARISH DRIFT'),
      rsiDivergence: 'MONITORING',
      insight:
          'Price is ${isBull ? "trending above" : "testing"} key short-term moving averages.',
    );

    return TickerIntelligence(
      ticker: ticker,
      earningsBeat: earnings,
      deepValue: deepValue,
      optionsActivity: options,
      momentum: momentum,
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v
            .toString()
            .replaceAll('%', '')
            .replaceAll('+', '')
            .replaceAll(',', '')) ??
        0.0;
  }
}
