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
          'MENTIONS LEGALES & CGU',
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
              'L\'investissement sur les marches financiers comporte un risque de perte partielle ou totale du capital. SIGMA est un outil d\'aide a la recherche et a l\'organisation de l\'information. Le contenu affiche ne constitue ni une recommandation personnalisee, ni un conseil en investissement, ni une sollicitation a acheter ou vendre un instrument financier. Toute decision reste sous votre seule responsabilite.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'CONDITIONS GENERALES D\'UTILISATION (CGU)',
              'En utilisant SIGMA, vous acceptez que les donnees soient fournies a titre informatif et puissent comporter des retards, approximations ou erreurs de sources tierces. Les analyses generees par IA sont des syntheses probabilistes et des aides a la lecture. Elles ne constituent pas une promesse de performance, une garantie de resultat ou une recommandation adaptee a votre situation.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'POLITIQUE DE CONFIDENTIALITE',
              'Vos donnees de recherche et vos listes de suivi sont stockees localement sur votre appareil, sauf mention contraire liee a un service tiers. Nous ne revendons pas vos donnees personnelles. Les cles d\'API utilisees pour les services externes doivent etre gerees avec prudence et selon les contraintes de securite de la plateforme.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'LIMITATION DE RESPONSABILITE',
              'SIGMA ne peut etre tenu responsable des pertes, dommages ou decisions prises sur la base des informations affichees. Avant toute operation, vous devez verifier les donnees, evaluer l\'adequation du risque a votre profil et, si necessaire, solliciter un professionnel habilite.',
            ),
            const SizedBox(height: 32),
            _buildLinkButton(
              context,
              'Politique de Confidentialite',
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
                '© 2026 SIGMA INTELLIGENCE TERMINAL\nTous droits reserves.',
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


