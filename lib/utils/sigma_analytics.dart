// ignore_for_file: curly_braces_in_flow_control_structures
/// SIGMA Advanced Analytics Engine
/// Fournit des indicateurs propriétaires et des calculs avancés
/// pour une analyse au-delà des capacités humaines standard.
library;

class SigmaAnalytics {
  /// Calcule le SIGMA Alpha Score - un indicateur propriétaire
  /// combinant momentum, qualité et valeur
  static double calculateAlphaScore({
    required double? peRatio,
    required double? roic,
    required double? debtToEquity,
    required double? grossMargin,
    required double? priceChange52W,
    required double? analystConsensus,
  }) {
    double score = 50.0; // Score de base

    // Composante Valeur (P/E)
    if (peRatio != null && peRatio > 0) {
      if (peRatio < 15) {
        score += 15; // Undervalued
      } else if (peRatio < 25)
        score += 10;
      else if (peRatio < 35)
        score += 5;
      else if (peRatio > 50)
        score -= 10; // Overvalued
    }

    // Composante Qualité (ROIC)
    if (roic != null) {
      if (roic > 25) {
        score += 20; // Excellent capital allocation
      } else if (roic > 15)
        score += 15;
      else if (roic > 10)
        score += 10;
      else if (roic < 5)
        score -= 10;
    }

    // Composante Risque (D/E)
    if (debtToEquity != null) {
      if (debtToEquity < 0.3) {
        score += 10; // Low leverage
      } else if (debtToEquity < 0.6)
        score += 5;
      else if (debtToEquity > 1.5)
        score -= 10; // High leverage risk
      else if (debtToEquity > 2.0)
        score -= 15;
    }

    // Composante Profitabilité (Gross Margin)
    if (grossMargin != null) {
      if (grossMargin > 60) {
        score += 10;
      } else if (grossMargin > 40)
        score += 5;
      else if (grossMargin < 20)
        score -= 5;
    }

    // Composante Momentum (52W Change)
    if (priceChange52W != null) {
      if (priceChange52W > 50) {
        score += 10;
      } else if (priceChange52W > 20)
        score += 5;
      else if (priceChange52W < -30)
        score -= 10;
    }

    // Composante Consensus
    if (analystConsensus != null) {
      score += (analystConsensus - 3) * 5; // Scale around 3 (Hold)
    }

    return score.clamp(0.0, 100.0);
  }

  /// Calcule l'Indicateur de Momentum Institutionnel (IMI)
  /// Détecte les mouvements smart money vs retail
  static Map<String, dynamic> calculateInstitutionalMomentum({
    required double? avgVolume,
    required double? currentVolume,
    required double? shortRatio,
    required double? insiderOwnership,
    required double? institutionalOwnership,
  }) {
    double imiScore = 50.0;
    String signal = 'NEUTRAL';
    List<String> insights = [];

    // Volume Anomaly Detection
    if (avgVolume != null && currentVolume != null && avgVolume > 0) {
      final volumeRatio = currentVolume / avgVolume;
      if (volumeRatio > 2.0) {
        imiScore += 15;
        insights.add(
          '📈 Volume ${volumeRatio.toStringAsFixed(1)}x la moyenne - Activité institutionnelle détectée',
        );
      } else if (volumeRatio > 1.5) {
        imiScore += 8;
        insights.add(
          '📊 Volume élevé ${volumeRatio.toStringAsFixed(1)}x - Intérêt accru',
        );
      } else if (volumeRatio < 0.5) {
        imiScore -= 5;
        insights.add('📉 Volume faible - Désintérêt temporaire');
      }
    }

    // Short Interest Analysis
    if (shortRatio != null) {
      if (shortRatio > 20) {
        imiScore -= 15;
        insights.add(
          '⚠️ Short Interest élevé (${shortRatio.toStringAsFixed(1)}%) - Potentiel squeeze ou bearish',
        );
      } else if (shortRatio > 10) {
        imiScore -= 5;
        insights.add(
          '🔸 Short Interest modéré (${shortRatio.toStringAsFixed(1)}%)',
        );
      } else if (shortRatio < 3) {
        imiScore += 5;
        insights.add('✅ Short Interest faible - Sentiment positif');
      }
    }

    // Institutional vs Insider Ownership
    if (institutionalOwnership != null) {
      if (institutionalOwnership > 80) {
        imiScore += 10;
        insights.add(
          '🏦 Forte présence institutionnelle (${institutionalOwnership.toStringAsFixed(0)}%)',
        );
      } else if (institutionalOwnership > 60) {
        imiScore += 5;
      } else if (institutionalOwnership < 30) {
        imiScore -= 5;
        insights.add('⚠️ Faible couverture institutionnelle');
      }
    }

    if (insiderOwnership != null && insiderOwnership > 10) {
      imiScore += 5;
      insights.add(
        '👔 Insiders alignés (${insiderOwnership.toStringAsFixed(1)}% ownership)',
      );
    }

    // Determine signal
    if (imiScore >= 70) {
      signal = 'STRONG_ACCUMULATION';
    } else if (imiScore >= 60)
      signal = 'ACCUMULATION';
    else if (imiScore <= 30)
      signal = 'DISTRIBUTION';
    else if (imiScore <= 40)
      signal = 'WEAK';

    return {
      'score': imiScore.clamp(0.0, 100.0),
      'signal': signal,
      'insights': insights,
    };
  }

