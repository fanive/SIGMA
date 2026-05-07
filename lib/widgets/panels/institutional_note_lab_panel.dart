// ignore_for_file: unused_element, unused_local_variable

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/sigma_models.dart';
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import '../../screens/financial_report_screen.dart';
import '../../theme/app_theme.dart';
import '../institutional/institutional_components.dart';
import '../../utils/logo_resolver.dart';
import '../../utils/financial_decision_engine.dart';
import '../../services/sigma_api_service.dart';
import '../analysis/analysis_sections.dart' show AiSentimentSection;
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SIGMA · INSTITUTIONAL NOTE LAB
//  Research Note + Comparative Note — Mobile-first editorial interface
//
//  Design principles:
//  · No cards. No gradients. No SaaS roundedness.
//  · Thin horizontal rules as section separators, like a typeset document.
//  · Lora for labels, tickers, metrics and editorial body text.
//  · Keep the analysis surface typographically uniform and readable.
//  · Restricted palette: navy accent, near-black text, warm off-white background.
//  · Sophistication from composition and restraint, not effects.
// ═══════════════════════════════════════════════════════════════════════════

// ── Palette tokens ──────────────────────────────────────────────────────────
const _kDarkBg = Color(0xFF070C14);
const _kDarkSurface = Color(0xFF0D1520);
const _kDarkBorder = Color(0xFF1A2535);
const _kDarkText = Color(0xFFE4E8EC);
const _kDarkDim = Color(0xFF6880A0);
const _kDarkDimSub = Color(0xFF445568);

const _kLightBg = Color(0xFFF8F6F2);
const _kLightSurface = Color(0xFFFFFEFC);
const _kLightBorder = Color(0xFFDDD9D2);
const _kLightText = Color(0xFF0A0F1A);
const _kLightDim = Color(0xFF70808A);
const _kLightDimSub = Color(0xFFA0AAB0);

// ── Typography helpers ───────────────────────────────────────────────────────
TextStyle _sectionLabel(Color c) => GoogleFonts.lora(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
      color: c,
    );

TextStyle _metricLabel(Color c) => GoogleFonts.lora(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: c,
    );

TextStyle _metricValue(Color c) => GoogleFonts.lora(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: c,
    );

TextStyle _bodyStyle(Color c, {bool disclaimer = false}) => GoogleFonts.lora(
      fontSize: disclaimer ? 12 : 14,
      height: disclaimer ? 1.55 : 1.65,
      color: c,
      fontWeight: FontWeight.w400,
    );

// ── Number formatting helpers ─────────────────────────────────────────────────
String _money(double v) {
  final a = v.abs();
  final s = v < 0 ? '\u2212' : '';
  if (a >= 1e12) return '$s\$${(a / 1e12).toStringAsFixed(2)}T';
  if (a >= 1e9) return '$s\$${(a / 1e9).toStringAsFixed(2)}B';
  if (a >= 1e6) return '$s\$${(a / 1e6).toStringAsFixed(2)}M';
  return '$s\$${a.toStringAsFixed(0)}';
}

String _pct(double v) {
  final p = v * 100;
  return '${p >= 0 ? '' : '\u2212'}${p.abs().toStringAsFixed(1)}%';
}

double _parsePrice(String raw) {
  final digits = raw.split('').where((ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 48 && c <= 57) || ch == '.';
  }).join();
  return double.tryParse(digits) ?? 0.0;
}

String _displayCurrentPrice(AnalysisData a) {
  final numeric = _parsePrice(a.price);
  if (numeric > 0) {
    return '\$${numeric.toStringAsFixed(numeric >= 1 ? 2 : 4)}';
  }
  final raw = a.price.trim();
  if (_hasText(raw) && raw != '0' && raw != '0.00') {
    return raw.startsWith('\$') ? raw : '\$$raw';
  }
  return 'Prix en chargement';
}

String _formatNoteTimestamp(String raw) {
  final clean = raw.trim();
  if (clean.isEmpty) return 'Date N/A';
  final dt = DateTime.tryParse(clean);
  if (dt == null) {
    return clean
        .replaceFirst(RegExp(r'\.\d+'), '')
        .replaceFirst(RegExp(r':\d{2}(?:\s|$)'), ' ')
        .trim();
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

String _cleanText(String v) {
  String clean = v.replaceAll('[AGENTIC OLLAMA]', '').trim();
  clean = clean.replaceAll(
      RegExp(
          r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F0F5}\u{1F004}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F1E6}-\u{1F1FF}\u{1F201}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}\u{1F251}\u{1F300}-\u{1F321}\u{1F324}-\u{1F393}\u{1F396}-\u{1F39B}\u{1F39E}-\u{1F3F0}\u{1F3F3}-\u{1F3F5}\u{1F3F7}-\u{1F4FD}\u{1F4FF}-\u{1F53D}\u{1F549}-\u{1F54E}\u{1F550}-\u{1F567}\u{1F56F}\u{1F570}\u{1F573}-\u{1F579}\u{1F57B}-\u{1F5A3}\u{1F5A5}-\u{1F5FA}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CB}-\u{1F6D2}\u{1F6E0}-\u{1F6E5}\u{1F6E9}\u{1F6EB}\u{1F6EC}\u{1F6F0}\u{1F6F3}-\u{1F6F6}\u{1F90D}-\u{1F93A}\u{1F93C}-\u{1F945}\u{1F947}-\u{1F970}\u{1F973}-\u{1F976}\u{1F97A}\u{1F97C}-\u{1F9A2}\u{1F9B0}-\u{1F9B9}\u{1F9C0}-\u{1F9C2}\u{1F9D0}-\u{1F9FF}]',
          unicode: true),
      '');
  return clean.trim();
}

// Builds a truly ticker-specific executive summary from quantitative fields.
// Falls back to the API summary only if it contains the ticker symbol.
String _buildExecutiveSummary(AnalysisData a) {
  final ticker = a.ticker.toUpperCase();
  final name = (a.companyName?.isNotEmpty == true) ? a.companyName! : ticker;
  final ks = a.keyStatistics;

  // Use API summary only if it's meaningfully specific (contains the ticker or company name)
  final raw = _cleanText(a.summary.isNotEmpty ? a.summary : '');
  if (raw.isNotEmpty &&
      (raw.toUpperCase().contains(ticker) ||
          (a.companyName?.isNotEmpty == true &&
              raw.toUpperCase().contains(a.companyName!.toUpperCase())))) {
    return raw;
  }

  final parts = <String>[];

  // Sentence 1 — identity + price + verdict
  final priceStr = _displayCurrentPrice(a);
  final changeStr = (a.changePercent != null)
      ? ' (${a.changePercent! >= 0 ? '+' : ''}${a.changePercent!.toStringAsFixed(2)}%)'
      : '';
  final sectorStr = (a.sector?.isNotEmpty == true)
      ? ', actif dans le secteur ${a.sector}'
      : '';
  final verdictLabel = a.verdict.isNotEmpty ? a.verdict : 'NEUTRE';
  parts.add('$name ($ticker) se négocie à $priceStr$changeStr$sectorStr. '
      'Notre verdict SIGMA est ${verdictLabel.toUpperCase()}, avec un score de confiance de ${(a.confidence * 100).toStringAsFixed(0)}%.');

  // Sentence 2 — key financials
  if (ks != null) {
    final sentences = <String>[];
    if (ks.marketCap > 0) {
      final mcap = ks.marketCap >= 1e12
          ? '\$${(ks.marketCap / 1e12).toStringAsFixed(1)}T'
          : ks.marketCap >= 1e9
              ? '\$${(ks.marketCap / 1e9).toStringAsFixed(1)}Md'
              : '\$${(ks.marketCap / 1e6).toStringAsFixed(0)}M';
      sentences.add('Cap. boursière : $mcap');
    }
    if (ks.trailingPE > 0 && ks.trailingPE < 999) {
      sentences.add('P/E : ${ks.trailingPE.toStringAsFixed(1)}x');
    } else if (ks.priceToSales > 0) {
      sentences.add('P/S : ${ks.priceToSales.toStringAsFixed(1)}x');
    }
    if (ks.revenueGrowth != 0) {
      final g = (ks.revenueGrowth * 100).toStringAsFixed(1);
      sentences.add('Croissance CA : ${ks.revenueGrowth >= 0 ? '+' : ''}$g%');
    }
    if (ks.profitMargins != 0) {
      final m = (ks.profitMargins * 100).toStringAsFixed(1);
      sentences.add('Marge nette : $m%');
    }
    if (sentences.isNotEmpty) {
      parts.add('Profil financier clé : ${sentences.join(' | ')}.');
    }
  }

  // Sentence 3 — upside + target price
  final current =
      double.tryParse(a.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  final target = a.targetPriceValue ?? 0;
  if (current > 0 && target > 0) {
    final upside = ((target - current) / current * 100);
    final direction = upside >= 0 ? 'potentiel haussier' : 'risque baissier';
    parts.add(
        'Objectif de cours : \$${target.toStringAsFixed(2)}, soit un $direction de ${upside.abs().toStringAsFixed(1)}% par rapport au cours actuel.');
  }

  // Sentence 4 — catalysts + risk
  final catalystCount = a.catalysts.length;
  final riskLabel = a.riskLevel.isNotEmpty ? a.riskLevel : 'MODÉRÉ';
  if (catalystCount > 0) {
    parts.add(
        '$catalystCount catalyseur(s) identifié(s), avec un profil de risque ${riskLabel.toUpperCase()}.');
  }

  // Sentence 5 — sigma score narrative
  final score = a.sigmaScore;
  final scoreLabel = score >= 75
      ? 'dossier fort'
      : score >= 50
          ? 'dossier neutre à positif'
          : 'dossier sous surveillance';
  parts.add('Score SIGMA : ${score.toStringAsFixed(0)}/100 — $scoreLabel.');

  return parts.join(' ');
}

bool _isUsefulLine(String value) {
  final clean = _cleanText(value).trim();
  if (!_hasText(clean)) return false;
  final lower = clean.toLowerCase();
  return !lower.contains('donnees insuffisantes') &&
      !lower.contains('données insuffisantes') &&
      !lower.contains('aucun argument') &&
      !lower.contains('n/a');
}

List<String> _dedupeLines(Iterable<String> raw, {int limit = 6}) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in raw) {
    final clean = _cleanText(item).trim();
    if (!_isUsefulLine(clean)) continue;
    final key = clean.toLowerCase();
    if (seen.add(key)) out.add(clean);
    if (out.length >= limit) break;
  }
  return out;
}

String _ratioText(double value) =>
    value.abs() <= 1 ? _pct(value) : '${value.toStringAsFixed(1)}x';

List<String> _investmentThesisItems(AnalysisData a) {
  final ks = a.keyStatistics;
  final items = <String>[
    ...a.verdictReasons,
  ];

  if (ks != null) {
    if (ks.revenueGrowth != 0) {
      items.add(
        'Croissance du chiffre d affaires: ${_pct(ks.revenueGrowth)}, signal cle pour juger la trajectoire fondamentale.',
      );
    }
    if (ks.profitMargins != 0 || ks.operatingMargins != 0) {
      items.add(
        'Rentabilite: marge nette ${_pct(ks.profitMargins)} et marge operationnelle ${_pct(ks.operatingMargins)}.',
      );
    }
    if (ks.trailingPE > 0 || ks.priceToSales > 0) {
      final valuation = ks.trailingPE > 0
          ? 'P/E TTM ${ks.trailingPE.toStringAsFixed(1)}x'
          : 'P/S ${ks.priceToSales.toStringAsFixed(1)}x';
      items.add(
          'Valorisation actuelle: $valuation, a comparer au profil de croissance et de marge.');
    }
    if (ks.freeCashflow != 0) {
      items.add(
          'Generation de cash: FCF ${_money(ks.freeCashflow)}, utile pour mesurer la qualite des resultats.');
    }
    if (ks.debtToEquity > 0) {
      items.add(
          'Structure financiere: dette/fonds propres ${ks.debtToEquity.toStringAsFixed(1)}x.');
    }
  }

  final upside = _upsidePercent(a);
  if (upside != null) {
    items.add(
        'Potentiel 12 mois: ${_pct(upside)} par rapport au prix courant et a l objectif disponible.');
  }
  if (a.analystRecommendations.consensusScore > 0) {
    items.add(
        'Consensus sell-side: ${a.analystRecommendations.consensusLabel} avec score ${a.analystRecommendations.consensusScore.toStringAsFixed(0)}/100.');
  }
  if (a.technicalAnalysis.isNotEmpty) {
    final t = a.technicalAnalysis.first;
    items.add(
        'Signal technique dominant: ${t.indicator} ${t.value} (${t.interpretation}).');
  }
  if (items.isEmpty && _hasText(a.summary)) items.add(a.summary);

  return _dedupeLines(items, limit: 6);
}

List<String> _riskFactorItems(AnalysisData a) {
  final ks = a.keyStatistics;
  final items = <String>[
    ...a.cons.map((c) => c.text),
  ];

  if (ks != null) {
    if (ks.revenueGrowth < 0) {
      items.add(
          'Croissance negative du chiffre d affaires (${_pct(ks.revenueGrowth)}), ce qui peut peser sur la valorisation.');
    }
    if (ks.profitMargins < 0) {
      items.add(
          'Marge nette negative (${_pct(ks.profitMargins)}), signal de pression sur la rentabilite.');
    }
    if (ks.debtToEquity > 2) {
      items.add(
          'Levier eleve: dette/fonds propres ${ks.debtToEquity.toStringAsFixed(1)}x.');
    }
    if (ks.beta > 1.3) {
      items.add(
          'Beta eleve (${ks.beta.toStringAsFixed(2)}), exposition superieure aux mouvements de marche.');
    }
    if (ks.freeCashflow < 0) {
      items.add(
          'Free cash flow negatif (${_money(ks.freeCashflow)}), a surveiller sur les prochains trimestres.');
    }
  }

  if (_hasText(a.riskLevel)) {
    items.add(
        'Risque SIGMA classe ${a.riskLevel.toUpperCase()}, a integrer dans la taille de position.');
  }
  if (a.volatility.ivRank != 'N/A') {
    items.add(
        'Volatilite implicite: ${a.volatility.ivRank}, regime ${a.volatility.interpretation}.');
  }

  return _dedupeLines(items, limit: 6);
}

List<String> _catalystItems(AnalysisData a) {
  final items = <String>[];
  for (final c in a.catalysts) {
    items.add(
        '${c.type}: ${c.headline}${_hasText(c.insight) ? ' - ${c.insight}' : ''}');
  }
  final calendar = a.earningsCalendar;
  if (calendar != null && calendar.isNotEmpty) {
    final earningsDate = calendar['Earnings Date'] ?? calendar['earningsDate'];
    if (earningsDate != null) {
      items.add('Publication resultats a surveiller: $earningsDate.');
    }
  }
  if (a.companyNews.isNotEmpty) {
    for (final n in a.companyNews.take(3)) {
      if (_hasText(n.title)) items.add('News flow: ${n.title}');
    }
  }
  final upside = _upsidePercent(a);
  if (upside != null && upside.abs() > 0.05) {
    items.add(
        'Re-rating possible si le marche converge vers l objectif implicite (${_pct(upside)}).');
  }
  if (items.isEmpty && a.actionPlan.isNotEmpty) items.addAll(a.actionPlan);
  return _dedupeLines(items, limit: 6);
}

List<String> _invalidationItems(AnalysisData a) {
  final ks = a.keyStatistics;
  final items = <String>[...a.actionPlan];
  if (ks != null) {
    if (ks.operatingMargins != 0) {
      items.add(
          'Invalider si la marge operationnelle se degrade nettement sous le niveau actuel (${_pct(ks.operatingMargins)}).');
    }
    if (ks.revenueGrowth != 0) {
      items.add(
          'Reviser la these si la croissance du CA s eloigne durablement du rythme actuel (${_pct(ks.revenueGrowth)}).');
    }
    if (ks.debtToEquity > 0) {
      items.add(
          'Surveiller tout durcissement du bilan au-dela du levier actuel (${ks.debtToEquity.toStringAsFixed(1)}x).');
    }
  }
  items.add(
      'Reevaluer apres resultats trimestriels, guidance ou revision analyste majeure.');
  return _dedupeLines(items, limit: 5);
}

