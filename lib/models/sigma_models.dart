// ignore_for_file: avoid_print, unnecessary_this
import 'signal_models.dart';

enum SigmaTier {
  free, // Standard analysis, delayed news
  pro, // Agentic analysis, real-time news, deeper depth
  elite // Full multi-agent commitee, deep reasoning R1
}

class SigmaUser {
  final String id;
  final String email;
  final SigmaTier tier;
  final DateTime? subExpiry;

  SigmaUser({
    required this.id,
    required this.email,
    this.tier = SigmaTier.free,
    this.subExpiry,
  });

  bool get isPro => tier == SigmaTier.pro || tier == SigmaTier.elite;
  bool get isElite => tier == SigmaTier.elite;
}

// 📡 AGENTIC RADAR MODELS
class CatalystInsight {
  final String ticker;
  final String title;
  final String description;
  final double impactScore; // 0.0 to 1.0
  final bool isNegative;
  final String source;
  final DateTime timestamp;

  CatalystInsight({
    required this.ticker,
    required this.title,
    required this.description,
    required this.impactScore,
    required this.isNegative,
    required this.source,
    required this.timestamp,
  });

  factory CatalystInsight.fromJson(Map<String, dynamic> json) {
    return CatalystInsight(
      ticker: json['ticker'] ?? 'GLOBAL',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      impactScore: (json['impactScore'] ?? 0.0).toDouble(),
      isNegative: json['isNegative'] ?? false,
      source: json['source'] ?? 'Agentic Scan',
      timestamp: DateTime.now(),
    );
  }
}

class HiddenSignal {
  final String type; // BULL, BEAR, NEUTRAL
  final String headline;
  final String insight;
  final String date;
  final String? url;

  HiddenSignal({
    required this.type,
    required this.headline,
    required this.insight,
    required this.date,
    this.url,
  });

  factory HiddenSignal.fromJson(Map<String, dynamic> json) => HiddenSignal(
        type: json['type']?.toString() ?? 'NEUTRAL',
        headline: json['headline']?.toString() ?? '',
        insight: json['insight']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        url: json['url']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'headline': headline,
        'insight': insight,
        'date': date,
        'url': url,
      };
}

class NewsArticle {
  final String title;
  final String source;
  final String url;
  final String publishedAt;
  final String summary;
  final String? imageUrl;

  NewsArticle({
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.summary,
    this.imageUrl,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
        title: AnalysisData.parseString(json['title']),
        source: AnalysisData.parseString(json['source'] ?? json['publisher']),
        url: AnalysisData.parseString(json['url'] ?? json['link']),
        publishedAt:
            AnalysisData.parseString(json['publishedAt'] ?? json['time']),
        summary: AnalysisData.parseString(json['summary']),
        imageUrl: AnalysisData.parseString(json['imageUrl'] ?? json['image']),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'source': source,
        'url': url,
        'publishedAt': publishedAt,
        'summary': summary,
        'imageUrl': imageUrl,
      };
}

class NotableEvent {
  final String date;
  final String label;
  final double score;
  final bool curated;

  NotableEvent({
    required this.date,
    required this.label,
    required this.score,
    required this.curated,
  });

