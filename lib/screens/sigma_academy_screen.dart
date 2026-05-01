// ignore_for_file: prefer_const_declarations
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

import '../config/academy_content.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class _TableRow {
  final String signal;
  final String read;
  final String action;
  const _TableRow(this.signal, this.read, this.action);
}

class _FormulaItem {
  final String name;
  final String formula;
  final String note;
  const _FormulaItem(this.name, this.formula, {this.note = ''});
}

class _OhlcBar {
  final double open;
  final double high;
  final double low;
  final double close;
  final String label;
  const _OhlcBar({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.label = '',
  });
  bool get isBull => close >= open;
}

class _LessonData {
  final String conceptTitle;
  final String conceptBody;
  final String quote;
  final String keyRule;
  final List<_TableRow> tableRows;
  final String proTip;
  final List<String> keyPoints;
  final List<_FormulaItem> formulas;
  const _LessonData({
    required this.conceptTitle,
    required this.conceptBody,
    required this.quote,
    required this.keyRule,
    required this.tableRows,
    required this.proTip,
    required this.keyPoints,
    this.formulas = const [],
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// LESSON CONTENT
// ═══════════════════════════════════════════════════════════════════════════════

_LessonData _lessonFor(AcademyModule module) {
  if (module.track == AcademyTrack.technical) {
    switch (module.id) {
      case 0:
        return const _LessonData(
          conceptTitle: 'Le chandelier japonais : encoder le prix en une image',
          conceptBody:
              'Invente au Japon au XVIIIe siecle, le chandelier encode '
              '4 donnees en une seule representation visuelle : '
              'l\'Ouverture (O), le Plus Haut (H), le Plus Bas (L) et la Cloture (C). '
              'Le corps (body) represente la distance entre Open et Close. '
              'Les meches (wicks) representent les extremes High et Low. '
              'La couleur indique si la cloture est au-dessus (vert) ou en-dessous (rouge) de l\'ouverture.',
          quote:
              '"Le corps montre la conviction. La meche montre la tentative."',
          keyRule:
              'Corps large = conviction forte dans la direction. '
              'Longue meche haute = zone de vente rejetee (resistance active). '
              'Doji (corps minuscule) = indecision totale : ne jamais entrer sur un Doji isole. '
              'Marteau = meche basse longue = rejet massif de la pression vendeuse.',
          tableRows: [
            _TableRow('Marubozu Haussier', 'Corps plein sans meche', 'Conviction acheteur maximale.'),
            _TableRow('Doji', 'Open = Close, meches egales', 'Indecision. Attendre confirmation.'),
            _TableRow('Marteau', 'Corps haut, meche basse 2x corps', 'Signal retournement haussier.'),
            _TableRow('Etoile Filante', 'Corps bas, meche haute 2x corps', 'Signal retournement baissier.'),
          ],
          proTip:
              'Lire les chandeliers dans leur contexte de structure. '
              'Un Marteau sur support = signal fort. Un Marteau en milieu de range = bruit. '
              'La zone fait 80% du travail, le pattern confirme les 20% restants.',
          keyPoints: [
            'Corps vert = cloture > ouverture. Les acheteurs ont domine la periode entiere.',
            'Corps rouge = cloture < ouverture. Les vendeurs ont domine la periode entiere.',
            'Meche haute = le prix est monte puis a ete rejete — resistance active sur cette zone.',
            'Meche basse = le prix est descendu puis a rebondi — support actif et acheteurs presents.',
          ],
        );
      case 1:
        return const _LessonData(
          conceptTitle: 'Patterns de chandeliers : les signaux de retournement',
          conceptBody:
              'Un chandelier isole donne peu d\'information. '
              'C\'est la combinaison de 2 a 3 chandeliers consecutifs qui cree un signal fiable. '
              'L\'Engulfing Haussier : un gros corps vert absorbe entierement un corps rouge precedent. '
              'Le Morning Star : trois chandeliers — baissier, indecis, haussier — forment un retournement. '
              'L\'Harami : un petit chandelier contenu dans le precedent signale une pause de tendance.',
          quote:
              '"Un pattern sans contexte est un bruit. Sur le bon niveau, c\'est un signal."',
          keyRule:
              'Valider chaque pattern par sa position sur le graphique : '
              'un Engulfing Haussier sur une zone de support testee 3 fois '
              'a 10x plus de valeur qu\'en milieu de range. '
              'Attendre toujours la cloture complete du dernier chandelier avant d\'agir.',
          tableRows: [
            _TableRow('Engulfing Haussier', 'Grand corps vert > corps rouge prec.', 'Long sur support confirme.'),
            _TableRow('Morning Star (3 bougies)', 'Bear + Doji/Indecis + Bull', 'Retournement haussier fiable.'),
            _TableRow('Harami Haussier', 'Petit bull contenu dans grand bear', 'Pause baissiere. Attendre conf.'),
            _TableRow('Evening Star (3 bougies)', 'Bull + Doji/Indecis + Bear', 'Retournement baissier en resistance.'),
          ],
          proTip:
              'Les professionnels ne tradent pas le pattern — ils tradent la zone. '
              'Un Engulfing sur support + volume en hausse + divergence RSI = '
              'triple confluence = setup haute probabilite. '
              'Plus il y a de confirmations alignees, meilleur est le ratio risque/recompense.',
          keyPoints: [
            'Engulfing : le deuxieme corps doit absorber entierement le corps du chandelier precedent.',
            'Morning/Evening Star : le chandelier central doit etre un corps court ou un Doji.',
            'Harami : le deuxieme chandelier est 100% contenu dans le premier (corps dans corps).',
            'Confirmer systematiquement par la bougie suivante avant d\'entrer en position.',
          ],
        );
      case 2:
        return const _LessonData(
          conceptTitle: 'La structure de marche : l\'ADN de la tendance',
          conceptBody:
              'Charles Dow a pose une regle simple en 1902 : un marche haussier fait '
              'des sommets de plus en plus hauts (Higher Highs) et des creux de plus en plus hauts '
              '(Higher Lows). Un marche baissier fait l\'exact inverse. '
              'Cette lecture de structure prime sur tous les indicateurs. '
              'Quand une resistance est cassee, elle devient support - c\'est l\'inversion de polarite.',
          quote:
              '"Ne jamais trader contre la structure dominante sans signal clair de retournement."',
          keyRule:
              'Un pullback sur ancienne resistance cassee (devenue support) est le setup '
              'le plus fiable de l\'analyse technique. La structure confirme, les indicateurs filtrent.',
          tableRows: [
            _TableRow('Higher Highs + Higher Lows', 'Tendance haussiere saine', 'Favoriser les longs sur pullbacks.'),
            _TableRow('Lower Highs + Lower Lows', 'Tendance baissiere saine', 'Favoriser les shorts sur rebounds.'),
            _TableRow('Sommets egaux, creux montants', 'Compression - triangle', 'Attention cassure imminente.'),
            _TableRow('Cassure + pullback + cloture', 'Inversion de polarite', 'Setup d\'entree haute probabilite.'),
          ],
          proTip:
              'La "regle des 3 touches" : un support ou une resistance est d\'autant plus fort '
              'qu\'il a ete teste et respecte 3 fois ou plus. '
              'La 4eme rupture sera souvent violente et rapide — c\'est la que les institutionnels attendent.',
          keyPoints: [
            'HH + HL = tendance haussiere. LH + LL = tendance baissiere. Simple, implacable.',
            'Support rompu = resistance. Resistance cassee = support. C\'est l\'inversion de polarite.',
            'Tracer les zones sur les corps de bougies (pas uniquement sur les meches extremes).',
            'La tendance du timeframe superieur prime toujours sur le timeframe inferieur.',
          ],
        );
      case 3:
        return const _LessonData(
          conceptTitle: 'Figures chartistes : anticiper les grandes cassures',
          conceptBody:
              'Les figures chartistes sont des configurations de prix qui se repetent '
              'sur tous les marches et timeframes. '
              'Le Tete-Epaules annonce un retournement haussier vers baissier. '
              'Le Double Top / Double Bottom signalent l\'epuisement d\'une tendance. '
              'Les triangles et drapeaux sont des figures de continuation : '
              'la tendance reprend avec force apres la phase de compression.',
          quote:
              '"La patience est la strategie. Attendre la cassure, jamais l\'anticiper."',
          keyRule:
              'La figure est valide uniquement a la cassure de la ligne de cou (neckline), '
              'confirmee par un volume superieur a la moyenne. '
              'Objectif de prix = amplitude de la figure reportee depuis le point de cassure.',
          tableRows: [
            _TableRow('Tete-Epaules (H&S)', 'Retournement haussier vers baissier', 'Short sur cassure neckline + volume.'),
            _TableRow('Double Top (Forme M)', 'Epuisement a double resistance', 'Biais baissier apres cloture sous cou.'),
            _TableRow('Triangle Ascendant', 'Compression haussiere (HH + HL)', 'Cassure haute = continuation forte.'),
            _TableRow('Drapeau (Flag)', 'Consolidation dans la tendance', 'Entree sur cassure du canal serre.'),
          ],
          proTip:
              'Les "fausses cassures" sont la regle, pas l\'exception. '
              'Attendre une cloture de chandelier complete au-dela du niveau, '
              'puis un retest valide de l\'ancienne zone pour entrer avec un risque minimal '
              'et un ratio risque/recompense optimal (minimum 1:2).',
          keyPoints: [
            'Tete-Epaules : 3 sommets, le central (tete) est plus haut. Ligne de cou = support critique.',
            'Double Top/Bottom : deux tests identiques d\'un niveau = epuisement de la tendance dominante.',
            'Triangles : convergence prix vers compression, puis cassure explosive avec volume.',
            'Drapeaux : correction contre-tendance en canal serre. Cassure = reprise de la tendance principale.',
          ],
        );
      case 4:
      default:
        return const _LessonData(
          conceptTitle: 'Les indicateurs de momentum : mesurer la force du flux',
          conceptBody:
              'Un indicateur ne predit pas l\'avenir - il quantifie l\'etat present. '
              'Le RSI 14 mesure la puissance relative des gains versus pertes sur 14 periodes. '
              'Le MACD calcule l\'ecart entre deux moyennes mobiles (EMA 12 et EMA 26) '
              'pour detecter les accelerations et decelerations de tendance. '
              'Le Volume valide ou invalide chaque signal de prix.',
          quote:
              '"RSI a 70 en tendance forte signifie force, pas signal de vente."',
          keyRule:
              'La divergence est plus puissante que le croisement : prix fait un nouveau sommet '
              'mais le RSI ne confirme pas = epuisement. '
              'C\'est le signal d\'alerte le plus fiable avant un retournement.',
          tableRows: [
            _TableRow('RSI > 50', 'Momentum positif', 'Biais acheteur. Favoriser longs.'),
            _TableRow('RSI < 30 + divergence', 'Epuisement vendeur', 'Zone de rebond potentiel.'),
            _TableRow('MACD croisement haussier', 'Acceleration haussiere', 'Confirmation si prix structure ok.'),
            _TableRow('Cassure + volume x1.5', 'Participation reelle', 'Signal credible et durable.'),
          ],
          proTip:
              'Le Volume est l\'indicateur le plus honnete. Une cassure avec faible volume est souvent '
              'un faux signal, un piege a retail. '
              'Les institutionnels laissent toujours une empreinte visible en volume.',
          keyPoints: [
            'RSI 14 = ratio gains moyens / pertes moyennes sur 14 bougies. > 50 = haussier.',
            'Divergence RSI : prix au nouveau sommet mais RSI en baisse = epuisement proche.',
            'MACD = EMA12 - EMA26. Ligne Signal = EMA9 du MACD. Histogramme = ecart des deux.',
            'Volume fort sur hausse = flux institutionnel sain. Volume faible = doute, prudence.',
          ],
          formulas: [
            _FormulaItem(
              'RSI (Relative Strength Index)',
              'RSI = 100 - 100 / (1 + RS)\n'
              'RS  = Moyenne gains (14p) / Moyenne pertes (14p)',
              note: 'Plage : 0-100. Surachete > 70. Survendu < 30.',
            ),
            _FormulaItem(
              'MACD',
              'MACD        = EMA(12) - EMA(26)\n'
              'Signal Line = EMA(9)  du MACD\n'
              'Histogramme = MACD - Signal Line',
              note: 'Croisement MACD > Signal = momentum haussier.',
            ),
          ],
        );
    }
  }

  // Fundamental track
  switch (module.id) {
    case 0:
      return const _LessonData(
        conceptTitle: 'Les 3 etats financiers : la sante en chiffres',
        conceptBody:
            'Chaque entreprise cotee publie trimestriellement 3 documents fondamentaux. '
            'Le Compte de Resultats (P&L) mesure la rentabilite sur une periode. '
            'Le Bilan photographie les actifs, dettes et capitaux propres a un instant T. '
            'Le Tableau des Flux de Tresorerie montre les mouvements reels de cash. '
            'Ces trois documents se lisent ensemble - jamais isolement.',
        quote:
            '"Les profits peuvent etre fabriques. Le cash, difficilement." — Howard Marks',
        keyRule:
            'Le Free Cash Flow (FCF = Cash Operations - Capex) est bien plus difficile '
            'a manipuler que le benefice net GAAP. C\'est lui que lisent les meilleurs analystes.',
        tableRows: [
          _TableRow('Marge brute > 60%', 'Pricing power fort', 'Signe de qualite et barrieres elevees.'),
          _TableRow('FCF / Net Income > 1x', 'Qualite profits excellente', 'Les profits se convertissent en cash.'),
          _TableRow('Dette nette / EBITDA > 5x', 'Bilan sous tension', 'Risque en cas de hausse des taux.'),
          _TableRow('CA +20% YoY', 'Momentum fort', 'Justifie prime de valorisation.'),
        ],
        proTip:
            'Warren Buffett lit les notes de bas de page en premier. '
            'C\'est la que se cachent les engagements hors bilan, les risques de litiges '
            'et les hypotheses comptables les plus agressives.',
        keyPoints: [
          'P&L : Revenus -> Marge Brute -> EBIT -> Net Income. Chaque ligne = une decision de gestion.',
          'Bilan : Actifs = Passifs + Fonds Propres. Toujours en equilibre. Photographie a un instant T.',
          'Cash Flow est divise en 3 : Activites operationnelles, investissement, financement.',
          'L\'EBITDA efface les amortissements. Utile pour comparer, mais masque les vrais besoins Capex.',
        ],
        formulas: [
          _FormulaItem(
            'Free Cash Flow (FCF)',
            'FCF = Cash Flow Opérationnel − Capex',
            note: 'Mesure la liquidité réelle générée après investissements.',
          ),
          _FormulaItem(
            'Marge Brute',
            'Marge Brute = (Revenus − Coût des ventes) / Revenus × 100',
            note: '> 60% = pricing power élevé et barrières à l\'entrée.',
          ),
          _FormulaItem(
            'EBITDA',
            'EBITDA = EBIT + Dotations aux amortissements',
            note: 'Proxy du flux opérationnel avant structure de capital.',
          ),
        ],
      );
    case 1:
    default:
      return const _LessonData(
        conceptTitle: 'La valorisation : le prix juste d\'une conviction',
        conceptBody:
            'Valoriser une entreprise, c\'est repondre a une question precise : combien vaut-elle '
            'par rapport a ce qu\'elle genere, a ses pairs et a son potentiel ? '
            'Le P/E compare le prix a l\'EPS. L\'EV/EBITDA compare la valeur totale de '
            'l\'entreprise a son profit operationnel. Le PEG ajuste la valorisation par la croissance.',
        quote:
            '"Acheter sans connaitre la valorisation, c\'est acheter une maison sans savoir le prix au m2."',
        keyRule:
            'Comparer TOUJOURS au secteur. P/E 25 pour un industriel = cher. '
            'P/E 25 pour un SaaS a 30% de croissance = potentiellement raisonnable. '
            'La croissance justifie (ou non) la prime payee.',
        tableRows: [
          _TableRow('P/E < mediane sectorielle', 'Potentielle sous-valorisation', 'Verifier qualite + croissance.'),
          _TableRow('EV/EBITDA < 10x', 'Zone value', 'Confirmer FCF positif et croissance.'),
          _TableRow('PEG < 1', 'Croissance sous-payee', 'Signal d\'attractivite fort si confirme.'),
          _TableRow('EV/Sales > 20x', 'Valorisation tendue', 'Croissance exceptionnelle requise.'),
        ],
        proTip:
            'L\'EV/EBITDA est le ratio prefere des banquiers M&A car il est neutre '
            'vis-a-vis de la structure de capital - on peut comparer une societe tres endettee '
            'avec une autre sans dette sur une base comparable.',
        keyPoints: [
          'P/E = Prix / Benefice par action. Simple mais fragile face aux elements non recurrents.',
          'EV = Market Cap + Dette Nette - Cash. Cout reel d\'acquisition d\'une entreprise entiere.',
          'EV/EBITDA est structurellement neutre : compare toutes structures de capital.',
          'PEG = P/E divise par le taux de croissance. PEG < 1 = croissance sous-payee.',
        ],
        formulas: [
          _FormulaItem(
            'P/E Ratio',
            'P/E = Prix de l\'action / BPA (Bénéfice par action)',
            note: 'Comparaison toujours relative au secteur.',
          ),
          _FormulaItem(
            'Enterprise Value (EV)',
            'EV = Capitalisation boursière + Dette nette − Trésorerie',
            note: 'Prix réel d\'acquisition de 100% d\'une société.',
          ),
          _FormulaItem(
            'PEG Ratio',
            'PEG = P/E / Taux de croissance annuel (%)',
            note: 'PEG < 1 : croissance payée à prix raisonnable.',
          ),
          _FormulaItem(
            'EV/EBITDA',
            'EV/EBITDA = Enterprise Value / EBITDA',
            note: 'Neutre à la structure de capital. Préféré en M&A.',
          ),
        ],
      );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLOUR HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

Color _trackColor(AcademyTrack track) => track == AcademyTrack.technical
    ? AppTheme.academyTrackTechnical
    : AppTheme.academyTrackFundamental;

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class SigmaAcademyScreen extends StatefulWidget {
  final AcademyTrack track;
  const SigmaAcademyScreen({super.key, required this.track});

  @override
  State<SigmaAcademyScreen> createState() => _SigmaAcademyScreenState();
}

class _SigmaAcademyScreenState extends State<SigmaAcademyScreen> {
  late final AcademyTrack _track = widget.track;
  int _moduleIndex = 0;

  List<AcademyModule> get _modules => _track == AcademyTrack.technical
      ? AcademyContent.technicalModules
      : AcademyContent.fundamentalModules;

  AcademyCurriculum get _curriculum =>
      AcademyContent.curricula.firstWhere((c) => c.track == _track);

  AcademyModule get _module =>
      _modules[_moduleIndex.clamp(0, _modules.length - 1)];

  void _onModuleSelect(int i) {
    HapticFeedback.selectionClick();
    setState(() => _moduleIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    return Scaffold(
      backgroundColor: AppTheme.backgroundShim(context),
      body: SafeArea(
        child: Column(
          children: [
            _AcademyHeader(
              curriculum: _curriculum,
              track: _track,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _ModuleSidebar(
                            modules: _modules,
                            selectedIndex: _moduleIndex,
                            track: _track,
                            onSelect: _onModuleSelect,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: AppTheme.borderShim(context),
                        ),
                        Expanded(
                          child: _LessonWorkspace(
                            key: ValueKey('${_track.name}-$_moduleIndex'),
                            module: _module,
                            moduleIndex: _moduleIndex,
                            moduleCount: _modules.length,
                            onPrev: _moduleIndex > 0
                                ? () => _onModuleSelect(_moduleIndex - 1)
                                : null,
                            onNext: _moduleIndex < _modules.length - 1
                                ? () => _onModuleSelect(_moduleIndex + 1)
                                : null,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _ModuleChipStrip(
                          modules: _modules,
                          selectedIndex: _moduleIndex,
                          track: _track,
                          onSelect: _onModuleSelect,
                        ),
                        Expanded(
                          child: _LessonWorkspace(
                            key: ValueKey('${_track.name}-$_moduleIndex'),
                            module: _module,
                            moduleIndex: _moduleIndex,
                            moduleCount: _modules.length,
                            onPrev: _moduleIndex > 0
                                ? () => _onModuleSelect(_moduleIndex - 1)
                                : null,
                            onNext: _moduleIndex < _modules.length - 1
                                ? () => _onModuleSelect(_moduleIndex + 1)
                                : null,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _AcademyHeader extends StatelessWidget {
  final AcademyCurriculum curriculum;
  final AcademyTrack track;
  final VoidCallback onBack;

  const _AcademyHeader({
    required this.curriculum,
    required this.track,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _trackColor(track);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row 1: Back + Title ───────────────────────────────────────────
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.getSurface(context),
            border: Border(
              bottom: BorderSide(color: accent.withValues(alpha: 0.15), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  fixedSize: const Size(36, 36),
                  foregroundColor: AppTheme.getPrimaryText(context),
                ),
              ),
              const SizedBox(width: 2),
              Icon(curriculum.icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                curriculum.title,
                style: AppTheme.compactTitle(context, size: 13, color: accent),
              ),
              const Spacer(),
              _StatPill('${curriculum.moduleCount} modules', accent),
              const SizedBox(width: 4),
              _StatPill(curriculum.duration, accent),
              const SizedBox(width: 4),
              _StatPill(curriculum.level, accent),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatPill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.5),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.overline(context, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIDEBAR (Desktop)
// ═══════════════════════════════════════════════════════════════════════════════

class _ModuleSidebar extends StatelessWidget {
  final List<AcademyModule> modules;
  final int selectedIndex;
  final AcademyTrack track;
  final ValueChanged<int> onSelect;

  const _ModuleSidebar({
    required this.modules,
    required this.selectedIndex,
    required this.track,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _trackColor(track);
    return Container(
      color: AppTheme.getSurface(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Text('PROGRAMME', style: AppTheme.overline(context, color: accent)),
                const Spacer(),
                Text(
                  '${modules.length} modules',
                  style: AppTheme.overline(
                    context,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < modules.length; i++)
            _ModuleSidebarRow(
              module: modules[i],
              index: i,
              selected: i == selectedIndex,
              track: track,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _ModuleSidebarRow extends StatelessWidget {
  final AcademyModule module;
  final int index;
  final bool selected;
  final AcademyTrack track;
  final VoidCallback onTap;

  const _ModuleSidebarRow({
    required this.module,
    required this.index,
    required this.selected,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _trackColor(track);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.4)
                  : AppTheme.borderShim(context),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: AppTheme.compactTitle(
                    context,
                    size: 14,
                    color: selected
                        ? accent
                        : AppTheme.getSecondaryText(context)
                            .withValues(alpha: 0.45),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.compactTitle(context, size: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      module.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.compactBody(
                        context,
                        size: 10,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip('${module.lessons} lecons', accent),
                        const SizedBox(width: 5),
                        _Chip(module.duration, accent),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHIP STRIP (Mobile)
// ═══════════════════════════════════════════════════════════════════════════════

class _ModuleChipStrip extends StatelessWidget {
  final List<AcademyModule> modules;
  final int selectedIndex;
  final AcademyTrack track;
  final ValueChanged<int> onSelect;

  const _ModuleChipStrip({
    required this.modules,
    required this.selectedIndex,
    required this.track,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _trackColor(track);
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.borderShim(context), width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        itemCount: modules.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.5)
                      : AppTheme.borderShim(context),
                  width: 0.5,
                ),
              ),
              child: Text(
                '${i + 1}  ${modules[i].subtitle}',
                style: AppTheme.compactBody(
                  context,
                  size: 11,
                  color: selected ? accent : AppTheme.getSecondaryText(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LESSON WORKSPACE
// ═══════════════════════════════════════════════════════════════════════════════

class _LessonWorkspace extends StatelessWidget {
  final AcademyModule module;
  final int moduleIndex;
  final int moduleCount;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _LessonWorkspace({
    super.key,
    required this.module,
    required this.moduleIndex,
    required this.moduleCount,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final data = _lessonFor(module);
    final accent = _trackColor(module.track);
    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      children: [
        // ── 1. Hero — typographic, no card ───────────────────────────────────
        _LessonHero(module: module, index: moduleIndex, total: moduleCount),
        const SizedBox(height: 20),
        Divider(height: 1, thickness: 0.5, color: AppTheme.borderShim(context)),
        const SizedBox(height: 20),

        // ── 2. Concept — inline text + left-border quote ──────────────────────
        Text(data.conceptTitle, style: AppTheme.compactTitle(context, size: 14)),
        const SizedBox(height: 10),
        Text(
          data.conceptBody,
          style: AppTheme.compactBody(context, size: 13).copyWith(height: 1.65),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            border: Border(left: BorderSide(color: accent, width: 3)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            data.quote,
            style: AppTheme.compactBody(context, size: 12).copyWith(
              height: 1.55,
              fontStyle: FontStyle.italic,
              color: AppTheme.getPrimaryText(context).withValues(alpha: 0.75),
            ),
          ),
        ),
        const SizedBox(height: 26),

        // ── 3. Chart — fl_chart line/area visualisation ───────────────────────
        _SectionLabel(label: 'VISUALISATION', icon: Icons.bar_chart_rounded),
        const SizedBox(height: 10),
        _ChartWidget(module: module, isDark: isDark),
        const SizedBox(height: 26),

        // ── 4. Key Rule — left-border callout ─────────────────────────────────
        _SectionLabel(label: 'REGLE FONDAMENTALE', icon: Icons.verified_outlined),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            border: Border(left: BorderSide(color: accent, width: 3)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: Icon(Icons.verified_rounded, size: 14, color: accent),
              ),
              Expanded(
                child: Text(
                  data.keyRule,
                  style: AppTheme.compactBody(context, size: 13)
                      .copyWith(height: 1.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),

        // ── 5. Reading Table ──────────────────────────────────────────────────
        _SectionLabel(label: 'TABLE DE LECTURE', icon: Icons.table_chart_outlined),
        const SizedBox(height: 10),
        _ReadingTable(rows: data.tableRows, accent: accent),
        const SizedBox(height: 26),

        // ── 6. Key Points — plain divider list ────────────────────────────────
        _SectionLabel(label: 'À RETENIR', icon: Icons.fact_check_outlined),
        const SizedBox(height: 6),
        for (var i = 0; i < data.keyPoints.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 12, top: 1),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTheme.compactTitle(context, size: 10, color: accent),
                  ),
                ),
                Expanded(
                  child: Text(
                    data.keyPoints[i],
                    style: AppTheme.compactBody(context, size: 13).copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          if (i < data.keyPoints.length - 1)
            Divider(height: 1, thickness: 0.5, color: AppTheme.borderShim(context)),
        ],
        const SizedBox(height: 26),

        // ── 7. Formulas (optional) ───────────────────────────────────────────
        if (data.formulas.isNotEmpty) ...[
          _SectionLabel(label: 'FORMULES CLÉS', icon: Icons.functions_rounded),
          const SizedBox(height: 10),
          _FormulaBlock(items: data.formulas, accent: accent),
          const SizedBox(height: 26),
        ],

        // ── 8. Pro Tip ────────────────────────────────────────────────────────
        _SectionLabel(label: 'CONSEIL DE PROFESSIONNEL', icon: Icons.workspace_premium_outlined),
        const SizedBox(height: 10),
        _ProTipCard(text: data.proTip),
        const SizedBox(height: 32),

        // ── 9. Navigation ─────────────────────────────────────────────────────
        _NavigationFooter(onPrev: onPrev, onNext: onNext),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CANDLESTICK CHART PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _CandlestickPainter extends CustomPainter {
  final List<_OhlcBar> bars;
  final bool isDark;
  final Color bullColor;
  final Color bearColor;
  final bool showLabels;
  final double minY;
  final double maxY;

  const _CandlestickPainter({
    required this.bars,
    required this.isDark,
    required this.bullColor,
    required this.bearColor,
    required this.minY,
    required this.maxY,
    this.showLabels = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxY <= minY || bars.isEmpty) return;
    final double range = maxY - minY;
    final double labelReserve = showLabels ? 26.0 : 4.0;
    const double topPad = 6.0;
    final double chartH = size.height - topPad - labelReserve;
    final double barW = size.width / bars.length;
    final double bodyW = math.max(5.0, math.min(barW * 0.58, 28.0));

    double py(double v) => topPad + (1.0 - (v - minY) / range) * chartH;

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final double cx = (i + 0.5) * barW;
      final Color color = bar.isBull ? bullColor : bearColor;

      // Wick
      canvas.drawLine(
        Offset(cx, py(bar.high)),
        Offset(cx, py(bar.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );

      // Body
      final double bodyTop = py(math.max(bar.open, bar.close));
      final double bodyBot = py(math.min(bar.open, bar.close));
      final double bh = math.max(2.0, bodyBot - bodyTop);
      canvas.drawRect(
        Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bh),
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      // Label below chart
      if (showLabels && bar.label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: bar.label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: barW - 1);
        tp.paint(canvas, Offset(cx - tp.width / 2, size.height - labelReserve + 5));
      }
    }
  }

  @override
  bool shouldRepaint(_CandlestickPainter old) =>
      old.bars != bars || old.isDark != isDark;
}

class _CandlestickChart extends StatelessWidget {
  final List<_OhlcBar> bars;
  final bool isDark;
  final bool showLabels;
  final Color bullColor;
  final Color bearColor;

  const _CandlestickChart({
    required this.bars,
    required this.isDark,
    required this.bullColor,
    required this.bearColor,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final allPrices = bars.expand((b) => [b.high, b.low]).toList();
    final double mn = allPrices.reduce(math.min);
    final double mx = allPrices.reduce(math.max);
    final double pad = (mx - mn) * 0.12;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _CandlestickPainter(
          bars: bars,
          isDark: isDark,
          bullColor: bullColor,
          bearColor: bearColor,
          minY: mn - pad,
          maxY: mx + pad,
          showLabels: showLabels,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHART WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _ChartWidget extends StatelessWidget {
  final AcademyModule module;
  final bool isDark;

  const _ChartWidget({required this.module, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF080B12) : const Color(0xFFF7F8FA);
    final borderColor = AppTheme.borderShim(context);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: module.track == AcademyTrack.technical
          ? _buildTechnicalChart(context)
          : module.id == 0
              ? _buildCascadeChart(context)
              : _buildValuationChart(context),
    );
  }

  // ── Technical: candlestick + fl_chart charts ────────────────────────────

  Widget _buildTechnicalChart(BuildContext context) {
    switch (module.id) {
      case 0:  return _buildCandlestickAnatomy(context);
      case 1:  return _buildCandlestickPatterns(context);
      case 2:  return _buildStructureLineChart(context);
      case 3:  return _buildFiguresChart(context);
      default: return _buildMomentumChart(context);
    }
  }

  // Module 0 — Chandelier Japonais : 6 types de base avec labels
  Widget _buildCandlestickAnatomy(BuildContext context) {
    const bars = [
      _OhlcBar(open: 98,  close: 108, high: 108,  low: 98,    label: 'MARUBOZU+'),
      _OhlcBar(open: 108, close: 98,  high: 108,  low: 98,    label: 'MARUBOZU-'),
      _OhlcBar(open: 103, close: 103, high: 110,  low: 96,    label: 'DOJI'),
      _OhlcBar(open: 107, close: 108, high: 109,  low: 97,    label: 'MARTEAU'),
      _OhlcBar(open: 98,  close: 97,  high: 110,  low: 96.5,  label: 'ETOILE'),
      _OhlcBar(open: 103, close: 105, high: 110,  low: 96,    label: 'TOUPIE'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            children: [
              _ChartLegendDot(color: AppTheme.eduBull, label: 'Haussier'),
              const SizedBox(width: 10),
              _ChartLegendDot(color: AppTheme.eduBear, label: 'Baissier'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: _CandlestickChart(
              bars: bars,
              isDark: isDark,
              showLabels: true,
              bullColor: AppTheme.eduBull,
              bearColor: AppTheme.eduBear,
            ),
          ),
        ),
      ],
    );
  }

  // Module 1 — Patterns : sequence continue avec patterns labellises
  Widget _buildCandlestickPatterns(BuildContext context) {
    const bars = [
      _OhlcBar(open: 100,   close: 101.5, high: 102,   low: 99.5),
      _OhlcBar(open: 101.5, close: 103,   high: 103.5, low: 101),
      _OhlcBar(open: 103,   close: 101.5, high: 103.5, low: 101,   label: 'E.1'),
      _OhlcBar(open: 101,   close: 105,   high: 105.5, low: 100.5, label: 'E.2'),
      _OhlcBar(open: 105,   close: 104,   high: 105.5, low: 103.5),
      _OhlcBar(open: 104,   close: 103,   high: 104.5, low: 102),
      _OhlcBar(open: 103,   close: 103.2, high: 103.8, low: 96,    label: 'MART'),
      _OhlcBar(open: 103,   close: 105,   high: 105.5, low: 102.5),
      _OhlcBar(open: 105,   close: 102.5, high: 105.5, low: 102,   label: 'M.1'),
      _OhlcBar(open: 102,   close: 102.3, high: 103,   low: 100.5, label: 'M.2'),
      _OhlcBar(open: 102,   close: 105.5, high: 106,   low: 101.5, label: 'M.3'),
      _OhlcBar(open: 105.5, close: 107,   high: 107.5, low: 105),
      _OhlcBar(open: 107,   close: 109.5, high: 110,   low: 106.5, label: 'H.1'),
      _OhlcBar(open: 109,   close: 108,   high: 109.5, low: 107.5, label: 'H.2'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
          child: Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              _ChartLegendDot(color: AppTheme.academyTrackTechnical, label: 'E = Engulfing'),
              _ChartLegendDot(color: AppTheme.eduBull, label: 'MART = Marteau'),
              _ChartLegendDot(color: AppTheme.eduBull, label: 'M = Morning Star'),
              _ChartLegendDot(color: AppTheme.eduBear, label: 'H = Harami'),
            ],
          ),
        ),
        Expanded(
          child: _CandlestickChart(
            bars: bars,
            isDark: isDark,
            showLabels: true,
            bullColor: AppTheme.eduBull,
            bearColor: AppTheme.eduBear,
          ),
        ),
      ],
    );
  }

  // Module 2 — Structure : HH/HL haussier → retournement LH/LL — chandeliers
  Widget _buildStructureLineChart(BuildContext context) {
    // Uptrend: alternating green pushes (HH) and small red corrections (HL)
    // Reversal at bar 11 (last HH), then LH and LL pattern
    const bars = [
      // Uptrend phase
      _OhlcBar(open: 100, close: 106, high: 107, low: 99),   // push up
      _OhlcBar(open: 106, close: 103, high: 107, low: 102),  // HL correction
      _OhlcBar(open: 103, close: 113, high: 114, low: 102),  // HH push
      _OhlcBar(open: 113, close: 108, high: 114, low: 107),  // HL correction
      _OhlcBar(open: 108, close: 121, high: 122, low: 107),  // HH push
      _OhlcBar(open: 121, close: 115, high: 122, low: 114),  // HL correction
      _OhlcBar(open: 115, close: 130, high: 131, low: 114),  // HH push
      _OhlcBar(open: 130, close: 124, high: 131, low: 123),  // HL correction
      _OhlcBar(open: 124, close: 140, high: 141, low: 123),  // HH final
      // Reversal phase
      _OhlcBar(open: 140, close: 132, high: 141, low: 131),  // strong red
      _OhlcBar(open: 132, close: 136, high: 138, low: 131),  // LH bounce fails
      _OhlcBar(open: 136, close: 126, high: 137, low: 125),  // LH → LL
      _OhlcBar(open: 126, close: 130, high: 131, low: 125),  // weak bounce LH
      _OhlcBar(open: 130, close: 118, high: 131, low: 117),  // LL breakdown
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: Row(
            children: [
              _ChartLegendDot(color: AppTheme.eduBull, label: 'HH / HL (hausse)'),
              const SizedBox(width: 12),
              _ChartLegendDot(color: AppTheme.eduBear, label: 'LH / LL (retournement)'),
            ],
          ),
        ),
        Expanded(
          child: _CandlestickChart(
            bars: bars,
            isDark: isDark,
            bullColor: AppTheme.eduBull,
            bearColor: AppTheme.eduBear,
          ),
        ),
      ],
    );
  }

  // Module 3 — Figures Chartistes : Tête-Épaules avec neckline
  Widget _buildFiguresChart(BuildContext context) {
    // H&S shaped price series
    const prices = [
      100.0, 104.0, 108.0, 111.0, 113.0, 110.0, 108.0,  // left shoulder (peak at 4)
      109.0, 113.0, 117.0, 120.0, 117.0, 113.0, 108.0,  // head (peak at 10)
      110.0, 112.0, 109.0, 107.0, 106.0,                // right shoulder (peak at 15)
      104.0, 100.0, 96.0, 92.0,                          // breakdown
    ];
    final spots = [
      for (int i = 0; i < prices.length; i++) FlSpot(i.toDouble(), prices[i]),
    ];
    const necklineY = 108.0;
    final gridColor = isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000);
    final labelColor = isDark ? const Color(0x80FFFFFF) : const Color(0x80000000);
    final lineColor = AppTheme.academyTrackTechnical;
    final neckColor = AppTheme.academyTrackFundamental;
    // peaks at indices 4, 10, 15 (right shoulder lower = valid H&S)
    const peakIdxs = [4, 10, 15];
    const neckIdxs = [6, 12];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              minY: 86, maxY: 128,
              lineTouchData: const LineTouchData(enabled: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: necklineY,
                    color: neckColor,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ],
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: TextStyle(fontSize: 9, color: labelColor),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: lineColor,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) =>
                        peakIdxs.contains(spot.x.toInt()) ||
                        neckIdxs.contains(spot.x.toInt()),
                    getDotPainter: (spot, _, __, ___) {
                      final isPeak = peakIdxs.contains(spot.x.toInt());
                      return FlDotCirclePainter(
                        radius: isPeak ? 5 : 4,
                        color: isPeak ? AppTheme.eduBear : lineColor,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white.withValues(alpha: 0.8),
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        lineColor.withValues(alpha: 0.15),
                        lineColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Legend overlay
          Positioned(
            top: 0, left: 4,
            child: Row(
              children: [
                _ChartLegendDot(color: AppTheme.eduBear, label: 'EP. G'),
                const SizedBox(width: 6),
                _ChartLegendDot(color: AppTheme.eduBear, label: 'TETE'),
                const SizedBox(width: 6),
                _ChartLegendDot(color: AppTheme.eduBear, label: 'EP. D'),
                const SizedBox(width: 8),
                _ChartLegendDot(color: neckColor, label: 'NECKLINE'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Module 4 — Momentum : chandeliers prix + RSI en stacked mini-charts
  Widget _buildMomentumChart(BuildContext context) {
    // 24 candles: uptrend with divergence at the end (price up, RSI down)
    const bars = [
      _OhlcBar(open: 100, close: 103, high: 104, low: 99),
      _OhlcBar(open: 103, close: 101, high: 104, low: 100),
      _OhlcBar(open: 101, close: 106, high: 107, low: 100),
      _OhlcBar(open: 106, close: 110, high: 111, low: 105),
      _OhlcBar(open: 110, close: 108, high: 112, low: 107),
      _OhlcBar(open: 108, close: 115, high: 116, low: 107),
      _OhlcBar(open: 115, close: 119, high: 120, low: 114),
      _OhlcBar(open: 119, close: 117, high: 120, low: 116),
      _OhlcBar(open: 117, close: 123, high: 124, low: 116),
      _OhlcBar(open: 123, close: 120, high: 124, low: 119),
      _OhlcBar(open: 120, close: 128, high: 129, low: 119),
      _OhlcBar(open: 128, close: 131, high: 132, low: 127),
      _OhlcBar(open: 131, close: 129, high: 132, low: 128),
      _OhlcBar(open: 129, close: 134, high: 135, low: 128),
      _OhlcBar(open: 134, close: 136, high: 137, low: 133),
      _OhlcBar(open: 136, close: 134, high: 137, low: 133),
      _OhlcBar(open: 134, close: 137, high: 138, low: 133),
      _OhlcBar(open: 137, close: 136, high: 138, low: 135),
      _OhlcBar(open: 136, close: 138, high: 139, low: 135),
      _OhlcBar(open: 138, close: 137, high: 139, low: 136),
      _OhlcBar(open: 137, close: 139, high: 140, low: 136),
      _OhlcBar(open: 139, close: 138, high: 140, low: 137),
      _OhlcBar(open: 138, close: 140, high: 141, low: 137),
      _OhlcBar(open: 140, close: 139, high: 142, low: 138),
    ];
    const rsiValues = [
      48.0, 55.0, 50.0, 58.0, 65.0, 60.0, 70.0, 74.0,
      68.0, 76.0, 70.0, 78.0, 80.0, 75.0, 77.0, 78.0,
      74.0, 75.0, 71.0, 72.0, 68.0, 67.0, 63.0, 60.0,
    ];
    final rsiSpots = [for (int i = 0; i < rsiValues.length; i++) FlSpot(i.toDouble(), rsiValues[i])];
    final gridColor = isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000);
    final labelColor = isDark ? const Color(0x80FFFFFF) : const Color(0x80000000);
    final rsiColor = AppTheme.academyTrackIndicators;

    return Column(
      children: [
        // Price panel (2/3 height) — candlesticks
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: _CandlestickChart(
                  bars: bars,
                  isDark: isDark,
                  bullColor: AppTheme.eduBull,
                  bearColor: AppTheme.eduBear,
                ),
              ),
              Positioned(
                top: 4, left: 8,
                child: _ChartLegendDot(color: AppTheme.academyTrackTechnical, label: 'Prix'),
              ),
            ],
          ),
        ),
        // Divider
        Divider(height: 1, thickness: 0.5, color: AppTheme.borderShim(context)),
        // RSI panel (1/3 height)
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            child: Stack(
              children: [
                LineChart(LineChartData(
                  minY: 25, maxY: 95,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true, drawVerticalLine: false,
                    checkToShowHorizontalLine: (v) => v == 30 || v == 50 || v == 70,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: v == 30 ? AppTheme.eduBear.withValues(alpha: 0.35)
                           : v == 70 ? AppTheme.eduBull.withValues(alpha: 0.35)
                           : gridColor,
                      strokeWidth: 0.8,
                      dashArray: v == 30 || v == 70 ? [4, 4] : null,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 36,
                        getTitlesWidget: (v, _) {
                          if (v == 30 || v == 70) return Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 9, color: labelColor));
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [LineChartBarData(
                    spots: rsiSpots, isCurved: true, curveSmoothness: 0.35,
                    color: rsiColor, barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [rsiColor.withValues(alpha: 0.15), Colors.transparent],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ),
                    ),
                  )],
                )),
                Positioned(top: 0, left: 4, child: _ChartLegendDot(color: rsiColor, label: 'RSI 14')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Fundamental Module 0: P&L Cascade BarChart ───────────────────────────

  Widget _buildCascadeChart(BuildContext context) {
    final textColor = isDark
        ? const Color(0x80FFFFFF)
        : const Color(0x80000000);
    final gridColor = isDark
        ? const Color(0x0DFFFFFF)
        : const Color(0x0D000000);

    const labels = ['Revenue', 'Marge B.', 'EBIT', 'Net Inc.', 'FCF'];
    const values = [100.0, 65.0, 28.0, 20.0, 18.0];
    const colors = [
      Color(0xFF42A5F5),
      Color(0xFF4CAF50),
      Color(0xFFFFD54F),
      Color(0xFFFF9800),
      Color(0xFF4DD0E1),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: 115,
          minY: 0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= values.length) return const SizedBox.shrink();
                  return Text(
                    '${values[i].round()}%',
                    style: TextStyle(
                      fontSize: 9,
                      color: colors[i],
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: TextStyle(fontSize: 9, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            values.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: colors[i].withValues(alpha: 0.8),
                  width: 30,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Fundamental Module 1: Valuation Comparison grouped BarChart ──────────

  Widget _buildValuationChart(BuildContext context) {
    final textColor = isDark
        ? const Color(0x80FFFFFF)
        : const Color(0x80000000);
    final gridColor = isDark
        ? const Color(0x0DFFFFFF)
        : const Color(0x0D000000);

    const companies = ['Value', 'Quality', 'Growth', 'Trap'];
    const peRatios = [12.0, 28.0, 42.0, 18.0];
    const evEbitda = [8.0, 21.0, 32.0, 13.0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: 50,
          minY: 0,
          groupsSpace: 10,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xDD101010),
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final metric = rodIdx == 0 ? 'P/E' : 'EV/EBITDA';
                return BarTooltipItem(
                  '$metric: ${rod.toY.toStringAsFixed(0)}x',
                  const TextStyle(color: Color(0xEEFFFFFF), fontSize: 10),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= companies.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      companies[i],
                      style: TextStyle(fontSize: 9, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            companies.length,
            (i) => BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: peRatios[i],
                  color: AppTheme.eduBlue.withValues(alpha: 0.82),
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: evEbitda[i],
                  color: AppTheme.eduGold.withValues(alpha: 0.82),
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHART LEGEND DOT
// ═══════════════════════════════════════════════════════════════════════════════

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FORMULA BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

class _FormulaBlock extends StatelessWidget {
  final List<_FormulaItem> items;
  final Color accent;

  const _FormulaBlock({required this.items, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          // Formula name
          Text(
            items[i].name.toUpperCase(),
            style: AppTheme.overline(context, color: AppTheme.getSecondaryText(context)),
          ),
          const SizedBox(height: 6),
          // Formula — left-border accent, Lora font
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: accent, width: 3),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(
              items[i].formula,
              style: AppTheme.compactTitle(context, size: 12, color: AppTheme.getPrimaryText(context))
                  .copyWith(height: 1.6, letterSpacing: 0.2),
            ),
          ),
          if (items[i].note.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              items[i].note,
              style: AppTheme.compactBody(
                context,
                size: 11,
                color: AppTheme.getSecondaryText(context),
              ).copyWith(height: 1.5),
            ),
          ],
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION LABEL
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.getSecondaryText(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.overline(context, color: AppTheme.getSecondaryText(context)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 0.5,
            color: AppTheme.borderShim(context),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO
// ═══════════════════════════════════════════════════════════════════════════════

class _LessonHero extends StatelessWidget {
  final AcademyModule module;
  final int index;
  final int total;

  const _LessonHero({
    required this.module,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _trackColor(module.track);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'MODULE ${(index + 1).toString().padLeft(2, '0')} / $total',
              style: AppTheme.overline(context, color: accent),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(total, (i) {
                final active = i == index;
                final done = i < index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : done
                            ? accent.withValues(alpha: 0.35)
                            : AppTheme.borderShim(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(module.icon, size: 19, color: accent),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: AppTheme.compactTitle(context, size: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.subtitle,
                    style: AppTheme.compactBody(
                      context,
                      size: 12,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          module.description,
          style: AppTheme.compactBody(context, size: 13).copyWith(height: 1.6),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip('${module.lessons} lecons', accent),
            _Chip(module.duration, accent),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// READING TABLE
// ═══════════════════════════════════════════════════════════════════════════════

class _ReadingTable extends StatelessWidget {
  final List<_TableRow> rows;
  final Color accent;

  const _ReadingTable({required this.rows, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final altBg = isDark
        ? const Color(0xFF0C1019).withValues(alpha: 0.6)
        : const Color(0xFFF8F9FC);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderShim(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.07),
              border: Border(
                bottom: BorderSide(color: accent.withValues(alpha: 0.15), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(children: [
                    Icon(Icons.signal_cellular_alt_rounded, size: 11, color: accent),
                    const SizedBox(width: 5),
                    Text('SIGNAL', style: AppTheme.overline(context, color: accent)),
                  ]),
                ),
                Expanded(
                  flex: 5,
                  child: Row(children: [
                    Icon(Icons.remove_red_eye_outlined, size: 11, color: accent),
                    const SizedBox(width: 5),
                    Text('LECTURE', style: AppTheme.overline(context, color: accent)),
                  ]),
                ),
                Expanded(
                  flex: 6,
                  child: Row(children: [
                    Icon(Icons.bolt_rounded, size: 11, color: accent),
                    const SizedBox(width: 5),
                    Text('ACTION', style: AppTheme.overline(context, color: accent)),
                  ]),
                ),
              ],
            ),
          ),
          // ── Data rows with alternating background ──────────────────────────
          for (var i = 0; i < rows.length; i++)
            _TableRowWidget(
              row: rows[i],
              accent: accent,
              isLast: i == rows.length - 1,
              altBg: i.isOdd ? altBg : Colors.transparent,
            ),
        ],
      ),
    );
  }
}

class _TableRowWidget extends StatelessWidget {
  final _TableRow row;
  final Color accent;
  final bool isLast;
  final Color altBg;

  const _TableRowWidget({
    required this.row,
    required this.accent,
    required this.isLast,
    required this.altBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: altBg,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppTheme.borderShim(context),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signal — accented, with left dot
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 4, right: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    row.signal,
                    style: AppTheme.compactBody(context, size: 11, color: accent)
                        .copyWith(height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Lecture
          Expanded(
            flex: 5,
            child: Text(
              row.read,
              style: AppTheme.compactBody(context, size: 11).copyWith(height: 1.5),
            ),
          ),
          // Action — muted italic
          Expanded(
            flex: 6,
            child: Text(
              row.action,
              style: AppTheme.compactBody(
                context,
                size: 11,
                color: AppTheme.getSecondaryText(context),
              ).copyWith(height: 1.5, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRO TIP
// ═══════════════════════════════════════════════════════════════════════════════

class _ProTipCard extends StatelessWidget {
  final String text;

  const _ProTipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: AppTheme.gold, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 12, color: AppTheme.gold),
              const SizedBox(width: 6),
              Text('CONSEIL PRO', style: AppTheme.overline(context, color: AppTheme.gold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTheme.compactBody(context, size: 13).copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAVIGATION FOOTER
// ═══════════════════════════════════════════════════════════════════════════════

class _NavigationFooter extends StatelessWidget {
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _NavigationFooter({required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 460;
    final prev = onPrev == null
        ? null
        : OutlinedButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: const Text('Precedent'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: BorderSide(color: AppTheme.getBorder(context), width: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
    final next = onNext == null
        ? null
        : FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Module suivant'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (prev != null) prev,
          if (prev != null && next != null) const SizedBox(height: 10),
          if (next != null) next,
        ],
      );
    }
    return Row(
      children: [
        if (prev != null) Expanded(child: prev),
        if (prev != null && next != null) const SizedBox(width: 12),
        if (next != null) Expanded(child: next),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MICRO WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _Chip extends StatelessWidget {
  final String label;
  final Color accent;

  const _Chip(this.label, this.accent);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: AppTheme.overline(context, color: accent)),
    );
  }
}