List<ProCon> _bullCasePoints(AnalysisData a) {
  final existing = a.pros.where((p) => _isUsefulLine(p.text)).toList();
  if (existing.isNotEmpty) return existing;
  return _investmentThesisItems(a)
      .take(4)
      .map((text) => ProCon(text: text, period: 'PRESENT'))
      .toList();
}

List<ProCon> _bearCasePoints(AnalysisData a) {
  final existing = a.cons.where((p) => _isUsefulLine(p.text)).toList();
  if (existing.isNotEmpty) return existing;
  return _riskFactorItems(a)
      .take(4)
      .map((text) => ProCon(text: text, period: 'PRESENT'))
      .toList();
}

bool _hasText(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return false;
  final u = t.toUpperCase();
  return u != 'N/A' &&
      u != 'NA' &&
      u != 'NULL' &&
      u != '-' &&
      !u.startsWith('EN ATTENTE');
}

bool _hasAnalystConsensus(AnalysisData a) {
  final r = a.analystRecommendations;
  return r.strongBuy + r.buy + r.hold + r.sell + r.strongSell > 0;
}

bool _hasOwnershipSignals(AnalysisData a) {
  final h = a.holders;
  return (h?.institutionsPercent ?? 0) != 0 ||
      (h?.insidersPercent ?? 0) != 0 ||
      (h?.institutionsCount ?? 0) > 0 ||
      a.institutionalActivity.smartMoneySentiment != 0 ||
      a.institutionalActivity.retailSentiment != 0 ||
      (a.socialSentiment?.mentions ?? 0) > 0 ||
      (a.insiderBuyRatio ?? 0) > 0;
}

Color _verdictColor(String v) {
  final u = v.toUpperCase();
  if (u.contains('BUY') || u.contains('ACHAT') || u.contains('SURPERF')) {
    return AppTheme.positive;
  }
  if (u.contains('SELL') || u.contains('VENTE') || u.contains('SOUS-PERF')) {
    return AppTheme.negative;
  }
  return AppTheme.warning;
}

AnalysisData? _relativeWinner(AnalysisData left, AnalysisData right) {
  final spread = (left.sigmaScore - right.sigmaScore).abs();
  if (spread < 1.5) return null;
  return left.sigmaScore > right.sigmaScore ? left : right;
}

// ════════════════════════════════════════════════════════════════════════════
//  MAIN PANEL
// ════════════════════════════════════════════════════════════════════════════

class InstitutionalNoteLabPanel extends StatefulWidget {
  final String? initialTicker;
  final bool openComparisonOnStart;

  const InstitutionalNoteLabPanel({
    super.key,
    this.initialTicker,
    this.openComparisonOnStart = false,
  });

  @override
  State<InstitutionalNoteLabPanel> createState() =>
      _InstitutionalNoteLabPanelState();
}

