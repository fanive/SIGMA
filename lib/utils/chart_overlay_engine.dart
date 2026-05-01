// ignore_for_file: curly_braces_in_flow_control_structures, dangling_library_doc_comments, prefer_const_constructors

/// ═══════════════════════════════════════════════════════════════════════════
/// SIGMA Chart Overlay Engine
/// ═══════════════════════════════════════════════════════════════════════════
/// Pure-Dart implementation of Pine Script-style technical overlays:
///   • SMA 50 / SMA 200 (Tendance Macro)
///   • MACD (12, 26, 9) — Momentum
///   • OBV (On-Balance Volume) — Volume Institutionnel
///   • Golden / Death Cross detection with MACD+OBV confirmation
///
/// All computations run on the client from raw OHLCV data.
/// No external dependencies — used directly by `InteractiveStockChart`.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class ChartOverlayEngine {
  // ── SMA ───────────────────────────────────────────────────────────────
  /// Compute Simple Moving Average for a given period.
  /// Returns a list of the same length as [closes], with `null` for indices
  /// where there are fewer than [period] data points.
  static List<double?> sma(List<double> closes, int period) {
    final result = List<double?>.filled(closes.length, null);
    if (closes.length < period) return result;

    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += closes[i];
    }
    result[period - 1] = sum / period;

    for (int i = period; i < closes.length; i++) {
      sum += closes[i] - closes[i - period];
      result[i] = sum / period;
    }
    return result;
  }

  // ── EMA ───────────────────────────────────────────────────────────────
  /// Compute Exponential Moving Average for a given period.
  static List<double?> ema(List<double> data, int period) {
    final result = List<double?>.filled(data.length, null);
    if (data.length < period) return result;

    // Seed with SMA
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += data[i];
    }
    final multiplier = 2.0 / (period + 1);
    result[period - 1] = sum / period;

    for (int i = period; i < data.length; i++) {
      result[i] = (data[i] - result[i - 1]!) * multiplier + result[i - 1]!;
    }
    return result;
  }

  // ── MACD (12, 26, 9) ────────────────────────────────────────────────
  /// Returns a [MacdResult] with macdLine, signalLine, and histogram.
  static MacdResult macd(List<double> closes, {int fast = 12, int slow = 26, int signal = 9}) {
    final emaFast = ema(closes, fast);
    final emaSlow = ema(closes, slow);

    final macdLine = List<double?>.filled(closes.length, null);
    final macdValues = <double>[];
    final macdIndices = <int>[];

    for (int i = 0; i < closes.length; i++) {
      if (emaFast[i] != null && emaSlow[i] != null) {
        macdLine[i] = emaFast[i]! - emaSlow[i]!;
        macdValues.add(macdLine[i]!);
        macdIndices.add(i);
      }
    }

    // Signal line = EMA(9) of MACD line
    final signalEma = ema(macdValues, signal);
    final signalLine = List<double?>.filled(closes.length, null);
    final histogram = List<double?>.filled(closes.length, null);

    for (int j = 0; j < signalEma.length; j++) {
      final idx = macdIndices[j];
      if (signalEma[j] != null) {
        signalLine[idx] = signalEma[j];
        histogram[idx] = macdLine[idx]! - signalEma[j]!;
      }
    }

    return MacdResult(
      macdLine: macdLine,
      signalLine: signalLine,
      histogram: histogram,
    );
  }

  // ── OBV (On-Balance Volume) ─────────────────────────────────────────
  /// Compute On-Balance Volume from closes and volumes.
  static List<double> obv(List<double> closes, List<double> volumes) {
    final result = List<double>.filled(closes.length, 0);
    if (closes.isEmpty) return result;

    result[0] = volumes[0];
    for (int i = 1; i < closes.length; i++) {
      if (closes[i] > closes[i - 1]) {
        result[i] = result[i - 1] + volumes[i];
      } else if (closes[i] < closes[i - 1]) {
        result[i] = result[i - 1] - volumes[i];
      } else {
        result[i] = result[i - 1];
      }
    }
    return result;
  }

  // ── CROSS EVENT DETECTION ───────────────────────────────────────────
  /// Detects Golden Cross and Death Cross events between SMA50 and SMA200,
  /// with MACD and OBV confirmation for strength classification.
  static List<CrossEvent> detectCrosses(
    List<double> closes,
    List<double> volumes, {
    int smaMidPeriod = 50,
    int smaLongPeriod = 200,
  }) {
    final smaMid = sma(closes, smaMidPeriod);
    final smaLong = sma(closes, smaLongPeriod);
    final macdResult = macd(closes);
    final obvValues = obv(closes, volumes);
    final obvSma = sma(obvValues, 21);

    final events = <CrossEvent>[];

    for (int i = 1; i < closes.length; i++) {
      if (smaMid[i] == null || smaLong[i] == null ||
          smaMid[i - 1] == null || smaLong[i - 1] == null) {
        continue;
      }

      final prevDiff = smaMid[i - 1]! - smaLong[i - 1]!;
      final currDiff = smaMid[i]! - smaLong[i]!;

      final isMacdBullish = macdResult.histogram[i] != null && macdResult.histogram[i]! > 0;
      final isObvBullish = obvSma[i] != null && obvValues[i] > obvSma[i]!;

      // Golden Cross: SMA50 crosses above SMA200
      if (prevDiff <= 0 && currDiff > 0) {
        final isStrong = isMacdBullish && isObvBullish;
        events.add(CrossEvent(
          index: i,
          price: closes[i],
          type: CrossType.goldenCross,
          strength: isStrong ? CrossStrength.strong : CrossStrength.weak,
          macdConfirmed: isMacdBullish,
          obvConfirmed: isObvBullish,
        ));
      }

      // Death Cross: SMA50 crosses below SMA200
      if (prevDiff >= 0 && currDiff < 0) {
        final isBearFullConfirm = !isMacdBullish && !isObvBullish;
        events.add(CrossEvent(
          index: i,
          price: closes[i],
          type: CrossType.deathCross,
          strength: isBearFullConfirm ? CrossStrength.strong : CrossStrength.weak,
          macdConfirmed: !isMacdBullish,
          obvConfirmed: !isObvBullish,
        ));
      }
    }

    return events;
  }

  // ── FULL OVERLAY COMPUTATION ────────────────────────────────────────
  /// One-shot computation of all overlays from raw OHLCV data.
  /// This is the main entry point called by the chart widget.
  static ChartOverlays compute(List<Map<String, dynamic>> ohlcv) {
    if (ohlcv.length < 2) {
      return ChartOverlays.empty();
    }

    final closes = ohlcv.map((e) => (e['close'] as num?)?.toDouble() ?? 0.0).toList();
    final volumes = ohlcv.map((e) => (e['volume'] as num?)?.toDouble() ?? 0.0).toList();

    // ADAPTIVE PERIODS: Ensure we always show MAs and Crosses even on short ranges
    int midPeriod = 50;
    int longPeriod = 200;
    
    if (closes.length < 200) {
      if (closes.length > 50) {
        midPeriod = 15;
        longPeriod = 45;
      } else {
        midPeriod = 7;
        longPeriod = 21;
      }
    }

    final sma50 = sma(closes, midPeriod);
    final sma200 = sma(closes, longPeriod);
    final macdResult = macd(closes);
    final obvValues = obv(closes, volumes);
    final obvSma21 = sma(obvValues, 21);
    final crossEvents = detectCrosses(closes, volumes, smaMidPeriod: midPeriod, smaLongPeriod: longPeriod);

    // Determine current regime
    String regime = 'NEUTRAL';
    if (closes.length >= 200 && sma50.last != null && sma200.last != null) {
      if (sma50.last! > sma200.last!) {
        regime = 'BULLISH';
      } else {
        regime = 'BEARISH';
      }
    }

    return ChartOverlays(
      fastPeriod: midPeriod,
      slowPeriod: longPeriod,
      sma50: sma50,
      sma200: sma200,
      macd: macdResult,
      obv: obvValues,
      obvSma: obvSma21,
      crossEvents: crossEvents,
      regime: regime,
    );
  }
}