  /// Calcule le Risk-Adjusted Return Score (RARS)
  /// Mesure le rendement ajusté au risque
  static double calculateRiskAdjustedScore({
    required double? beta,
    required double? sharpeRatio,
    required double? volatility,
    required double? maxDrawdown,
  }) {
    double rars = 50.0;

    // Beta Analysis
    if (beta != null) {
      if (beta >= 0.8 && beta <= 1.2) {
        rars += 10; // Market-neutral beta
      } else if (beta < 0.8) {
        rars += 5; // Defensive
      } else if (beta > 1.5) {
        rars -= 10; // High volatility
      }
    }

    // Sharpe Ratio
    if (sharpeRatio != null) {
      if (sharpeRatio > 2.0) {
        rars += 20;
      } else if (sharpeRatio > 1.0)
        rars += 10;
      else if (sharpeRatio < 0)
        rars -= 15;
    }

    // Volatility
    if (volatility != null) {
      if (volatility < 20) {
        rars += 10;
      } else if (volatility > 50)
        rars -= 15;
    }

    // Max Drawdown
    if (maxDrawdown != null) {
      if (maxDrawdown.abs() < 10) {
        rars += 10;
      } else if (maxDrawdown.abs() > 30)
        rars -= 15;
    }

    return rars.clamp(0.0, 100.0);
  }

  /// Calcule le Fair Value Estimate basé sur DCF simplifié
  static Map<String, dynamic> calculateFairValue({
    required double currentPrice,
    required double? eps,
    required double? revenueGrowth,
    required double? peRatio,
    required double? industryPE,
    required double? dcfValue,
  }) {
    List<double> estimates = [];
    Map<String, double> methods = {};

    // Méthode 1: DCF (si disponible)
    if (dcfValue != null && dcfValue > 0) {
      estimates.add(dcfValue);
      methods['DCF'] = dcfValue;
    }

    // Méthode 2: EPS * Industry P/E
    if (eps != null && industryPE != null && eps > 0) {
      final epsValue = eps * industryPE;
      estimates.add(epsValue);
      methods['EPS Multiple'] = epsValue;
    }

    // Méthode 3: PEG Ratio estimation
    if (eps != null && revenueGrowth != null && revenueGrowth > 0) {
      // Fair P/E should equal growth rate
      final pegValue = eps * revenueGrowth;
      estimates.add(pegValue);
      methods['PEG'] = pegValue;
    }

    if (estimates.isEmpty) {
      return {
        'fairValue': currentPrice,
        'upside': 0.0,
        'confidence': 'LOW',
        'methods': methods,
      };
    }

    final avgFairValue = estimates.reduce((a, b) => a + b) / estimates.length;
    final upside = ((avgFairValue - currentPrice) / currentPrice) * 100;

    String confidence = 'MEDIUM';
    if (estimates.length >= 3) confidence = 'HIGH';
    if (estimates.length == 1) confidence = 'LOW';

    return {
      'fairValue': avgFairValue,
      'upside': upside,
      'confidence': confidence,
      'methods': methods,
      'isUndervalued': upside > 15,
      'isOvervalued': upside < -15,
    };
  }

  /// Génère un Trade Setup optimisé basé sur l'analyse technique
  static Map<String, dynamic> generateOptimalTradeSetup({
    required double currentPrice,
    required double? support,
    required double? resistance,
    required double? atr, // Average True Range
    required double targetUpside,
  }) {
    // Calcul de la zone d'entrée (près du support)
    final entryLow = support ?? (currentPrice * 0.97);
    final entryHigh = support != null ? support * 1.02 : currentPrice;

    // Calcul du target (basé sur resistance ou upside)
    final target = resistance ?? (currentPrice * (1 + targetUpside / 100));

    // Calcul du stop loss (ATR-based ou pourcentage)
    final stopLoss = atr != null
        ? currentPrice - (atr * 2)
        : currentPrice * 0.93;

    // Risk/Reward Ratio
    final risk = currentPrice - stopLoss;
    final reward = target - currentPrice;
    final rrRatio = risk > 0 ? reward / risk : 0.0;

    return {
      'entryZone':
          '\$${entryLow.toStringAsFixed(2)} - \$${entryHigh.toStringAsFixed(2)}',
      'targetPrice': '\$${target.toStringAsFixed(2)}',
      'stopLoss': '\$${stopLoss.toStringAsFixed(2)}',
      'riskRewardRatio': '${rrRatio.toStringAsFixed(1)}:1',
      'riskPercent': ((risk / currentPrice) * 100).toStringAsFixed(1),
      'rewardPercent': ((reward / currentPrice) * 100).toStringAsFixed(1),
      'isViable': rrRatio >= 2.0,
    };
  }