class _InstitutionalNoteLabPanelState extends State<InstitutionalNoteLabPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final TextEditingController _singleCtrl;
  late final TextEditingController _leftCtrl;
  late final TextEditingController _rightCtrl;

  Future<List<AnalysisData>>? _cmpFuture;
  String? _noteError;
  String? _comparisonError;
  bool _isGenerating = false;
  bool _isComparing = false;
  bool _compactComparisonHeader = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialTicker?.trim().toUpperCase();
    final baseTicker = (seed != null && seed.isNotEmpty) ? seed : null;

    _singleCtrl = TextEditingController(text: baseTicker ?? '');
    _leftCtrl = TextEditingController(text: baseTicker ?? '');
    _rightCtrl = TextEditingController();

    _tab = TabController(length: 2, vsync: this);
    if (widget.openComparisonOnStart) {
      _tab.index = 1;
    }
    _tab.addListener(_syncModeState);
    _leftCtrl.addListener(_onComparisonTickerEdited);
    _rightCtrl.addListener(_onComparisonTickerEdited);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateNoteLabContext();
    });
  }

  void _syncModeState() {
    if (mounted && !_tab.indexIsChanging) {
      if (_tab.index == 1 && _leftCtrl.text.trim().isEmpty) {
        _leftCtrl.text = _singleCtrl.text.trim().toUpperCase();
      }
      if (_tab.index == 0 && _singleCtrl.text.trim().isEmpty) {
        _singleCtrl.text = _leftCtrl.text.trim().toUpperCase();
      }
      setState(() {});
    }
  }

  void _onComparisonTickerEdited() {
    if (_compactComparisonHeader) {
      setState(() {
        _compactComparisonHeader = false;
      });
    }
  }

  void _expandComparisonHeader() {
    if (!_compactComparisonHeader) return;
    HapticFeedback.selectionClick();
    setState(() {
      _compactComparisonHeader = false;
    });
  }

  Future<void> _hydrateNoteLabContext() async {
    if (!mounted) return;

    final terminalProvider = Provider.of<TerminalProvider?>(
      context,
      listen: false,
    );
    final sigmaProvider = context.read<SigmaProvider>();

    final seedFromTerminal = terminalProvider?.consumeNoteLabTickerSeed();
    final openComparisonFromTerminal =
        terminalProvider?.consumeOpenNoteLabComparison() ?? false;
    final openComparison =
        widget.openComparisonOnStart || openComparisonFromTerminal;

    if (seedFromTerminal != null && seedFromTerminal.isNotEmpty) {
      _singleCtrl.text = seedFromTerminal;
      _leftCtrl.text = seedFromTerminal;
    }

    if (!openComparison) {
      return;
    }

    _tab.animateTo(1);
    _prefillComparisonPeerFromCurrentAnalysis(sigmaProvider);

    if (_leftCtrl.text.trim().isNotEmpty && _rightCtrl.text.trim().isNotEmpty) {
      await _launchComparison(sigmaProvider);
    }
  }

  void _prefillComparisonPeerFromCurrentAnalysis(SigmaProvider sp) {
    if (_rightCtrl.text.trim().isNotEmpty) return;

    final leftTicker = _leftCtrl.text.trim().toUpperCase();
    if (leftTicker.isEmpty) return;

    final current = sp.currentAnalysis;
    if (current == null || current.ticker.toUpperCase() != leftTicker) {
      return;
    }

    final peer = current.sectorPeers
        .map((item) => item.ticker.trim().toUpperCase())
        .where((ticker) => ticker.isNotEmpty && ticker != leftTicker)
        .cast<String?>()
        .firstWhere(
          (ticker) => ticker != null,
          orElse: () => null,
        );

    if (peer != null && peer.isNotEmpty) {
      _rightCtrl.text = peer;
    }
  }

  @override
  void dispose() {
    _tab.removeListener(_syncModeState);
    _leftCtrl.removeListener(_onComparisonTickerEdited);
    _rightCtrl.removeListener(_onComparisonTickerEdited);
    _tab.dispose();
    _singleCtrl.dispose();
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sp = context.watch<SigmaProvider>();
    return Material(
      color: isDark ? _kDarkBg : _kLightBg,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NoteCommandBar(
              controller: _tab,
              modeIndex: _tab.index,
              singleCtrl: _singleCtrl,
              leftCtrl: _leftCtrl,
              rightCtrl: _rightCtrl,
              isDark: isDark,
              isAnalyzing: sp.isAnalysisLoading || _isGenerating,
              isComparing: _isComparing,
              compactComparisonHeader: _compactComparisonHeader,
              onExpandComparison: _expandComparisonHeader,
              onAnalyze: _generateNote,
              onCompare: () => _launchComparison(sp),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ResearchTab(
                    sp: sp,
                    error: _noteError,
                    isDark: isDark,
                    isGenerating: _isGenerating,
                  ),
                  _ComparativeTab(
                    sp: sp,
                    future: _cmpFuture,
                    error: _comparisonError,
                    isDark: isDark,
                    isComparing: _isComparing,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateNote() async {
    if (_isGenerating) return;

    final sp = context.read<SigmaProvider>();
    final symbol = _singleCtrl.text.trim().toUpperCase();
    if (symbol.isEmpty) return;

    setState(() {
      _noteError = null;
      _isGenerating = true;
    });

    try {
      final resolved = await sp.resolveTickerInput(symbol, strict: true);
      if (!mounted) return;

      if (resolved.isEmpty) {
        setState(() => _noteError = 'Ticker introuvable. Verifiez la saisie.');
        return;
      }

      _singleCtrl.text = resolved;
      await sp.analyzeTicker(resolved, forceRefresh: false);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _noteError = 'Analyse indisponible pour ce ticker. Reessayez.');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _launchComparison(SigmaProvider sp) async {
    if (_isComparing) return;

    final l = _leftCtrl.text.trim().toUpperCase();
    final r = _rightCtrl.text.trim().toUpperCase();
    if (l.isEmpty || r.isEmpty) {
      setState(() =>
          _comparisonError = 'Entrez deux tickers pour lancer la comparaison.');
      return;
    }

    setState(() {
      _comparisonError = null;
      _isComparing = true;
    });

    try {
      final left = await sp.resolveTickerInput(l, strict: true);
      final right = await sp.resolveTickerInput(r, strict: true);
      if (!mounted) return;

      if (left.isEmpty || right.isEmpty) {
        setState(() => _comparisonError =
            'Ticker introuvable. Verifiez les symboles saisis.');
        return;
      }
      if (left == right) {
        setState(() => _comparisonError =
            'Choisissez deux tickers differents pour comparer.');
        return;
      }

      _leftCtrl.text = left;
      _rightCtrl.text = right;

      final future = sp.analyzeComparisonResolved(left, right);
      setState(() {
        _cmpFuture = future;
      });

      await future;
      if (mounted) {
        setState(() {
          _compactComparisonHeader = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _comparisonError =
          'Comparaison indisponible. Reessayez dans un instant.');
    } finally {
      if (mounted) {
        setState(() => _isComparing = false);
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TAB VIEWS
// ════════════════════════════════════════════════════════════════════════════

class _ResearchTab extends StatelessWidget {
  final SigmaProvider sp;
  final String? error;
  final bool isDark;
  final bool isGenerating;

  const _ResearchTab({
    required this.sp,
    required this.error,
    required this.isDark,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    final a = sp.currentAnalysis;
    return Column(
      children: [
        if (error != null) _ErrorBand(message: error!, isDark: isDark),
        Expanded(
          child: (sp.isAnalysisLoading || isGenerating)
              ? _LoadingState(
                  isDark: isDark,
                  message: 'Analyse en cours. Construction de la note...',
                )
              : a == null
                  ? _IdleState(
                      isDark: isDark,
                      message:
                          'Entrez un ticker pour generer une note de conviction institutionnelle.',
                    )
                  : _ResearchNoteScroll(a: a, isDark: isDark),
        ),
      ],
    );
  }
}

class _ComparativeTab extends StatelessWidget {
  final SigmaProvider sp;
  final Future<List<AnalysisData>>? future;
  final String? error;
  final bool isDark;
  final bool isComparing;

  const _ComparativeTab({
    required this.sp,
    required this.future,
    required this.error,
    required this.isDark,
    required this.isComparing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null) _ErrorBand(message: error!, isDark: isDark),
        Expanded(
          child: FutureBuilder<List<AnalysisData>>(
            future: future,
            builder: (ctx, snap) {
              if (isComparing) {
                return _LoadingState(
                  isDark: isDark,
                  message: 'Comparaison en cours. Consolidation des donnees...',
                );
              }
              if (future == null) {
                return _IdleState(
                  isDark: isDark,
                  message:
                      'Entrez deux tickers pour generer une comparative research note sectorielle.',
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return _LoadingState(
                  isDark: isDark,
                  message: 'Comparaison en cours. Generation du rapport...',
                );
              }
              if (snap.hasError) {
                return _IdleState(
                  isDark: isDark,
                  message:
                      'Echec de la comparaison.\nVerifiez les tickers et reessayez.',
                );
              }
              if (!snap.hasData || snap.data!.length != 2) {
                return _IdleState(
                  isDark: isDark,
                  message:
                      'Comparaison indisponible.\nVerifiez les tickers saisis.',
                );
              }
              return _ComparativeNoteScroll(
                left: snap.data![0],
                right: snap.data![1],
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  RESEARCH NOTE SCROLL — Full document
// ════════════════════════════════════════════════════════════════════════════

class _ResearchNoteScroll extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _ResearchNoteScroll({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final summary = _buildExecutiveSummary(a);
    final thesisItems = _investmentThesisItems(a);
    final catalystItems = _catalystItems(a);
    final riskItems = _riskFactorItems(a);
    final invalidationItems = _invalidationItems(a);
    final hasProfile = _hasText(a.companyProfile) ||
        _hasText(a.businessModel) ||
        _hasText(a.revenueStreams) ||
        _hasText(a.companyName);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 1. Executive Cover
        _NoteCover(a: a, isDark: isDark, showRecommendation: false),

        // 2. Executive Summary — always shown, derived from ticker-specific data
        _Section(
          isDark: isDark,
          label: 'EXECUTIVE SUMMARY',
          meta:
              'Confiance: ${(a.confidence * 100).toStringAsFixed(0)}% · ${_formatNoteTimestamp(a.lastUpdated)}',
          child: _BodyBlock(text: summary, isDark: isDark),
        ),

        // 2bis. Company profile (always prioritized near top)
        _Section(
          isDark: isDark,
          label: 'COMPANY PROFILE',
          meta: hasProfile
              ? null
              : 'Profil en mode fallback (donnees partielles)',
          child: _CompanyProfileBlock(a: a, isDark: isDark),
        ),

        // 3. Investment Thesis
        _Section(
          isDark: isDark,
          label: 'INVESTMENT THESIS',
          meta: a.verdictReasons.isEmpty
              ? 'These reconstruite depuis les donnees structurees'
              : null,
          child: _BulletList(
            items: thesisItems.isNotEmpty
                ? thesisItems
                : [
                    'These non concluante: donnees quantitatives encore insuffisantes pour isoler un angle de conviction.'
                  ],
            isDark: isDark,
            dotColor: AppTheme.primary,
          ),
        ),

        // 3bis. Institutional committee lens
        _Section(
          isDark: isDark,
          label: 'AGENTIC COMMITTEE REVIEW',
          meta: 'Multi-agent signal synthesis',
          child: _AgenticCommitteeBlock(a: a, isDark: isDark),
        ),

        // 3ter. Bull vs Bear Debate
        _Section(
          isDark: isDark,
          label: 'BULL VS BEAR DEBATE',
          child: _DebateBlock(a: a, isDark: isDark),
        ),

        // 4. Catalysts
        _Section(
          isDark: isDark,
          label: 'CATALYSTS',
          child: a.catalysts.isNotEmpty
              ? _CatalystList(catalysts: a.catalysts, isDark: isDark)
              : _BulletList(
                  items: catalystItems.isNotEmpty
                      ? catalystItems
                      : [
                          'Aucun catalyseur date detecte; prochaine mise a jour apres nouvelles donnees, resultats ou revision analyste.'
                        ],
                  isDark: isDark,
                  dotColor: AppTheme.primary,
                ),
        ),

        // 5. Financial Summary
        _Section(
          isDark: isDark,
          label: 'FINANCIAL SUMMARY',
          child: _FinancialSummary(a: a, isDark: isDark),
        ),

        // 6. Valuation
        _Section(
          isDark: isDark,
          label: 'VALUATION',
          child: _ValuationGrid(a: a, isDark: isDark),
        ),

        // 6bis. Technical signals from real OHLCV enrichment
        _Section(
          isDark: isDark,
          label: 'TECHNICAL SIGNALS',
          child: _TechnicalSignalsBlock(a: a, isDark: isDark),
        ),

        if (_hasAnalystConsensus(a))
          _Section(
            isDark: isDark,
            label: 'ANALYST CONSENSUS',
            child: _AnalystConsensusBlock(a: a, isDark: isDark),
          ),

        if (_hasOwnershipSignals(a))
          _Section(
            isDark: isDark,
            label: 'OWNERSHIP & FLOWS',
            child: _OwnershipFlowBlock(a: a, isDark: isDark),
          ),

        // 9. Risk Factors
        _Section(
          isDark: isDark,
          label: 'RISK FACTORS',
          meta: a.cons.isEmpty
              ? 'Risques reconstruits depuis ratios, volatilite et bilan'
              : null,
          child: _BulletList(
            items: riskItems.isNotEmpty
                ? riskItems
                : [
                    'Aucun facteur de risque specifique n a ete isole; conserver une taille de position prudente tant que la profondeur de donnees reste limitee.'
                  ],
            isDark: isDark,
            dotColor: AppTheme.negative,
          ),
        ),

        // 8. What Would Change Our View
        _Section(
          isDark: isDark,
          label: 'WHAT WOULD CHANGE OUR VIEW?',
          child: _BulletList(
            items: invalidationItems,
            isDark: isDark,
          ),
        ),

        // 9. Scenario Analysis
        _Section(
          isDark: isDark,
          label: 'SCENARIO ANALYSIS',
          child: _ScenarioGrid(a: a, isDark: isDark),
        ),

        // 10. Market intelligence (API news) — after core analysis
        if (a.companyNews.isNotEmpty)
          _Section(
            isDark: isDark,
            label: 'MARKET INTELLIGENCE',
            child: _NewsDigest(news: a.companyNews, isDark: isDark),
          ),

        // 10bis. AI News Sentiment — FinBERT via Hugging Face
        _Section(
          isDark: isDark,
          label: 'AI NEWS SENTIMENT',
          meta: 'FinBERT · Hugging Face Inference API',
          child: _AiSentimentBlock(symbol: a.ticker, isDark: isDark),
        ),

        // 10ter. AI News Summary — BART-large-cnn via Hugging Face
        _Section(
          isDark: isDark,
          label: 'AI NEWS SUMMARY',
          meta: 'BART-large-cnn · Hugging Face Inference API',
          child: _AiSummaryBlock(symbol: a.ticker, isDark: isDark),
        ),

        // 11. Hypotheses & Limits
        _Section(
          isDark: isDark,
          label: 'HYPOTHESES ET LIMITES',
          meta: 'Sources: Sigma API + Finnhub free tier',
          child: _BodyBlock(
            isDark: isDark,
            disclaimer: true,
            text:
                'Cette note repose sur des donnees de marche issues de sources tierces et des estimations generees par modele. Les hypotheses de croissance, marges et valorisation peuvent evoluer rapidement. Ce document ne constitue pas un conseil en investissement, ne constitue pas une recommandation personnalisee, et ne saurait se substituer a une analyse independante. La fraicheur et la completude des donnees ne sont pas garanties.',
          ),
        ),

        _Section(
          isDark: isDark,
          label: 'RECOMMANDATION FINALE',
          child: _FinalRecommendationSingleBlock(a: a, isDark: isDark),
        ),

        _Section(
          isDark: isDark,
          label: 'RAPPORT DETAILLE',
          isLast: true,
          child: _FullReportButton(
            analysis: a,
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  COMPARATIVE NOTE SCROLL
// ════════════════════════════════════════════════════════════════════════════

class _ComparativeNoteScroll extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _ComparativeNoteScroll({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final decision = _buildComparisonDecision(left, right);
    final preferred = decision.winner ?? left;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _ComparativeCover(
          left: left,
          right: right,
          isDark: isDark,
          showVerdicts: false,
        ),
        _Section(
          isDark: isDark,
          label: 'SCORECARD PONDEREE',
          child: _WeightedScorecardBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'SCENARIOS & RENDEMENT ATTENDU',
          child: _ComparativeScenarioBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'GRILLE COMPARATIVE',
          child: _CompareGrid(left: left, right: right, isDark: isDark),
        ),
        _Section(
          isDark: isDark,
          label: 'FACTEURS DE DECISION',
          child: _RelativeFactorTable(left: left, right: right, isDark: isDark),
        ),
        _Section(
          isDark: isDark,
          label: 'ANALYST CONSENSUS RELATIF',
          child: _ConsensusComparisonBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'OWNERSHIP & FLOWS RELATIFS',
          child: _OwnershipComparisonBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'CATALYSEURS ET RISQUES',
          child:
              _ComparativeNarrative(left: left, right: right, isDark: isDark),
        ),
        _Section(
          isDark: isDark,
          label: 'PLAN D EXECUTION',
          child: _ExecutionPlanBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'CONDITIONS D INVALIDATION',
          child: _InvalidationBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'RESUME INVESTISSEUR',
          child: _InvestorSummaryBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'DECISION RELATIVE',
          child: _RelativeDecision(left: left, right: right, isDark: isDark),
        ),
        _Section(
          isDark: isDark,
          label: 'RECOMMANDATION FINALE',
          child: _FinalRecommendationBlock(
            left: left,
            right: right,
            isDark: isDark,
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'LIMITES DE LA COMPARAISON',
          isLast: true,
          child: _BodyBlock(
            isDark: isDark,
            disclaimer: true,
            text: 'Cette grille ne tient pas compte des differences de cycle '
                'sectoriel, de structure de capital, de mix geographique ou '
                "d'exposition saisonniere. Les donnees peuvent ne pas etre "
                'strictement comparables selon les normes comptables appliquees.',
          ),
        ),
        _Section(
          isDark: isDark,
          label: 'RAPPORT DETAILLE',
          isLast: true,
          child: _FullReportButton(
            analysis: preferred,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOTE COVER
// ════════════════════════════════════════════════════════════════════════════

class _NoteCover extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;
  final bool showRecommendation;

  const _NoteCover({
    required this.a,
    required this.isDark,
    this.showRecommendation = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? _kDarkBg : _kLightBg;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final logo = _resolveTickerLogo(a);

    final currentPrice = _parsePrice(a.price);
    final targetPrice =
        a.targetPriceValue ?? _parsePrice(a.tradeSetup.cleanTargetPrice);
    final upside = currentPrice > 0 && targetPrice > 0
        ? (targetPrice - currentPrice) / currentPrice * 100
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ticker + company name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TickerLogoThumb(symbol: a.ticker, logoUrl: logo, size: 34),
              const SizedBox(width: 8),
              Text(
                a.ticker,
                style: GoogleFonts.lora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: txt,
                ),
              ),
              if (a.companyName != null && a.companyName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.companyName!,
                    style: GoogleFonts.lora(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: dim,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              _FavoriteButton(ticker: a.ticker, isDark: isDark),
            ],
          ),

          if (a.exchange != null || a.sector != null) ...[
            const SizedBox(height: 3),
            Text(
              [
                if (a.exchange != null) a.exchange!,
                if (a.sector != null) a.sector!
              ].join(' · '),
              style: GoogleFonts.lora(
                fontSize: 10,
                letterSpacing: 0.4,
                color: dim,
              ),
            ),
          ],

          const SizedBox(height: 10),
          _HRule(isDark: isDark),
          const SizedBox(height: 10),

          if (showRecommendation) ...[
            // Recommendation row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CoverKV(
                    label: 'RECOMMANDATION',
                    value: a.verdict.isEmpty ? 'N/A' : a.verdict.toUpperCase(),
                    isDark: isDark,
                    valueColor: _verdictColor(a.verdict),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CoverKV(
                    label: 'CONVICTION',
                    value: '${(a.confidence * 100).toStringAsFixed(0)}%',
                    isDark: isDark,
                  ),
                ),
                if (a.riskLevel.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CoverKV(
                      label: 'RISQUE',
                      value: a.riskLevel.toUpperCase(),
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),
            _HRule(isDark: isDark),
            const SizedBox(height: 10),
          ],

          // Price row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRIX ACTUEL', style: _sectionLabel(dim)),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _displayCurrentPrice(a),
                          style: GoogleFonts.lora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: txt,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (a.changePercent != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: (a.changePercent! >= 0
                                      ? AppTheme.positive
                                      : AppTheme.negative)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '${a.changePercent! >= 0 ? '+' : ''}${a.changePercent!.toStringAsFixed(2)}%',
                              style: GoogleFonts.lora(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: a.changePercent! >= 0
                                    ? AppTheme.positive
                                    : AppTheme.negative,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (targetPrice > 0) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _CoverKV(
                    label: 'OBJECTIF',
                    value: '\$${targetPrice.toStringAsFixed(2)}',
                    isDark: isDark,
                  ),
                ),
              ],
              if (upside != null) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _CoverKV(
                    label: 'POTENTIEL',
                    value:
                        '${upside >= 0 ? '+' : ''}${upside.toStringAsFixed(1)}%',
                    isDark: isDark,
                    valueColor:
                        upside >= 0 ? AppTheme.positive : AppTheme.negative,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Horizon + timestamp
          Row(
            children: [
              Text('HORIZON 12 MOIS', style: _sectionLabel(dim)),
              const Spacer(),
              Text(
                _formatNoteTimestamp(a.lastUpdated),
                style: GoogleFonts.lora(fontSize: 10, color: dim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  COMPARATIVE COVER
// ════════════════════════════════════════════════════════════════════════════

class _ComparativeCover extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;
  final bool showVerdicts;

  const _ComparativeCover({
    required this.left,
    required this.right,
    required this.isDark,
    this.showVerdicts = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? _kDarkBg : _kLightBg;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final sector = left.sector ?? right.sector;
    final leftLogo = _resolveTickerLogo(left);
    final rightLogo = _resolveTickerLogo(right);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COMPARATIVE RESEARCH NOTE', style: _sectionLabel(dim)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TickerLogoThumb(symbol: left.ticker, logoUrl: leftLogo, size: 30),
              const SizedBox(width: 8),
              Text(
                left.ticker,
                style: GoogleFonts.lora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: txt,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'vs',
                  style: GoogleFonts.lora(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: dim,
                  ),
                ),
              ),
              TickerLogoThumb(
                symbol: right.ticker,
                logoUrl: rightLogo,
                size: 30,
              ),
              const SizedBox(width: 8),
              Text(
                right.ticker,
                style: GoogleFonts.lora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: txt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  _companyDisplayName(left),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: dim,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _companyDisplayName(right),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: dim,
                  ),
                ),
              ),
            ],
          ),
          if (sector != null) ...[
            const SizedBox(height: 3),
            Text(
              '$sector · Analyse comparative · Horizon 12 mois',
              style: GoogleFonts.lora(
                fontSize: 10,
                color: dim,
                letterSpacing: 0.3,
              ),
            ),
          ],
          if (showVerdicts) ...[
            const SizedBox(height: 10),
            _HRule(isDark: isDark),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _CoverKV(
                    label: 'VUE ${left.ticker}',
                    value: left.verdict.isEmpty
                        ? 'N/A'
                        : left.verdict.toUpperCase(),
                    isDark: isDark,
                    valueColor: _verdictColor(left.verdict),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CoverKV(
                    label: 'VUE ${right.ticker}',
                    value: right.verdict.isEmpty
                        ? 'N/A'
                        : right.verdict.toUpperCase(),
                    isDark: isDark,
                    valueColor: _verdictColor(right.verdict),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FinalRecommendationSingleBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _FinalRecommendationSingleBlock({
    required this.a,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final decision = FinancialDecisionEngine.evaluate(a, language: 'FR');
    final verdict = decision.verdict.toUpperCase();
    final confidence = '${(decision.confidence * 100).toStringAsFixed(0)}%';
    final reasons = [
      ...decision.positives.take(3),
      ...decision.negatives.take(2),
    ].map(_cleanText).toList(growable: false);
    final target = decision.targetPrice == null
        ? 'N/A'
        : '\$${decision.targetPrice!.toStringAsFixed(2)}';
    final upside = decision.upside == null ? 'N/A' : _pct(decision.upside!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          verdict,
          style: GoogleFonts.lora(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _verdictColor(decision.verdict),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Confiance: $confidence · Risque: ${decision.riskLevel.toUpperCase()} · Objectif: $target · Potentiel: $upside',
          style: GoogleFonts.lora(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: txt,
          ),
        ),
        const SizedBox(height: 8),
        Text(decision.summary, style: _bodyStyle(dim)),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BulletList(
            items: reasons,
            isDark: isDark,
            dotColor: AppTheme.primary,
          ),
        ] else ...[
          const SizedBox(height: 10),
          Text(
            'La conclusion finale repose principalement sur le couple valorisation/risque observe sur les donnees disponibles.',
            style: _bodyStyle(dim),
          ),
        ],
      ],
    );
  }
}

class _RelativeDecision extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _RelativeDecision({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final decision = _buildComparisonDecision(left, right);
    final winner = decision.winner;
    final spread = (decision.leftScore - decision.rightScore).abs();

    final title = winner == null
        ? 'Conclusion equilibree'
        : 'Preference relative: ${winner.ticker}';
    final rationale = winner == null
        ? 'Les deux dossiers restent proches. La decision depend surtout du prix d entree, de la tolerance au risque et du poids deja present en portefeuille.'
        : '${winner.ticker} ressort mieux dans cette lecture relative, avec un avantage de ${spread.toStringAsFixed(1)} point${spread >= 2 ? 's' : ''} sur la scorecard ponderee.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.lora(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: winner == null ? txt : decision.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(rationale, style: _bodyStyle(dim)),
        const SizedBox(height: 8),
        Text(
          'Confiance de la conclusion: ${decision.confidence.toStringAsFixed(0)}% · Horizon: 12 mois',
          style: GoogleFonts.lora(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: txt,
          ),
        ),
      ],
    );
  }
}

class _InvestorSummaryBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _InvestorSummaryBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final decision = _buildComparisonDecision(left, right);
    final dim = isDark ? _kDarkDim : _kLightDim;
    final winner = decision.winner;
    final loser =
        winner == null ? null : (winner.ticker == left.ticker ? right : left);

    final investorType = winner == null
        ? 'Profil: investisseur prudent en phase d observation.'
        : (_riskValue(winner.riskLevel) <= 1
            ? 'Profil: investisseur orienté qualite / risque controle.'
            : 'Profil: investisseur acceptant davantage de volatilite contre un potentiel superieur.');

    final text = winner == null
        ? 'Les deux titres presentent aujourd hui un profil proche. Le meilleur choix depend principalement du prix d entree et de votre contrainte de risque.'
        : '${winner.ticker} est prefere a ${loser!.ticker} car il combine une meilleure lisibilite fondamentale et un profil rendement/risque plus robuste a ce stade.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: _bodyStyle(dim)),
        const SizedBox(height: 10),
        Text(
          investorType,
          style: GoogleFonts.lora(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? _kDarkText : _kLightText,
          ),
        ),
      ],
    );
  }
}

class _WeightedScorecardBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _WeightedScorecardBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final decision = _buildComparisonDecision(left, right);
    final dim = isDark ? _kDarkDim : _kLightDim;
    final txt = isDark ? _kDarkText : _kLightText;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    if (decision.rows.isEmpty) {
      return _BodyBlock(
        isDark: isDark,
        text:
            'Scorecard indisponible faute de donnees comparables suffisantes.',
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Score ${left.ticker}: ${decision.leftScore.toStringAsFixed(1)}',
                style: GoogleFonts.lora(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: txt,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Score ${right.ticker}: ${decision.rightScore.toStringAsFixed(1)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.lora(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: txt,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...decision.rows.asMap().entries.map((entry) {
          final row = entry.value;
          final isLast = entry.key == decision.rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: border, width: 0.45),
                    ),
                  ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    '${row.label} (${row.weight.toStringAsFixed(0)})',
                    style: _metricLabel(dim),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row.leftPoints.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: _metricValue(
                      row.winnerTicker == left.ticker ? AppTheme.positive : txt,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    row.rightPoints.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: _metricValue(
                      row.winnerTicker == right.ticker
                          ? AppTheme.positive
                          : txt,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ComparativeScenarioBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _ComparativeScenarioBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final leftUpside = _upsidePercent(left);
    final rightUpside = _upsidePercent(right);
    final decision = _buildComparisonDecision(left, right);
    final winner = decision.winner;

    String fmt(double? value) {
      if (value == null) return 'N/A';
      return '${value >= 0 ? '+' : ''}${(value * 100).toStringAsFixed(1)}%';
    }

    final rows = <String>[
      '${left.ticker}: potentiel central ${fmt(leftUpside)}',
      '${right.ticker}: potentiel central ${fmt(rightUpside)}',
      if (winner != null)
        'Scenario central: surperformance relative attendue de ${winner.ticker} si les catalyseurs identifies se materialisent.',
      if (winner == null)
        'Scenario central: performance relative proche; la valeur d entree devient le principal facteur de resultat.',
      'Scenario adverse: en cas de revision negative des marges ou du bilan, neutraliser la preference relative.',
    ];

    return _BulletList(
      items: rows,
      isDark: isDark,
      dotColor: AppTheme.warning,
    );
  }
}

class _RelativeFactorTable extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _RelativeFactorTable({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_RelativeFactor>[
      _factor('Score SIGMA', left.sigmaScore, right.sigmaScore),
      _factor('Croissance CA', _comparisonMetric(left, 'revenueGrowth'),
          _comparisonMetric(right, 'revenueGrowth'),
          pct: true),
      _factor('Marge oper.', _comparisonMetric(left, 'operatingMargins'),
          _comparisonMetric(right, 'operatingMargins'),
          pct: true),
      _factor('Marge nette', _comparisonMetric(left, 'profitMargins'),
          _comparisonMetric(right, 'profitMargins'),
          pct: true),
      _factor('ROE', _comparisonMetric(left, 'returnOnEquity'),
          _comparisonMetric(right, 'returnOnEquity'),
          pct: true),
      _factor('P/E', _comparisonMetric(left, 'trailingPE'),
          _comparisonMetric(right, 'trailingPE'),
          lowerIsBetter: true),
      _factor('Dette / EQ', _comparisonMetric(left, 'debtToEquity'),
          _comparisonMetric(right, 'debtToEquity'),
          lowerIsBetter: true),
      _factor('FCF', _comparisonMetric(left, 'freeCashflow'),
          _comparisonMetric(right, 'freeCashflow'),
          money: true),
      _factor(
          'Detention inst.',
          _comparisonMetric(left, 'institutionalOwnership'),
          _comparisonMetric(right, 'institutionalOwnership'),
          pct: true),
      _factor('Potentiel prix', _comparisonMetric(left, 'targetUpside'),
          _comparisonMetric(right, 'targetUpside'),
          pct: true),
    ]
        .where((row) => row.leftValue != 'N/A' || row.rightValue != 'N/A')
        .toList();

    if (rows.isEmpty) {
      return _BodyBlock(
        isDark: isDark,
        text:
            'Les facteurs quantitatifs sont encore en cours de consolidation.',
      );
    }

    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    return Column(
      children: rows.asMap().entries.map((entry) {
        final row = entry.value;
        final isLast = entry.key == rows.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: border, width: 0.45),
                  ),
                ),
          child: Row(
            children: [
              Expanded(
                  flex: 4, child: Text(row.label, style: _metricLabel(dim))),
              Expanded(
                flex: 3,
                child: Text(
                  row.leftValue,
                  textAlign: TextAlign.right,
                  style: _metricValue(
                    row.winnerTicker == left.ticker ? AppTheme.positive : txt,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  row.rightValue,
                  textAlign: TextAlign.right,
                  style: _metricValue(
                    row.winnerTicker == right.ticker ? AppTheme.positive : txt,
                  ),
                ),
              ),
              SizedBox(
                width: 58,
                child: Text(
                  row.winnerTicker ?? 'NEUTRE',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: row.winnerTicker == null ? dim : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  _RelativeFactor _factor(
    String label,
    double? leftMetric,
    double? rightMetric, {
    bool pct = false,
    bool money = false,
    bool lowerIsBetter = false,
  }) {
    String fmt(double? value) {
      if (value == null || value == 0) return 'N/A';
      if (pct) return _pct(value);
      if (money) return _money(value);
      return value.toStringAsFixed(1);
    }

    String? winner;
    if (leftMetric != null &&
        rightMetric != null &&
        leftMetric != 0 &&
        rightMetric != 0 &&
        (leftMetric - rightMetric).abs() > 0.01) {
      final leftWins =
          lowerIsBetter ? leftMetric < rightMetric : leftMetric > rightMetric;
      winner = leftWins ? left.ticker : right.ticker;
    }

    return _RelativeFactor(label, fmt(leftMetric), fmt(rightMetric), winner);
  }
}

class _ComparativeNarrative extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _ComparativeNarrative({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bullets = <String>[
      ..._comparisonCatalystsFor(left),
      ..._comparisonCatalystsFor(right),
      if (left.cons.isNotEmpty)
        'Risque ${left.ticker}: ${_cleanText(left.cons.first.text)}',
      if (right.cons.isNotEmpty)
        'Risque ${right.ticker}: ${_cleanText(right.cons.first.text)}',
    ];

    if (bullets.isEmpty) {
      return _BodyBlock(
        isDark: isDark,
        text:
            'Les catalyseurs et risques specifiques restent a confirmer par les prochaines donnees de marche et publications societes.',
      );
    }

    return _BulletList(
      items: bullets.take(5).toList(),
      isDark: isDark,
      dotColor: AppTheme.primary,
    );
  }
}

class _FinalRecommendationBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _FinalRecommendationBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final decision = _buildComparisonDecision(left, right);
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          decision.title,
          style: GoogleFonts.lora(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: decision.color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Confiance relative: ${decision.confidence.toStringAsFixed(0)}%',
          style: GoogleFonts.lora(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: txt,
          ),
        ),
        const SizedBox(height: 10),
        Text(decision.summary, style: _bodyStyle(dim)),
        if (decision.keyDrivers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BulletList(
            items: decision.keyDrivers,
            isDark: isDark,
            dotColor: AppTheme.primary,
          ),
        ],
      ],
    );
  }
}

class _ExecutionPlanBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _ExecutionPlanBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final decision = _buildComparisonDecision(left, right);
    final winner = decision.winner;
    final loser =
        winner == null ? null : (winner.ticker == left.ticker ? right : left);

    final steps = <String>[
      if (winner != null)
        'Priorite relative: surponderer ${winner.ticker} face a ${loser!.ticker}, par paliers plutot qu en une seule execution.',
      if (winner == null)
        'Lecture neutre: conserver une exposition equilibree et attendre une divergence plus nette des fondamentaux.',
      'Valider le point d entree contre la volatilite recente et eviter de payer une extension de prix court terme.',
      'Reevaluer la comparaison a chaque publication trimestrielle, changement de guidance ou revision analyste majeure.',
      'Limiter la taille de position si la qualite des donnees est incomplete ou si les signaux deviennent contradictoires.',
    ];

    return _BulletList(
      items: steps,
      isDark: isDark,
      dotColor: AppTheme.primary,
    );
  }
}

class _InvalidationBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _InvalidationBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final conditions = <String>[
      if (left.actionPlan.isNotEmpty)
        '${left.ticker}: ${left.actionPlan.first}',
      if (right.actionPlan.isNotEmpty)
        '${right.ticker}: ${right.actionPlan.first}',
      'Invalider la preference si deux facteurs majeurs basculent simultanement (croissance, marges, valorisation, bilan).',
      'Suspendre la conclusion en cas de choc exogene sectoriel rendant les comparaisons historiques non pertinentes.',
    ];

    return _BulletList(
      items: conditions.take(5).toList(),
      isDark: isDark,
      dotColor: AppTheme.negative,
    );
  }
}

_ComparisonDecision _buildComparisonDecision(
    AnalysisData left, AnalysisData right) {
  final rows = <_DecisionScoreRow>[];

  void addOutcome(
    String label,
    double? leftValue,
    double? rightValue,
    double weight, {
    bool lowerIsBetter = false,
  }) {
    if (leftValue == null || rightValue == null) return;
    if (leftValue == 0 || rightValue == 0) return;

    final adjustedLeft = lowerIsBetter ? -leftValue : leftValue;
    final adjustedRight = lowerIsBetter ? -rightValue : rightValue;
    final delta = (adjustedLeft - adjustedRight).abs();
    final scale = adjustedLeft.abs() + adjustedRight.abs() + 1e-9;
    final strength = (delta / scale).clamp(0.0, 1.0);

    final leftWins = adjustedLeft > adjustedRight;
    final leftPoints = leftWins
        ? weight * (0.5 + 0.5 * strength)
        : weight * (0.5 - 0.5 * strength);
    final rightPoints = weight - leftPoints;

    rows.add(
      _DecisionScoreRow(
        label: label,
        weight: weight,
        leftPoints: leftPoints,
        rightPoints: rightPoints,
        winnerTicker: (leftPoints - rightPoints).abs() < 0.01
            ? null
            : (leftPoints > rightPoints ? left.ticker : right.ticker),
      ),
    );
  }

  addOutcome('Score SIGMA', left.sigmaScore, right.sigmaScore, 24);
  addOutcome('Confiance', left.confidence * 100, right.confidence * 100, 14);
  addOutcome('Croissance CA', _comparisonMetric(left, 'revenueGrowth'),
      _comparisonMetric(right, 'revenueGrowth'), 14);
  addOutcome(
      'Marge operationnelle',
      _comparisonMetric(left, 'operatingMargins'),
      _comparisonMetric(right, 'operatingMargins'),
      14);
  addOutcome('ROE', _comparisonMetric(left, 'returnOnEquity'),
      _comparisonMetric(right, 'returnOnEquity'), 10);
  addOutcome('Dette / EQ', _comparisonMetric(left, 'debtToEquity'),
      _comparisonMetric(right, 'debtToEquity'), 10,
      lowerIsBetter: true);
  addOutcome('P/E', _comparisonMetric(left, 'trailingPE'),
      _comparisonMetric(right, 'trailingPE'), 8,
      lowerIsBetter: true);
  addOutcome('Potentiel de prix', _comparisonMetric(left, 'targetUpside'),
      _comparisonMetric(right, 'targetUpside'), 6);

  // Technical & flow signals (from analyzeStock enrichment)
  final lInsiderBuy = _comparisonMetric(left, 'insiderBuyRatio');
  final rInsiderBuy = _comparisonMetric(right, 'insiderBuyRatio');
  if (lInsiderBuy != null && rInsiderBuy != null) {
    addOutcome('Insider buy ratio', lInsiderBuy * 100, rInsiderBuy * 100, 8);
  }
  // IV rank: lower IV = less fear = slight edge (for comparable sectors)
  final lIV = _parseComparisonNumber(left.volatility.ivRank);
  final rIV = _parseComparisonNumber(right.volatility.ivRank);
  if (lIV != null && rIV != null && lIV > 0 && rIV > 0) {
    addOutcome('Volatilite implicite', lIV, rIV, 6, lowerIsBetter: true);
  }
  // Beta: lower is less risky (lowerIsBetter for conservative comparison)
  final lBeta = _comparisonMetric(left, 'beta');
  final rBeta = _comparisonMetric(right, 'beta');
  if (lBeta != null && rBeta != null && lBeta > 0 && rBeta > 0) {
    addOutcome('Beta', lBeta, rBeta, 4, lowerIsBetter: true);
  }
  // Analyst target upside
  addOutcome('FCF', _comparisonMetric(left, 'freeCashflow'),
      _comparisonMetric(right, 'freeCashflow'), 8);
  addOutcome('Marge nette', _comparisonMetric(left, 'profitMargins'),
      _comparisonMetric(right, 'profitMargins'), 8);
  addOutcome('Croissance EPS YoY', _comparisonMetric(left, 'earningsGrowth'),
      _comparisonMetric(right, 'earningsGrowth'), 8);
  addOutcome(
      'Detention institutionnelle',
      _comparisonMetric(left, 'institutionalOwnership'),
      _comparisonMetric(right, 'institutionalOwnership'),
      6);

  final totalWeight = rows.fold<double>(0, (acc, e) => acc + e.weight);
  final leftScore = rows.fold<double>(0, (acc, e) => acc + e.leftPoints);
  final rightScore = rows.fold<double>(0, (acc, e) => acc + e.rightPoints);

  AnalysisData? winner;
  String title;
  Color color;
  String summary;

  if (totalWeight <= 0 || (leftScore - rightScore).abs() < 4) {
    winner = null;
    title = 'RECOMMANDATION FINALE: NEUTRE / WATCHLIST';
    color = AppTheme.warning;
    summary =
        'La comparaison ne degage pas de domination suffisamment nette. Prioriser la discipline de prix et attendre un catalyseur discriminant avant de surponderer un dossier.';
  } else {
    winner = leftScore > rightScore ? left : right;
    final loser = winner.ticker == left.ticker ? right : left;
    final edge = ((leftScore - rightScore).abs() / totalWeight) * 100;
    title = 'RECOMMANDATION FINALE: SURPONDERER ${winner.ticker}';
    color = _verdictColor(winner.verdict);
    summary =
        '${winner.ticker} presente actuellement le meilleur couple qualite/valorisation face a ${loser.ticker}, avec un avantage relatif estime a ${edge.toStringAsFixed(0)}% sur la scorecard comparative.';
  }

  final confidence = totalWeight <= 0
      ? 0.0
      : ((leftScore - rightScore).abs() / totalWeight) * 100;

  final drivers = rows.toList()
    ..sort((a, b) {
      final weightCmp = b.weight.compareTo(a.weight);
      if (weightCmp != 0) return weightCmp;
      final bGap = (b.leftPoints - b.rightPoints).abs();
      final aGap = (a.leftPoints - a.rightPoints).abs();
      return bGap.compareTo(aGap);
    });

  final keyDrivers = drivers.take(4).map((e) {
    final orientation = e.winnerTicker == left.ticker
        ? '${left.ticker} > ${right.ticker}'
        : (e.winnerTicker == right.ticker
            ? '${right.ticker} > ${left.ticker}'
            : 'NEUTRE');
    return '${e.label}: $orientation';
  }).toList(growable: false);

  return _ComparisonDecision(
    winner: winner,
    title: title,
    summary: summary,
    confidence: confidence.clamp(0, 100),
    color: color,
    keyDrivers: keyDrivers,
    leftScore: leftScore,
    rightScore: rightScore,
    rows: rows,
  );
}

int _riskValue(String rawRisk) {
  final risk = rawRisk.trim().toUpperCase();
  if (risk.contains('LOW') || risk.contains('FAIBLE')) return 1;
  if (risk.contains('MED') || risk.contains('MOYEN')) return 2;
  if (risk.contains('HIGH') || risk.contains('ELEVE')) return 3;
  return 2;
}

double? _upsidePercent(AnalysisData analysis) {
  final current = _parsePrice(analysis.price);
  final target = analysis.targetPriceValue ??
      _parsePrice(analysis.tradeSetup.cleanTargetPrice);
  if (current <= 0 || target <= 0) return null;
  return (target - current) / current;
}

String _smartPct(double raw) {
  if (raw == 0) return 'N/A';
  final value = raw.abs() <= 1 ? raw * 100 : raw;
  return '${value.toStringAsFixed(1)}%';
}

String _lookupKey(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _isUsableNumber(double? value) => value != null && value != 0;

double? _parseComparisonNumber(dynamic value, {bool percentAsRatio = false}) {
  if (value == null) return null;
  if (value is Map) {
    return _parseComparisonNumber(
      value['raw'] ?? value['fmt'] ?? value['value'],
      percentAsRatio: percentAsRatio,
    );
  }
  if (value is num) {
    final n = value.toDouble();
    if (percentAsRatio && n.abs() > 1.5) return n / 100;
    return n;
  }
  final raw = value.toString().trim();
  if (!_hasText(raw)) return null;
  final hasPercent = raw.contains('%');
  final match = RegExp(r'-?\d+(?:[,.]\d+)?').firstMatch(raw);
  if (match == null) return null;
  var n = double.tryParse(match.group(0)!.replaceAll(',', '.'));
  if (n == null) return null;
  final upper = raw.toUpperCase();
  if (upper.contains('T')) n *= 1e12;
  if (upper.contains('B')) n *= 1e9;
  if (upper.contains('M')) n *= 1e6;
  if (upper.contains('K')) n *= 1e3;
  if (percentAsRatio && (hasPercent || n.abs() > 1.5)) n /= 100;
  return n;
}

Map<String, dynamic> _rawInstitutionalMap(AnalysisData analysis) {
  final raw = analysis.rawInstitutionalData;
  if (!_hasText(raw)) return const {};
  try {
    final decoded = jsonDecode(raw!);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

dynamic _findDeep(dynamic node, Set<String> aliases, [int depth = 0]) {
  if (node == null || depth > 7) return null;
  if (node is Map) {
    for (final entry in node.entries) {
      if (aliases.contains(_lookupKey(entry.key.toString()))) {
        return entry.value;
      }
    }
    for (final value in node.values) {
      final found = _findDeep(value, aliases, depth + 1);
      if (found != null) return found;
    }
  }
  if (node is List) {
    for (final value in node.take(80)) {
      final found = _findDeep(value, aliases, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

String? _findDeepText(dynamic node, Set<String> aliases, [int depth = 0]) {
  final found = _findDeep(node, aliases, depth);
  final text = found?.toString().trim();
  return _hasText(text) ? text : null;
}

List<String> _metricAliases(String key) {
  switch (key) {
    case 'marketCap':
      return ['marketCap', 'market capitalization', 'capitalisation bours.'];
    case 'trailingPE':
      return ['trailingPE', 'trailing pe', 'pe', 'p/e ratio'];
    case 'forwardPE':
      return ['forwardPE', 'forward pe', 'p/e previsionnel'];
    case 'pegRatio':
      return ['pegRatio', 'peg'];
    case 'priceToSales':
      return ['priceToSales', 'price to sales', 'p/s'];
    case 'enterpriseToEbitda':
      return ['enterpriseToEbitda', 'ev ebitda', 'ev/ebitda'];
    case 'revenueGrowth':
      return ['revenueGrowth', 'revenue growth', 'croissance ca'];
    case 'operatingMargins':
      return ['operatingMargins', 'operating margin', 'marge oper'];
    case 'profitMargins':
      return ['profitMargins', 'net margin', 'marge nette'];
    case 'returnOnEquity':
      return ['returnOnEquity', 'roe'];
    case 'debtToEquity':
      return ['debtToEquity', 'debt equity', 'debt/equity', 'd/e ratio'];
    case 'freeCashflow':
      return ['freeCashflow', 'free cash flow', 'fcf'];
    case 'earningsGrowth':
      return ['earningsGrowth', 'eps growth', 'earnings growth'];
    case 'beta':
      return ['beta'];
    case 'shortPercentOfFloat':
      return ['shortPercentOfFloat', 'short percent of float'];
    case 'dividendYield':
      return ['dividendYield', 'dividend yield'];
  }
  return [key];
}

bool _metricIsPercent(String key) {
  return {
    'revenueGrowth',
    'operatingMargins',
    'profitMargins',
    'returnOnEquity',
    'earningsGrowth',
    'shortPercentOfFloat',
    'dividendYield',
    'targetUpside',
  }.contains(key);
}

double? _matrixMetric(
  AnalysisData analysis,
  List<String> aliases, {
  bool percentAsRatio = false,
}) {
  final normalized = aliases.map(_lookupKey).toSet();
  for (final item in analysis.financialMatrix) {
    final label = _lookupKey(item.label);
    final matches = normalized.any(
      (alias) => label.contains(alias) || alias.contains(label),
    );
    if (!matches) continue;
    final value = _parseComparisonNumber(
      item.value,
      percentAsRatio: percentAsRatio,
    );
    if (_isUsableNumber(value)) return value;
  }
  return null;
}

double? _deepMetric(
  AnalysisData analysis,
  List<String> aliases, {
  bool percentAsRatio = false,
}) {
  final normalized = aliases.map(_lookupKey).toSet();
  final roots = <dynamic>[
    analysis.fullOwnership,
    analysis.earningsCalendar,
    analysis.earningsTrend,
    analysis.dividendData,
    analysis.historicalEarnings,
    analysis.institutionalHolders,
    _rawInstitutionalMap(analysis),
  ];
  for (final root in roots) {
    final value = _parseComparisonNumber(
      _findDeep(root, normalized),
      percentAsRatio: percentAsRatio,
    );
    if (_isUsableNumber(value)) return value;
  }
  return null;
}

double? _majorHolderBreakdownMetric(
  AnalysisData analysis,
  String needle, {
  bool percentAsRatio = true,
}) {
  final rows = (analysis.fullOwnership?['majorHolders'] as List?) ??
      (_rawInstitutionalMap(analysis)['majorHolders'] as List?) ??
      const [];
  for (final row in rows) {
    if (row is! Map) continue;
    for (final value in row.values) {
      final text = value?.toString() ?? '';
      if (text.toLowerCase().contains(needle.toLowerCase())) {
        return _parseComparisonNumber(text, percentAsRatio: percentAsRatio);
      }
    }
  }
  return null;
}

double? _institutionalOwnership(AnalysisData analysis) {
  final holderValue = analysis.holders?.institutionsPercent;
  if (_isUsableNumber(holderValue)) return holderValue;
  return _deepMetric(
        analysis,
        ['institutionsPercentHeld', 'institutional ownership'],
        percentAsRatio: true,
      ) ??
      _majorHolderBreakdownMetric(analysis, 'held by institutions');
}

double? _insiderOwnership(AnalysisData analysis) {
  final holderValue = analysis.holders?.insidersPercent;
  if (_isUsableNumber(holderValue)) return holderValue;
  return _deepMetric(
        analysis,
        ['insidersPercentHeld', 'insider ownership'],
        percentAsRatio: true,
      ) ??
      _majorHolderBreakdownMetric(analysis, 'held by insiders');
}

int? _institutionCount(AnalysisData analysis) {
  final count = analysis.holders?.institutionsCount;
  if (count != null && count > 0) return count;
  final rows = analysis.institutionalHolders ??
      (analysis.fullOwnership?['institutionsList'] as List?) ??
      (analysis.fullOwnership?['institutions'] as List?);
  if (rows != null && rows.isNotEmpty) return rows.length;
  return null;
}

String _topHolderName(AnalysisData analysis) {
  if (analysis.holders?.topInstitutions.isNotEmpty == true) {
    return analysis.holders!.topInstitutions.first.organization;
  }
  final rows = analysis.institutionalHolders ??
      (analysis.fullOwnership?['institutionsList'] as List?) ??
      (analysis.fullOwnership?['institutions'] as List?) ??
      const [];
  for (final row in rows) {
    if (row is! Map) continue;
    final name = row['holder'] ??
        row['Holder'] ??
        row['organization'] ??
        row['name'] ??
        row['Organization'];
    if (_hasText(name?.toString())) return name.toString();
  }
  return 'N/A';
}

double? _comparisonMetric(AnalysisData analysis, String key) {
  if (key == 'targetUpside') return _upsidePercent(analysis);
  if (key == 'institutionalOwnership') return _institutionalOwnership(analysis);
  if (key == 'insiderOwnership') return _insiderOwnership(analysis);
  if (key == 'insiderBuyRatio') return analysis.insiderBuyRatio;

  final ks = analysis.keyStatistics;
  double? primary;
  switch (key) {
    case 'marketCap':
      primary = ks?.marketCap;
      break;
    case 'trailingPE':
      primary = ks?.trailingPE;
      break;
    case 'forwardPE':
      primary = ks?.forwardPE;
      break;
    case 'pegRatio':
      primary = ks?.pegRatio;
      break;
    case 'priceToSales':
      primary = ks?.priceToSales;
      break;
    case 'enterpriseToEbitda':
      primary = ks?.enterpriseToEbitda;
      break;
    case 'revenueGrowth':
      primary = ks?.revenueGrowth;
      break;
    case 'operatingMargins':
      primary = ks?.operatingMargins;
      break;
    case 'profitMargins':
      primary = ks?.profitMargins;
      break;
    case 'returnOnEquity':
      primary = ks?.returnOnEquity;
      break;
    case 'debtToEquity':
      primary = ks?.debtToEquity;
      break;
    case 'freeCashflow':
      primary = ks?.freeCashflow;
      break;
    case 'earningsGrowth':
      primary = ks?.earningsGrowth;
      break;
    case 'beta':
      primary = ks?.beta;
      primary ??= _parseComparisonNumber(analysis.volatility.beta);
      break;
    case 'shortPercentOfFloat':
      primary = ks?.shortPercentOfFloat;
      break;
    case 'dividendYield':
      primary = ks?.dividendYield;
      break;
  }
  if (_isUsableNumber(primary)) return primary;

  final aliases = _metricAliases(key);
  final percentAsRatio = _metricIsPercent(key);
  return _matrixMetric(
        analysis,
        aliases,
        percentAsRatio: percentAsRatio,
      ) ??
      _deepMetric(
        analysis,
        aliases,
        percentAsRatio: percentAsRatio,
      );
}

String _companyDisplayName(AnalysisData analysis) {
  if (_hasText(analysis.companyName)) return analysis.companyName!.trim();
  final rawName = _findDeepText(
    _rawInstitutionalMap(analysis),
    {'companyname', 'longname', 'shortname'},
  );
  return rawName ?? analysis.ticker;
}

String _comparisonMetricText(
  AnalysisData analysis,
  String key, {
  bool pct = false,
  bool money = false,
  int decimals = 1,
}) {
  final value = _comparisonMetric(analysis, key);
  if (!_isUsableNumber(value)) return 'N/A';
  if (pct) return _pct(value!);
  if (money) return _money(value!);
  return value!.toStringAsFixed(decimals);
}

String _targetPriceText(AnalysisData analysis) {
  final target = analysis.targetPriceValue ??
      _parseComparisonNumber(analysis.tradeSetup.cleanTargetPrice);
  if (!_isUsableNumber(target)) return 'N/A';
  return '\$${target!.toStringAsFixed(2)}';
}

List<String> _comparisonCatalystsFor(AnalysisData analysis) {
  final items = <String>[];
  for (final catalyst in analysis.catalysts.take(2)) {
    final headline = catalyst.event;
    if (_hasText(headline)) items.add('${analysis.ticker}: $headline');
  }
  for (final event in analysis.corporateEvents.take(2)) {
    final label = [event.date, event.event, event.description]
        .where((part) => _hasText(part))
        .join(' - ');
    if (_hasText(label)) items.add('${analysis.ticker}: $label');
  }
  final calendar = analysis.earningsCalendar;
  if (calendar != null && calendar.isNotEmpty) {
    final rawDate = calendar['Earnings Date'] ?? calendar['earningsDate'];
    final date = rawDate is List && rawDate.isNotEmpty
        ? rawDate.first?.toString()
        : rawDate?.toString();
    if (_hasText(date)) {
      items.add('${analysis.ticker}: prochaine publication resultats $date');
    }
  }
  for (final rating in analysis.analystRatings.take(1)) {
    if (_hasText(rating.firm) || _hasText(rating.rating)) {
      items.add(
        '${analysis.ticker}: ${rating.firm} ${rating.action} ${rating.rating}'
            .trim(),
      );
    }
  }
  for (final news in analysis.companyNews.take(2)) {
    if (_hasText(news.title)) items.add('${analysis.ticker}: ${news.title}');
  }
  final upside = _upsidePercent(analysis);
  if (upside != null) {
    items.add(
      '${analysis.ticker}: potentiel analyste ${upside >= 0 ? '+' : ''}${(upside * 100).toStringAsFixed(1)}%',
    );
  }
  return items.toSet().take(5).toList(growable: false);
}

String _winnerByHigher({
  required String leftTicker,
  required String rightTicker,
  required double? left,
  required double? right,
}) {
  if (left == null || right == null) return 'NEUTRE';
  if ((left - right).abs() < 0.01) return 'NEUTRE';
  return left > right ? leftTicker : rightTicker;
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION PRIMITIVE
// ════════════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isDark;
  final bool isLast;
  final String? meta;

  const _Section({
    required this.label,
    required this.child,
    required this.isDark,
    this.isLast = false,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? _kDarkBg : _kLightBg;
    final dim = isDark ? _kDarkDim : _kLightDim;

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
            child: Text(label, style: _sectionLabel(dim)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _HRule(isDark: isDark),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: child,
          ),
          if (meta != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Text(
                meta!,
                style: GoogleFonts.lora(fontSize: 10, color: dim),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 0.5,
                color: (isDark ? _kDarkBorder : _kLightBorder)
                    .withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONTENT BLOCKS
// ════════════════════════════════════════════════════════════════════════════

class _BodyBlock extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool disclaimer;

  const _BodyBlock({
    required this.text,
    required this.isDark,
    this.disclaimer = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = disclaimer
        ? (isDark ? _kDarkDim : _kLightDim)
        : (isDark ? _kDarkText : _kLightText);

    if (text.isEmpty) {
      return Text('\u2014', style: _bodyStyle(c, disclaimer: disclaimer));
    }

    return MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: _bodyStyle(c, disclaimer: disclaimer),
        strong: _bodyStyle(c, disclaimer: disclaimer)
            .copyWith(fontWeight: FontWeight.w800),
        em: _bodyStyle(c, disclaimer: disclaimer)
            .copyWith(fontStyle: FontStyle.italic),
        h1: GoogleFonts.lora(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: 0.5),
        h2: GoogleFonts.lora(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: 0.5),
        h3: GoogleFonts.lora(
            fontSize: 13, fontWeight: FontWeight.w700, color: c),
        h4: GoogleFonts.lora(
            fontSize: 12, fontWeight: FontWeight.w700, color: c),
        listBullet: _bodyStyle(c, disclaimer: disclaimer),
        blockSpacing: 10,
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final bool isDark;
  final Color? dotColor;

  const _BulletList({
    required this.items,
    required this.isDark,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dot = dotColor ?? AppTheme.primary;
    if (items.isEmpty) {
      return Text('\u2014', style: _bodyStyle(txt));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dot,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.isEmpty ? '\u2014' : item,
                        style: _bodyStyle(txt),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _CatalystList extends StatelessWidget {
  final List<Catalyst> catalysts;
  final bool isDark;

  const _CatalystList({required this.catalysts, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;

    return Column(
      children: catalysts.take(5).map((c) {
        final isRisk = c.type.toLowerCase().contains('risk') ||
            c.type.toLowerCase().contains('risque');
        final accent = isRisk ? AppTheme.negative : AppTheme.positive;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 2,
                height: 44,
                color: accent.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.type.toUpperCase(),
                      style: GoogleFonts.lora(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.headline,
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: txt,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.insight.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        c.insight,
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          height: 1.45,
                          color: dim,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CompanyProfileBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _CompanyProfileBlock({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = <_KV>[];

    if (_hasText(a.companyName)) rows.add(_KV('Societe', a.companyName!));
    if (_hasText(a.exchange)) rows.add(_KV('Marche', a.exchange!));
    if (_hasText(a.sector)) rows.add(_KV('Secteur', a.sector!));
    if (_hasText(a.industry)) rows.add(_KV('Industrie', a.industry!));
    if (_hasText(a.ceo)) rows.add(_KV('CEO', a.ceo!));
    if (a.employees != null && a.employees! > 0) {
      rows.add(_KV('Employes', a.employees!.toString()));
    }
    if (_hasText(a.country)) rows.add(_KV('Pays', a.country!));

    final profileText = _hasText(a.companyProfile)
        ? _cleanText(a.companyProfile)
        : (_hasText(a.businessModel)
            ? _cleanText(a.businessModel)
            : 'Le profil detaille entreprise est partiellement indisponible sur la requete API actuelle.');

    final revenueText = _hasText(a.revenueStreams)
        ? _cleanText(a.revenueStreams)
        : 'Repartition des revenus non renseignee par la source courante.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rows.isNotEmpty) _MetricTable(rows: rows, isDark: isDark),
        if (rows.isNotEmpty) const SizedBox(height: 10),
        _BodyBlock(text: profileText, isDark: isDark),
        const SizedBox(height: 10),
        _BodyBlock(text: 'Revenue streams: $revenueText', isDark: isDark),
        if (_hasText(a.website)) ...[
          const SizedBox(height: 10),
          _BodyBlock(text: 'Site: ${a.website}', isDark: isDark),
        ],
      ],
    );
  }
}

class _AgenticCommitteeBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _AgenticCommitteeBlock({required this.a, required this.isDark});

  String _truncate(String? text) {
    if (text == null || text.isEmpty) {
      return 'Données insuffisantes pour une conclusion ferme.';
    }
    return text.length > 120 ? '${text.substring(0, 117)}...' : text;
  }

  @override
  Widget build(BuildContext context) {
    final thoughts = a.agenticThoughts;

    final List<String> syntheticThoughts = [];
    if (thoughts.length >= 5) {
      syntheticThoughts.addAll(thoughts);
    } else {
      final current = _parsePrice(a.price);
      final target =
          a.targetPriceValue ?? _parsePrice(a.tradeSetup.cleanTargetPrice);
      final upside = current > 0 && target > 0
          ? ((target - current) / current * 100).toStringAsFixed(1)
          : null;

      syntheticThoughts.add(upside != null
          ? 'Analyse technique: objectif implicite ${upside.startsWith('-') ? '' : '+'}$upside% contre le dernier prix observe.'
          : 'Analyse technique: surveiller la confirmation du prix et des volumes avant de renforcer.');
      syntheticThoughts.add(_hasText(
              a.institutionalActivity.darkPoolInterpretation)
          ? 'Sentiment de marche: ${_truncate(a.institutionalActivity.darkPoolInterpretation)}'
          : 'Sentiment de marche: aucun signal institutionnel exploitable ne domine aujourd hui.');
      final pE = a.keyStatistics?.forwardPE ?? 0;
      syntheticThoughts.add(
          'Fondamentaux: ${pE > 0 ? "valorisation a ${pE.toStringAsFixed(1)}x P/E forward." : _truncate(a.summary)}');
      syntheticThoughts.add(_hasText(a.volatility.interpretation)
          ? 'Profil de risque: ${a.riskLevel.toUpperCase()}. ${_truncate(a.volatility.interpretation)}'
          : 'Profil de risque: taille de position a calibrer tant que la volatilite realisee reste incomplete.');
      syntheticThoughts.add(_hasText(a.alphaRecommendation)
          ? 'Strategie: ${_truncate(a.alphaRecommendation)}'
          : 'Strategie: entree progressive, controle du risque, reevaluation apres prochains resultats.');
    }

    return Column(
      children: [
        _AgentRow(
          name: 'TREND ANALYST',
          icon: Icons.analytics_outlined,
          thought: syntheticThoughts[0],
          isDark: isDark,
        ),
        _AgentRow(
          name: 'SENTIMENT AGENT',
          icon: Icons.psychology_outlined,
          thought: syntheticThoughts[1],
          isDark: isDark,
        ),
        _AgentRow(
          name: 'FUNDAMENTAL AGENT',
          icon: Icons.account_balance_outlined,
          thought: syntheticThoughts[2],
          isDark: isDark,
        ),
        _AgentRow(
          name: 'RISK COMPARATOR',
          icon: Icons.balance_outlined,
          thought: syntheticThoughts[3],
          isDark: isDark,
        ),
        _AgentRow(
          name: 'STRATEGY BUILDER',
          icon: Icons.gps_fixed_outlined,
          thought: syntheticThoughts[4],
          isDark: isDark,
        ),
      ],
    );
  }
}

class _AgentRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final String thought;
  final bool isDark;

  const _AgentRow({
    required this.name,
    required this.icon,
    required this.thought,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDimSub : _kLightDimSub;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? _kDarkSurface : _kLightSurface,
              border: Border.all(color: border, width: 0.5),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isDark ? _kDarkDim : _kLightDim,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: dim,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _cleanText(thought),
                  style: _bodyStyle(txt).copyWith(
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentCommitteeView extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _InvestmentCommitteeView({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final points = <String>[];

    if (_hasText(a.alphaRecommendation)) {
      points.add('Recommendation alpha: ${_cleanText(a.alphaRecommendation)}');
    }
    if (_hasText(a.webIntelligence)) {
      points.add('Web intelligence: ${_cleanText(a.webIntelligence!)}');
    }
    if (_hasText(a.rawInstitutionalData)) {
      points.add('Flux institutionnel: ${_cleanText(a.rawInstitutionalData!)}');
    }
    if (a.recommendationSteps.isNotEmpty) {
      points.addAll(a.recommendationSteps.take(3).map(_cleanText));
    }
    if (points.isEmpty) {
      points.addAll([
        'Aucune divergence institutionnelle forte detectee a ce stade.',
        'Conserver une execution progressive, avec reevaluation apres resultats trimestriels.',
        'Prioriser la discipline de valorisation tant que la profondeur de donnees reste partielle.',
      ]);
    }

    return _BulletList(
      items: points,
      isDark: isDark,
      dotColor: AppTheme.primary,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FINANCIAL SUMMARY
// ════════════════════════════════════════════════════════════════════════════

class _FinancialSummary extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _FinancialSummary({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ks = a.keyStatistics;
    final rows = <_KV>[];

    if (ks != null) {
      if (ks.revenue > 0) {
        rows.add(_KV("Chiffre d'affaires", _money(ks.revenue)));
      }
      if (ks.revenueGrowth != 0) {
        rows.add(_KV('Croissance du CA', _pct(ks.revenueGrowth)));
      }
      if (ks.operatingMargins != 0) {
        rows.add(_KV('Marge operationnelle', _pct(ks.operatingMargins)));
      }
      if (ks.profitMargins != 0) {
        rows.add(_KV('Marge nette', _pct(ks.profitMargins)));
      }
      if (ks.returnOnEquity != 0) {
        rows.add(_KV('ROE', _pct(ks.returnOnEquity)));
      }
      if (ks.returnOnAssets != 0) {
        rows.add(_KV('ROA', _pct(ks.returnOnAssets)));
      }
      if (ks.freeCashflow > 0) {
        rows.add(_KV('Free Cash Flow', _money(ks.freeCashflow)));
      }
      if (ks.totalDebt > 0) {
        rows.add(_KV('Dette totale', _money(ks.totalDebt)));
      }
      if (ks.debtToEquity > 0) {
        rows.add(
            _KV('Dette / Fonds propres', ks.debtToEquity.toStringAsFixed(1)));
      }
      if (ks.currentRatio > 0) {
        rows.add(_KV('Liquidite generale', ks.currentRatio.toStringAsFixed(2)));
      }
    } else {
      for (final m in a.financialMatrix.take(8)) {
        if (m.label.isNotEmpty && m.value.isNotEmpty && m.value != 'N/A') {
          rows.add(_KV(m.label, m.value));
        }
      }
    }

    if (rows.isEmpty) {
      return _BodyBlock(
        isDark: isDark,
        text: 'Donnees financieres en cours de chargement.',
      );
    }
    return _MetricTable(rows: rows, isDark: isDark);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  VALUATION GRID
// ════════════════════════════════════════════════════════════════════════════

class _ValuationGrid extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _ValuationGrid({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ks = a.keyStatistics;
    final rows = <_KV>[];

    if (ks != null) {
      if (ks.marketCap > 0) {
        rows.add(_KV('Capitalisation', _money(ks.marketCap)));
      }
      if (ks.enterpriseValue > 0) {
        rows.add(_KV('Valeur entreprise (EV)', _money(ks.enterpriseValue)));
      }
      if (ks.trailingPE > 0) {
        rows.add(_KV('P/E (TTM)', ks.trailingPE.toStringAsFixed(1)));
      }
      if (ks.forwardPE > 0) {
        rows.add(_KV('P/E previsionnel', ks.forwardPE.toStringAsFixed(1)));
      }
      if (ks.pegRatio > 0) {
        rows.add(_KV('Ratio PEG', ks.pegRatio.toStringAsFixed(2)));
      }
      if (ks.priceToBook > 0) {
        rows.add(_KV('P/B', ks.priceToBook.toStringAsFixed(2)));
      }
      if (ks.priceToSales > 0) {
        rows.add(_KV('P/S', ks.priceToSales.toStringAsFixed(2)));
      }
      if (ks.enterpriseToEbitda > 0) {
        rows.add(_KV('EV / EBITDA', ks.enterpriseToEbitda.toStringAsFixed(1)));
      }
    }

    if (rows.isEmpty) {
      final t = a.targetPriceValue != null && a.targetPriceValue! > 0
          ? '\$${a.targetPriceValue!.toStringAsFixed(2)}'
          : (a.tradeSetup.cleanTargetPrice.isEmpty
              ? 'N/A'
              : a.tradeSetup.cleanTargetPrice);
      final fallbackRows = <_KV>[
        _KV('Objectif de prix', t),
        _KV('Score SIGMA', a.sigmaScore.toStringAsFixed(1)),
        _KV('Confiance', '${(a.confidence * 100).toStringAsFixed(0)}%'),
        _KV('Risque', a.riskLevel.isEmpty ? 'N/A' : a.riskLevel),
      ];
      return _MetricTable(rows: fallbackRows, isDark: isDark);
    }

    return _MetricTable(rows: rows, isDark: isDark);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TECHNICAL SIGNAL TABLE — 3-column: indicator | value | colored badge
// ════════════════════════════════════════════════════════════════════════════

class _TechnicalSignalTable extends StatelessWidget {
  final List<TechnicalIndicator> signals;
  final bool isDark;

  const _TechnicalSignalTable({required this.signals, required this.isDark});

  Color _signalColor(String interpretation) {
    final up = interpretation.toUpperCase().trim();
    if (up.contains('BULLISH') ||
        up.contains('STRONG BUY') ||
        up == 'BUY' ||
        up.contains('OVERSOLD') ||
        up.contains('UPTREND') ||
        up.contains('POSITIVE')) {
      return AppTheme.positive;
    }
    if (up.contains('BEARISH') ||
        up.contains('STRONG SELL') ||
        up == 'SELL' ||
        up.contains('OVERBOUGHT') ||
        up.contains('DOWNTREND') ||
        up.contains('NEGATIVE')) {
      return AppTheme.negative;
    }
    // NEUTRAL, HOLD, WAIT, MIXED → amber
    return const Color(0xFFFFC107);
  }

  String _signalLabel(String interpretation) {
    final up = interpretation.toUpperCase().trim();
    if (up.isEmpty) return '—';
    // Normalize well-known labels
    const known = [
      'STRONG BUY',
      'BUY',
      'STRONG SELL',
      'SELL',
      'HOLD',
      'NEUTRAL',
      'OVERSOLD',
      'OVERBOUGHT',
      'BULLISH',
      'BEARISH',
      'WAIT',
      'MIXED',
      'UPTREND',
      'DOWNTREND',
      'POSITIVE',
      'NEGATIVE',
    ];
    for (final k in known) {
      if (up.contains(k)) return k;
    }
    return up.length > 11 ? '${up.substring(0, 11)}…' : up;
  }

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    return Column(
      children: signals.asMap().entries.map((entry) {
        final t = entry.value;
        final isLast = entry.key == signals.length - 1;
        final sigColor = _signalColor(t.interpretation);
        final sigLabel = _signalLabel(t.interpretation);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: border, width: 0.5),
                  ),
                ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Indicator name
              Expanded(
                flex: 4,
                child: Text(
                  t.indicator,
                  style: _metricLabel(dim),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Value
              Expanded(
                flex: 3,
                child: Text(
                  t.value,
                  style: _metricValue(txt),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Signal badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: sigColor.withValues(alpha: 0.10),
                  border: Border.all(
                      color: sigColor.withValues(alpha: 0.30), width: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  sigLabel,
                  style: GoogleFonts.lora(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: sigColor,
                    letterSpacing: 0.7,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TechnicalSignalsBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _TechnicalSignalsBlock({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final signals = a.technicalAnalysis
        .where((t) => _hasText(t.indicator) && _hasText(t.value))
        .take(10)
        .toList(growable: false);

    if (signals.isNotEmpty) {
      return _TechnicalSignalTable(signals: signals, isDark: isDark);
    }

    // Fallback when no technical data yet
    final fallback = <_KV>[];
    if (_hasText(a.tradeSetup.cleanEntryZone)) {
      fallback.add(_KV('Zone entree', a.tradeSetup.cleanEntryZone));
    }
    if (_hasText(a.tradeSetup.cleanStopLoss)) {
      fallback.add(_KV('Stop', a.tradeSetup.cleanStopLoss));
    }
    if (_hasText(a.volatility.beta) && a.volatility.beta != 'N/A') {
      fallback.add(_KV('Beta', a.volatility.beta));
    }
    if (_hasText(a.volatility.ivRank) && a.volatility.ivRank != 'N/A') {
      fallback.add(_KV('IV rank', a.volatility.ivRank));
    }

    final current = _parsePrice(a.price);
    final target =
        a.targetPriceValue ?? _parsePrice(a.tradeSetup.cleanTargetPrice);
    if (current > 0 && target > 0) {
      final upside = ((target - current) / current) * 100;
      fallback.add(_KV('Potentiel cible',
          '${upside >= 0 ? '+' : ''}${upside.toStringAsFixed(1)}%'));
    }
    if (a.sigmaScore > 0) {
      fallback.add(_KV('Score SIGMA', a.sigmaScore.toStringAsFixed(0)));
    }
    if (_hasText(a.riskLevel)) {
      fallback.add(_KV('Regime de risque', a.riskLevel.toUpperCase()));
    }

    if (fallback.isNotEmpty) {
      return _MetricTable(rows: fallback, isDark: isDark);
    }

    return _BodyBlock(
      isDark: isDark,
      text:
          'Le flux OHLCV complet n est pas encore charge; la lecture technique sera enrichie automatiquement des que le graphique sera disponible.',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SCENARIO GRID — Bull / Base / Bear
// ════════════════════════════════════════════════════════════════════════════

class _ScenarioGrid extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _ScenarioGrid({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final txt = isDark ? _kDarkText : _kLightText;
    final trends = a.projectedTrend.where((p) => p.price > 0).toList();

    if (trends.isNotEmpty) {
      final first = trends.first.price;
      final mid = trends[trends.length ~/ 2].price;
      final last = trends.last.price;

      String pct(double from, double to) {
        if (from <= 0 || to <= 0) return 'N/A';
        final value = ((to - from) / from) * 100;
        return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
      }

      final rows = [
        (
          label: 'DEPART',
          target: '\$${first.toStringAsFixed(2)}',
          text: 'Point de reference du modele projete (${trends.first.date}).',
          color: txt,
        ),
        (
          label: 'MILIEU',
          target: '\$${mid.toStringAsFixed(2)}',
          text: 'Variation intermediaire estimee: ${pct(first, mid)}.',
          color: txt,
        ),
        (
          label: 'FIN',
          target: '\$${last.toStringAsFixed(2)}',
          text: 'Variation totale projetee: ${pct(first, last)}.',
          color: last >= first ? AppTheme.positive : AppTheme.negative,
        ),
      ];

      return Column(
        children: rows.asMap().entries.map((entry) {
          final s = entry.value;
          final isLast = entry.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: border, width: 0.5),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    s.label,
                    style: GoogleFonts.lora(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: s.color,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    s.target,
                    style: GoogleFonts.lora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: s.color,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    s.text,
                    style: GoogleFonts.lora(
                      fontSize: 12,
                      height: 1.5,
                      color: dim,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    final current = _parsePrice(a.price);
    final target =
        a.targetPriceValue ?? _parsePrice(a.tradeSetup.cleanTargetPrice);
    if (current > 0 && target > 0) {
      final expected = ((target - current) / current) * 100;
      return _BodyBlock(
        isDark: isDark,
        text:
            'Objectif API disponible: \$${target.toStringAsFixed(2)} vs prix actuel \$${current.toStringAsFixed(2)} (${expected >= 0 ? '+' : ''}${expected.toStringAsFixed(1)}%).',
      );
    }

    if (current > 0) {
      final risk = _riskValue(a.riskLevel);
      final basePct = ((a.sigmaScore - 50) / 200).clamp(-0.10, 0.25);
      final spread = risk == 1 ? 0.12 : (risk == 2 ? 0.18 : 0.26);
      final bear = current * (1 + basePct - spread);
      final base = current * (1 + basePct);
      final bull = current * (1 + basePct + spread * 0.8);

      final rows = <_KV>[
        _KV('Bear case (12m)', '\$${bear.toStringAsFixed(2)}'),
        _KV('Base case (12m)', '\$${base.toStringAsFixed(2)}'),
        _KV('Bull case (12m)', '\$${bull.toStringAsFixed(2)}'),
      ];
      return _MetricTable(rows: rows, isDark: isDark);
    }

    return _BodyBlock(
      isDark: isDark,
      text:
          'Donnees de projection insuffisantes pour produire un scenario fiable a partir de l API.',
    );
  }
}

class _NewsDigest extends StatelessWidget {
  final List<NewsArticle> news;
  final bool isDark;

  const _NewsDigest({required this.news, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    return Column(
      children: news.take(5).toList().asMap().entries.map((entry) {
        final item = entry.value;
        final isLast = entry.key == (news.take(5).length - 1);
        return GestureDetector(
          onTap: item.url.isNotEmpty
              ? () async {
                  final uri = Uri.tryParse(item.url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: border, width: 0.45),
                    ),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.source.toUpperCase(),
                        style: GoogleFonts.lora(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: dim,
                        ),
                      ),
                    ),
                    Text(
                      item.publishedAt,
                      style: GoogleFonts.lora(
                        fontSize: 10,
                        color: dim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: GoogleFonts.lora(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: txt,
                    height: 1.4,
                  ),
                ),
                if (item.summary.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lora(
                      fontSize: 12,
                      color: dim,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI SENTIMENT BLOCK — loads FinBERT sentiment lazily
// ─────────────────────────────────────────────────────────────────────────────
class _AiSentimentBlock extends StatefulWidget {
  final String symbol;
  final bool isDark;

  const _AiSentimentBlock({required this.symbol, required this.isDark});

  @override
  State<_AiSentimentBlock> createState() => _AiSentimentBlockState();
}

class _AiSentimentBlockState extends State<_AiSentimentBlock> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = SigmaApiService.getAiSentiment(widget.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5)),
              const SizedBox(width: 10),
              Text('Analyse FinBERT en cours...',
                  style: GoogleFonts.lora(
                      fontSize: 11, color: AppTheme.textTertiary)),
            ]),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sentiment IA indisponible pour ce ticker.',
                style: GoogleFonts.lora(
                    fontSize: 11, color: AppTheme.textTertiary)),
          );
        }
        return AiSentimentSection(snap.data);
      },
    );
  }
}

// ── AI Summary Block (BART) ────────────────────────────────────────────────
class _AiSummaryBlock extends StatefulWidget {
  final String symbol;
  final bool isDark;

  const _AiSummaryBlock({required this.symbol, required this.isDark});

  @override
  State<_AiSummaryBlock> createState() => _AiSummaryBlockState();
}

class _AiSummaryBlockState extends State<_AiSummaryBlock> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = SigmaApiService.getAiSummary(widget.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5)),
              const SizedBox(width: 10),
              Text('Résumé BART en cours...',
                  style: GoogleFonts.lora(
                      fontSize: 11, color: AppTheme.textTertiary)),
            ]),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Résumé IA indisponible pour ce ticker.',
                style: GoogleFonts.lora(
                    fontSize: 11, color: AppTheme.textTertiary)),
          );
        }
        final d = snap.data!;
        final summaryText = (d['summary'] as String? ?? '').trim();
        if (summaryText.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Résumé IA indisponible pour ce ticker.',
                style: GoogleFonts.lora(
                    fontSize: 11, color: AppTheme.textTertiary)),
          );
        }
        final sourcesRaw = d['sources'];
        final sources = sourcesRaw is List
            ? sourcesRaw.map((s) => s.toString()).toList()
            : <String>[];
        final textColor = widget.isDark
            ? AppTheme.white.withValues(alpha: 0.87)
            : AppTheme.black87;
        final dimColor = widget.isDark ? AppTheme.white24 : AppTheme.black26;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summaryText,
                style: GoogleFonts.lora(
                    fontSize: 12,
                    height: 1.6,
                    color: textColor)),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: sources
                    .take(5)
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(s,
                              style: GoogleFonts.lora(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                  letterSpacing: 0.3)),
                        ))
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AnalystConsensusBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _AnalystConsensusBlock({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ar = a.analystRecommendations;
    final total = ar.strongBuy + ar.buy + ar.hold + ar.sell + ar.strongSell;

    if (total <= 0) {
      return _BodyBlock(
        isDark: isDark,
        text:
            'Consensus analyste non disponible sur ce ticker pour la fenetre courante.',
      );
    }

    final rows = <_KV>[
      _KV('Consensus', ar.consensusLabel),
      _KV('Score consensus', ar.consensusScore.toStringAsFixed(0)),
      _KV(
        'Distribution',
        'SB ${ar.strongBuy} · B ${ar.buy} · H ${ar.hold} · S ${ar.sell} · SS ${ar.strongSell}',
      ),
      _KV('Fenetre', _hasText(ar.period) ? ar.period : 'N/A'),
    ];

    return _MetricTable(rows: rows, isDark: isDark);
  }
}

class _OwnershipFlowBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _OwnershipFlowBlock({required this.a, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = <_KV>[];
    final holders = a.holders;

    if (holders != null) {
      if (holders.institutionsPercent != 0) {
        rows.add(
          _KV('Detention institutionnelle',
              _smartPct(holders.institutionsPercent)),
        );
      }
      if (holders.insidersPercent != 0) {
        rows.add(_KV('Detention insiders', _smartPct(holders.insidersPercent)));
      }
      if (holders.institutionsCount > 0) {
        rows.add(_KV('Nb institutions', holders.institutionsCount.toString()));
      }
    }

    if (a.institutionalActivity.smartMoneySentiment != 0) {
      rows.add(
        _KV(
          'Smart money sentiment',
          _smartPct(a.institutionalActivity.smartMoneySentiment),
        ),
      );
    }
    if (a.institutionalActivity.retailSentiment != 0) {
      rows.add(
        _KV(
          'Retail sentiment',
          _smartPct(a.institutionalActivity.retailSentiment),
        ),
      );
    }
    if (a.socialSentiment != null && a.socialSentiment!.mentions > 0) {
      rows.add(
          _KV('Mentions sociales', a.socialSentiment!.mentions.toString()));
    }
    if (a.insiderBuyRatio != null && a.insiderBuyRatio! > 0) {
      rows.add(_KV('Insider buy ratio', _smartPct(a.insiderBuyRatio!)));
    }

    if (rows.isEmpty) {
      return _BodyBlock(
        isDark: isDark,
        text:
            'Flux de positionnement (ownership/sentiment) encore partiels pour cette valeur.',
      );
    }

    return _MetricTable(rows: rows, isDark: isDark);
  }
}

class _ConsensusComparisonBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _ConsensusComparisonBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = left.analystRecommendations;
    final r = right.analystRecommendations;

    final rows = <_RelativeFactor>[
      _RelativeFactor(
        'Score consensus',
        l.consensusScore > 0 ? l.consensusScore.toStringAsFixed(0) : 'N/A',
        r.consensusScore > 0 ? r.consensusScore.toStringAsFixed(0) : 'N/A',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: l.consensusScore > 0 ? l.consensusScore : null,
          right: r.consensusScore > 0 ? r.consensusScore : null,
        ),
      ),
      _RelativeFactor(
        'Confiance modele',
        '${(left.confidence * 100).toStringAsFixed(0)}%',
        '${(right.confidence * 100).toStringAsFixed(0)}%',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: left.confidence,
          right: right.confidence,
        ),
      ),
    ];

    return _RelativeTable(rows: rows, isDark: isDark);
  }
}

class _OwnershipComparisonBlock extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _OwnershipComparisonBlock({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final li = _institutionalOwnership(left);
    final ri = _institutionalOwnership(right);
    final lInside = _insiderOwnership(left);
    final rInside = _insiderOwnership(right);
    final lCount = _institutionCount(left);
    final rCount = _institutionCount(right);

    final ls = left.institutionalActivity.smartMoneySentiment;
    final rs = right.institutionalActivity.smartMoneySentiment;

    final lm = left.socialSentiment?.mentions;
    final rm = right.socialSentiment?.mentions;

    final rows = <_RelativeFactor>[
      _RelativeFactor(
        'Detention institutionnelle',
        li != null && li != 0 ? _smartPct(li) : 'N/A',
        ri != null && ri != 0 ? _smartPct(ri) : 'N/A',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: li == null || li == 0 ? null : li,
          right: ri == null || ri == 0 ? null : ri,
        ),
      ),
      _RelativeFactor(
        'Detention insiders',
        lInside != null && lInside != 0 ? _smartPct(lInside) : 'N/A',
        rInside != null && rInside != 0 ? _smartPct(rInside) : 'N/A',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: lInside == null || lInside == 0 ? null : lInside,
          right: rInside == null || rInside == 0 ? null : rInside,
        ),
      ),
      _RelativeFactor(
        'Nombre institutions',
        lCount != null && lCount > 0 ? lCount.toString() : 'N/A',
        rCount != null && rCount > 0 ? rCount.toString() : 'N/A',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: lCount?.toDouble(),
          right: rCount?.toDouble(),
        ),
      ),
      _RelativeFactor(
        'Premier holder',
        _topHolderName(left),
        _topHolderName(right),
        null,
      ),
      _RelativeFactor(
        'Smart money sentiment',
        ls != 0 ? _smartPct(ls) : 'N/A',
        rs != 0 ? _smartPct(rs) : 'N/A',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: ls == 0 ? null : ls,
          right: rs == 0 ? null : rs,
        ),
      ),
      _RelativeFactor(
        'Mentions sociales',
        lm != null && lm > 0 ? lm.toString() : 'N/A',
        rm != null && rm > 0 ? rm.toString() : 'N/A',
        _winnerByHigher(
          leftTicker: left.ticker,
          rightTicker: right.ticker,
          left: lm == null || lm == 0 ? null : lm.toDouble(),
          right: rm == null || rm == 0 ? null : rm.toDouble(),
        ),
      ),
    ];

    return _RelativeTable(rows: rows, isDark: isDark);
  }
}

class _FullReportButton extends StatelessWidget {
  final AnalysisData analysis;
  final bool isDark;

  const _FullReportButton({required this.analysis, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FinancialReportScreen(analysis: analysis),
            ),
          );
        },
        icon: const Icon(Icons.description_rounded, size: 16),
        label: Text(
          'Voir le rapport complet',
          style: GoogleFonts.lora(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.35),
            width: 0.8,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}

String _resolveTickerLogo(AnalysisData analysis) {
  return LogoResolver.resolve(analysis.ticker, providedUrl: analysis.image);
}

// ════════════════════════════════════════════════════════════════════════════
//  COMPARATIVE GRID
// ════════════════════════════════════════════════════════════════════════════

class _CompareGrid extends StatelessWidget {
  final AnalysisData left;
  final AnalysisData right;
  final bool isDark;

  const _CompareGrid({
    required this.left,
    required this.right,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    final rows = <_CmpKV>[
      _CmpKV('Societe', _companyDisplayName(left), _companyDisplayName(right)),
      _CmpKV('Recommandation', left.verdict.toUpperCase(),
          right.verdict.toUpperCase()),
      _CmpKV('Prix actuel', left.price, right.price),
      _CmpKV('Objectif', _targetPriceText(left), _targetPriceText(right)),
      _CmpKV(
          'Capitalisation',
          _comparisonMetricText(left, 'marketCap', money: true),
          _comparisonMetricText(right, 'marketCap', money: true)),
      _CmpKV('P/E (TTM)', _comparisonMetricText(left, 'trailingPE'),
          _comparisonMetricText(right, 'trailingPE')),
      _CmpKV('P/E previsionnel', _comparisonMetricText(left, 'forwardPE'),
          _comparisonMetricText(right, 'forwardPE')),
      _CmpKV('PEG', _comparisonMetricText(left, 'pegRatio'),
          _comparisonMetricText(right, 'pegRatio')),
      _CmpKV('EV/EBITDA', _comparisonMetricText(left, 'enterpriseToEbitda'),
          _comparisonMetricText(right, 'enterpriseToEbitda')),
      _CmpKV(
          'Croissance CA',
          _comparisonMetricText(left, 'revenueGrowth', pct: true),
          _comparisonMetricText(right, 'revenueGrowth', pct: true)),
      _CmpKV(
          'Marge oper.',
          _comparisonMetricText(left, 'operatingMargins', pct: true),
          _comparisonMetricText(right, 'operatingMargins', pct: true)),
      _CmpKV(
          'Marge nette',
          _comparisonMetricText(left, 'profitMargins', pct: true),
          _comparisonMetricText(right, 'profitMargins', pct: true)),
      _CmpKV('ROE', _comparisonMetricText(left, 'returnOnEquity', pct: true),
          _comparisonMetricText(right, 'returnOnEquity', pct: true)),
      _CmpKV(
          'Free Cash Flow',
          _comparisonMetricText(left, 'freeCashflow', money: true),
          _comparisonMetricText(right, 'freeCashflow', money: true)),
      _CmpKV('Dette / EQ', _comparisonMetricText(left, 'debtToEquity'),
          _comparisonMetricText(right, 'debtToEquity')),
      _CmpKV(
          'EPS growth',
          _comparisonMetricText(left, 'earningsGrowth', pct: true),
          _comparisonMetricText(right, 'earningsGrowth', pct: true)),
      _CmpKV('Beta', _comparisonMetricText(left, 'beta'),
          _comparisonMetricText(right, 'beta')),
      _CmpKV(
          'Ownership inst.',
          _comparisonMetricText(left, 'institutionalOwnership', pct: true),
          _comparisonMetricText(right, 'institutionalOwnership', pct: true)),
      _CmpKV(
          'Insider buy ratio',
          _comparisonMetricText(left, 'insiderBuyRatio', pct: true),
          _comparisonMetricText(right, 'insiderBuyRatio', pct: true)),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                flex: 3,
                child: Text(
                  left.ticker,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: txt,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  right.ticker,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: txt,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 0.7, color: border),
        ...rows.asMap().entries.map((entry) {
          final r = entry.value;
          final isLast = entry.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: border, width: 0.45),
                    ),
                  ),
            child: Row(
              children: [
                Expanded(
                    flex: 5, child: Text(r.metric, style: _metricLabel(dim))),
                Expanded(
                  flex: 3,
                  child: Text(r.left,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _metricValue(txt)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(r.right,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _metricValue(txt)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  METRIC TABLE
// ════════════════════════════════════════════════════════════════════════════

class _MetricTable extends StatelessWidget {
  final List<_KV> rows;
  final bool isDark;

  const _MetricTable({required this.rows, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    return Column(
      children: rows.asMap().entries.map((entry) {
        final r = entry.value;
        final isLast = entry.key == rows.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: border, width: 0.5),
                  ),
                ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  r.k,
                  style: _metricLabel(dim),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: Text(
                  r.v,
                  style: _metricValue(txt),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RelativeTable extends StatelessWidget {
  final List<_RelativeFactor> rows;
  final bool isDark;

  const _RelativeTable({required this.rows, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final border = isDark ? _kDarkBorder : _kLightBorder;

    final visibleRows = rows
        .where((r) => r.leftValue != 'N/A' || r.rightValue != 'N/A')
        .toList(growable: false);

    if (visibleRows.isEmpty) {
      return _BodyBlock(
        isDark: isDark,
        text: 'Donnees comparatives insuffisantes pour cette section.',
      );
    }

    return Column(
      children: visibleRows.asMap().entries.map((entry) {
        final row = entry.value;
        final isLast = entry.key == visibleRows.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: isLast
              ? null
              : BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: border, width: 0.45),
                  ),
                ),
          child: Row(
            children: [
              Expanded(
                  flex: 4, child: Text(row.label, style: _metricLabel(dim))),
              Expanded(
                flex: 3,
                child: Text(
                  row.leftValue,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _metricValue(txt),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  row.rightValue,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _metricValue(txt),
                ),
              ),
              SizedBox(
                width: 58,
                child: Text(
                  row.winnerTicker ?? 'NEUTRE',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: (row.winnerTicker == null ||
                            row.winnerTicker == 'NEUTRE')
                        ? dim
                        : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CHROME WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _NoteCommandBar extends StatelessWidget {
  final TabController controller;
  final int modeIndex;
  final TextEditingController singleCtrl;
  final TextEditingController leftCtrl;
  final TextEditingController rightCtrl;
  final bool isDark;
  final bool isAnalyzing;
  final bool isComparing;
  final bool compactComparisonHeader;
  final VoidCallback onExpandComparison;
  final VoidCallback onAnalyze;
  final VoidCallback onCompare;

  const _NoteCommandBar({
    required this.controller,
    required this.modeIndex,
    required this.singleCtrl,
    required this.leftCtrl,
    required this.rightCtrl,
    required this.isDark,
    required this.isAnalyzing,
    required this.isComparing,
    required this.compactComparisonHeader,
    required this.onExpandComparison,
    required this.onAnalyze,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? _kDarkSurface : _kLightSurface;
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    final busy = modeIndex == 0 ? isAnalyzing : isComparing;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'NOTE LAB',
                  style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: txt,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TabBar(
                  controller: controller,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 1.4,
                  dividerColor: Colors.transparent,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  labelColor: txt,
                  unselectedLabelColor: dim,
                  labelStyle: GoogleFonts.lora(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                  tabs: const [
                    Tab(text: 'ANALYSE'),
                    Tab(text: 'COMPARAISON'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (modeIndex == 0)
            Row(
              children: [
                Expanded(
                  child: _TickerField(
                    ctrl: singleCtrl,
                    isDark: isDark,
                    hint: 'Ticker ou entreprise',
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: busy ? 'ANALYSE...' : 'ANALYSER',
                  isDark: isDark,
                  active: !busy,
                  onTap: onAnalyze,
                  busy: busy,
                ),
              ],
            )
          else if (compactComparisonHeader && !isComparing)
            _CompactComparisonHeader(
              leftTicker: leftCtrl.text.trim().toUpperCase(),
              rightTicker: rightCtrl.text.trim().toUpperCase(),
              isDark: isDark,
              onEdit: onExpandComparison,
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TickerField(
                        ctrl: leftCtrl,
                        isDark: isDark,
                        hint: 'Entreprise A',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Text(
                        'vs',
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? _kDarkDim : _kLightDim,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _TickerField(
                        ctrl: rightCtrl,
                        isDark: isDark,
                        hint: 'Entreprise B',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ActionBtn(
                    label: busy ? 'COMPARAISON...' : 'COMPARER',
                    isDark: isDark,
                    active: !busy,
                    onTap: onCompare,
                    busy: busy,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactComparisonHeader extends StatelessWidget {
  final String leftTicker;
  final String rightTicker;
  final bool isDark;
  final VoidCallback onEdit;

  const _CompactComparisonHeader({
    required this.leftTicker,
    required this.rightTicker,
    required this.isDark,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? _kDarkBorder : _kLightBorder;
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;

    final left = leftTicker.isEmpty ? 'A' : leftTicker;
    final right = rightTicker.isEmpty ? 'B' : rightTicker;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1420) : const Color(0xFFF0EDE8),
        border: Border.all(color: border, width: 0.7),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$left vs $right',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lora(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: txt,
                letterSpacing: 0.3,
              ),
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 26),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              'MODIFIER',
              style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: dim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerField extends StatefulWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final String hint;

  const _TickerField(
      {required this.ctrl, required this.isDark, required this.hint});

  @override
  State<_TickerField> createState() => _TickerFieldState();
}

class _TickerFieldState extends State<_TickerField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _TickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ctrl != widget.ctrl) {
      oldWidget.ctrl.removeListener(_onTextChanged);
      widget.ctrl.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.ctrl.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.ctrl.text.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      context.read<SigmaProvider>().updateSearchResults(query);
    });
  }

  Iterable<Map<String, dynamic>> _filterOptions(
    SigmaProvider sp,
    String query,
  ) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return const Iterable<Map<String, dynamic>>.empty();

    final results = sp.instantSearchResults(q).where((item) {
      final symbol = (item['symbol'] ?? '').toString().toUpperCase();
      final name =
          (item['description'] ?? item['name'] ?? '').toString().toUpperCase();
      return symbol.startsWith(q) || symbol.contains(q) || name.contains(q);
    }).toList(growable: false);

    return results.take(8);
  }

  @override
  Widget build(BuildContext context) {
    final fill =
        widget.isDark ? const Color(0xFF0A1420) : const Color(0xFFF0EDE8);
    final border = widget.isDark ? _kDarkBorder : const Color(0xFFC8C4BC);
    final txClr = widget.isDark ? _kDarkText : _kLightText;
    final hnClr = widget.isDark ? _kDarkDimSub : _kLightDimSub;
    final bg = widget.isDark ? _kDarkSurface : _kLightSurface;

    return Consumer<SigmaProvider>(
      builder: (context, sp, _) {
        return RawAutocomplete<Map<String, dynamic>>(
          textEditingController: widget.ctrl,
          focusNode: _focusNode,
          displayStringForOption: (option) =>
              (option['symbol'] ?? '').toString().toUpperCase(),
          optionsBuilder: (textEditingValue) =>
              _filterOptions(sp, textEditingValue.text),
          onSelected: (selection) {
            widget.ctrl.text =
                (selection['symbol'] ?? '').toString().toUpperCase();
            widget.ctrl.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.ctrl.text.length),
            );
            _focusNode.unfocus();
          },
          fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textCtrl,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => onFieldSubmitted(),
              style: GoogleFonts.lora(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: txClr,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.lora(fontSize: 12, color: hnClr),
                filled: true,
                fillColor: fill,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: sp.isSearching
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: hnClr,
                          ),
                        ),
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: border, width: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optionList = options.toList(growable: false);
            if (optionList.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width - 64,
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border.all(color: border, width: 0.8),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: optionList.length,
                    separatorBuilder: (_, __) => Container(
                      height: 0.6,
                      color: border,
                    ),
                    itemBuilder: (context, index) {
                      final option = optionList[index];
                      final symbol =
                          (option['symbol'] ?? '').toString().toUpperCase();
                      // Re-resolve from sp.searchResults so async logo
                      // hydration is reflected without waiting for a text change.
                      final freshOption = sp.searchResults.firstWhere(
                        (r) =>
                            (r['symbol'] ?? '').toString().toUpperCase() ==
                            symbol,
                        orElse: () => option,
                      );
                      final name = (freshOption['description'] ??
                              freshOption['name'] ??
                              '')
                          .toString();
                      final logoUrl =
                          (freshOption['logo'] ?? freshOption['logoUrl'])
                              ?.toString();

                      final exchange = (freshOption['stockExchange'] ??
                              freshOption['exchangeShortName'] ??
                              freshOption['exchange'] ??
                              '')
                          .toString();
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              TickerLogoThumb(symbol: symbol, logoUrl: logoUrl),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          symbol,
                                          style: GoogleFonts.lora(
                                            fontSize: 13,
                                            color: txClr,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                        if (exchange.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              exchange.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.lora(
                                                fontSize: 9,
                                                color: hnClr,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (name.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.lora(
                                          fontSize: 11,
                                          color: hnClr,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final bool isDark;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.isDark,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary
              : AppTheme.primary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: Colors.white.withValues(alpha: active ? 1.0 : 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MICRO WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _HRule extends StatelessWidget {
  final bool isDark;

  const _HRule({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = isDark ? _kDarkBorder : _kLightBorder;
    return Container(height: 0.6, color: c);
  }
}

class _CoverKV extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _CoverKV({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final txt = isDark ? _kDarkText : _kLightText;
    final dim = isDark ? _kDarkDim : _kLightDim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _sectionLabel(dim)),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.lora(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: valueColor ?? txt,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  final bool isDark;
  final String message;

  const _LoadingState({
    required this.isDark,
    this.message = 'Generation de la note en cours...',
  });

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? _kDarkDim : _kLightDim;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1.2, color: dim),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: GoogleFonts.lora(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: dim,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  final bool isDark;
  final String message;
  const _IdleState({required this.isDark, required this.message});

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? _kDarkDimSub : _kLightDimSub;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(fontSize: 14, height: 1.65, color: dim),
        ),
      ),
    );
  }
}

class _ErrorBand extends StatelessWidget {
  final String message;
  final bool isDark;
  const _ErrorBand({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.negative.withValues(alpha: 0.35),
          width: 0.7,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        message,
        style: GoogleFonts.lora(fontSize: 12, color: AppTheme.negative),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DATA TYPES
// ════════════════════════════════════════════════════════════════════════════

class _KV {
  final String k, v;
  const _KV(this.k, this.v);
}

class _CmpKV {
  final String metric, left, right;
  const _CmpKV(this.metric, this.left, this.right);
}

class _RelativeFactor {
  final String label;
  final String leftValue;
  final String rightValue;
  final String? winnerTicker;

  const _RelativeFactor(
    this.label,
    this.leftValue,
    this.rightValue,
    this.winnerTicker,
  );
}

class _DecisionScoreRow {
  final String label;
  final double weight;
  final double leftPoints;
  final double rightPoints;
  final String? winnerTicker;

  const _DecisionScoreRow({
    required this.label,
    required this.weight,
    required this.leftPoints,
    required this.rightPoints,
    required this.winnerTicker,
  });
}

class _ComparisonDecision {
  final AnalysisData? winner;
  final String title;
  final String summary;
  final double confidence;
  final Color color;
  final List<String> keyDrivers;
  final double leftScore;
  final double rightScore;
  final List<_DecisionScoreRow> rows;

  const _ComparisonDecision({
    required this.winner,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.color,
    required this.keyDrivers,
    required this.leftScore,
    required this.rightScore,
    required this.rows,
  });
}

class _DebateBlock extends StatelessWidget {
  final AnalysisData a;
  final bool isDark;

  const _DebateBlock({required this.a, required this.isDark});

  bool _validNarrative(String? value) {
    final clean = (value ?? '').trim().toLowerCase();
    return clean.length > 24 &&
        !clean.contains('failed to generate') &&
        clean != '{}' &&
        clean != '[]';
  }

  String _fallbackNarrative(List<ProCon> points, bool bull) {
    final ticker = a.ticker.toUpperCase();
    final base = bull
        ? '$ticker presente un cas constructif si les fondamentaux et le consensus confirment le potentiel identifie.'
        : '$ticker conserve un cas de prudence si la valorisation, les marges ou le momentum se degradent.';
    final cleanPoints = points
        .map((p) => _cleanText(p.text))
        .where(_isUsefulLine)
        .take(3)
        .toList(growable: false);
    if (cleanPoints.isEmpty) return base;
    return '$base Points cles: ${cleanPoints.join(' ')}';
  }

  Widget _buildPointList(
      String title, List<ProCon> points, Color color, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  points.isNotEmpty && title.contains('BULL')
                      ? Icons.keyboard_double_arrow_up_rounded
                      : Icons.keyboard_double_arrow_down_rounded,
                  color: color,
                  size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle,
                          size: 4, color: color.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.text,
                        style: GoogleFonts.lora(
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.white.withValues(alpha: 0.8)
                              : AppTheme.black.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (points.isEmpty)
            Text('Aucun argument saillant identifié.',
                style: _bodyStyle(isDark ? _kDarkDim : _kLightDim)
                    .copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SigmaProvider>();
    final bullPoints = _bullCasePoints(a);
    final bearPoints = _bearCasePoints(a);
    final bullNarrative = _validNarrative(a.bullCase)
        ? a.bullCase!
        : _fallbackNarrative(bullPoints, true);
    final bearNarrative = _validNarrative(a.bearCase)
        ? a.bearCase!
        : _fallbackNarrative(bearPoints, false);
    final narrow = MediaQuery.of(context).size.width < 560;
    final bullList = _buildPointList('BULL CASE ARGUMENTS',
        bullPoints.take(5).toList(), AppTheme.positive, context);
    final bearList = _buildPointList('BEAR CASE ARGUMENTS',
        bearPoints.take(5).toList(), AppTheme.negative, context);

    if (sp.isDebateLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            children: [
              const CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 16),
              Text('SYNTHÈSE INSTITUTIONNELLE EN COURS...',
                  style: GoogleFonts.lora(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: isDark ? _kDarkDim : _kLightDim)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrow)
          Column(
            children: [
              bullList,
              const SizedBox(height: 10),
              bearList,
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: bullList),
              const SizedBox(width: 1),
              Expanded(child: bearList),
            ],
          ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(
                    color: isDark ? _kDarkDim : _kLightDim, width: 2)),
          ),
          child: Text('EXECUTIVE SUMMARY',
              style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isDark ? _kDarkDim : _kLightDim,
                  letterSpacing: 1.5)),
        ),
        const SizedBox(height: 24),
        _PersonaArgument(
          title: 'INSTITUTIONAL BULL PERSPECTIVE',
          content: bullNarrative,
          color: AppTheme.positive,
          isDark: isDark,
        ),
        const SizedBox(height: 32),
        _PersonaArgument(
          title: 'INSTITUTIONAL BEAR PERSPECTIVE',
          content: bearNarrative,
          color: AppTheme.negative,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _PersonaArgument extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final bool isDark;

  const _PersonaArgument({
    required this.title,
    required this.content,
    required this.color,
    required this.isDark,
  });

  /// Strips JSON artifacts and EMOJIS from AI output to ensure clean professional text.
  String _cleanContent(String raw) {
    String text = raw.trim();

    // Remove Emojis (Institutional requirement)
    text = text.replaceAll(
        RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E6}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F0F5}\u{1F004}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F1E6}-\u{1F1FF}\u{1F201}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}\u{1F251}\u{1F300}-\u{1F321}\u{1F324}-\u{1F393}\u{1F396}-\u{1F39B}\u{1F39E}-\u{1F3F0}\u{1F3F3}-\u{1F3F5}\u{1F3F7}-\u{1F4FD}\u{1F4FF}-\u{1F53D}\u{1F549}-\u{1F54E}\u{1F550}-\u{1F567}\u{1F56F}\u{1F570}\u{1F573}-\u{1F579}\u{1F57B}-\u{1F5A3}\u{1F5A5}-\u{1F5FA}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CB}-\u{1F6D2}\u{1F6E0}-\u{1F6E5}\u{1F6E9}\u{1F6EB}\u{1F6EC}\u{1F6F0}\u{1F6F3}-\u{1F6F6}\u{1F90D}-\u{1F93A}\u{1F93C}-\u{1F945}\u{1F947}-\u{1F970}\u{1F973}-\u{1F976}\u{1F97A}\u{1F97C}-\u{1F9A2}\u{1F9B0}-\u{1F9B9}\u{1F9C0}-\u{1F9C2}\u{1F9D0}-\u{1F9FF}]',
            unicode: true),
        '');

    // If the content looks like JSON, try to extract the text value
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        // Try to extract a meaningful text field from JSON
        final RegExp jsonValuePattern = RegExp(
          r'"(?:bull|bear|case|text|content|analysis|argument|response)":\s*"((?:[^"\\]|\\.)*)"',
          caseSensitive: false,
        );
        final match = jsonValuePattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          text = match
              .group(1)!
              .replaceAll(r'\n', '\n')
              .replaceAll(r'\"', '"')
              .replaceAll(r'\t', ' ');
        }
      } catch (_) {}
    }

    // Remove markdown formatting artifacts
    text = text
        .replaceAll(RegExp(r'^```[\w]*\n?', multiLine: true), '')
        .replaceAll('```', '')
        .replaceAll(RegExp(r'^\*\*(.+?)\*\*', multiLine: true), r'$1')
        .trim();

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final dim = isDark ? _kDarkDim : _kLightDim;
    final cleanText = _cleanContent(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lora(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          cleanText,
          style: _bodyStyle(isDark ? _kDarkText : _kLightText).copyWith(
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final String ticker;
  final bool isDark;

  const _FavoriteButton({
    required this.ticker,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SigmaProvider>();
    final isFavorite = sp.favoriteTickers.contains(ticker.toUpperCase());

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
        color: isFavorite ? AppTheme.gold : (isDark ? _kDarkDim : _kLightDim),
        size: 22,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        sp.toggleFavorite(ticker);
      },
      tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 20,
    );
  }
}
