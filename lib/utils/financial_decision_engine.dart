import '../models/sigma_models.dart';

class FinancialDecisionFactor {
  final String category;
  final String label;
  final String value;
  final double points;
  final String thesis;

  const FinancialDecisionFactor({
    required this.category,
    required this.label,
    required this.value,
    required this.points,
    required this.thesis,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'label': label,
        'value': value,
        'points': points,
        'thesis': thesis,
      };
}

class FinancialDecisionResult {
  final double score;
  final double confidence;
  final String verdict;
  final String riskLevel;
  final String summary;
  final String methodology;
  final String alphaRecommendation;
  final double? currentPrice;
  final double? targetPrice;
  final double? upside;
  final List<FinancialDecisionFactor> factors;
  final List<String> positives;
  final List<String> negatives;
  final List<String> recommendationSteps;

  const FinancialDecisionResult({
    required this.score,
    required this.confidence,
    required this.verdict,
    required this.riskLevel,
    required this.summary,
    required this.methodology,
    required this.alphaRecommendation,
    required this.currentPrice,
    required this.targetPrice,
    required this.upside,
    required this.factors,
    required this.positives,
    required this.negatives,
    required this.recommendationSteps,
  });

  List<Map<String, dynamic>> get factorRows =>
      factors.map((factor) => factor.toJson()).toList(growable: false);
}

class FinancialDecisionEngine {
  static FinancialDecisionResult evaluate(
    AnalysisData data, {
    String language = 'FR',
  }) {
    final isFr = language.toUpperCase().startsWith('FR');
    final factors = <FinancialDecisionFactor>[];
    final ks = data.keyStatistics;
    var score = 50.0;
    var riskPenalty = 0.0;

    void add({
      required String category,
      required String label,
      required String value,
      required double points,
      required String thesis,
      double risk = 0,
    }) {
      if (points == 0) return;
      score += points;
      riskPenalty += risk;
      factors.add(
        FinancialDecisionFactor(
          category: category,
          label: label,
          value: value,
          points: points,
          thesis: thesis,
        ),
      );
    }

    final current = _parsePrice(data.price);
    final explicitTarget = data.targetPriceValue ??
        _parsePrice(data.tradeSetup.cleanTargetPrice, emptyAsNull: true);
    final upside = current != null && current > 0 && explicitTarget != null
        ? (explicitTarget - current) / current
        : null;

    if (ks != null) {
      final pe = _positive(ks.trailingPE);
      if (pe != null) {
        if (pe <= 18) {
          add(
            category: 'Valorisation',
            label: 'P/E TTM',
            value: '${pe.toStringAsFixed(1)}x',
            points: 8,
            thesis: isFr
                ? 'Valorisation attractive: P/E TTM a ${pe.toStringAsFixed(1)}x, sous un seuil raisonnable pour une societe rentable.'
                : 'Attractive valuation: TTM P/E at ${pe.toStringAsFixed(1)}x, below a reasonable threshold for a profitable company.',
          );
        } else if (pe <= 28) {
          add(
            category: 'Valorisation',
            label: 'P/E TTM',
            value: '${pe.toStringAsFixed(1)}x',
            points: 4,
            thesis: isFr
                ? 'Valorisation acceptable: P/E TTM a ${pe.toStringAsFixed(1)}x, encore defendable si la qualite reste solide.'
                : 'Acceptable valuation: TTM P/E at ${pe.toStringAsFixed(1)}x, still defensible if quality remains solid.',
          );
        } else if (pe >= 50) {
          add(
            category: 'Valorisation',
            label: 'P/E TTM',
            value: '${pe.toStringAsFixed(1)}x',
            points: -8,
            thesis: isFr
                ? 'Valorisation exigeante: P/E TTM a ${pe.toStringAsFixed(1)}x, le marche paie deja beaucoup de croissance future.'
                : 'Demanding valuation: TTM P/E at ${pe.toStringAsFixed(1)}x, with substantial future growth already priced in.',
            risk: 1.5,
          );
        } else if (pe >= 35) {
          add(
            category: 'Valorisation',
            label: 'P/E TTM',
            value: '${pe.toStringAsFixed(1)}x',
            points: -5,
            thesis: isFr
                ? 'Multiple eleve: P/E TTM a ${pe.toStringAsFixed(1)}x, la marge d erreur est reduite.'
                : 'Elevated multiple: TTM P/E at ${pe.toStringAsFixed(1)}x, leaving less room for error.',
            risk: 1,
          );
        }
      }

      final peg = _positive(ks.pegRatio);
      if (peg != null) {
        if (peg <= 1.4) {
          add(
            category: 'Valorisation',
            label: 'PEG',
            value: peg.toStringAsFixed(2),
            points: 4,
            thesis: isFr
                ? 'PEG favorable a ${peg.toStringAsFixed(2)}, la croissance semble payer une partie du multiple.'
                : 'Favorable PEG at ${peg.toStringAsFixed(2)}, growth appears to justify part of the multiple.',
          );
        } else if (peg >= 3) {
          add(
            category: 'Valorisation',
            label: 'PEG',
            value: peg.toStringAsFixed(2),
            points: -4,
            thesis: isFr
                ? 'PEG tendu a ${peg.toStringAsFixed(2)}, le prix parait cher au regard de la croissance.'
                : 'Stretched PEG at ${peg.toStringAsFixed(2)}, price looks expensive relative to growth.',
            risk: 0.5,
          );
        }
      }

      final revenueGrowth = ks.revenueGrowth;
      if (revenueGrowth >= 0.15) {
        add(
          category: 'Croissance',
          label: 'Croissance CA',
          value: _pct(revenueGrowth),
          points: 8,
          thesis: isFr
              ? 'Croissance du chiffre d affaires soutenue a ${_pct(revenueGrowth)}, signal positif pour le levier operationnel.'
              : 'Strong revenue growth at ${_pct(revenueGrowth)}, a positive signal for operating leverage.',
        );
      } else if (revenueGrowth >= 0.05) {
        add(
          category: 'Croissance',
          label: 'Croissance CA',
          value: _pct(revenueGrowth),
          points: 4,
          thesis: isFr
              ? 'Croissance du chiffre d affaires positive a ${_pct(revenueGrowth)}, mais pas assez forte pour compenser seule une valorisation elevee.'
              : 'Positive revenue growth at ${_pct(revenueGrowth)}, though not strong enough alone to offset a high multiple.',
        );
      } else if (revenueGrowth < 0) {
        add(
          category: 'Croissance',
          label: 'Croissance CA',
          value: _pct(revenueGrowth),
          points: -8,
          thesis: isFr
              ? 'Contraction du chiffre d affaires a ${_pct(revenueGrowth)}, facteur negatif majeur pour la recommandation.'
              : 'Revenue contraction at ${_pct(revenueGrowth)}, a major negative factor for the recommendation.',
          risk: 1.5,
        );
      }

      final epsGrowth = ks.earningsGrowth;
      if (epsGrowth >= 0.15) {
        add(
          category: 'Croissance',
          label: 'Croissance EPS',
          value: _pct(epsGrowth),
          points: 5,
          thesis: isFr
              ? 'Croissance EPS de ${_pct(epsGrowth)}, indiquant une progression du benefice par action.'
              : 'EPS growth of ${_pct(epsGrowth)}, indicating progress in earnings per share.',
        );
      } else if (epsGrowth < 0) {
        add(
          category: 'Croissance',
          label: 'Croissance EPS',
          value: _pct(epsGrowth),
          points: -5,
          thesis: isFr
              ? 'Croissance EPS negative a ${_pct(epsGrowth)}, signe de pression sur les resultats.'
              : 'Negative EPS growth at ${_pct(epsGrowth)}, signalling earnings pressure.',
          risk: 1,
        );
      }

      final roe = ks.returnOnEquity;
      if (roe >= 0.20) {
        add(
          category: 'Qualite',
          label: 'ROE',
          value: _pct(roe),
          points: 8,
          thesis: isFr
              ? 'ROE eleve a ${_pct(roe)}, signe d une bonne rentabilite des fonds propres.'
              : 'High ROE at ${_pct(roe)}, showing strong return on equity.',
        );
      } else if (roe >= 0.12) {
        add(
          category: 'Qualite',
          label: 'ROE',
          value: _pct(roe),
          points: 5,
          thesis: isFr
              ? 'ROE correct a ${_pct(roe)}, qualite financiere defendable.'
              : 'Solid ROE at ${_pct(roe)}, supporting financial quality.',
        );
      } else if (roe > 0 && roe < 0.06) {
        add(
          category: 'Qualite',
          label: 'ROE',
          value: _pct(roe),
          points: -5,
          thesis: isFr
              ? 'ROE faible a ${_pct(roe)}, rentabilite des capitaux propres insuffisante.'
              : 'Weak ROE at ${_pct(roe)}, insufficient return on equity.',
          risk: 1,
        );
      }

      final netMargin = ks.profitMargins;
      if (netMargin >= 0.20) {
        add(
          category: 'Qualite',
          label: 'Marge nette',
          value: _pct(netMargin),
          points: 7,
          thesis: isFr
              ? 'Marge nette forte a ${_pct(netMargin)}, protection importante contre les cycles.'
              : 'Strong net margin at ${_pct(netMargin)}, providing meaningful cycle protection.',
        );
      } else if (netMargin >= 0.10) {
        add(
          category: 'Qualite',
          label: 'Marge nette',
          value: _pct(netMargin),
          points: 4,
          thesis: isFr
              ? 'Marge nette positive a ${_pct(netMargin)}, qualite operationnelle acceptable.'
              : 'Positive net margin at ${_pct(netMargin)}, acceptable operating quality.',
        );
      } else if (netMargin < 0) {
        add(
          category: 'Qualite',
          label: 'Marge nette',
          value: _pct(netMargin),
          points: -8,
          thesis: isFr
              ? 'Marge nette negative a ${_pct(netMargin)}, risque d execution eleve.'
              : 'Negative net margin at ${_pct(netMargin)}, pointing to elevated execution risk.',
          risk: 2,
        );
      } else if (netMargin > 0 && netMargin < 0.04) {
        add(
          category: 'Qualite',
          label: 'Marge nette',
          value: _pct(netMargin),
          points: -4,
          thesis: isFr
              ? 'Marge nette faible a ${_pct(netMargin)}, faible coussin si les revenus ralentissent.'
              : 'Thin net margin at ${_pct(netMargin)}, leaving little buffer if revenue slows.',
          risk: 1,
        );
      }

      final fcf = ks.freeCashflow;
      if (fcf > 0) {
        add(
          category: 'Cash-flow',
          label: 'Free cash flow',
          value: _money(fcf),
          points: 6,
          thesis: isFr
              ? 'Free cash flow positif (${_money(fcf)}), la qualite des resultats est mieux soutenue par le cash.'
              : 'Positive free cash flow (${_money(fcf)}), improving earnings quality.',
        );
      } else if (fcf < 0) {
        add(
          category: 'Cash-flow',
          label: 'Free cash flow',
          value: _money(fcf),
          points: -7,
          thesis: isFr
              ? 'Free cash flow negatif (${_money(fcf)}), risque de financement ou de dilution a surveiller.'
              : 'Negative free cash flow (${_money(fcf)}), raising financing or dilution risk.',
          risk: 1.5,
        );
      }

      final debtToEquity = ks.debtToEquity;
      if (debtToEquity > 0 && debtToEquity <= 0.7) {
        add(
          category: 'Bilan',
          label: 'Dette / fonds propres',
          value: '${debtToEquity.toStringAsFixed(2)}x',
          points: 3,
          thesis: isFr
              ? 'Levier contenu a ${debtToEquity.toStringAsFixed(2)}x dette/fonds propres.'
              : 'Contained leverage at ${debtToEquity.toStringAsFixed(2)}x debt/equity.',
        );
      } else if (debtToEquity >= 2) {
        add(
          category: 'Bilan',
          label: 'Dette / fonds propres',
          value: '${debtToEquity.toStringAsFixed(2)}x',
          points: -7,
          thesis: isFr
              ? 'Levier eleve a ${debtToEquity.toStringAsFixed(2)}x dette/fonds propres, sensibilite accrue aux taux et au cycle.'
              : 'High leverage at ${debtToEquity.toStringAsFixed(2)}x debt/equity, increasing rate and cycle sensitivity.',
          risk: 2,
        );
      }

      final beta = ks.beta;
      if (beta > 0 && beta < 0.90) {
        add(
          category: 'Risque',
          label: 'Beta',
          value: beta.toStringAsFixed(2),
          points: 2,
          thesis: isFr
              ? 'Beta contenu a ${beta.toStringAsFixed(2)}, volatilite relative inferieure au marche.'
              : 'Contained beta at ${beta.toStringAsFixed(2)}, lower relative volatility than the market.',
        );
      } else if (beta >= 1.8) {
        add(
          category: 'Risque',
          label: 'Beta',
          value: beta.toStringAsFixed(2),
          points: -6,
          thesis: isFr
              ? 'Beta eleve a ${beta.toStringAsFixed(2)}, le titre amplifie fortement les mouvements de marche.'
              : 'High beta at ${beta.toStringAsFixed(2)}, meaning the stock strongly amplifies market moves.',
          risk: 2,
        );
      } else if (beta >= 1.3) {
        add(
          category: 'Risque',
          label: 'Beta',
          value: beta.toStringAsFixed(2),
          points: -3,
          thesis: isFr
              ? 'Beta superieur au marche (${beta.toStringAsFixed(2)}), taille de position a controler.'
              : 'Above-market beta (${beta.toStringAsFixed(2)}), position sizing should be controlled.',
          risk: 1,
        );
      }

      final shortFloat = ks.shortPercentOfFloat;
      if (shortFloat >= 0.12) {
        add(
          category: 'Risque',
          label: 'Short float',
          value: _pct(shortFloat),
          points: -4,
          thesis: isFr
              ? 'Short interest eleve (${_pct(shortFloat)} du float), risque de volatilite et de controverse.'
              : 'High short interest (${_pct(shortFloat)} of float), increasing volatility and controversy risk.',
          risk: 1,
        );
      }
    }

    if (upside != null) {
      if (upside >= 0.20) {
        add(
          category: 'Valorisation',
          label: 'Upside cible',
          value: _pct(upside),
          points: 10,
          thesis: isFr
              ? 'Objectif disponible implique ${_pct(upside)} de potentiel, soutien important pour une recommandation positive.'
              : 'Available target implies ${_pct(upside)} upside, a major support for a positive recommendation.',
        );
      } else if (upside >= 0.10) {
        add(
          category: 'Valorisation',
          label: 'Upside cible',
          value: _pct(upside),
          points: 6,
          thesis: isFr
              ? 'Objectif disponible implique ${_pct(upside)} de potentiel, signal favorable mais pas suffisant seul.'
              : 'Available target implies ${_pct(upside)} upside, a favorable but not standalone signal.',
        );
      } else if (upside <= -0.10) {
        add(
          category: 'Valorisation',
          label: 'Upside cible',
          value: _pct(upside),
          points: -8,
          thesis: isFr
              ? 'Objectif disponible implique ${_pct(upside)} de baisse, conclusion prudente necessaire.'
              : 'Available target implies ${_pct(upside)} downside, requiring a cautious conclusion.',
          risk: 1.5,
        );
      } else if (upside <= -0.05) {
        add(
          category: 'Valorisation',
          label: 'Upside cible',
          value: _pct(upside),
          points: -4,
          thesis: isFr
              ? 'Potentiel cible negatif (${_pct(upside)}), asymetrie prix/risque peu attractive.'
              : 'Negative target upside (${_pct(upside)}), making price/risk asymmetry unattractive.',
          risk: 0.5,
        );
      }
    }

    final consensus = data.analystRecommendations.consensusScore;
    if (consensus > 0) {
      if (consensus >= 72) {
        add(
          category: 'Consensus',
          label: 'Analystes',
          value: data.analystRecommendations.consensusLabel,
          points: 7,
          thesis: isFr
              ? 'Consensus sell-side favorable (${data.analystRecommendations.consensusLabel}, ${consensus.toStringAsFixed(0)}/100).'
              : 'Supportive sell-side consensus (${data.analystRecommendations.consensusLabel}, ${consensus.toStringAsFixed(0)}/100).',
        );
      } else if (consensus <= 35) {
        add(
          category: 'Consensus',
          label: 'Analystes',
          value: data.analystRecommendations.consensusLabel,
          points: -7,
          thesis: isFr
              ? 'Consensus sell-side defavorable (${data.analystRecommendations.consensusLabel}, ${consensus.toStringAsFixed(0)}/100).'
              : 'Unfavorable sell-side consensus (${data.analystRecommendations.consensusLabel}, ${consensus.toStringAsFixed(0)}/100).',
          risk: 1,
        );
      }
    }

    final insiderBuyRatio = data.insiderBuyRatio;
    if (insiderBuyRatio != null) {
      if (insiderBuyRatio >= 0.60) {
        add(
          category: 'Flux',
          label: 'Insider buy ratio',
          value: _pct(insiderBuyRatio),
          points: 5,
          thesis: isFr
              ? 'Flux insiders orientes achat (${_pct(insiderBuyRatio)}), signal d alignement interne.'
              : 'Insider flow skewed to buys (${_pct(insiderBuyRatio)}), signalling internal alignment.',
        );
      } else if (insiderBuyRatio <= 0.40) {
        add(
          category: 'Flux',
          label: 'Insider buy ratio',
          value: _pct(insiderBuyRatio),
          points: -5,
          thesis: isFr
              ? 'Flux insiders orientes vente (${_pct(insiderBuyRatio)}), signal prudentiel.'
              : 'Insider flow skewed to sells (${_pct(insiderBuyRatio)}), a cautionary signal.',
          risk: 1,
        );
      }
    }

    final institutionsPercent = data.holders?.institutionsPercent ?? 0;
    if (institutionsPercent >= 0.50 && institutionsPercent <= 0.85) {
      add(
        category: 'Ownership',
        label: 'Detention institutionnelle',
        value: _pct(institutionsPercent),
        points: 3,
        thesis: isFr
            ? 'Detention institutionnelle significative (${_pct(institutionsPercent)}), le dossier dispose d un soutien professionnel.'
            : 'Meaningful institutional ownership (${_pct(institutionsPercent)}), indicating professional sponsorship.',
      );
    }

    final iv = _parseLoosePercent(data.volatility.ivRank);
    if (iv != null) {
      if (iv >= 0.60) {
        add(
          category: 'Risque',
          label: 'Volatilite implicite',
          value: _pct(iv),
          points: -4,
          thesis: isFr
              ? 'Volatilite implicite elevee (${_pct(iv)}), le marche price un risque important.'
              : 'High implied volatility (${_pct(iv)}), with the market pricing meaningful risk.',
          risk: 1,
        );
      } else if (iv > 0 && iv <= 0.25) {
        add(
          category: 'Risque',
          label: 'Volatilite implicite',
          value: _pct(iv),
          points: 2,
          thesis: isFr
              ? 'Volatilite implicite contenue (${_pct(iv)}), profil de risque plus lisible.'
              : 'Contained implied volatility (${_pct(iv)}), making the risk profile cleaner.',
        );
      }
    }

    final technicalText = data.technicalAnalysis
        .take(6)
        .map((item) => '${item.indicator} ${item.value} ${item.interpretation}')
        .join(' ')
        .toLowerCase();
    if (technicalText.contains('bullish') ||
        technicalText.contains('above') ||
        technicalText.contains('golden')) {
      add(
        category: 'Technique',
        label: 'Momentum',
        value: 'Bullish',
        points: 3,
        thesis: isFr
            ? 'Momentum technique constructif, utile pour le timing de la decision.'
            : 'Constructive technical momentum, useful for decision timing.',
      );
    } else if (technicalText.contains('bearish') ||
        technicalText.contains('below') ||
        technicalText.contains('death')) {
      add(
        category: 'Technique',
        label: 'Momentum',
        value: 'Bearish',
        points: -3,
        thesis: isFr
            ? 'Momentum technique defavorable, le timing d entree demande plus de prudence.'
            : 'Unfavorable technical momentum, requiring more caution on entry timing.',
        risk: 0.5,
      );
    }

    if (data.catalysts.isNotEmpty || data.corporateEvents.isNotEmpty) {
      final count = data.catalysts.length + data.corporateEvents.length;
      add(
        category: 'Catalyseurs',
        label: 'Evenements identifiables',
        value: count.toString(),
        points: count >= 2 ? 3 : 2,
        thesis: isFr
            ? 'Catalyseurs identifiables sur 12 mois, ce qui donne un calendrier de re-evaluation concret.'
            : 'Identifiable 12-month catalysts create a concrete review calendar.',
      );
    }

    score = score.clamp(0, 100);
    final inferredTarget = current == null || current <= 0
        ? explicitTarget
        : current * (1 + ((score - 50) / 180).clamp(-0.22, 0.32));
    final target = explicitTarget ?? inferredTarget;
    final finalUpside = current != null && current > 0 && target != null
        ? (target - current) / current
        : upside;

    final positives = factors.where((factor) => factor.points > 0).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    final negatives = factors.where((factor) => factor.points < 0).toList()
      ..sort((a, b) => a.points.compareTo(b.points));

    final verdict = _verdict(score, isFr);
    final riskLevel = _riskLevel(riskPenalty, ks?.beta ?? 0, isFr);
    final evidenceCoverage = (factors.length / 12).clamp(0.0, 1.0);
    final conviction = ((score - 50).abs() / 50).clamp(0.0, 1.0);
    final balancePenalty =
        positives.isNotEmpty && negatives.isNotEmpty ? 0.08 : 0.0;
    final confidence =
        (0.35 + 0.35 * evidenceCoverage + 0.35 * conviction - balancePenalty)
            .clamp(0.20, 0.95);

    final topPositive = positives.isNotEmpty
        ? positives.first.thesis
        : (isFr
            ? 'Aucun avantage financier dominant n est ressorti des donnees disponibles.'
            : 'No dominant financial advantage emerged from the available data.');
    final topNegative = negatives.isNotEmpty
        ? negatives.first.thesis
        : (isFr
            ? 'Aucun risque quantitatif majeur n a domine la lecture.'
            : 'No major quantitative risk dominated the read-through.');

    final summary = isFr
        ? '${data.companyName ?? data.ticker} recoit une recommandation $verdict avec un score SIGMA data-driven de ${score.toStringAsFixed(0)}/100. $topPositive ${negatives.isNotEmpty ? topNegative : ''} La decision finale combine valorisation, croissance, qualite des marges, cash-flow, bilan, consensus, flux insiders et risque de marche.'
        : '${data.companyName ?? data.ticker} receives a $verdict recommendation with a data-driven SIGMA score of ${score.toStringAsFixed(0)}/100. $topPositive ${negatives.isNotEmpty ? topNegative : ''} The final decision combines valuation, growth, margin quality, cash flow, balance sheet, consensus, insider flow and market risk.';

    final alphaRecommendation = _alphaRecommendation(
      verdict: verdict,
      score: score,
      confidence: confidence,
      upside: finalUpside,
      riskLevel: riskLevel,
      isFr: isFr,
    );

    return FinancialDecisionResult(
      score: score,
      confidence: confidence,
      verdict: verdict,
      riskLevel: riskLevel,
      summary: summary.trim(),
      methodology: isFr
          ? 'Recommandation calculee par pondération multi-facteurs: valorisation, upside, croissance CA/EPS, marges, ROE, FCF, levier, consensus analystes, flux insiders, ownership, volatilite, beta, short interest, technique et catalyseurs. Le score part de 50 puis chaque signal ajoute ou retire des points selon son intensite.'
          : 'Recommendation computed through multi-factor weighting: valuation, upside, revenue/EPS growth, margins, ROE, FCF, leverage, analyst consensus, insider flow, ownership, volatility, beta, short interest, technicals and catalysts. The score starts at 50 and each signal adds or subtracts points based on intensity.',
      alphaRecommendation: alphaRecommendation,
      currentPrice: current,
      targetPrice: target,
      upside: finalUpside,
      factors: factors,
      positives: positives.map((factor) => factor.thesis).take(6).toList(),
      negatives: negatives.map((factor) => factor.thesis).take(6).toList(),
      recommendationSteps: _steps(
        verdict: verdict,
        ticker: data.ticker,
        current: current,
        target: target,
        upside: finalUpside,
        riskLevel: riskLevel,
        isFr: isFr,
      ),
    );
  }

