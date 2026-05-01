import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// SIGMA ENGINE MODELS — ASKI DOJO SPECIFICATION
/// This file defines the institutional-grade engines and signals required
/// for the Sigma institutional research platform.
/// ═══════════════════════════════════════════════════════════════════════════════

enum SigmaEngineType {
  dailyCreamReport,
  deepValueSignal,
  overboughtOversold,
  trendReversal,
  balanceSheetEngine,
  sectorIntelligence,
  researchReport,
  cashFlowCalculator,
  unusualOptions,
  earningsBeat,
  marketRadar,
  earningsIntelligence,
  growthValueEngine,
  firstPositiveQuarter,
  fcfGrowthEngine,
  fcfXray,
  marginAcceleration,
  momentumGrowth,
  consistencyGrowth,
}

class SigmaEngineMetadata {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String trademark;
  final bool isVerified;

  const SigmaEngineMetadata({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.trademark = '',
    this.isVerified = false,
  });
}

class SigmaSignalEntry {
  final String ticker;
  final String companyName;
  final double score;
  final String signal;
  final String insight;
  final DateTime timestamp;
  final Map<String, dynamic> metrics;

  SigmaSignalEntry({
    required this.ticker,
    required this.companyName,
    required this.score,
    required this.signal,
    required this.insight,
    required this.timestamp,
    this.metrics = const {},
  });
}

class DailyCreamReport {
  final DateTime date;
  final String marketSynthesis;
  final List<SigmaSignalEntry> topMovers;
  final List<SigmaSignalEntry> alphaPicks;

  DailyCreamReport({
    required this.date,
    required this.marketSynthesis,
    required this.topMovers,
    required this.alphaPicks,
  });
}

class EarningsBeatSignal {
  final String ticker;
  final double beatOdds; // 0-100
  final double guidanceRaiseOdds;
  final String directionOdds;
  final String optionsSignal; // BULLISH / BEARISH
  final String analysis;

  EarningsBeatSignal({
    required this.ticker,
    required this.beatOdds,
    required this.guidanceRaiseOdds,
    required this.directionOdds,
    required this.optionsSignal,
    required this.analysis,
  });
}

class TickerIntelligence {
  final String ticker;
  final EarningsBeatSignal? earningsBeat;
  final DeepValueAnalysis? deepValue;
  final UnusualOptionsActivity? optionsActivity;
  final MomentumSignal? momentum;

  TickerIntelligence({
    required this.ticker,
    this.earningsBeat,
    this.deepValue,
    this.optionsActivity,
    this.momentum,
  });
}

class DeepValueAnalysis {
  final double fcfYield;
  final String balanceSheetStrength; // e.g., "FORTRESS"
  final String valuationStatus; // e.g., "UNDERVALUED"
  final String insight;

  DeepValueAnalysis({
    required this.fcfYield,
    required this.balanceSheetStrength,
    required this.valuationStatus,
    required this.insight,
  });
}

class UnusualOptionsActivity {
  final String alertType; // e.g., "WHALE CALLS"
  final double convictionScore;
  final String detail;

  UnusualOptionsActivity({
    required this.alertType,
    required this.convictionScore,
    required this.detail,
  });
}

class MomentumSignal {
  final String status; // e.g., "OVERSOLD REVERSAL"
  final String rsiDivergence;
  final String insight;

  MomentumSignal({
    required this.status,
    required this.rsiDivergence,
    required this.insight,
  });
}
