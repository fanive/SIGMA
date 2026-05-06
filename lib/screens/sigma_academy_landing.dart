import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── SIGMA Académie Landing ────────────────────────────────────────────────────
// Stub screen — placeholder until the full Academy module is implemented.

class SigmaAcademyLanding extends StatelessWidget {
  const SigmaAcademyLanding({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            size: 20,
            color: AppTheme.getPrimaryText(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SIGMA ACADÉMIE',
          style: AppTheme.overline(context, color: AppTheme.primary),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 32,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Formation en cours de déploiement',
                style: AppTheme.compactTitle(context, size: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Les modules Technique & Fondamentaux seront disponibles prochainement.',
                style: AppTheme.compactBody(context,
                    size: 13,
                    color: AppTheme.getSecondaryText(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