  static String _verdict(double score, bool isFr) {
    if (score >= 72) return isFr ? 'ACHAT FORT' : 'STRONG BUY';
    if (score >= 62) return isFr ? 'ACHAT' : 'BUY';
    if (score <= 32) return isFr ? 'VENTE FORTE' : 'STRONG SELL';
    if (score <= 43) return isFr ? 'VENTE' : 'SELL';
    return isFr ? 'CONSERVER' : 'HOLD';
  }

  static String _riskLevel(double riskPenalty, double beta, bool isFr) {
    final riskScore = riskPenalty +
        (beta >= 1.8
            ? 2
            : beta >= 1.3
                ? 1
                : 0);
    if (riskScore >= 4) return isFr ? 'ELEVE' : 'HIGH';
    if (riskScore >= 1.5) return isFr ? 'MOYEN' : 'MEDIUM';
    return isFr ? 'FAIBLE' : 'LOW';
  }

  static List<String> _steps({
    required String verdict,
    required String ticker,
    required double? current,
    required double? target,
    required double? upside,
    required String riskLevel,
    required bool isFr,
  }) {
    final targetText =
        target == null ? 'N/A' : '\$${target.toStringAsFixed(2)}';
    final upsideText = upside == null ? 'N/A' : _pct(upside);
    final isPositive = verdict.contains('ACHAT') || verdict.contains('BUY');
    final isNegative = verdict.contains('VENTE') || verdict.contains('SELL');

    if (isPositive) {
      return [
        isFr
            ? 'Accumuler $ticker par paliers, pas en une seule execution, pour limiter le risque de mauvais timing.'
            : 'Accumulate $ticker in tranches rather than a single execution to limit timing risk.',
        isFr
            ? 'Objectif de reference: $targetText, potentiel estime: $upsideText.'
            : 'Reference target: $targetText, estimated upside: $upsideText.',
        isFr
            ? 'Reduire ou suspendre l achat si les marges, le FCF ou la croissance se degradent au prochain trimestre.'
            : 'Reduce or pause buying if margins, FCF or growth deteriorate next quarter.',
      ];
    }
    if (isNegative) {
      return [
        isFr
            ? 'Eviter de renforcer $ticker tant que les signaux de qualite, croissance ou valorisation ne se normalisent pas.'
            : 'Avoid adding to $ticker until quality, growth or valuation signals normalize.',
        isFr
            ? 'Surveiller un retour du potentiel risque/rendement vers une zone positive avant toute re-evaluation.'
            : 'Wait for risk/reward to return to a positive zone before reassessing.',
        isFr
            ? 'Conserver seulement une exposition tactique si le dossier est deja en portefeuille et que le risque $riskLevel est acceptable.'
            : 'Keep only tactical exposure if already held and $riskLevel risk is acceptable.',
      ];
    }
    return [
      isFr
          ? 'Maintenir $ticker en watchlist active: le signal n est pas assez asymetrique pour surponderer maintenant.'
          : 'Keep $ticker on active watchlist: the signal is not asymmetric enough to overweight now.',
      isFr
          ? 'Attendre un meilleur point d entree, une revision de guidance ou une amelioration des facteurs de score.'
          : 'Wait for a better entry, guidance revision or improvement in score factors.',
      isFr
          ? 'Reviser la decision si le potentiel cible depasse 10-15% avec une qualite financiere stable.'
          : 'Revisit the decision if target upside exceeds 10-15% with stable financial quality.',
    ];
  }

