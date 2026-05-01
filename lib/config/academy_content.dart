import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ACADEMY CONTENT — Data models only. No colors, no logic.
// ═══════════════════════════════════════════════════════════════════════════════

enum AcademyTrack { technical, fundamental }

class AcademyCurriculum {
  final AcademyTrack track;
  final String title;
  final String subtitle;
  final IconData icon;
  final int moduleCount;
  final int lessonCount;
  final String duration;
  final String level;

  const AcademyCurriculum({
    required this.track,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.moduleCount,
    required this.lessonCount,
    required this.duration,
    required this.level,
  });
}

class AcademyModule {
  final int id;
  final AcademyTrack track;
  final String title;
  final String subtitle;
  final String description;
  final int lessons;
  final String duration;
  final IconData icon;

  const AcademyModule({
    required this.id,
    required this.track,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.lessons,
    required this.duration,
    required this.icon,
  });
}

class AcademyContent {
  AcademyContent._();

  static const List<AcademyCurriculum> curricula = [
    AcademyCurriculum(
      track: AcademyTrack.technical,
      title: 'ANALYSE TECHNIQUE',
      subtitle: 'Lire les graphiques comme un professionnel',
      icon: Icons.candlestick_chart_rounded,
      moduleCount: 5,
      lessonCount: 26,
      duration: '2h 30min',
      level: 'Debutant',
    ),
    AcademyCurriculum(
      track: AcademyTrack.fundamental,
      title: 'ANALYSE FONDAMENTALE',
      subtitle: 'Evaluer la vraie valeur d\'une entreprise',
      icon: Icons.account_balance_rounded,
      moduleCount: 2,
      lessonCount: 12,
      duration: '1h 30min',
      level: 'Intermediaire',
    ),
  ];

  static const List<AcademyModule> technicalModules = [
    AcademyModule(
      id: 0,
      track: AcademyTrack.technical,
      title: 'CHANDELIERS JAPONAIS',
      subtitle: 'Anatomie et lecture d\'un prix',
      description:
          'Le chandelier japonais encode 4 donnees en une image : ouverture, plus haut, plus bas et cloture. '
          'Comprendre chaque type de chandelier est la premiere etape de toute analyse technique serieuse.',
      lessons: 4,
      duration: '20 min',
      icon: Icons.candlestick_chart_rounded,
    ),
    AcademyModule(
      id: 1,
      track: AcademyTrack.technical,
      title: 'PATTERNS DE CHANDELIERS',
      subtitle: 'Engulfing, Morning Star, Harami',
      description:
          'Les patterns de chandeliers (2-3 bougies) generent des signaux de retournement et de continuation. '
          'Apprendre a les identifier et a les valider par le contexte de structure.',
      lessons: 5,
      duration: '25 min',
      icon: Icons.auto_graph_rounded,
    ),
    AcademyModule(
      id: 2,
      track: AcademyTrack.technical,
      title: 'TENDANCES & STRUCTURES',
      subtitle: 'Sommets, creux et polarite',
      description:
          'La theorie de Dow definit une tendance haussiere par des sommets et des creux croissants. '
          'Comprendre cette logique est la base de toute decision de positionnement.',
      lessons: 6,
      duration: '30 min',
      icon: Icons.trending_up_rounded,
    ),
    AcademyModule(
      id: 3,
      track: AcademyTrack.technical,
      title: 'FIGURES CHARTISTES',
      subtitle: 'Tete-epaules, triangles, drapeaux',
      description:
          'Les figures chartistes sont des configurations de prix qui se repetent sur tous les marches. '
          'Tete-Epaules, Double Top, triangles et drapeaux permettent d\'anticiper les grandes cassures.',
      lessons: 6,
      duration: '35 min',
      icon: Icons.area_chart_rounded,
    ),
    AcademyModule(
      id: 4,
      track: AcademyTrack.technical,
      title: 'MOMENTUM & INDICATEURS',
      subtitle: 'RSI, MACD et Volumes',
      description:
          'Les indicateurs ne predisent pas — ils mesurent. Apprendre a les utiliser comme '
          'confirmations du signal de prix, jamais comme signaux primaires.',
      lessons: 5,
      duration: '40 min',
      icon: Icons.speed_rounded,
    ),
  ];

  static const List<AcademyModule> fundamentalModules = [
    AcademyModule(
      id: 0,
      track: AcademyTrack.fundamental,
      title: 'LES ETATS FINANCIERS',
      subtitle: 'P&L, Bilan et Cash Flow',
      description:
          'Trois documents racontent l\'histoire complete d\'une entreprise. '
          'Savoir ou chercher la verite derriere les chiffres publies chaque trimestre.',
      lessons: 5,
      duration: '40 min',
      icon: Icons.description_rounded,
    ),
    AcademyModule(
      id: 1,
      track: AcademyTrack.fundamental,
      title: 'VALORISATION & RATIOS',
      subtitle: 'P/E, EV/EBITDA et PEG',
      description:
          'Un titre bon marche en P/E peut etre cher en EV/FCF. '
          'Comparer des societes d\'un meme secteur avec les metriques des analystes sell-side.',
      lessons: 7,
      duration: '50 min',
      icon: Icons.calculate_rounded,
    ),
  ];
}