  /// Calcule le Sentiment Composite Score
  static double calculateCompositeSentiment({
    double? analystSentiment,
    double? socialSentiment,
    double? insiderSentiment,
    double? technicalSentiment,
  }) {
    List<double> scores = [];
    List<double> weights = [];

    if (analystSentiment != null) {
      scores.add(analystSentiment);
      weights.add(0.35); // 35% weight
    }

    if (socialSentiment != null) {
      scores.add(socialSentiment);
      weights.add(0.15); // 15% weight
    }

    if (insiderSentiment != null) {
      scores.add(insiderSentiment);
      weights.add(0.30); // 30% weight
    }

    if (technicalSentiment != null) {
      scores.add(technicalSentiment);
      weights.add(0.20); // 20% weight
    }

    if (scores.isEmpty) return 50.0;

    // Normalize weights
    final totalWeight = weights.reduce((a, b) => a + b);
    double weightedSum = 0;
    for (int i = 0; i < scores.length; i++) {
      weightedSum += scores[i] * (weights[i] / totalWeight);
    }

    return weightedSum.clamp(0.0, 100.0);
  }

  /// Génère une interprétation textuelle du score SIGMA
  static String interpretSigmaScore(double score) {
    if (score >= 80) {
      return 'OPPORTUNITÉ EXCEPTIONNELLE - Tous les indicateurs alignés';
    }
    if (score >= 70) return 'SIGNAL FORT - Conditions favorables pour entrée';
    if (score >= 60) return 'POSITIF - Mérite attention avec due diligence';
    if (score >= 50) return 'NEUTRE - Pas de signal directionnel clair';
    if (score >= 40) return 'PRUDENCE - Facteurs de risque présents';
    if (score >= 30) return 'FAIBLE - Conditions défavorables';
    return 'ÉVITER - Risques multiples détectés';
  }

  /// Calcule le momentum technique composite
  static Map<String, dynamic> calculateTechnicalMomentum({
    double? rsi,
    double? macdHistogram,
    double? priceVsSMA50,
    double? priceVsSMA200,
    double? adx,
  }) {
    double score = 50.0;
    String trend = 'NEUTRAL';
    List<String> signals = [];

    // RSI Analysis
    if (rsi != null) {
      if (rsi > 70) {
        score -= 10;
        signals.add('⚠️ RSI Suracheté (${rsi.toStringAsFixed(0)})');
      } else if (rsi < 30) {
        score += 10;
        signals.add(
          '✅ RSI Survendu (${rsi.toStringAsFixed(0)}) - Potentiel rebond',
        );
      } else if (rsi > 50 && rsi < 70) {
        score += 5;
        signals.add('📈 RSI Bullish (${rsi.toStringAsFixed(0)})');
      }
    }

    // MACD Analysis
    if (macdHistogram != null) {
      if (macdHistogram > 0) {
        score += 10;
        signals.add('📊 MACD Positif - Momentum haussier');
      } else {
        score -= 5;
        signals.add('📉 MACD Négatif - Momentum baissier');
      }
    }

    // SMA Analysis
    if (priceVsSMA50 != null && priceVsSMA200 != null) {
      if (priceVsSMA50 > 0 && priceVsSMA200 > 0) {
        score += 15;
        trend = 'UPTREND';
        signals.add(
          '🚀 Au-dessus SMA50 et SMA200 - Tendance haussière confirmée',
        );
      } else if (priceVsSMA50 < 0 && priceVsSMA200 < 0) {
        score -= 15;
        trend = 'DOWNTREND';
        signals.add('🔻 Sous SMA50 et SMA200 - Tendance baissière');
      } else if (priceVsSMA50 > 0 && priceVsSMA200 < 0) {
        score += 5;
        trend = 'RECOVERY';
        signals.add('🔄 Reprise potentielle - Prix au-dessus SMA50');
      }
    }

    // ADX (Trend Strength)
    if (adx != null) {
      if (adx > 25) {
        signals.add('💪 Tendance forte (ADX: ${adx.toStringAsFixed(0)})');
        if (trend == 'UPTREND') score += 5;
      } else if (adx < 20) {
        signals.add('〰️ Marché en range (ADX: ${adx.toStringAsFixed(0)})');
      }
    }

    return {
      'score': score.clamp(0.0, 100.0),
      'trend': trend,
      'signals': signals,
      'strength': adx ?? 0,
    };
  }
}

/// Extension pour formater les nombres de manière professionnelle
extension ProfessionalFormat on num {
  String toCompactString() {
    if (this >= 1e12) return '${(this / 1e12).toStringAsFixed(2)}T';
    if (this >= 1e9) return '${(this / 1e9).toStringAsFixed(2)}B';
    if (this >= 1e6) return '${(this / 1e6).toStringAsFixed(2)}M';
    if (this >= 1e3) return '${(this / 1e3).toStringAsFixed(1)}K';
    return toStringAsFixed(2);
  }

  String toPercentString() {
    return '${toStringAsFixed(2)}%';
  }
}