  factory NotableEvent.fromJson(Map<String, dynamic> json) {
    return NotableEvent(
      date: json['date']?.toString() ?? '',
      label: json['label'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      curated: json['curated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'label': label,
        'score': score,
        'curated': curated,
      };
}

class CorporateEvent {
  final String date;
  final String event; // Earnings, Dividend, Split, etc.
  final String description;

  CorporateEvent({
    required this.date,
    required this.event,
    required this.description,
  });

  factory CorporateEvent.fromJson(Map<String, dynamic> json) => CorporateEvent(
        date: json['date']?.toString() ?? '',
        event: json['event']?.toString() ?? '',
        description:
            json['description']?.toString() ?? json['impact']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'event': event,
        'description': description,
      };
}

class TradeSetup {
  final String entryZone;
  final String targetPrice;
  final String stopLoss;
  final String riskRewardRatio;

  TradeSetup({
    required this.entryZone,
    required this.targetPrice,
    required this.stopLoss,
    required this.riskRewardRatio,
  });

  /// Extrait uniquement les valeurs numériques/prix d'une chaîne
  /// Ex: "Entre $145.50 et $150.00" -> "$145.50 - $150.00"
  /// Ex: "$145.50" -> "$145.50"
  static String _extractPriceOnly(String input) {
    if (input.isEmpty || input == 'N/A') return input;

    // Pattern pour capturer les prix (avec $, €, ou juste des nombres)
    final pricePattern = RegExp(r'[\$€£]?\d+[,.]?\d*[MBK]?');
    final matches = pricePattern.allMatches(input).toList();

    if (matches.isEmpty) return input;

    // Si on a plusieurs prix, les joindre avec " - "
    final prices = matches.map((m) => m.group(0)!.trim()).toList();

    // Dédupliquer et joindre
    final uniquePrices = prices.toSet().toList();
    if (uniquePrices.length == 1) return uniquePrices.first;
    if (uniquePrices.length == 2) {
      return '${uniquePrices[0]} - ${uniquePrices[1]}';
    }
    return uniquePrices.take(2).join(' - ');
  }

  /// Getter pour la zone d'entrée nettoyée (prix uniquement)
  String get cleanEntryZone => _extractPriceOnly(entryZone);

  /// Getter pour le prix cible nettoyé
  String get cleanTargetPrice => _extractPriceOnly(targetPrice);

  /// Getter pour le stop loss nettoyé
  String get cleanStopLoss => _extractPriceOnly(stopLoss);

  factory TradeSetup.fromJson(Map<String, dynamic> json) => TradeSetup(
        entryZone: json['entryZone']?.toString() ??
            json['entrySignal']?.toString() ??
            'N/A',
        targetPrice: json['targetPrice']?.toString() ??
            json['profitTarget']?.toString() ??
            'N/A',
        stopLoss: json['stopLoss']?.toString() ?? 'N/A',
        riskRewardRatio: json['riskRewardRatio']?.toString() ??
            json['setupType']?.toString() ??
            'N/A',
      );

  Map<String, dynamic> toJson() => {
        'entryZone': entryZone,
        'targetPrice': targetPrice,
        'stopLoss': stopLoss,
        'riskRewardRatio': riskRewardRatio,
      };
}

class InsiderTransaction {
  final String name;
  final String share;
  final String change;
  final String filingDate;
  final String transactionDate;
  final String transactionPrice;

  InsiderTransaction({
    required this.name,
    required this.share,
    required this.change,
    required this.filingDate,
    required this.transactionDate,
    required this.transactionPrice,
  });

  factory InsiderTransaction.fromJson(Map<String, dynamic> json) =>
      InsiderTransaction(
        name: json['name']?.toString() ?? 'N/A',
        share: json['share']?.toString() ?? '0',
        change: json['change']?.toString() ?? '0',
        filingDate: json['filingDate']?.toString() ?? '',
        transactionDate: json['transactionDate']?.toString() ?? '',
        transactionPrice: json['transactionPrice']?.toString() ?? '0',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'share': share,
        'change': change,
        'filingDate': filingDate,
        'transactionDate': transactionDate,
        'transactionPrice': transactionPrice,
      };
}

class GlobalInsiderTrade {
  final String type; // buy/sell
  final String symbol;
  final String name;
  final String title;
  final int shares;
  final double price;
  final double value;
  final String date;
  final bool csuite;
  final List<String>
      labels; // OpenInsider Style: Cluster, Significant, C-Suite, etc.

  GlobalInsiderTrade({
    required this.type,
    required this.symbol,
    required this.name,
    required this.title,
    required this.shares,
    required this.price,
    required this.value,
    required this.date,
    required this.csuite,
    this.labels = const [],
  });

  factory GlobalInsiderTrade.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawLabels = json['labels'] ?? [];
    return GlobalInsiderTrade(
      type: json['type']?.toString().toLowerCase() ??
          (json['transactionType']?.toString().toLowerCase().contains('buy') ==
                  true
              ? 'buy'
              : 'sell'),
      symbol: json['symbol']?.toString() ?? json['ticker'] ?? 'N/A',
      name: json['name']?.toString() ?? json['reportingName'] ?? 'N/A',
      title: json['title']?.toString() ?? json['typeOfOwner'] ?? 'N/A',
      shares:
          AnalysisData.parseInt(json['shares'] ?? json['securitiesTransacted']),
      price: AnalysisData.parseNum(json['price'] ?? json['pricePerShare']),
      value: AnalysisData.parseNum(json['value'] ??
          (AnalysisData.parseNum(json['pricePerShare']) *
              AnalysisData.parseNum(json['securitiesTransacted']))),
      date: json['date']?.toString() ?? json['transactionDate'] ?? '',
      csuite: json['csuite'] ??
          _isCSuite(json['title'] ?? json['typeOfOwner'] ?? ''),
      labels: rawLabels.map((l) => l.toString()).toList(),
    );
  }

  static bool _isCSuite(String title) {
    final t = title.toUpperCase();
    return t.contains('CEO') ||
        t.contains('CFO') ||
        t.contains('COO') ||
        t.contains('PRESIDENT') ||
        t.contains('CHIEF');
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'symbol': symbol,
        'name': name,
        'title': title,
        'shares': shares,
        'price': price,
        'value': value,
        'date': date,
        'csuite': csuite,
        'labels': labels,
      };
}

class SocialSentimentData {
  final double redditSentiment;
  final double twitterSentiment;
  final int mentions;

  SocialSentimentData({
    required this.redditSentiment,
    required this.twitterSentiment,
    required this.mentions,
  });

  factory SocialSentimentData.fromJson(Map<String, dynamic> json) =>
      SocialSentimentData(
        redditSentiment: AnalysisData.parseNum(json['redditSentiment']),
        twitterSentiment: AnalysisData.parseNum(json['twitterSentiment']),
        mentions: (json['mentions'] as num? ?? 0).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'redditSentiment': redditSentiment,
        'twitterSentiment': twitterSentiment,
        'mentions': mentions,
      };
}

class InstitutionalActivity {
  final double smartMoneySentiment;
  final double retailSentiment;
  final String darkPoolInterpretation;

  InstitutionalActivity({
    required this.smartMoneySentiment,
    required this.retailSentiment,
    required this.darkPoolInterpretation,
  });

  factory InstitutionalActivity.fromJson(Map<String, dynamic> json) =>
      InstitutionalActivity(
        smartMoneySentiment: AnalysisData.parseNum(json['smartMoneySentiment']),
        retailSentiment: AnalysisData.parseNum(json['retailSentiment'] ?? 0.5),
        darkPoolInterpretation: json['darkPoolInterpretation']?.toString() ??
            json['netInstitutionalBuying']?.toString() ??
            '',
      );

  Map<String, dynamic> toJson() => {
        'smartMoneySentiment': smartMoneySentiment,
        'retailSentiment': retailSentiment,
        'darkPoolInterpretation': darkPoolInterpretation,
      };
}

class StockSentiment {
  final double score;
  final String label;
  final String interpretation;

  StockSentiment({
    required this.score,
    required this.label,
    required this.interpretation,
  });

  factory StockSentiment.fromJson(Map<String, dynamic> json) => StockSentiment(
        score: AnalysisData.parseNum(json['score']),
        label: json['label']?.toString() ?? json['rating']?.toString() ?? '',
        interpretation: json['interpretation']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'score': score,
        'label': label,
        'interpretation': interpretation,
      };
}

class MarketSentiment {
  final double score;
  final String label;
  final double? previousClose;

  MarketSentiment({
    required this.score,
    required this.label,
    this.previousClose,
  });

  factory MarketSentiment.fromJson(Map<String, dynamic> json) =>
      MarketSentiment(
        score: AnalysisData.parseNum(json['score']),
        label: json['label']?.toString() ?? json['sentiment']?.toString() ?? '',
        previousClose: json['previousClose'] != null
            ? AnalysisData.parseNum(json['previousClose'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'score': score,
        'label': label,
        'previousClose': previousClose,
      };
}

class TechnicalIndicator {
  final String indicator;
  final String value;
  final String interpretation;

  TechnicalIndicator({
    required this.indicator,
    required this.value,
    required this.interpretation,
  });

  factory TechnicalIndicator.fromJson(Map<String, dynamic> json) =>
      TechnicalIndicator(
        indicator: json['indicator']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        interpretation: json['interpretation']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'indicator': indicator,
        'value': value,
        'interpretation': interpretation,
      };
}

class ProjectedTrendPoint {
  final String date;
  final double price;
  final String signal;

  ProjectedTrendPoint({
    String? date,
    double? price,
    required this.signal,
    String? day,
    double? value,
  })  : date = date ?? day ?? '',
        price = price ?? value ?? 0.0;

  factory ProjectedTrendPoint.fromJson(Map<String, dynamic> json) =>
      ProjectedTrendPoint(
        date: json['date']?.toString() ?? json['day']?.toString() ?? '',
        price: AnalysisData.parseNum(json['price'] ?? json['value']),
        signal: json['signal']?.toString() ?? 'NEUTRAL',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'price': price,
        'signal': signal,
      };
}

class FinancialMatrixItem {
  final String label;
  final String value;
  final String assessment; // EXCELLENT, DANGEROUS, NEUTRAL

  FinancialMatrixItem({
    required this.label,
    required this.value,
    required this.assessment,
  });

  factory FinancialMatrixItem.fromJson(Map<String, dynamic> json) =>
      FinancialMatrixItem(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        assessment: json['assessment']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'assessment': assessment,
      };

  FinancialMatrixItem copyWith({
    String? label,
    String? value,
    String? assessment,
  }) {
    return FinancialMatrixItem(
      label: label ?? this.label,
      value: value ?? this.value,
      assessment: assessment ?? this.assessment,
    );
  }
}

class Source {
  final String? title;
  final String? url;

  Source({this.title, this.url});

  factory Source.fromJson(Map<String, dynamic> json) =>
      Source(title: json['title']?.toString(), url: json['url']?.toString());

  Map<String, dynamic> toJson() => {'title': title, 'url': url};
}

class Catalyst {
  final String type; // MOTEUR | RISQUE
  final String headline;
  final String insight;

  Catalyst({
    required this.type,
    required this.headline,
    required this.insight,
    String? date, // Added for compatibility
  }) : date = date ?? '';

  String get event => headline;
  final String date;
  String get impact => insight;

  factory Catalyst.fromJson(Map<String, dynamic> json) => Catalyst(
        type: json['type']?.toString() ?? 'MOTEUR',
        headline: json['headline'] ?? json['event']?.toString() ?? '',
        insight: json['insight'] ?? json['impact']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'headline': headline,
        'insight': insight,
      };
}

class VolatilityData {
  final String ivRank;
  final String beta;
  final String interpretation;

  VolatilityData({
    required this.ivRank,
    required this.beta,
    required this.interpretation,
  });

  factory VolatilityData.fromJson(Map<String, dynamic> json) {
    String rank = json['ivRank']?.toString() ?? '';
    if (rank.isEmpty) {
      final yL = json['yearlyLow']?.toString() ?? '';
      final yH = json['yearlyHigh']?.toString() ?? '';
      if (yL.isNotEmpty && yH.isNotEmpty) {
        rank = '$yL - $yH';
      } else {
        rank = 'N/A';
      }
    }
    return VolatilityData(
      ivRank: rank,
      beta: json['beta']?.toString() ?? 'N/A',
      interpretation: json['interpretation']?.toString() ?? 'NORMAL',
    );
  }

  Map<String, dynamic> toJson() => {
        'ivRank': ivRank,
        'beta': beta,
        'interpretation': interpretation,
      };
}

class AnalystRecommendation {
  final int strongBuy;
  final int buy;
  final int hold;
  final int sell;
  final int strongSell;
  final String period;

  AnalystRecommendation({
    required this.strongBuy,
    required this.buy,
    required this.hold,
    required this.sell,
    required this.strongSell,
    required this.period,
  });

  factory AnalystRecommendation.fromJson(Map<String, dynamic> json) =>
      AnalystRecommendation(
        strongBuy: (json['strongBuy'] as num? ?? 0).toInt(),
        buy: (json['buy'] as num? ?? 0).toInt(),
        hold: (json['hold'] as num? ?? 0).toInt(),
        sell: (json['sell'] as num? ?? 0).toInt(),
        strongSell: (json['strongSell'] as num? ?? 0).toInt(),
        period: json['period']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'strongBuy': strongBuy,
        'buy': buy,
        'hold': hold,
        'sell': sell,
        'strongSell': strongSell,
        'period': period,
      };

  double get consensusScore {
    int total = strongBuy + buy + hold + sell + strongSell;
    if (total == 0) return 0;
    // Score: SB: 100, B: 75, H: 50, S: 25, SS: 0
    double weighted =
        (strongBuy * 100 + buy * 75 + hold * 50 + sell * 25) / total;
    return weighted;
  }

  String get consensusLabel {
    double score = consensusScore;
    if (score >= 80) return 'STRONG BUY';
    if (score >= 60) return 'BUY';
    if (score >= 40) return 'HOLD';
    if (score >= 20) return 'SELL';
    return 'STRONG SELL';
  }
}

class ProCon {
  final String text;
  final String period; // PASSÉ, PRÉSENT, FUTUR
  final String? source;
  final String? sourceUrl;

  ProCon({
    required this.text,
    required this.period,
    this.source,
    this.sourceUrl,
  });

  factory ProCon.fromJson(Map<String, dynamic> json) {
    // Extract potential values
    final point = json['point']?.toString() ??
        json['text']?.toString() ??
        json['reason']?.toString();
    final analysis = json['analysis']?.toString();

    // Combine them if both exist, otherwise use what's available
    String fullText = '';
    if (point != null && point.isNotEmpty) {
      fullText = point;
      if (analysis != null && analysis.isNotEmpty) {
        fullText += ' - $analysis';
      }
    } else if (analysis != null && analysis.isNotEmpty) {
      fullText = analysis;
    }

    return ProCon(
      text: fullText,
      period: json['period']?.toString() ?? 'PRÉSENT',
      source: json['source']?.toString(),
      sourceUrl: json['sourceUrl']?.toString() ?? json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'period': period,
        'source': source,
        'sourceUrl': sourceUrl,
      };
}

class PeerComparison {
  final String ticker;
  final String name;
  final String price;
  final String verdict;
  final double confidence;
  final String profitabilityPotential;
  final String marketCap;
  final double peRatio;
  final String? type; // PAIR, CONCURRENT, COMPARABLE

  PeerComparison({
    required this.ticker,
    required this.name,
    required this.price,
    required this.verdict,
    required this.confidence,
    required this.profitabilityPotential,
    required this.marketCap,
    required this.peRatio,
    this.type,
  });

  factory PeerComparison.fromJson(Map<String, dynamic> json) => PeerComparison(
        ticker: json['ticker']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: json['price']?.toString() ?? '',
        verdict: json['verdict']?.toString() ?? 'ATTENDRE',
        confidence: AnalysisData.parseNum(json['confidence']),
        profitabilityPotential:
            json['profitabilityPotential']?.toString() ?? '',
        marketCap: json['marketCap']?.toString() ?? 'N/A',
        peRatio: AnalysisData.parseNum(json['peRatio'] ?? json['pe']),
        type: json['type']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'ticker': ticker,
        'name': name,
        'price': price,
        'verdict': verdict,
        'confidence': confidence,
        'profitabilityPotential': profitabilityPotential,
        'marketCap': marketCap,
        'peRatio': peRatio,
        'type': type,
      };
}

class TechnicalBacktest {
  final double cagr;
  final double maxDrawdown;
  final double totalReturn;
  final String period;

  TechnicalBacktest({
    required this.cagr,
    required this.maxDrawdown,
    required this.totalReturn,
    required this.period,
  });

  factory TechnicalBacktest.fromJson(Map<String, dynamic> json) =>
      TechnicalBacktest(
        cagr: AnalysisData.parseNum(json['cagr']),
        maxDrawdown: AnalysisData.parseNum(json['maxDrawdown']),
        totalReturn: AnalysisData.parseNum(json['totalReturn']),
        period: json['period']?.toString() ?? 'N/A',
      );

  Map<String, dynamic> toJson() => {
        'cagr': cagr,
        'maxDrawdown': maxDrawdown,
        'totalReturn': totalReturn,
        'period': period,
      };
}

class AnalysisData {
  final String ticker;
  final String companyProfile;
  final String businessModel;
  final String revenueStreams;
  final String lastUpdated;
  final String price;
  final String verdict;
  final List<String> verdictReasons;
  final String riskLevel;
  final List<ProCon> pros;
  final List<ProCon> cons;
  final double sigmaScore;
  final double confidence;
  final String summary;
  final List<HiddenSignal> hiddenSignals;
  final List<Catalyst> catalysts;
  final VolatilityData volatility;
  final StockSentiment fearAndGreed;
  final MarketSentiment marketSentiment;
  final TradeSetup tradeSetup;
  final InstitutionalActivity institutionalActivity;
  final List<TechnicalIndicator> technicalAnalysis;
  final List<ProjectedTrendPoint> projectedTrend;
  final List<FinancialMatrixItem> financialMatrix;
  final List<PeerComparison> sectorPeers;
  final List<Source> topSources;
  final AnalystRecommendation analystRecommendations;
  final List<String> supports; // Added for advanced TA
  final List<String> resistances; // Added for advanced TA
  final String? marketStatus; // "OUVERT", "FERMÉ", "PRÉ-MARCHÉ", "AFTER-HOURS"
  final String? priceComparison; // Contrast with S&P 500 or previous close
  final List<InsiderTransaction> insiderTransactions;
  final SocialSentimentData? socialSentiment;
  final List<AnalystRating> analystRatings;
  final List<String> actionPlan; // Plan d'action stratégique
  final double? esgScore;
  final int? controversyScore;
  final double? insiderBuyRatio;
  final String? isin;
  final String? companyName;
  final Map<String, dynamic>? technicalInsights;
  final double? targetPriceValue;
  final HoldersData? holders;
  final String? scoreMethodology;
  final List<NewsArticle> companyNews;
  final List<CorporateEvent> corporateEvents;
  TechnicalBacktest? backtest;
  final KeyStatistics? keyStatistics;
  final int? employees;
  final String? website;
  final String? sector;
  final String? industry;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final PredictiveAnalysis? predictiveSignals;
  final List<String> recommendationSteps;
  final String? ipoDate;
  final String? phone;
  final String? exchange;
  final String? ceo;
  final String? image;
  final String? exchangeFullName;
  final double? changePercent;
  final List<CompanyOfficer> officers;
  final bool isWebEnhanced;
  final String? webIntelligence;
  final List<String> agenticThoughts; // Multi-agent debate simulation
  final String alphaRecommendation; // High-conviction advice
  final List<dynamic>? historicalEarnings;
  // NEW — yfinance intelligence pipeline
  final Map<String, dynamic>? earningsCalendar;
  final List<Map<String, dynamic>>? institutionalHolders;
  final Map<String, dynamic>? earningsTrend;
  final Map<String, dynamic>? dividendData;
  final Map<String, dynamic>? fullOwnership;

  // NEW — Raw Institutional Feed for the Research Report
  final String? rawInstitutionalData;

  AnalysisData({
    required this.ticker,
    required this.companyProfile,
    this.businessModel = 'N/A',
    this.revenueStreams = 'N/A',
    required this.lastUpdated,
    required this.price,
    required this.verdict,
    this.verdictReasons = const [],
    required this.riskLevel,
    required this.pros,
    required this.cons,
    required this.sigmaScore,
    required this.confidence,
    required this.summary,
    required this.hiddenSignals,
    required this.catalysts,
    required this.volatility,
    required this.fearAndGreed,
    required this.marketSentiment,
    required this.tradeSetup,
    required this.institutionalActivity,
    required this.technicalAnalysis,
    required this.projectedTrend,
    required this.financialMatrix,
    required this.sectorPeers,
    required this.topSources,
    required this.analystRecommendations,
    this.supports = const [],
    this.resistances = const [],
    this.marketStatus,
    this.priceComparison,
    this.insiderTransactions = const [],
    this.socialSentiment,
    this.analystRatings = const [],
    this.actionPlan = const [],
    this.esgScore,
    this.controversyScore,
    this.insiderBuyRatio,
    this.isin,
    this.technicalInsights,
    this.targetPriceValue,
    this.holders,
    this.companyNews = const [],
    this.corporateEvents = const [],
    this.scoreMethodology,
    this.backtest,
    this.companyName,
    this.keyStatistics,
    this.predictiveSignals,
    this.employees,
    this.website,
    this.sector,
    this.industry,
    this.address,
    this.city,
    this.state,
    this.country,
    this.recommendationSteps = const [],
    this.ipoDate,
    this.phone,
    this.exchange,
    this.ceo,
    this.image,
    this.exchangeFullName,
    this.changePercent,
    this.officers = const [],
    this.isWebEnhanced = false,
    this.webIntelligence,
    this.agenticThoughts = const [],
    this.alphaRecommendation = "N/A",
    this.historicalEarnings,
    this.earningsCalendar,
    this.institutionalHolders,
    this.earningsTrend,
    this.dividendData,
    this.fullOwnership,
    this.rawInstitutionalData,
  });

  AnalysisData copyWith({
    String? ticker,
    String? companyProfile,
    String? businessModel,
    String? revenueStreams,
    String? lastUpdated,
    String? price,
    String? verdict,
    List<String>? verdictReasons,
    String? riskLevel,
    List<ProCon>? pros,
    List<ProCon>? cons,
    double? sigmaScore,
    double? confidence,
    String? summary,
    List<HiddenSignal>? hiddenSignals,
    List<Catalyst>? catalysts,
    VolatilityData? volatility,
    StockSentiment? fearAndGreed,
    MarketSentiment? marketSentiment,
    TradeSetup? tradeSetup,
    InstitutionalActivity? institutionalActivity,
    List<TechnicalIndicator>? technicalAnalysis,
    List<ProjectedTrendPoint>? projectedTrend,
    List<FinancialMatrixItem>? financialMatrix,
    List<PeerComparison>? sectorPeers,
    List<Source>? topSources,
    AnalystRecommendation? analystRecommendations,
    List<String>? supports,
    List<String>? resistances,
    String? marketStatus,
    String? priceComparison,
    List<InsiderTransaction>? insiderTransactions,
    SocialSentimentData? socialSentiment,
    List<AnalystRating>? analystRatings,
    List<String>? actionPlan,
    double? esgScore,
    int? controversyScore,
    double? insiderBuyRatio,
    String? isin,
    String? companyName,
    Map<String, dynamic>? technicalInsights,
    double? targetPriceValue,
    HoldersData? holders,
    TechnicalBacktest? backtest,
    String? scoreMethodology,
    KeyStatistics? keyStatistics,
    List<NewsArticle>? companyNews,
    List<CorporateEvent>? corporateEvents,
    PredictiveAnalysis? predictiveSignals,
    int? employees,
    String? website,
    String? sector,
    String? industry,
    String? address,
    String? city,
    String? state,
    String? country,
    List<String>? recommendationSteps,
    String? ipoDate,
    String? phone,
    String? exchange,
    String? ceo,
    String? image,
    String? exchangeFullName,
    double? changePercent,
    List<CompanyOfficer>? officers,
    bool? isWebEnhanced,
    String? webIntelligence,
    List<String>? agenticThoughts,
    String? alphaRecommendation,
    List<dynamic>? historicalEarnings,
    Map<String, dynamic>? earningsCalendar,
    List<Map<String, dynamic>>? institutionalHolders,
    Map<String, dynamic>? earningsTrend,
    Map<String, dynamic>? dividendData,
    Map<String, dynamic>? fullOwnership,
    String? rawInstitutionalData,
  }) {
    return AnalysisData(
      ticker: ticker ?? this.ticker,
      companyProfile: companyProfile ?? this.companyProfile,
      businessModel: businessModel ?? this.businessModel,
      revenueStreams: revenueStreams ?? this.revenueStreams,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      price: price ?? this.price,
      verdict: verdict ?? this.verdict,
      verdictReasons: verdictReasons ?? this.verdictReasons,
      riskLevel: riskLevel ?? this.riskLevel,
      pros: pros ?? this.pros,
      cons: cons ?? this.cons,
      sigmaScore: sigmaScore ?? this.sigmaScore,
      confidence: confidence ?? this.confidence,
      summary: summary ?? this.summary,
      hiddenSignals: hiddenSignals ?? this.hiddenSignals,
      catalysts: catalysts ?? this.catalysts,
      volatility: volatility ?? this.volatility,
      fearAndGreed: fearAndGreed ?? this.fearAndGreed,
      marketSentiment: marketSentiment ?? this.marketSentiment,
      tradeSetup: tradeSetup ?? this.tradeSetup,
      institutionalActivity:
          institutionalActivity ?? this.institutionalActivity,
      technicalAnalysis: technicalAnalysis ?? this.technicalAnalysis,
      projectedTrend: projectedTrend ?? this.projectedTrend,
      financialMatrix: financialMatrix ?? this.financialMatrix,
      sectorPeers: sectorPeers ?? this.sectorPeers,
      topSources: topSources ?? this.topSources,
      analystRecommendations:
          analystRecommendations ?? this.analystRecommendations,
      supports: supports ?? this.supports,
      resistances: resistances ?? this.resistances,
      marketStatus: marketStatus ?? this.marketStatus,
      priceComparison: priceComparison ?? this.priceComparison,
      insiderTransactions: insiderTransactions ?? this.insiderTransactions,
      socialSentiment: socialSentiment ?? this.socialSentiment,
      analystRatings: analystRatings ?? this.analystRatings,
      actionPlan: actionPlan ?? this.actionPlan,
      esgScore: esgScore ?? this.esgScore,
      controversyScore: controversyScore ?? this.controversyScore,
      insiderBuyRatio: insiderBuyRatio ?? this.insiderBuyRatio,
      isin: isin ?? this.isin,
      companyName: companyName ?? this.companyName,
      technicalInsights: technicalInsights ?? this.technicalInsights,
      targetPriceValue: targetPriceValue ?? this.targetPriceValue,
      holders: holders ?? this.holders,
      scoreMethodology: scoreMethodology ?? this.scoreMethodology,
      backtest: backtest ?? this.backtest,
      keyStatistics: keyStatistics ?? this.keyStatistics,
      companyNews: companyNews ?? this.companyNews,
      corporateEvents: corporateEvents ?? this.corporateEvents,
      predictiveSignals: predictiveSignals ?? this.predictiveSignals,
      employees: employees ?? this.employees,
      website: website ?? this.website,
      sector: sector ?? this.sector,
      industry: industry ?? this.industry,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      recommendationSteps: recommendationSteps ?? this.recommendationSteps,
      ipoDate: ipoDate ?? this.ipoDate,
      phone: phone ?? this.phone,
      exchange: exchange ?? this.exchange,
      ceo: ceo ?? this.ceo,
      image: image ?? this.image,
      exchangeFullName: exchangeFullName ?? this.exchangeFullName,
      changePercent: changePercent ?? this.changePercent,
      officers: officers ?? this.officers,
      isWebEnhanced: isWebEnhanced ?? this.isWebEnhanced,
      webIntelligence: webIntelligence ?? this.webIntelligence,
      agenticThoughts: agenticThoughts ?? this.agenticThoughts,
      alphaRecommendation: alphaRecommendation ?? this.alphaRecommendation,
      historicalEarnings: historicalEarnings ?? this.historicalEarnings,
      earningsCalendar: earningsCalendar ?? this.earningsCalendar,
      institutionalHolders: institutionalHolders ?? this.institutionalHolders,
      earningsTrend: earningsTrend ?? this.earningsTrend,
      dividendData: dividendData ?? this.dividendData,
      fullOwnership: fullOwnership ?? this.fullOwnership,
      rawInstitutionalData: rawInstitutionalData ?? this.rawInstitutionalData,
    );
  }

  // Helper robuste pour conversion numérique (gère String "12.5" et num 12.5)
  static double parseNum(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      if (value.isEmpty) return 0.0;
      // Nettoyage basique (ex: "12,5" -> "12.5", "12.5%" -> "12.5")
      String cleaned = value.replaceAll(',', '.').replaceAll('%', '').trim();
      cleaned = cleaned.replaceAll('\$', '').replaceAll(' ', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static String parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static Map<String, dynamic> parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (e) {
        // Fallback manual if key/value types are mixed
        final Map<String, dynamic> result = {};
        value.forEach((k, v) => result[k.toString()] = v);
        return result;
      }
    }
    return {};
  }

  static int parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  static List<dynamic> parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    return [];
  }

  static List<FinancialMatrixItem> _parseFinancialMatrix(
    Map<String, dynamic> json,
    Map<String, dynamic> Function(dynamic) safeMap,
  ) {
    final rawList = parseList(json['financialMatrix'] ?? json['financials']);
    final parsed =
        rawList.map((x) => FinancialMatrixItem.fromJson(safeMap(x))).toList();

    // Liste des métriques requises avec leurs labels
    const requiredMetrics = [
      'CAPITALISATION BOURS.',
      'P/E RATIO',
      'ROIC',
      'D/E RATIO',
      'EPS',
      'ROE',
      'EBIT',
      'MARGE BRUTE',
    ];

    // Vérifier que toutes les métriques requises sont présentes
    final existingLabels = parsed.map((m) => m.label.toUpperCase()).toSet();

    for (final metric in requiredMetrics) {
      final found = existingLabels.any(
        (label) => label.contains(metric) || metric.contains(label),
      );

      if (!found) {
        // Ajouter la métrique manquante avec valeur "En attente..."
        parsed.add(
          FinancialMatrixItem(
            label: metric,
            value: 'En attente...',
            assessment: 'NEUTRAL',
          ),
        );
      }
    }

    return parsed;
  }

  /// Récupère une métrique spécifique de la financialMatrix par son label
  String getMetric(String label) {
    if (label.isEmpty) return 'N/A';
    final target = label.toUpperCase();

    // Fallback manuel pour les métriques critiques si KeyStatistics est présent
    if (keyStatistics != null) {
      if (target.contains('CAPITALISATION') || target.contains('MARKET CAP')) {
        if (keyStatistics!.marketCap != 0) {
          return _formatCompact(keyStatistics!.marketCap);
        }
      } else if (target.contains('P/E RATIO') ||
          target.contains('TRAILING PE')) {
        if (keyStatistics!.trailingPE != 0) {
          return keyStatistics!.trailingPE.toStringAsFixed(2);
        }
      } else if (target.contains('ROE') && keyStatistics!.returnOnEquity != 0) {
        return '${(keyStatistics!.returnOnEquity * 100).toStringAsFixed(2)}%';
      } else if (target.contains('D/E') && keyStatistics!.debtToEquity != 0) {
        return keyStatistics!.debtToEquity.toStringAsFixed(2);
      }
    }

    final item = financialMatrix.firstWhere(
      (m) {
        final itemLabel = m.label.toUpperCase();
        return itemLabel.contains(target) || target.contains(itemLabel);
      },
      orElse: () => FinancialMatrixItem(
        label: label,
        value: 'N/A',
        assessment: 'NEUTRAL',
      ),
    );
    return item.value;
  }

  String _formatCompact(double n) {
    if (n >= 1e12) return '${(n / 1e12).toStringAsFixed(2)}T';
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(2)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(2)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(2)}K';
    return n.toStringAsFixed(0);
  }

  factory AnalysisData.fromJson(Map<String, dynamic> json) {
    // Helper pour garantir qu'on passe bien une Map au sous-objets
    Map<String, dynamic> safeMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return {};
    }

    return AnalysisData(
      ticker: parseString(json['ticker']),
      companyName: json['companyName']?.toString(),
      companyProfile: parseString(json['companyProfile']),
      businessModel: parseString(json['businessModel'], fallback: 'N/A'),
      revenueStreams: parseString(json['revenueStreams'], fallback: 'N/A'),
      lastUpdated: parseString(json['lastUpdated']),
      price: parseString(json['price']),
      verdict: parseString(json['verdict'], fallback: 'ATTENDRE'),
      verdictReasons:
          parseList(json['verdictReasons']).map((e) => e.toString()).toList(),
      riskLevel: parseString(json['riskLevel'], fallback: 'MOYEN'),
      pros: parseList(json['pros'])
          .map((x) => ProCon.fromJson(safeMap(x)))
          .toList(),
      cons: parseList(json['cons'])
          .map((x) => ProCon.fromJson(safeMap(x)))
          .toList(),
      sigmaScore: parseNum(json['sigmaScore']),
      confidence: parseNum(json['confidence']),
      summary: parseString(json['summary']),
      hiddenSignals: parseList(json['hiddenSignals'])
          .map((x) => HiddenSignal.fromJson(safeMap(x)))
          .toList(),
      catalysts: parseList(json['catalysts'])
          .map((x) => Catalyst.fromJson(safeMap(x)))
          .toList(),
      volatility: VolatilityData.fromJson(safeMap(json['volatility'])),
      fearAndGreed: StockSentiment.fromJson(safeMap(json['fearAndGreed'])),
      marketSentiment: MarketSentiment.fromJson(
        safeMap(json['marketSentiment']),
      ),
      tradeSetup: TradeSetup.fromJson(safeMap(json['tradeSetup'])),
      institutionalActivity: InstitutionalActivity.fromJson(
        safeMap(json['institutionalActivity']),
      ),
      technicalAnalysis: parseList(json['technicalAnalysis'])
          .map((x) => TechnicalIndicator.fromJson(safeMap(x)))
          .toList(),
      projectedTrend: parseList(json['projectedTrend'])
          .map((x) => ProjectedTrendPoint.fromJson(safeMap(x)))
          .toList(),
      financialMatrix: _parseFinancialMatrix(json, safeMap),
      sectorPeers: parseList(json['sectorPeers'] ?? json['peers'])
          .map((x) => PeerComparison.fromJson(safeMap(x)))
          .toList(),
      topSources: parseList(json['topSources'])
          .map((x) => Source.fromJson(safeMap(x)))
          .toList(),
      analystRecommendations: AnalystRecommendation.fromJson(
        safeMap(json['analystRecommendations']),
      ),
      supports: parseList(json['supports']).map((e) => e.toString()).toList(),
      resistances:
          parseList(json['resistances']).map((e) => e.toString()).toList(),
      marketStatus: parseString(json['marketStatus']),
      priceComparison: parseString(json['priceComparison']),
      insiderTransactions: parseList(json['insiderTransactions'])
          .map((x) => InsiderTransaction.fromJson(safeMap(x)))
          .toList(),
      socialSentiment: json['socialSentiment'] != null
          ? SocialSentimentData.fromJson(safeMap(json['socialSentiment']))
          : null,
      analystRatings: parseList(json['analystRatings'])
          .map((x) => AnalystRating.fromJson(safeMap(x)))
          .toList(),
      actionPlan:
          parseList(json['actionPlan']).map((e) => e.toString()).toList(),
      esgScore: json['esgScore'] != null ? parseNum(json['esgScore']) : null,
      controversyScore: json['controversyScore'] != null
          ? parseInt(json['controversyScore'])
          : null,
      insiderBuyRatio: json['insiderBuyRatio'] != null
          ? parseNum(json['insiderBuyRatio'])
          : null,
      isin: parseString(json['isin']),
      technicalInsights: json['technicalInsights'] != null
          ? Map<String, dynamic>.from(json['technicalInsights'])
          : null,
      targetPriceValue: parseNum(json['targetPriceValue']),
      holders: json['holders'] != null
          ? HoldersData.fromJson(safeMap(json['holders']))
          : null,
      companyNews: parseList(json['companyNews'])
          .map((x) => NewsArticle.fromJson(safeMap(x)))
          .toList(),
      corporateEvents: parseList(json['corporateEvents'])
          .map((x) => CorporateEvent.fromJson(safeMap(x)))
          .toList(),
      scoreMethodology: parseString(json['scoreMethodology']),
      backtest: json['backtest'] != null
          ? TechnicalBacktest.fromJson(safeMap(json['backtest']))
          : null,
      keyStatistics: json['keyStatistics'] != null
          ? KeyStatistics.fromJson(safeMap(json['keyStatistics']))
          : null,
      employees: (json['employees'] ?? json['fullTimeEmployees']) != null
          ? parseInt(json['employees'] ?? json['fullTimeEmployees'])
          : null,
      website: parseString(json['website']),
      sector: parseString(json['sector']),
      industry: parseString(json['industry']),
      address: parseString(json['address']),
      city: parseString(json['city']),
      state: parseString(json['state']),
      country: parseString(json['country']),
      recommendationSteps: parseList(json['recommendationSteps'])
          .map((e) => e.toString())
          .toList(),
      ipoDate: parseString(json['ipoDate'] ?? json['ipo_date']),
      phone: parseString(json['phone']),
      exchange: parseString(json['exchange'] ?? json['exchangeName']),
      ceo: parseString(json['ceo']),
      image: parseString(json['image']),
      exchangeFullName: parseString(json['exchangeFullName']),
      changePercent: json['change_percent'] != null
          ? parseNum(json['change_percent'])
          : null,
      officers: parseList(json['officers'])
          .map((x) => CompanyOfficer.fromJson(safeMap(x)))
          .toList(),
      isWebEnhanced:
          json['isWebEnhanced'] == true || json['webIntelligence'] != null,
      webIntelligence: json['webIntelligence']?.toString(),
      agenticThoughts: (json['agenticThoughts'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      alphaRecommendation: json['alphaRecommendation']?.toString() ?? "N/A",
      historicalEarnings: json['historicalEarnings'] as List?,
      earningsCalendar: json['earningsCalendar'] is Map
          ? Map<String, dynamic>.from(json['earningsCalendar'])
          : null,
      institutionalHolders: (json['institutionalHolders'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList(),
      earningsTrend: json['earningsTrend'] is Map
          ? Map<String, dynamic>.from(json['earningsTrend'])
          : null,
      dividendData: json['dividendData'] is Map
          ? Map<String, dynamic>.from(json['dividendData'])
          : null,
      fullOwnership: json['fullOwnership'] is Map
          ? Map<String, dynamic>.from(json['fullOwnership'])
          : null,
    );
  }

  /// Crée une copie avec un nouveau prix
  AnalysisData copyWithPrice(String newPrice) {
    return AnalysisData(
      ticker: ticker,
      companyProfile: companyProfile,
      businessModel: businessModel,
      revenueStreams: revenueStreams,
      lastUpdated: lastUpdated,
      price: newPrice,
      verdict: verdict,
      verdictReasons: verdictReasons,
      riskLevel: riskLevel,
      pros: pros,
      cons: cons,
      sigmaScore: sigmaScore,
      confidence: confidence,
      summary: summary,
      hiddenSignals: hiddenSignals,
      catalysts: catalysts,
      volatility: volatility,
      fearAndGreed: fearAndGreed,
      marketSentiment: marketSentiment,
      tradeSetup: tradeSetup,
      institutionalActivity: institutionalActivity,
      technicalAnalysis: technicalAnalysis,
      projectedTrend: projectedTrend,
      financialMatrix: financialMatrix,
      sectorPeers: sectorPeers,
      topSources: topSources,
      analystRecommendations: analystRecommendations,
      marketStatus: marketStatus,
      priceComparison: priceComparison,
      insiderTransactions: insiderTransactions,
      socialSentiment: socialSentiment,
      analystRatings: analystRatings,
      actionPlan: actionPlan,
      esgScore: esgScore,
      controversyScore: controversyScore,
      insiderBuyRatio: insiderBuyRatio,
      isin: isin,
      technicalInsights: technicalInsights,
      targetPriceValue: targetPriceValue,
      holders: holders,
      scoreMethodology: scoreMethodology,
      keyStatistics: keyStatistics,
      recommendationSteps: recommendationSteps,
      companyName: companyName,
      companyNews: companyNews,
      corporateEvents: corporateEvents,
      predictiveSignals: predictiveSignals,
      employees: employees,
      website: website,
      sector: sector,
      industry: industry,
      address: address,
      city: city,
      state: state,
      country: country,
      ipoDate: ipoDate,
      phone: phone,
      exchange: exchange,
      ceo: ceo,
      image: image,
      exchangeFullName: exchangeFullName,
    )..backtest = backtest;
  }

  Map<String, dynamic> toJson() => {
        'ticker': ticker,
        'companyProfile': companyProfile,
        'businessModel': businessModel,
        'revenueStreams': revenueStreams,
        'lastUpdated': lastUpdated,
        'price': price,
        'verdict': verdict,
        'verdictReasons': verdictReasons,
        'riskLevel': riskLevel,
        'pros': pros.map((x) => x.toJson()).toList(),
        'cons': cons.map((x) => x.toJson()).toList(),
        'sigmaScore': sigmaScore,
        'confidence': confidence,
        'summary': summary,
        'hiddenSignals': hiddenSignals.map((x) => x.toJson()).toList(),
        'catalysts': catalysts.map((x) => x.toJson()).toList(),
        'volatility': volatility.toJson(),
        'fearAndGreed': fearAndGreed.toJson(),
        'marketSentiment': marketSentiment.toJson(),
        'tradeSetup': tradeSetup.toJson(),
        'institutionalActivity': institutionalActivity.toJson(),
        'technicalAnalysis': technicalAnalysis.map((x) => x.toJson()).toList(),
        'projectedTrend': projectedTrend.map((x) => x.toJson()).toList(),
        'financialMatrix': financialMatrix.map((x) => x.toJson()).toList(),
        'sectorPeers': sectorPeers.map((x) => x.toJson()).toList(),
        'topSources': topSources.map((x) => x.toJson()).toList(),
        'analystRecommendations': analystRecommendations.toJson(),
        'marketStatus': marketStatus,
        'priceComparison': priceComparison,
        'insiderTransactions':
            insiderTransactions.map((x) => x.toJson()).toList(),
        'socialSentiment': socialSentiment?.toJson(),
        'analystRatings': analystRatings.map((x) => x.toJson()).toList(),
        'actionPlan': actionPlan,
        'esgScore': esgScore,
        'controversyScore': controversyScore,
        'insiderBuyRatio': insiderBuyRatio,
        'isin': isin,
        'technicalInsights': technicalInsights,
        'targetPriceValue': targetPriceValue,
        'holders': holders?.toJson(),
        'backtest': backtest?.toJson(),
        'keyStatistics': keyStatistics?.toJson(),
        'employees': employees,
        'website': website,
        'sector': sector,
        'industry': industry,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'recommendationSteps': recommendationSteps,
        'companyName': companyName,
        'companyNews': companyNews.map((x) => x.toJson()).toList(),
        'corporateEvents': corporateEvents.map((x) => x.toJson()).toList(),
        'predictiveSignals': predictiveSignals?.toJson(),
        'ipoDate': ipoDate,
        'phone': phone,
        'exchange': exchange,
        'ceo': ceo,
        'image': image,
        'exchangeFullName': exchangeFullName,
        'scoreMethodology': scoreMethodology,
        'change_percent': changePercent,
        'officers': officers.map((x) => x.toJson()).toList(),
        'isWebEnhanced': isWebEnhanced,
        'webIntelligence': webIntelligence,
        'agenticThoughts': agenticThoughts,
        'alphaRecommendation': alphaRecommendation,
        'historicalEarnings': historicalEarnings,
        'earningsCalendar': earningsCalendar,
        'institutionalHolders': institutionalHolders,
        'earningsTrend': earningsTrend,
        'dividendData': dividendData,
        'fullOwnership': fullOwnership,
        'rawInstitutionalData': rawInstitutionalData,
      };
}

class AnalystRating {
  final String date;
  final String firm;
  final String action; // Upgrade, Downgrade, Init
  final String rating; // Buy, Hold, etc.

  AnalystRating({
    required this.date,
    required this.firm,
    required this.action,
    required this.rating,
  });

  factory AnalystRating.fromJson(Map<String, dynamic> json) => AnalystRating(
        date: AnalysisData.parseString(json['date']),
        firm: AnalysisData.parseString(json['firm']),
        action: AnalysisData.parseString(json['action']),
        rating: AnalysisData.parseString(json['rating']),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'firm': firm,
        'action': action,
        'rating': rating,
      };
}

class SectorInsight {
  final String name;
  final double performance;
  final String sentiment;
  final String trend;
  final String institutionalFlow;
  final String reason;

  SectorInsight({
    required this.name,
    required this.performance,
    required this.sentiment,
    required this.trend,
    required this.institutionalFlow,
    required this.reason,
  });

  factory SectorInsight.fromJson(Map<String, dynamic> json) => SectorInsight(
        name: AnalysisData.parseString(json['name']),
        performance: AnalysisData.parseNum(json['performance']),
        sentiment:
            AnalysisData.parseString(json['sentiment'], fallback: 'NEUTRAL'),
        trend: AnalysisData.parseString(json['trend'], fallback: 'NEUTRAL'),
        institutionalFlow: AnalysisData.parseString(
          json['institutionalFlow'],
          fallback: 'NEUTRAL',
        ),
        reason: AnalysisData.parseString(json['reason']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'performance': performance,
        'sentiment': sentiment,
        'trend': trend,
        'institutionalFlow': institutionalFlow,
        'reason': reason,
      };
}

class MarketOverview {
  final String marketRegime;
  final String regimeDescription;
  final String vixLevel;
  final List<SectorInsight> sectors;
  final String lastUpdated;
  final List<Map<String, String>> news;
  final MacroIndicators? macroIndicators;
  final List<YahooIndexSummary>? yahooSummary;
  final List<Map<String, dynamic>>? upcomingIpos;
  final String sentiment; // EXTREME FEAR, FEAR, NEUTRAL, GREED, EXTREME GREED
  final double sentimentValue; // 0 to 100
  final List<NewsArticle> globalNews;
  final double vixValue;
  final double vixChange;
  final double vixChangePercent;
  final List<MarketMover>? topGainers;
  final List<MarketMover>? topLosers;
  final List<EconomicEvent>? economicCalendar;
  final List<NotableEvent>? notableEvents;
  final Map<String, dynamic>? indicators;
  final List<NewsArticle>? sentimentNews;
  final List<Map<String, dynamic>>? sentimentHistory;
  final List<GlobalInsiderTrade>? insiderTrades;
  final Map<String, dynamic>? backtest;
  final List<ScoreComponent>? sentimentComponents;
  final Map<String, double>? sectorSentiment;

  MarketOverview({
    required this.marketRegime,
    required this.regimeDescription,
    required this.vixLevel,
    required this.sectors,
    required this.lastUpdated,
    required this.sentiment,
    required this.sentimentValue,
    required this.globalNews,
    this.vixValue = 0.0,
    this.vixChange = 0.0,
    this.vixChangePercent = 0.0,
    this.news = const [],
    this.macroIndicators,
    this.economicCalendar,
    this.topGainers,
    this.topLosers,
    this.yahooSummary,
    this.upcomingIpos,
    this.notableEvents,
    this.indicators,
    this.sentimentNews,
    this.sentimentHistory,
    this.insiderTrades,
    this.backtest,
    this.sentimentComponents,
    this.sectorSentiment,
  });

  factory MarketOverview.fromJson(Map<String, dynamic> json) => MarketOverview(
        marketRegime: AnalysisData.parseString(
          json['marketRegime'],
          fallback: 'UNKNOWN',
        ),
        regimeDescription: AnalysisData.parseString(json['regimeDescription']),
        vixLevel: AnalysisData.parseString(json['vixLevel'], fallback: '0.0'),
        lastUpdated: AnalysisData.parseString(json['lastUpdated']),
        sentiment:
            AnalysisData.parseString(json['sentiment'], fallback: 'NEUTRAL'),
        sentimentValue: AnalysisData.parseNum(json['sentimentValue']),
        globalNews: (json['globalNews'] as List?)
                ?.map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        vixValue: (json['vixValue'] ?? 0.0).toDouble(),
        vixChange: (json['vixChange'] ?? 0.0).toDouble(),
        vixChangePercent: (json['vixChangePercent'] ?? 0.0).toDouble(),
        sectors: (json['sectors'] as List? ?? [])
            .map((x) => SectorInsight.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        news: (json['news'] as List? ?? [])
            .map(
              (x) => (x as Map).map(
                (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
              ),
            )
            .toList(),
        macroIndicators: json['macroIndicators'] != null
            ? MacroIndicators.fromJson(
                Map<String, dynamic>.from(json['macroIndicators']),
              )
            : null,
        economicCalendar: (json['economicCalendar'] as List? ?? [])
            .map((x) => EconomicEvent.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        topGainers: (json['topGainers'] as List? ?? [])
            .map((x) => MarketMover.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        topLosers: (json['topLosers'] as List? ?? [])
            .map((x) => MarketMover.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        yahooSummary: (json['yahooSummary'] as List?)
            ?.map(
                (x) => YahooIndexSummary.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        upcomingIpos: (json['upcomingIpos'] as List?)
            ?.map((x) => Map<String, dynamic>.from(x))
            .toList(),
        notableEvents: (json['notableEvents'] as List?)
            ?.map((x) => NotableEvent.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        indicators: json['indicators'] != null
            ? Map<String, dynamic>.from(json['indicators'])
            : null,
        sentimentNews: (json['sentimentNews'] as List?)
            ?.map((e) => NewsArticle.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        sentimentHistory: (json['sentimentHistory'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList(),
        insiderTrades: (json['insiderTrades'] as List?)
            ?.map((e) =>
                GlobalInsiderTrade.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        backtest: json['backtest'] != null
            ? Map<String, dynamic>.from(json['backtest'])
            : null,
        sentimentComponents: (json['sentimentComponents'] as List?)
            ?.map((x) => ScoreComponent.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        sectorSentiment: json['sectorSentiment'] != null
            ? (json['sectorSentiment'] as Map).map(
                (k, v) =>
                    MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        'marketRegime': marketRegime,
        'regimeDescription': regimeDescription,
        'vixLevel': vixLevel,
        'sectors': sectors.map((x) => x.toJson()).toList(),
        'lastUpdated': lastUpdated,
        'news': news,
        'macroIndicators': macroIndicators?.toJson(),
        'economicCalendar': economicCalendar?.map((x) => x.toJson()).toList(),
        'topGainers': topGainers?.map((x) => x.toJson()).toList(),
        'topLosers': topLosers?.map((x) => x.toJson()).toList(),
        'yahooSummary': yahooSummary?.map((x) => x.toJson()).toList(),
        'upcomingIpos': upcomingIpos,
        'notableEvents': notableEvents?.map((x) => x.toJson()).toList(),
        'indicators': indicators,
        'sentimentNews': sentimentNews?.map((x) => x.toJson()).toList(),
        'sentimentHistory': sentimentHistory,
        'insiderTrades': insiderTrades?.map((x) => x.toJson()).toList(),
        'sentiment': sentiment,
        'sentimentValue': sentimentValue,
        'globalNews': globalNews.map((x) => x.toJson()).toList(),
        'vixValue': vixValue,
        'vixChange': vixChange,
        'vixChangePercent': vixChangePercent,
      };

  // Getters for market indices
  String get sp500 {
    if (yahooSummary == null) return 'N/A';
    final sp500 = yahooSummary!.firstWhere(
      (summary) => summary.symbol == '^GSPC',
      orElse: () => YahooIndexSummary(
        symbol: '^GSPC',
        name: 'S&P 500',
        price: 0,
        change: 0,
        changePercent: 0,
      ),
    );
    return sp500.price > 0
        ? '${sp500.price.toStringAsFixed(2)} (${sp500.changePercent >= 0 ? '+' : ''}${sp500.changePercent.toStringAsFixed(2)}%)'
        : 'N/A';
  }

  String get dowJones {
    if (yahooSummary == null) return 'N/A';
    final dow = yahooSummary!.firstWhere(
      (summary) => summary.symbol == '^DJI',
      orElse: () => YahooIndexSummary(
        symbol: '^DJI',
        name: 'Dow Jones',
        price: 0,
        change: 0,
        changePercent: 0,
      ),
    );
    return dow.price > 0
        ? '${dow.price.toStringAsFixed(2)} (${dow.changePercent >= 0 ? '+' : ''}${dow.changePercent.toStringAsFixed(2)}%)'
        : 'N/A';
  }

  String get nasdaq {
    if (yahooSummary == null) return 'N/A';
    final nasdaq = yahooSummary!.firstWhere(
      (summary) => summary.symbol == '^IXIC',
      orElse: () => YahooIndexSummary(
        symbol: '^IXIC',
        name: 'Nasdaq',
        price: 0,
        change: 0,
        changePercent: 0,
      ),
    );
    return nasdaq.price > 0
        ? '${nasdaq.price.toStringAsFixed(2)} (${nasdaq.changePercent >= 0 ? '+' : ''}${nasdaq.changePercent.toStringAsFixed(2)}%)'
        : 'N/A';
  }
}

class YahooIndexSummary {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;

  YahooIndexSummary({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
  });

  factory YahooIndexSummary.fromJson(Map<String, dynamic> json) =>
      YahooIndexSummary(
        symbol: json['symbol']?.toString() ?? '',
        name: json['shortName'] ?? json['name'] ?? '',
        price: AnalysisData.parseNum(json['price']),
        change: AnalysisData.parseNum(json['change']),
        changePercent: AnalysisData.parseNum(json['changePercent']),
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'price': price,
        'change': change,
        'changePercent': changePercent,
      };
}

class EconomicEvent {
  final String date;
  final String event;
  final String impact; // HIGH, MEDIUM, LOW
  final String country;
  final String? actual;
  final String? estimate;
  final String? previous;

  EconomicEvent({
    required this.date,
    required this.event,
    required this.impact,
    this.country = '',
    this.actual,
    this.estimate,
    this.previous,
  });

  factory EconomicEvent.fromJson(Map<String, dynamic> json) => EconomicEvent(
        date: json['date']?.toString() ?? '',
        event: json['event']?.toString() ?? '',
        impact: json['impact']?.toString() ?? 'LOW',
        country: json['country']?.toString() ?? '',
        actual: json['actual']?.toString(),
        estimate: json['estimate']?.toString(),
        previous: json['previous']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'event': event,
        'impact': impact,
        'country': country,
        'actual': actual,
        'estimate': estimate,
        'previous': previous,
      };
}

class MarketMover {
  final String ticker;
  final String name;
  final double change;

  MarketMover({required this.ticker, required this.change, this.name = ''});

  factory MarketMover.fromJson(Map<String, dynamic> json) => MarketMover(
        ticker: json['ticker']?.toString() ?? '',
        name: (json['name'] ?? json['shortName'] ?? json['longName'] ?? '')
            .toString(),
        change: AnalysisData.parseNum(json['change']),
      );

  Map<String, dynamic> toJson() =>
      {'ticker': ticker, 'name': name, 'change': change};
}

class MacroIndicators {
  final double treasury10Y;
  final double dollarIndex; // DXY
  final double goldPrice;
  final double oilPrice;

  MacroIndicators({
    required this.treasury10Y,
    required this.dollarIndex,
    required this.goldPrice,
    required this.oilPrice,
  });

  factory MacroIndicators.fromJson(Map<String, dynamic> json) =>
      MacroIndicators(
        treasury10Y: AnalysisData.parseNum(json['treasury10Y']),
        dollarIndex: AnalysisData.parseNum(json['dollarIndex']),
        goldPrice: AnalysisData.parseNum(json['goldPrice']),
        oilPrice: AnalysisData.parseNum(json['oilPrice']),
      );

  Map<String, dynamic> toJson() => {
        'treasury10Y': treasury10Y,
        'dollarIndex': dollarIndex,
        'goldPrice': goldPrice,
        'oilPrice': oilPrice,
      };
}

class MajorHolder {
  final String organization;
  final double pctHeld;
  final double position;
  final double value;
  final String reportDate;

  MajorHolder({
    required this.organization,
    required this.pctHeld,
    required this.position,
    required this.value,
    required this.reportDate,
  });

  factory MajorHolder.fromJson(Map<String, dynamic> json) => MajorHolder(
        organization: json['organization']?.toString() ?? 'N/A',
        pctHeld: AnalysisData.parseNum(json['pctHeld']),
        position: AnalysisData.parseNum(json['position']),
        value: AnalysisData.parseNum(json['value']),
        reportDate: json['reportDate']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'organization': organization,
        'pctHeld': pctHeld,
        'position': position,
        'value': value,
        'reportDate': reportDate,
      };
}

class HoldersData {
  final double insidersPercent;
  final double institutionsPercent;
  final int institutionsCount;
  final List<MajorHolder> topInstitutions;
  final List<MajorHolder> topFunds;

  HoldersData({
    required this.insidersPercent,
    required this.institutionsPercent,
    required this.institutionsCount,
    required this.topInstitutions,
    required this.topFunds,
  });

  factory HoldersData.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] ?? json;
    return HoldersData(
      insidersPercent: AnalysisData.parseNum(breakdown['insidersPercentHeld']),
      institutionsPercent: AnalysisData.parseNum(
        breakdown['institutionsPercentHeld'],
      ),
      institutionsCount: AnalysisData.parseNum(
        breakdown['institutionsCount'],
      ).toInt(),
      topInstitutions: (json['institutions'] as List? ?? [])
          .map((x) => MajorHolder.fromJson(x))
          .toList(),
      topFunds: (json['funds'] as List? ?? [])
          .map((x) => MajorHolder.fromJson(x))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'insidersPercent': insidersPercent,
        'institutionsPercent': institutionsPercent,
        'institutionsCount': institutionsCount,
        'topInstitutions': topInstitutions.map((x) => x.toJson()).toList(),
        'topFunds': topFunds.map((x) => x.toJson()).toList(),
      };
}

class KeyStatistics {
  final double marketCap;
  final double enterpriseValue;
  final double trailingPE;
  final double forwardPE;
  final double pegRatio;
  final double priceToSales;
  final double priceToBook;
  final double enterpriseToRevenue;
  final double enterpriseToEbitda;
  final double profitMargins;
  final double operatingMargins;
  final double returnOnAssets;
  final double returnOnEquity;
  final double revenue;
  final double revenueGrowth;
  final double grossProfits;
  final double freeCashflow;
  final double operatingCashflow;
  final double totalCash;
  final double totalDebt;
  final double debtToEquity;
  final double currentRatio;
  final double quickRatio;
  final double totalCashPerShare;
  final double revenuePerShare;
  final double beta;
  final double shortRatio;
  final double shortPercentOfFloat;
  final double sharesOutstanding;
  final double floatShares;
  // NEW — yfinance summaryDetail dividend & range data
  final double dividendYield;
  final double dividendRate;
  final double fiveYearAvgDividendYield;
  final double payoutRatio;
  final double fiftyTwoWeekHigh;
  final double fiftyTwoWeekLow;
  final double fiftyDayAverage;
  final double twoHundredDayAverage;
  final double trailingAnnualDividendYield;
  final double earningsGrowth;
  // NEW — EPS & volume
  final double averageVolume;
  final double trailingEps;
  final double forwardEps;

  KeyStatistics({
    required this.marketCap,
    required this.enterpriseValue,
    required this.trailingPE,
    required this.forwardPE,
    required this.pegRatio,
    required this.priceToSales,
    required this.priceToBook,
    required this.enterpriseToRevenue,
    required this.enterpriseToEbitda,
    required this.profitMargins,
    required this.operatingMargins,
    required this.returnOnAssets,
    required this.returnOnEquity,
    required this.revenue,
    required this.revenueGrowth,
    required this.grossProfits,
    required this.freeCashflow,
    required this.operatingCashflow,
    required this.totalCash,
    required this.totalDebt,
    required this.debtToEquity,
    required this.currentRatio,
    required this.quickRatio,
    required this.totalCashPerShare,
    required this.revenuePerShare,
    required this.beta,
    required this.shortRatio,
    required this.shortPercentOfFloat,
    required this.sharesOutstanding,
    required this.floatShares,
    this.dividendYield = 0,
    this.dividendRate = 0,
    this.fiveYearAvgDividendYield = 0,
    this.payoutRatio = 0,
    this.fiftyTwoWeekHigh = 0,
    this.fiftyTwoWeekLow = 0,
    this.fiftyDayAverage = 0,
    this.twoHundredDayAverage = 0,
    this.trailingAnnualDividendYield = 0,
    this.earningsGrowth = 0,
    this.averageVolume = 0,
    this.trailingEps = 0,
    this.forwardEps = 0,
  });

  factory KeyStatistics.fromYahoo(Map<String, dynamic> json) {
    // DEBUG: Print received modules
    print('=== KeyStatistics.fromYahoo DEBUG ===');
    print('Available keys: ${json.keys.toList()}');

    final Map<String, dynamic> summaryDetail = Map<String, dynamic>.from(
      json['summaryDetail'] ?? {},
    );
    final Map<String, dynamic> defaultKeyStatistics = Map<String, dynamic>.from(
      json['defaultKeyStatistics'] ?? {},
    );
    final Map<String, dynamic> financialData = Map<String, dynamic>.from(
      json['financialData'] ?? {},
    );
    final Map<String, dynamic> priceData = Map<String, dynamic>.from(
      json['price'] ?? {},
    );

    // DEBUG: Print sample data
    print('summaryDetail keys: ${summaryDetail.keys.take(10).toList()}');
    print(
      'defaultKeyStatistics keys: ${defaultKeyStatistics.keys.take(10).toList()}',
    );
    print('financialData keys: ${financialData.keys.take(10).toList()}');
    print('priceData keys: ${priceData.keys.take(10).toList()}');

    // Helper to extract values from Yahoo's format: {raw: 123.45, fmt: "123.45"}
    double getValue(Map<String, dynamic>? container, String key) {
      if (container == null) return 0.0;
      final field = container[key];
      if (field == null) return 0.0;
      if (field is Map) {
        if (field['raw'] != null) return AnalysisData.parseNum(field['raw']);
      }
      return AnalysisData.parseNum(field);
    }

    // Extract market cap - try multiple sources
    double marketCap = getValue(priceData, 'marketCap');
    if (marketCap == 0) marketCap = getValue(summaryDetail, 'marketCap');

    print('DEBUG marketCap: $marketCap');
    print('DEBUG trailingPE raw: ${summaryDetail['trailingPE']}');

    return KeyStatistics(
      marketCap: marketCap,
      enterpriseValue: getValue(defaultKeyStatistics, 'enterpriseValue'),
      trailingPE: getValue(summaryDetail, 'trailingPE'),
      forwardPE: getValue(summaryDetail, 'forwardPE'),
      pegRatio: getValue(defaultKeyStatistics, 'pegRatio'),
      priceToSales: getValue(summaryDetail, 'priceToSalesTrailing12Months'),
      priceToBook: getValue(defaultKeyStatistics, 'priceToBook'),
      enterpriseToRevenue: getValue(
        defaultKeyStatistics,
        'enterpriseToRevenue',
      ),
      enterpriseToEbitda: getValue(defaultKeyStatistics, 'enterpriseToEbitda'),
      profitMargins: getValue(financialData, 'profitMargins'),
      operatingMargins: getValue(financialData, 'operatingMargins'),
      returnOnAssets: getValue(financialData, 'returnOnAssets'),
      returnOnEquity: getValue(financialData, 'returnOnEquity'),
      revenue: getValue(financialData, 'totalRevenue'),
      revenueGrowth: getValue(financialData, 'revenueGrowth'),
      grossProfits: getValue(financialData, 'grossProfits'),
      freeCashflow: getValue(financialData, 'freeCashflow'),
      operatingCashflow: getValue(financialData, 'operatingCashflow'),
      totalCash: getValue(financialData, 'totalCash'),
      totalDebt: getValue(financialData, 'totalDebt'),
      debtToEquity: getValue(financialData, 'debtToEquity'),
      currentRatio: getValue(financialData, 'currentRatio'),
      quickRatio: getValue(financialData, 'quickRatio'),
      totalCashPerShare: getValue(financialData, 'totalCashPerShare'),
      revenuePerShare: getValue(financialData, 'revenuePerShare'),
      beta: getValue(summaryDetail, 'beta'),
      shortRatio: getValue(defaultKeyStatistics, 'shortRatio'),
      shortPercentOfFloat: getValue(
        defaultKeyStatistics,
        'shortPercentOfFloat',
      ),
      sharesOutstanding: getValue(defaultKeyStatistics, 'sharesOutstanding'),
      floatShares: getValue(defaultKeyStatistics, 'floatShares'),
      dividendYield: getValue(summaryDetail, 'dividendYield'),
      dividendRate: getValue(summaryDetail, 'dividendRate'),
      fiveYearAvgDividendYield:
          getValue(summaryDetail, 'fiveYearAvgDividendYield'),
      payoutRatio: getValue(summaryDetail, 'payoutRatio'),
      fiftyTwoWeekHigh: getValue(summaryDetail, 'fiftyTwoWeekHigh'),
      fiftyTwoWeekLow: getValue(summaryDetail, 'fiftyTwoWeekLow'),
      fiftyDayAverage: getValue(summaryDetail, 'fiftyDayAverage'),
      twoHundredDayAverage: getValue(summaryDetail, 'twoHundredDayAverage'),
      trailingAnnualDividendYield:
          getValue(summaryDetail, 'trailingAnnualDividendYield'),
      earningsGrowth: getValue(financialData, 'earningsGrowth'),
      averageVolume: getValue(summaryDetail, 'averageVolume'),
      trailingEps: getValue(defaultKeyStatistics, 'trailingEps'),
      forwardEps: getValue(defaultKeyStatistics, 'forwardEps'),
    );
  }

  KeyStatistics copyWith({
    double? marketCap,
    double? enterpriseValue,
    double? trailingPE,
    double? forwardPE,
    double? pegRatio,
    double? priceToSales,
    double? priceToBook,
    double? enterpriseToRevenue,
    double? enterpriseToEbitda,
    double? profitMargins,
    double? operatingMargins,
    double? returnOnAssets,
    double? returnOnEquity,
    double? revenue,
    double? revenueGrowth,
    double? grossProfits,
    double? freeCashflow,
    double? operatingCashflow,
    double? totalCash,
    double? totalDebt,
    double? debtToEquity,
    double? currentRatio,
    double? quickRatio,
    double? totalCashPerShare,
    double? revenuePerShare,
    double? beta,
    double? shortRatio,
    double? shortPercentOfFloat,
    double? sharesOutstanding,
    double? floatShares,
    double? dividendYield,
    double? dividendRate,
    double? fiveYearAvgDividendYield,
    double? payoutRatio,
    double? fiftyTwoWeekHigh,
    double? fiftyTwoWeekLow,
    double? fiftyDayAverage,
    double? twoHundredDayAverage,
    double? trailingAnnualDividendYield,
    double? earningsGrowth,
    double? averageVolume,
    double? trailingEps,
    double? forwardEps,
  }) {
    return KeyStatistics(
      marketCap: marketCap ?? this.marketCap,
      enterpriseValue: enterpriseValue ?? this.enterpriseValue,
      trailingPE: trailingPE ?? this.trailingPE,
      forwardPE: forwardPE ?? this.forwardPE,
      pegRatio: pegRatio ?? this.pegRatio,
      priceToSales: priceToSales ?? this.priceToSales,
      priceToBook: priceToBook ?? this.priceToBook,
      enterpriseToRevenue: enterpriseToRevenue ?? this.enterpriseToRevenue,
      enterpriseToEbitda: enterpriseToEbitda ?? this.enterpriseToEbitda,
      profitMargins: profitMargins ?? this.profitMargins,
      operatingMargins: operatingMargins ?? this.operatingMargins,
      returnOnAssets: returnOnAssets ?? this.returnOnAssets,
      returnOnEquity: returnOnEquity ?? this.returnOnEquity,
      revenue: revenue ?? this.revenue,
      revenueGrowth: revenueGrowth ?? this.revenueGrowth,
      grossProfits: grossProfits ?? this.grossProfits,
      freeCashflow: freeCashflow ?? this.freeCashflow,
      operatingCashflow: operatingCashflow ?? this.operatingCashflow,
      totalCash: totalCash ?? this.totalCash,
      totalDebt: totalDebt ?? this.totalDebt,
      debtToEquity: debtToEquity ?? this.debtToEquity,
      currentRatio: currentRatio ?? this.currentRatio,
      quickRatio: quickRatio ?? this.quickRatio,
      totalCashPerShare: totalCashPerShare ?? this.totalCashPerShare,
      revenuePerShare: revenuePerShare ?? this.revenuePerShare,
      beta: beta ?? this.beta,
      shortRatio: shortRatio ?? this.shortRatio,
      shortPercentOfFloat: shortPercentOfFloat ?? this.shortPercentOfFloat,
      sharesOutstanding: sharesOutstanding ?? this.sharesOutstanding,
      floatShares: floatShares ?? this.floatShares,
      dividendYield: dividendYield ?? this.dividendYield,
      dividendRate: dividendRate ?? this.dividendRate,
      fiveYearAvgDividendYield:
          fiveYearAvgDividendYield ?? this.fiveYearAvgDividendYield,
      payoutRatio: payoutRatio ?? this.payoutRatio,
      fiftyTwoWeekHigh: fiftyTwoWeekHigh ?? this.fiftyTwoWeekHigh,
      fiftyTwoWeekLow: fiftyTwoWeekLow ?? this.fiftyTwoWeekLow,
      fiftyDayAverage: fiftyDayAverage ?? this.fiftyDayAverage,
      twoHundredDayAverage: twoHundredDayAverage ?? this.twoHundredDayAverage,
      trailingAnnualDividendYield:
          trailingAnnualDividendYield ?? this.trailingAnnualDividendYield,
      earningsGrowth: earningsGrowth ?? this.earningsGrowth,
      averageVolume: averageVolume ?? this.averageVolume,
      trailingEps: trailingEps ?? this.trailingEps,
      forwardEps: forwardEps ?? this.forwardEps,
    );
  }

  factory KeyStatistics.fromJson(Map<String, dynamic> json) => KeyStatistics(
        marketCap: AnalysisData.parseNum(json['marketCap']),
        enterpriseValue: AnalysisData.parseNum(json['enterpriseValue']),
        trailingPE: AnalysisData.parseNum(json['trailingPE']),
        forwardPE: AnalysisData.parseNum(json['forwardPE']),
        pegRatio: AnalysisData.parseNum(json['pegRatio']),
        priceToSales: AnalysisData.parseNum(json['priceToSales']),
        priceToBook: AnalysisData.parseNum(json['priceToBook']),
        enterpriseToRevenue: AnalysisData.parseNum(json['enterpriseToRevenue']),
        enterpriseToEbitda: AnalysisData.parseNum(json['enterpriseToEbitda']),
        profitMargins: AnalysisData.parseNum(json['profitMargins']),
        operatingMargins: AnalysisData.parseNum(json['operatingMargins']),
        returnOnAssets: AnalysisData.parseNum(json['returnOnAssets']),
        returnOnEquity: AnalysisData.parseNum(json['returnOnEquity']),
        revenue: AnalysisData.parseNum(json['revenue']),
        revenueGrowth: AnalysisData.parseNum(json['revenueGrowth']),
        grossProfits: AnalysisData.parseNum(json['grossProfits']),
        freeCashflow: AnalysisData.parseNum(json['freeCashflow']),
        operatingCashflow: AnalysisData.parseNum(json['operatingCashflow']),
        totalCash: AnalysisData.parseNum(json['totalCash']),
        totalDebt: AnalysisData.parseNum(json['totalDebt']),
        debtToEquity: AnalysisData.parseNum(json['debtToEquity']),
        currentRatio: AnalysisData.parseNum(json['currentRatio']),
        quickRatio: AnalysisData.parseNum(json['quickRatio']),
        totalCashPerShare: AnalysisData.parseNum(json['totalCashPerShare']),
        revenuePerShare: AnalysisData.parseNum(json['revenuePerShare']),
        beta: AnalysisData.parseNum(json['beta']),
        shortRatio: AnalysisData.parseNum(json['shortRatio']),
        shortPercentOfFloat: AnalysisData.parseNum(json['shortPercentOfFloat']),
        sharesOutstanding: AnalysisData.parseNum(json['sharesOutstanding']),
        floatShares: AnalysisData.parseNum(json['floatShares']),
        dividendYield: AnalysisData.parseNum(json['dividendYield']),
        dividendRate: AnalysisData.parseNum(json['dividendRate']),
        fiveYearAvgDividendYield:
            AnalysisData.parseNum(json['fiveYearAvgDividendYield']),
        payoutRatio: AnalysisData.parseNum(json['payoutRatio']),
        fiftyTwoWeekHigh: AnalysisData.parseNum(json['fiftyTwoWeekHigh']),
        fiftyTwoWeekLow: AnalysisData.parseNum(json['fiftyTwoWeekLow']),
        fiftyDayAverage: AnalysisData.parseNum(json['fiftyDayAverage']),
        twoHundredDayAverage:
            AnalysisData.parseNum(json['twoHundredDayAverage']),
        trailingAnnualDividendYield:
            AnalysisData.parseNum(json['trailingAnnualDividendYield']),
        earningsGrowth: AnalysisData.parseNum(json['earningsGrowth']),
        averageVolume: AnalysisData.parseNum(json['averageVolume']),
        trailingEps: AnalysisData.parseNum(json['trailingEps']),
        forwardEps: AnalysisData.parseNum(json['forwardEps']),
      );

  Map<String, dynamic> toJson() => {
        'marketCap': marketCap,
        'enterpriseValue': enterpriseValue,
        'trailingPE': trailingPE,
        'forwardPE': forwardPE,
        'pegRatio': pegRatio,
        'priceToSales': priceToSales,
        'priceToBook': priceToBook,
        'enterpriseToRevenue': enterpriseToRevenue,
        'enterpriseToEbitda': enterpriseToEbitda,
        'profitMargins': profitMargins,
        'operatingMargins': operatingMargins,
        'returnOnAssets': returnOnAssets,
        'returnOnEquity': returnOnEquity,
        'revenue': revenue,
        'revenueGrowth': revenueGrowth,
        'grossProfits': grossProfits,
        'freeCashflow': freeCashflow,
        'operatingCashflow': operatingCashflow,
        'totalCash': totalCash,
        'totalDebt': totalDebt,
        'debtToEquity': debtToEquity,
        'currentRatio': currentRatio,
        'quickRatio': quickRatio,
        'totalCashPerShare': totalCashPerShare,
        'revenuePerShare': revenuePerShare,
        'beta': beta,
        'shortRatio': shortRatio,
        'shortPercentOfFloat': shortPercentOfFloat,
        'sharesOutstanding': sharesOutstanding,
        'floatShares': floatShares,
        'dividendYield': dividendYield,
        'dividendRate': dividendRate,
        'fiveYearAvgDividendYield': fiveYearAvgDividendYield,
        'payoutRatio': payoutRatio,
        'fiftyTwoWeekHigh': fiftyTwoWeekHigh,
        'fiftyTwoWeekLow': fiftyTwoWeekLow,
        'fiftyDayAverage': fiftyDayAverage,
        'twoHundredDayAverage': twoHundredDayAverage,
        'trailingAnnualDividendYield': trailingAnnualDividendYield,
        'earningsGrowth': earningsGrowth,
        'averageVolume': averageVolume,
        'trailingEps': trailingEps,
        'forwardEps': forwardEps,
      };
}

class CompanyOfficer {
  final String name;
  final String title;
  final int age;
  final String totalPay;

  CompanyOfficer({
    required this.name,
    required this.title,
    this.age = 0,
    this.totalPay = '',
  });

  factory CompanyOfficer.fromJson(Map<String, dynamic> json) => CompanyOfficer(
        name: AnalysisData.parseString(json['name']),
        title: AnalysisData.parseString(json['title']),
        age: AnalysisData.parseInt(json['age']),
        totalPay: AnalysisData.parseString(json['totalPay']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'age': age,
        'totalPay': totalPay,
      };
}

// ─── SENTIMENT MODELS ───

class MarketItem {
  final String symbol;
  final double price;
  final double change;
  final double percent;
  final List<double> history;

  MarketItem({
    required this.symbol,
    required this.price,
    required this.change,
    required this.percent,
    required this.history,
  });

  factory MarketItem.fromJson(String symbol, Map<String, dynamic> json) {
    return MarketItem(
      symbol: symbol,
      price: AnalysisData.parseNum(json['price']),
      change: AnalysisData.parseNum(json['chg']),
      percent: AnalysisData.parseNum(json['pct']),
      history: (json['closes'] as List? ?? [])
          .map((e) => AnalysisData.parseNum(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'price': price,
        'change': change,
        'percent': percent,
        'history': history,
      };
}

class ScoreComponent {
  final String name;
  final double value;
  final double weight;
  final String description;
  final String raw;

  ScoreComponent({
    required this.name,
    required this.value,
    required this.weight,
    required this.description,
    required this.raw,
  });

  factory ScoreComponent.fromJson(Map<String, dynamic> json) {
    return ScoreComponent(
      name: json['name'] ?? '',
      value: AnalysisData.parseNum(json['val']),
      weight: AnalysisData.parseNum(json['wt']),
      description: json['desc'] ?? '',
      raw: json['raw'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'weight': weight,
        'description': description,
        'raw': raw,
      };
}

class FearGreedData {
  final double score;
  final String rating;
  final Map<String, dynamic> indicators;
  final List<dynamic> history;
  final Map<String, MarketItem> market;
  final List<ScoreComponent> components;
  final Map<String, double> sectors;
  final List<NotableEvent> notableEvents;
  final Map<String, dynamic> backtest;
  final int timestamp;

  FearGreedData({
    required this.score,
    required this.rating,
    required this.indicators,
    required this.history,
    required this.market,
    required this.components,
    required this.sectors,
    required this.notableEvents,
    required this.backtest,
    required this.timestamp,
  });

  factory FearGreedData.fromJson(Map<String, dynamic> json) {
    final marketMap = <String, MarketItem>{};
    if (json['market'] != null) {
      (json['market'] as Map<String, dynamic>).forEach((key, value) {
        marketMap[key] = MarketItem.fromJson(key, value);
      });
    }

    final scoreData = json['score'] ?? {};
    final componentsList = (scoreData['components'] as List? ?? [])
        .map((e) => ScoreComponent.fromJson(e))
        .toList();

    final sectorsMap = <String, double>{};
    if (json['sectors'] != null) {
      (json['sectors'] as Map<String, dynamic>).forEach((key, value) {
        sectorsMap[key] = AnalysisData.parseNum(value);
      });
    }

    final notableList = (json['notable'] as List? ?? [])
        .map((e) => NotableEvent.fromJson(e))
        .toList();

    return FearGreedData(
      score: AnalysisData.parseNum(json['index_score'] ?? scoreData['score']),
      rating: json['index_rating'] ??
          _getRatingForScore(AnalysisData.parseNum(scoreData['score'])),
      indicators: json['indicators'] ?? {},
      history: json['index_history_local'] ?? json['recent'] ?? [],
      market: marketMap,
      components: componentsList,
      sectors: sectorsMap,
      notableEvents: notableList,
      backtest: json['backtest'] ?? {},
      timestamp: json['ts'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _getRatingForScore(double s) {
    if (s <= 20) return 'EXTREME FEAR';
    if (s <= 40) return 'FEAR';
    if (s <= 60) return 'NEUTRAL';
    if (s <= 80) return 'GREED';
    return 'EXTREME GREED';
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'rating': rating,
        'indicators': indicators,
        'history': history,
        'market': market.map((k, v) => MapEntry(k, v.toJson())),
        'components': components.map((x) => x.toJson()).toList(),
        'sectors': sectors,
        'notableEvents': notableEvents.map((x) => x.toJson()).toList(),
        'backtest': backtest,
        'timestamp': timestamp,
      };
}

class SentimentNews {
  final String title;
  final String link;
  final String publisher;
  final int time;

  SentimentNews({
    required this.title,
    required this.link,
    required this.publisher,
    required this.time,
  });

  factory SentimentNews.fromJson(Map<String, dynamic> json) => SentimentNews(
        title: json['title'] ?? '',
        link: json['url'] ?? json['link'] ?? '',
        publisher: json['source'] ?? json['publisher'] ?? '',
        time: (json['time'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'link': link,
        'publisher': publisher,
        'time': time,
      };
}
