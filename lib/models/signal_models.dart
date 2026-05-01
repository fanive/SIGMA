/// Modèles de données pour les signaux prédictifs SIGMA
/// Ces modèles permettent de structurer les signaux d'investissement avancés
library;

/// Signal technique individuel
class TechnicalSignal {
  final String indicator;
  final double value;
  final String signalType;
  final double strength;
  final String interpretation;
  final String timeframe;

  TechnicalSignal({
    required this.indicator,
    required this.value,
    required this.signalType,
    required this.strength,
    required this.interpretation,
    required this.timeframe,
  });

  Map<String, dynamic> toJson() => {
    'indicator': indicator,
    'value': value,
    'signalType': signalType,
    'strength': strength,
    'interpretation': interpretation,
    'timeframe': timeframe,
  };
}

/// Données de momentum
class MomentumData {
  final double roc5;
  final double roc10;
  final double roc20;
  final double velocity;
  final double overallScore;
  final String trend;
  final bool isAccelerating;

  MomentumData({
    required this.roc5,
    required this.roc10,
    required this.roc20,
    required this.velocity,
    required this.overallScore,
    required this.trend,
    required this.isAccelerating,
  });

  factory MomentumData.empty() => MomentumData(
    roc5: 0,
    roc10: 0,
    roc20: 0,
    velocity: 0,
    overallScore: 50,
    trend: 'NEUTRAL',
    isAccelerating: false,
  );

  Map<String, dynamic> toJson() => {
    'roc5': roc5,
    'roc10': roc10,
    'roc20': roc20,
    'velocity': velocity,
    'overallScore': overallScore,
    'trend': trend,
    'isAccelerating': isAccelerating,
  };
}

/// Flux Smart Money vs Retail
class SmartMoneyFlow {
  final double institutionalPercent;
  final double insiderPercent;
  final int netInsiderBuys;
  final double netInsiderVolume;
  final double retailSentiment;
  final double smartMoneyScore;
  final String divergenceType;
  final String interpretation;

  SmartMoneyFlow({
    required this.institutionalPercent,
    required this.insiderPercent,
    required this.netInsiderBuys,
    required this.netInsiderVolume,
    required this.retailSentiment,
    required this.smartMoneyScore,
    required this.divergenceType,
    required this.interpretation,
  });

  factory SmartMoneyFlow.empty() => SmartMoneyFlow(
    institutionalPercent: 0,
    insiderPercent: 0,
    netInsiderBuys: 0,
    netInsiderVolume: 0,
    retailSentiment: 50,
    smartMoneyScore: 50,
    divergenceType: 'UNKNOWN',
    interpretation: 'Données insuffisantes',
  );

  Map<String, dynamic> toJson() => {
    'institutionalPercent': institutionalPercent,
    'insiderPercent': insiderPercent,
    'netInsiderBuys': netInsiderBuys,
    'netInsiderVolume': netInsiderVolume,
    'retailSentiment': retailSentiment,
    'smartMoneyScore': smartMoneyScore,
    'divergenceType': divergenceType,
    'interpretation': interpretation,
  };
}

/// Signaux de sentiment multi-sources
class SentimentSignals {
  final double socialScore;
  final double newsScore;
  final double analystScore;
  final double compositeScore;
  final String trend;

  SentimentSignals({
    required this.socialScore,
    required this.newsScore,
    required this.analystScore,
    required this.compositeScore,
    required this.trend,
  });

  factory SentimentSignals.empty() => SentimentSignals(
    socialScore: 50,
    newsScore: 50,
    analystScore: 50,
    compositeScore: 50,
    trend: 'NEUTRAL',
  );

  Map<String, dynamic> toJson() => {
    'socialScore': socialScore,
    'newsScore': newsScore,
    'analystScore': analystScore,
    'compositeScore': compositeScore,
    'trend': trend,
  };
}

/// Signal de divergence (très puissant)
class DivergenceSignal {
  final String type;
  final String indicator;
  final double strength;
  final String description;
  final String implication;
  final String reliability;