  static String _alphaRecommendation({
    required String verdict,
    required double score,
    required double confidence,
    required double? upside,
    required String riskLevel,
    required bool isFr,
  }) {
    final upsideText = upside == null ? 'N/A' : _pct(upside);
    if (verdict.contains('ACHAT') || verdict.contains('BUY')) {
      return isFr
          ? 'Biais positif: score ${score.toStringAsFixed(0)}/100, confiance ${(confidence * 100).toStringAsFixed(0)}%, potentiel $upsideText. Favoriser une entree disciplinee compte tenu du risque $riskLevel.'
          : 'Positive bias: score ${score.toStringAsFixed(0)}/100, confidence ${(confidence * 100).toStringAsFixed(0)}%, upside $upsideText. Favor disciplined entry given $riskLevel risk.';
    }
    if (verdict.contains('VENTE') || verdict.contains('SELL')) {
      return isFr
          ? 'Biais negatif: score ${score.toStringAsFixed(0)}/100, confiance ${(confidence * 100).toStringAsFixed(0)}%. Eviter de payer le dossier tant que les signaux cles ne se retournent pas.'
          : 'Negative bias: score ${score.toStringAsFixed(0)}/100, confidence ${(confidence * 100).toStringAsFixed(0)}%. Avoid paying for the name until key signals turn.';
    }
    return isFr
        ? 'Biais neutre: score ${score.toStringAsFixed(0)}/100. La decision rationnelle est de patienter jusqu a une meilleure asymetrie rendement/risque.'
        : 'Neutral bias: score ${score.toStringAsFixed(0)}/100. The rational decision is to wait for better risk/reward asymmetry.';
  }

  static double? _positive(double value) => value > 0 ? value : null;

  static double? _parsePrice(String value, {bool emptyAsNull = false}) {
    final match = RegExp(r'-?\d+(?:[,.]\d+)?').firstMatch(value);
    if (match == null) return emptyAsNull ? null : 0;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  static double? _parseLoosePercent(String value) {
    final match = RegExp(r'-?\d+(?:[,.]\d+)?').firstMatch(value);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(0)!.replaceAll(',', '.'));
    if (parsed == null) return null;
    return parsed.abs() > 1.5 || value.contains('%') ? parsed / 100 : parsed;
  }

  static String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

  static String _money(double value) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    if (abs >= 1e12) return '$sign\$${(abs / 1e12).toStringAsFixed(2)}T';
    if (abs >= 1e9) return '$sign\$${(abs / 1e9).toStringAsFixed(2)}B';
    if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(1)}M';
    return '$sign\$${abs.toStringAsFixed(0)}';
  }
}
