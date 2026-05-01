import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sigma_models.dart';
import '../../providers/sigma_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/apple_compliance.dart';
import 'package:quantum_invest/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA SUBSCRIPTION — Clean institutional pricing screen
// ═══════════════════════════════════════════════════════════════════════════════

class SigmaSubscriptionPanel extends StatelessWidget {
  const SigmaSubscriptionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getSurface(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppTheme.getPrimaryText(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'ABONNEMENT',
          style: AppTheme.overline(context, color: AppTheme.gold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: AppTheme.borderShim(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Consumer<SigmaProvider>(
                builder: (context, sp, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Page headline ─────────────────────────────────────
                      Text(
                        'Choisissez votre niveau',
                        style: AppTheme.compactTitle(context, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Accédez à la profondeur de recherche qui correspond à votre mandat d\'investissement.',
                        style: AppTheme.compactBody(
                          context,
                          size: 14,
                          color: AppTheme.getSecondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Plans ─────────────────────────────────────────────
                      _PlanCard(
                        tier: SigmaTier.free,
                        label: 'SIGMA CORE',
                        price: 'Gratuit',
                        priceNote: 'pour toujours',
                        description:
                            'Un point de départ structuré pour suivre les marchés avec discipline.',
                        features: const [
                          'Vue macro générale',
                          'Recherche standard sur les sociétés',
                          'Liste de convictions (10 valeurs)',
                        ],
                        isActive: sp.currentTier == SigmaTier.free,
                        onUpgrade: null,
                      ),

                      const SizedBox(height: 16),

                      _PlanCard(
                        tier: SigmaTier.pro,
                        label: 'SIGMA PRO',
                        price: '9,99 \$',
                        priceNote: 'par mois',
                        description:
                            'Un flux de recherche complet pour les investisseurs actifs qui construisent des convictions.',
                        features: const [
                          'Intelligence de marché en temps réel',
                          'Raisonnement d\'investissement multi-étapes',
                          'Détection des catalyseurs et signaux',
                          'Analyses et conversations illimitées',
                        ],
                        isHighlighted: true,
                        isActive: sp.currentTier == SigmaTier.pro,
                        onUpgrade: () async {
                          final ok = await PaymentService.processPayment(
                            context: context,
                            tier: SigmaTier.pro,
                            amount: 9.99,
                          );
                          if (ok && context.mounted) {
                            context.read<SigmaProvider>().upgradeTier(SigmaTier.pro);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      _PlanCard(
                        tier: SigmaTier.elite,
                        label: 'SIGMA ELITE',
                        price: '19,99 \$',
                        priceNote: 'par mois',
                        description:
                            'Couverture de niveau bureau privé pour la recherche à haute conviction.',
                        features: const [
                          'Flux de comité d\'investissement complet',
                          'Rapports de recherche institutionnels approfondis',
                          'Accès anticipé au radar de catalyseurs',
                          'Accès prioritaire à l\'API de recherche',
                        ],
                        isElite: true,
                        isActive: sp.currentTier == SigmaTier.elite,
                        onUpgrade: () async {
                          final ok = await PaymentService.processPayment(
                            context: context,
                            tier: SigmaTier.elite,
                            amount: 19.99,
                          );
                          if (ok && context.mounted) {
                            context.read<SigmaProvider>().upgradeTier(SigmaTier.elite);
                          }
                        },
                      ),

                      const SizedBox(height: 40),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppTheme.borderShim(context),
                      ),
                      const SizedBox(height: 20),

                      // ── Restore + manage ─────────────────────────────────
                      Center(
                        child: TextButton(
                          onPressed: () => AppleCompliance.manageSubscriptions(),
                          child: Text(
                            'Restaurer les achats',
                            style: AppTheme.overline(
                              context,
                              color: AppTheme.getSecondaryText(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── Legal ─────────────────────────────────────────────
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegalLink(
                              label: 'Conditions d\'utilisation',
                              onTap: () => AppleCompliance.openTermsOfService(),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '·',
                                style: AppTheme.compactBody(
                                  context,
                                  color: AppTheme.getSecondaryText(context),
                                ),
                              ),
                            ),
                            _LegalLink(
                              label: 'Confidentialité',
                              onTap: () => AppleCompliance.openPrivacyPolicy(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Les abonnements sont débités sur votre compte iTunes à la confirmation d\'achat.\nRenouvellement automatique sauf résiliation 24h avant la fin de la période.',
                          textAlign: TextAlign.center,
                          style: AppTheme.compactBody(
                            context,
                            size: 10,
                            color: AppTheme.getSecondaryText(context)
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SigmaTier tier;
  final String label;
  final String price;
  final String priceNote;
  final String description;
  final List<String> features;
  final bool isHighlighted;
  final bool isElite;
  final bool isActive;
  final VoidCallback? onUpgrade;

  const _PlanCard({
    required this.tier,
    required this.label,
    required this.price,
    required this.priceNote,
    required this.description,
    required this.features,
    this.isHighlighted = false,
    this.isElite = false,
    required this.isActive,
    required this.onUpgrade,
  });

  Color _accentColor(BuildContext context) {
    if (isElite) return AppTheme.gold;
    if (isHighlighted) return AppTheme.primary;
    return AppTheme.getSecondaryText(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    final borderColor = isActive
        ? accent.withValues(alpha: 0.6)
        : AppTheme.borderShim(context);
    final borderWidth = isActive ? 1.5 : 0.5;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header band ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: AppTheme.borderShim(context), width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: AppTheme.overline(context, color: accent),
                          ),
                          if (isHighlighted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                border: Border.all(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.35),
                                  width: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'POPULAIRE',
                                style: AppTheme.overline(
                                    context, color: AppTheme.primary),
                              ),
                            ),
                          ],
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.35),
                                  width: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'ACTIF',
                                style: AppTheme.overline(context, color: accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: AppTheme.compactBody(
                          context,
                          size: 12,
                          color: AppTheme.getSecondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: AppTheme.compactTitle(context, size: 20),
                    ),
                    Text(
                      priceNote,
                      style: AppTheme.overline(
                        context,
                        color: AppTheme.getSecondaryText(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Feature list ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Column(
              children: features.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: AppTheme.compactBody(context, size: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ── CTA ────────────────────────────────────────────────────────
          if (onUpgrade != null || isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: isActive
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: borderColor, width: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                        child: Text(
                          'Plan actuel',
                          style: AppTheme.overline(context, color: accent),
                        ),
                      )
                    : FilledButton(
                        onPressed: onUpgrade,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              isElite ? AppTheme.gold : AppTheme.primary,
                          foregroundColor: isElite
                              ? const Color(0xFF0B0E14)
                              : AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isElite ? 'Passer à ELITE' : 'Passer à PRO',
                          style: AppTheme.overline(
                            context,
                            color: isElite
                                ? const Color(0xFF0B0E14)
                                : AppTheme.white,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Legal link ───────────────────────────────────────────────────────────────

class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LegalLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTheme.compactBody(
          context,
          size: 10,
          color: AppTheme.getSecondaryText(context),
        ).copyWith(decoration: TextDecoration.underline),
      ),
    );
  }
}
