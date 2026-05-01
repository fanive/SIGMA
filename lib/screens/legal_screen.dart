// ignore_for_file: unused_import, unused_local_variable
import 'package:flutter/material.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import 'package:quantum_invest/theme/gs_components.dart';
import '../utils/apple_compliance.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MENTIONS LÃ‰GALES & CGU',
          style: AppTheme.label(context).copyWith(letterSpacing: 2, color: AppTheme.primary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              'IMPORTANT : AVERTISSEMENT SUR LES RISQUES',
              'L\'investissement boursier comporte des risques de perte en capital. SIGMA est un outil d\'intelligence artificielle et ne constitue en aucun cas un conseil financier personnalisÃ©. Vous Ãªtes seul responsable de vos dÃ©cisions d\'investissement.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'CONDITIONS GÃ‰NÃ‰RALES D\'UTILISATION (CGU)',
              'En utilisant SIGMA, vous acceptez que les donnÃ©es fournies soient Ã  titre informatif. Nous ne garantissons pas l\'exactitude absolue des donnÃ©es provenant de tiers (Yahoo Finance, FMP, Finnhub). L\'application utilise des modÃ¨les d\'IA pour gÃ©nÃ©rer des analyses qui sont des interprÃ©tations mathÃ©matiques et non des garanties de profit.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'POLITIQUE DE CONFIDENTIALITÃ‰',
              'Vos donnÃ©es de recherche et vos listes de favoris sont stockÃ©es localement sur votre appareil. Nous ne revendons pas vos donnÃ©es personnelles Ã  des tiers. Les clÃ©s d\'API utilisÃ©es pour les services externes sont protÃ©gÃ©es par chiffrement.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'LIMITATION DE RESPONSABILITÃ‰',
              'SIGMA dÃ©cline toute responsabilitÃ© en cas de perte financiÃ¨re rÃ©sultant de l\'utilisation de ses services. Nous recommandons de toujours consulter un conseiller financier agrÃ©Ã© avant de placer votre capital sur les marchÃ©s.',
            ),
            const SizedBox(height: 32),
            _buildLinkButton(
              context,
              'Politique de ConfidentialitÃ©',
              Icons.lock,
              () => AppleCompliance.openPrivacyPolicy(),
            ),
            const SizedBox(height: 12),
            _buildLinkButton(
              context,
              'Conditions d\'Utilisation (EULA)',
              Icons.description,
              () => AppleCompliance.openTermsOfService(),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Â© 2026 SIGMA INTELLIGENCE TERMINAL\nTous droits rÃ©servÃ©s.',
                textAlign: TextAlign.center,
                style: AppTheme.body(context, size: 10, muted: true),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.getBorder(context)),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          color: AppTheme.getSurface(context).withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.body(context, size: 14, muted: false).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.open_in_new, size: 14, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.h2(context).copyWith(fontSize: 14, color: AppTheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: AppTheme.body(context, size: 13),
        ),
        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }
}

