import 'package:flutter/material.dart';

import 'package:quantum_invest/theme/app_theme.dart';
import '../institutional/institutional_components.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EXECUTIVE RESEARCH PANEL â€” Global Finance Standards
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class ResearchPanelContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final List<Widget>? actions;
  final bool showHeader;
  final EdgeInsetsGeometry? padding;

  const ResearchPanelContainer({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.actions,
    this.showHeader = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundShim(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) _buildHeader(context),
          Expanded(
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: InstitutionalHeader(
        eyebrow: 'SIGMA RESEARCH OFFICE',
        title: title,
        thesis: _subtitleFor(title),
        icon: icon,
        actions: actions,
      ),
    );
  }

  String? _subtitleFor(String rawTitle) {
    final title = rawTitle.toUpperCase();
    if (title.contains('PORTFOLIO') || title.contains('PORTEFEUILLE')) {
      return 'Allocation, expositions et discipline de portefeuille.';
    }
    if (title.contains('GRAPHIQUE') || title.contains('CHART')) {
      return 'Lecture prix-volume avec contexte technique et niveaux d’intérêt.';
    }
    if (title.contains('ANALY') || title.contains('RECHERCHE')) {
      return 'Thèse, valorisation, risques et catalyseurs en format recherche.';
    }
    if (title.trim().isEmpty) return null;
    return 'Vue de travail institutionnelle pour structurer la décision.';
  }
}