  DivergenceSignal({
    required this.type,
    required this.indicator,
    required this.strength,
    required this.description,
    required this.implication,
    required this.reliability,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'indicator': indicator,
    'strength': strength,
    'description': description,
    'implication': implication,
    'reliability': reliability,
  };
}

/// Analyse du volume
class VolumeAnalysis {
  final double averageVolume;
  final double lastVolume;
  final double volumeRatio;
  final String trend;
  final bool isVolumeConfirming;
  final String interpretation;

  VolumeAnalysis({
    required this.averageVolume,
    required this.lastVolume,
    required this.volumeRatio,
    required this.trend,
    required this.isVolumeConfirming,
    required this.interpretation,
  });

  factory VolumeAnalysis.empty() => VolumeAnalysis(
    averageVolume: 0,
    lastVolume: 0,
    volumeRatio: 1,
    trend: 'NEUTRAL',
    isVolumeConfirming: false,
    interpretation: 'Volume normal',
  );

  Map<String, dynamic> toJson() => {
    'averageVolume': averageVolume,
    'lastVolume': lastVolume,
    'volumeRatio': volumeRatio,
    'trend': trend,
    'isVolumeConfirming': isVolumeConfirming,
    'interpretation': interpretation,
  };
}

/// Analyse des tendances multi-timeframe
class TrendAnalysis {
  final String shortTermTrend;
  final String mediumTermTrend;
  final String longTermTrend;
  final String overallTrend;
  final double support;
  final double resistance;
  final int trendStrength;

  TrendAnalysis({
    required this.shortTermTrend,
    required this.mediumTermTrend,
    required this.longTermTrend,
    required this.overallTrend,
    required this.support,
    required this.resistance,
    required this.trendStrength,
  });

  factory TrendAnalysis.empty() => TrendAnalysis(
    shortTermTrend: 'NEUTRAL',
    mediumTermTrend: 'NEUTRAL',
    longTermTrend: 'NEUTRAL',
    overallTrend: 'NEUTRAL',
    support: 0,
    resistance: 0,
    trendStrength: 50,
  );

  Map<String, dynamic> toJson() => {
    'shortTermTrend': shortTermTrend,
    'mediumTermTrend': mediumTermTrend,
    'longTermTrend': longTermTrend,
    'overallTrend': overallTrend,
    'support': support,
    'resistance': resistance,
    'trendStrength': trendStrength,
  };
}

/// Recommandation d'investissement finale
class InvestmentRecommendation {
  final String
  action; // STRONG_BUY, BUY, ACCUMULATE, HOLD, REDUCE, SELL, STRONG_SELL
  final double confidence;
  final String entryZone;
  final String targetPrice;
  final String stopLoss;
  final List<String> reasons;
  final double riskRewardRatio;
  final String timeHorizon;

  InvestmentRecommendation({
    required this.action,
    required this.confidence,
    required this.entryZone,
    required this.targetPrice,
    required this.stopLoss,
    required this.reasons,
    required this.riskRewardRatio,
    required this.timeHorizon,
  });

  factory InvestmentRecommendation.empty() => InvestmentRecommendation(
    action: 'HOLD',
    confidence: 50,
    entryZone: 'N/A',
    targetPrice: 'N/A',
    stopLoss: 'N/A',
    reasons: ['Analyse en cours...'],
    riskRewardRatio: 1.0,
    timeHorizon: 'MEDIUM_TERM',
  );

  /// Retourne la couleur associée à l'action
  String get actionColor {
    switch (action) {
      case 'STRONG_BUY':
        return '#00C853'; // Vert vif
      case 'BUY':
        return '#4CAF50'; // Vert
      case 'ACCUMULATE':
        return '#8BC34A'; // Vert clair
      case 'HOLD':
        return '#FFC107'; // Jaune
      case 'REDUCE':
        return '#FF9800'; // Orange
      case 'SELL':
        return '#F44336'; // Rouge
      case 'STRONG_SELL':
        return '#B71C1C'; // Rouge foncé
      default:
        return '#9E9E9E'; // Gris
    }
  }

  /// Retourne le label français de l'action
  String get actionLabel {
    switch (action) {
      case 'STRONG_BUY':
        return 'ACHAT FORT';
      case 'BUY':
        return 'ACHETER';
      case 'ACCUMULATE':
        return 'ACCUMULER';
      case 'HOLD':
        return 'CONSERVER';
      case 'REDUCE':
        return 'RÉDUIRE';
      case 'SELL':
        return 'VENDRE';
      case 'STRONG_SELL':
        return 'VENTE URGENTE';
      default:
        return 'ATTENDRE';
    }
  }