// ── DATA MODELS ──────────────────────────────────────────────────────────

class MacdResult {
  final List<double?> macdLine;
  final List<double?> signalLine;
  final List<double?> histogram;

  const MacdResult({
    required this.macdLine,
    required this.signalLine,
    required this.histogram,
  });
}

enum CrossType { goldenCross, deathCross }
enum CrossStrength { strong, weak }

class CrossEvent {
  final int index;
  final double price;
  final CrossType type;
  final CrossStrength strength;
  final bool macdConfirmed;
  final bool obvConfirmed;

  const CrossEvent({
    required this.index,
    required this.price,
    required this.type,
    required this.strength,
    required this.macdConfirmed,
    required this.obvConfirmed,
  });

  bool get isGolden => type == CrossType.goldenCross;
  bool get isDeath => type == CrossType.deathCross;
  bool get isStrong => strength == CrossStrength.strong;
}

class ChartOverlays {
  final int fastPeriod;
  final int slowPeriod;
  final List<double?> sma50;
  final List<double?> sma200;
  final MacdResult macd;
  final List<double> obv;
  final List<double?> obvSma;
  final List<CrossEvent> crossEvents;
  final String regime;

  const ChartOverlays({
    required this.fastPeriod,
    required this.slowPeriod,
    required this.sma50,
    required this.sma200,
    required this.macd,
    required this.obv,
    required this.obvSma,
    required this.crossEvents,
    required this.regime,
  });

  factory ChartOverlays.empty() => const ChartOverlays(
    fastPeriod: 50,
    slowPeriod: 200,
    sma50: [],
    sma200: [],
    macd: MacdResult(macdLine: [], signalLine: [], histogram: []),
    obv: [],
    obvSma: [],
    crossEvents: [],
    regime: 'NEUTRAL',
  );

  bool get isEmpty => sma50.isEmpty;

  /// Latest MACD histogram value (for the status badge)
  double? get latestMacdHist {
    for (int i = macd.histogram.length - 1; i >= 0; i--) {
      if (macd.histogram[i] != null) return macd.histogram[i];
    }
    return null;
  }

  /// Is OBV currently bullish?
  bool get isObvBullish {
    if (obv.isEmpty || obvSma.isEmpty) return false;
    final lastObvSma = obvSma.lastWhere((e) => e != null, orElse: () => null);
    return lastObvSma != null && obv.last > lastObvSma;
  }
}
