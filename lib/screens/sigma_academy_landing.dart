import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/academy_content.dart';
import '../theme/app_theme.dart';
import 'sigma_academy_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ACADEMY LANDING — choose your track before entering
// ═══════════════════════════════════════════════════════════════════════════════

class SigmaAcademyLanding extends StatelessWidget {
  const SigmaAcademyLanding({super.key});

  void _enter(BuildContext context, AcademyTrack track) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SigmaAcademyScreen(track: track),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundShim(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.getSurface(context),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderShim(context),
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      fixedSize: const Size(36, 36),
                      foregroundColor: AppTheme.getPrimaryText(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SIGMA ACADEMY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title block
                    Text(
                      'Choisissez',
                      style: AppTheme.serif(context, size: 28, weight: FontWeight.w800),
                    ),
                    Text(
                      'votre programme',
                      style: AppTheme.serif(
                        context,
                        size: 28,
                        weight: FontWeight.w800,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chaque programme suit une progression pedagogique stricte. '
                      'Completez les modules dans l\'ordre pour maximiser votre apprentissage.',
                      style: AppTheme.compactBody(context, size: 13).copyWith(height: 1.65),
                    ),
                    const SizedBox(height: 36),

                    // Track cards
                    for (final curriculum in AcademyContent.curricula)
                      _TrackCard(
                        curriculum: curriculum,
                        isDark: isDark,
                        onTap: () => _enter(context, curriculum.track),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final AcademyCurriculum curriculum;
  final bool isDark;
  final VoidCallback onTap;

  const _TrackCard({
    required this.curriculum,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = curriculum.track == AcademyTrack.technical
        ? AppTheme.academyTrackTechnical
        : AppTheme.academyTrackFundamental;
    final isTech = curriculum.track == AcademyTrack.technical;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.getSurface(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.borderShim(context),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top accent band ───────────────────────────────────────────
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 14),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(curriculum.icon, size: 22, color: accent),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                curriculum.title,
                                style: AppTheme.compactTitle(context, size: 15, color: accent),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                curriculum.subtitle,
                                style: AppTheme.compactBody(
                                  context,
                                  size: 12,
                                  color: AppTheme.getSecondaryText(context),
                                ).copyWith(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: accent.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Divider
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppTheme.borderShim(context),
                    ),
                    const SizedBox(height: 14),

                    // Stats row
                    Row(
                      children: [
                        _StatItem(
                          icon: Icons.view_module_rounded,
                          value: '${curriculum.moduleCount}',
                          label: 'modules',
                          accent: accent,
                        ),
                        _StatDivider(),
                        _StatItem(
                          icon: Icons.menu_book_rounded,
                          value: '${curriculum.lessonCount}',
                          label: 'leçons',
                          accent: accent,
                        ),
                        _StatDivider(),
                        _StatItem(
                          icon: Icons.timer_outlined,
                          value: curriculum.duration,
                          label: 'durée',
                          accent: accent,
                        ),
                        _StatDivider(),
                        _StatItem(
                          icon: Icons.signal_cellular_alt_rounded,
                          value: curriculum.level,
                          label: 'niveau',
                          accent: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Module preview pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _modulesFor(curriculum.track).map((m) => _ModulePill(
                        label: m.title,
                        accent: accent,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    // CTA
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 16, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            isTech
                                ? 'COMMENCER L\'ANALYSE TECHNIQUE'
                                : 'COMMENCER L\'ANALYSE FONDAMENTALE',
                            style: AppTheme.overline(context, color: accent),
                          ),
                        ],
                      ),
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

  List<AcademyModule> _modulesFor(AcademyTrack track) =>
      track == AcademyTrack.technical
          ? AcademyContent.technicalModules
          : AcademyContent.fundamentalModules;
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.compactTitle(context, size: 11, color: accent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.compactBody(
              context,
              size: 9,
              color: AppTheme.getSecondaryText(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 36,
      color: AppTheme.borderShim(context),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ModulePill extends StatelessWidget {
  final String label;
  final Color accent;

  const _ModulePill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTheme.compactBody(
          context,
          size: 10,
          color: AppTheme.getSecondaryText(context),
        ),
      ),
    );
  }
}