  Map<String, dynamic> toJson() => {
    'action': action,
    'confidence': confidence,
    'entryZone': entryZone,
    'targetPrice': targetPrice,
    'stopLoss': stopLoss,
    'reasons': reasons,
    'riskRewardRatio': riskRewardRatio,
    'timeHorizon': timeHorizon,
  };
}

/// Analyse prédictive complète
class PredictiveAnalysis {
  final String ticker;
  final DateTime timestamp;
  final double overallScore;
  final InvestmentRecommendation recommendation;
  final List<TechnicalSignal> technicalSignals;
  final MomentumData momentum;
  final SmartMoneyFlow smartMoneyFlow;
  final SentimentSignals sentiment;
  final List<DivergenceSignal> divergences;
  final VolumeAnalysis volumeAnalysis;
  final TrendAnalysis trendAnalysis;

  PredictiveAnalysis({
    required this.ticker,
    required this.timestamp,
    required this.overallScore,
    required this.recommendation,
    required this.technicalSignals,
    required this.momentum,
    required this.smartMoneyFlow,
    required this.sentiment,
    required this.divergences,
    required this.volumeAnalysis,
    required this.trendAnalysis,
  });

  factory PredictiveAnalysis.empty(String ticker) => PredictiveAnalysis(
    ticker: ticker,
    timestamp: DateTime.now(),
    overallScore: 50,
    recommendation: InvestmentRecommendation.empty(),
    technicalSignals: [],
    momentum: MomentumData.empty(),
    smartMoneyFlow: SmartMoneyFlow.empty(),
    sentiment: SentimentSignals.empty(),
    divergences: [],
    volumeAnalysis: VolumeAnalysis.empty(),
    trendAnalysis: TrendAnalysis.empty(),
  );

  /// Score global formaté
  String get formattedScore => overallScore.toStringAsFixed(1);

  /// Label du score
  String get scoreLabel {
    if (overallScore >= 75) return 'EXCELLENT';
    if (overallScore >= 60) return 'BON';
    if (overallScore >= 45) return 'NEUTRE';
    if (overallScore >= 30) return 'FAIBLE';
    return 'CRITIQUE';
  }

  /// Couleur du score
  String get scoreColor {
    if (overallScore >= 75) return '#00C853';
    if (overallScore >= 60) return '#4CAF50';
    if (overallScore >= 45) return '#FFC107';
    if (overallScore >= 30) return '#FF9800';
    return '#F44336';
  }

  /// Nombre de signaux haussiers
  int get bullishSignalsCount {
    int count = 0;
    for (var sig in technicalSignals) {
      if (sig.signalType.contains('BULLISH') ||
          sig.signalType.contains('OVERSOLD')) {
        count++;
      }
    }
    if (momentum.trend.contains('BULLISH')) count++;
    if (smartMoneyFlow.smartMoneyScore > 60) count++;
    for (var div in divergences) {
      if (div.type == 'BULLISH_DIVERGENCE') count++;
    }
    return count;
  }

  /// Nombre de signaux baissiers
  int get bearishSignalsCount {
    int count = 0;
    for (var sig in technicalSignals) {
      if (sig.signalType.contains('BEARISH') ||
          sig.signalType.contains('OVERBOUGHT')) {
        count++;
      }
    }
    if (momentum.trend.contains('BEARISH')) count++;
    if (smartMoneyFlow.smartMoneyScore < 40) count++;
    for (var div in divergences) {
      if (div.type == 'BEARISH_DIVERGENCE') count++;
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'ticker': ticker,
    'timestamp': timestamp.toIso8601String(),
    'overallScore': overallScore,
    'recommendation': recommendation.toJson(),
    'technicalSignals': technicalSignals.map((s) => s.toJson()).toList(),
    'momentum': momentum.toJson(),
    'smartMoneyFlow': smartMoneyFlow.toJson(),
    'sentiment': sentiment.toJson(),
    'divergences': divergences.map((d) => d.toJson()).toList(),
    'volumeAnalysis': volumeAnalysis.toJson(),
    'trendAnalysis': trendAnalysis.toJson(),
  };
}
