// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/sigma_provider.dart';
import '../theme/app_theme.dart';
import '../theme/gs_components.dart';
import '../models/sigma_models.dart';
import '../utils/apple_compliance.dart';
import '../widgets/panels/sigma_subscription_panel.dart';
import 'sigma_academy_landing.dart';
import 'legal_screen.dart';
import 'notifications_screen.dart';
import 'splash/splash_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSize = '—';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    int total = 0;
    for (final key in prefs.getKeys()) {
      final val = prefs.get(key);
      if (val is String) {
        total += val.length * 2;
      } else if (val is List) {
        for (final item in val) {
          if (item is String) total += item.length * 2;
        }
      } else {
        total += 8;
      }
    }
    if (!mounted) return;
    setState(() {
      if (total == 0) {
        _cacheSize = 'VIDE';
      } else if (total < 1024) {
        _cacheSize = '$total B';
      } else if (total < 1024 * 1024) {
        _cacheSize = '${(total / 1024).toStringAsFixed(1)} KB';
      } else {
        _cacheSize = '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SigmaProvider>(
      builder: (context, provider, _) {
        final langLabel = provider.language == 'FR' ? 'Français' : 'English';
        final themeLabel = switch (provider.themeMode) {
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
          ThemeMode.system => 'Système',
        };

        return Scaffold(
          backgroundColor: AppTheme.transparent,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [

              // ── Page header ──────────────────────────────────────────
              _ConfigHeader(provider: provider),

              // ── Section: COMPTE ──────────────────────────────────────
              const GSSectionHeader('COMPTE'),
              GSSettingsGroup(tiles: [
                GSListTile(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Abonnement',
                  value: provider.currentTier.name.toUpperCase(),
                  trailing: provider.currentTier != SigmaTier.free
                      ? GSBadge('PRO', color: AppTheme.gold)
                      : null,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppTheme.transparent,
                    builder: (_) => const SigmaSubscriptionPanel(),
                  ),
                ),
                GSListTile(
                  icon: Icons.open_in_new_rounded,
                  label: 'Gérer l\'abonnement',
                  onTap: () => AppleCompliance.manageSubscriptions(),
                ),
                GSListTile(
                  icon: Icons.refresh_rounded,
                  label: 'Restaurer les achats',
                  onTap: () => AppleCompliance.restorePurchases(context),
                ),
              ]),

              // ── Section: PRÉFÉRENCES ─────────────────────────────────
              const GSSectionHeader('PRÉFÉRENCES'),
              GSSettingsGroup(tiles: [
                GSListTile(
                  icon: Icons.language_rounded,
                  label: 'Langue',
                  value: langLabel,
                  onTap: () => _showLanguagePicker(context, provider),
                ),
                GSListTile(
                  icon: Icons.brightness_6_rounded,
                  label: 'Apparence',
                  value: themeLabel,
                  onTap: () => _showThemePicker(context, provider),
                ),
                GSListTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Overlay IA',
                  trailing: GSToggle(
                    value: provider.showAiFab,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      provider.toggleAiFab();
                    },
                  ),
                ),
              ]),

              // ── Section: ACADÉMIE ────────────────────────────────────
              const GSSectionHeader('ACADÉMIE'),
              _AcademyEntryCard(),

              // ── Section: SYSTÈME ─────────────────────────────────────
              const GSSectionHeader('SYSTÈME'),
              GSSettingsGroup(tiles: [
                GSListTile(
                  icon: Icons.storage_rounded,
                  label: 'Cache',
                  value: _cacheSize,
                  trailing: GSIconAction(
                    icon: Icons.delete_outline_rounded,
                    color: AppTheme.negative,
                    onTap: () => _showPurgeConfirmation(context, provider),
                  ),
                  onTap: () => _showPurgeConfirmation(context, provider),
                ),
                GSListTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Centre d\'alertes',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen())),
                ),
                GSListTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Mentions légales',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LegalScreen())),
                ),
                GSListTile(
                  icon: Icons.restart_alt_rounded,
                  label: 'Revoir l\'onboarding',
                  onTap: () => _resetOnboarding(context),
                ),
                GSListTile(
                  icon: Icons.person_remove_outlined,
                  label: 'Supprimer mon compte',
                  destructive: true,
                  onTap: () =>
                      AppleCompliance.showDeleteAccountDialog(context),
                ),
              ]),

              // ── Section: ASSISTANCE ──────────────────────────────────
              const GSSectionHeader('ASSISTANCE'),
              GSSettingsGroup(tiles: [
                GSListTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Centre d\'aide',
                  onTap: () => _launchURL('https://sigma-research.ai/help'),
                ),
                GSListTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'Contacter le support',
                  onTap: () =>
                      _launchURL('mailto:support@sigma-research.ai'),
                ),
                GSListTile(
                  icon: Icons.star_outline_rounded,
                  label: 'Noter l\'application',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Merci pour votre soutien !')),
                    );
                  },
                ),
              ]),

              // ── Section: INFORMATIONS ────────────────────────────────
              const GSSectionHeader('INFORMATIONS'),
              GSSettingsGroup(tiles: [
                GSListTile(
                  icon: Icons.description_outlined,
                  label: 'Politique de confidentialité',
                  onTap: () => AppleCompliance.openPrivacyPolicy(),
                ),
                GSListTile(
                  icon: Icons.menu_book_rounded,
                  label: 'Licences Open Source',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'SIGMA Research',
                    applicationVersion: '1.3.0',
                  ),
                ),
              ]),

              const SizedBox(height: 40),

              // ── Footer ───────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'SIGMA RESEARCH',
                      style: AppTheme.overline(context,
                          color: AppTheme.getPrimaryText(context)
                              .withValues(alpha: 0.22)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v1.3.0 · Private Markets Intelligence',
                      style: AppTheme.compactBody(context,
                          size: 9,
                          color: AppTheme.getSecondaryText(context)
                              .withValues(alpha: 0.35)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _resetOnboarding(BuildContext context) async {
    final nav = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_complete', false);
    if (!mounted) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => const SplashScreen(showOnboarding: true)),
      (route) => false,
    );
  }

  void _showThemePicker(BuildContext context, SigmaProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.transparent,
      builder: (_) => GSBottomSheet(
        title: 'APPARENCE',
        children: [
          GSPickerItem(
            label: 'Light',
            icon: Icons.light_mode_rounded,
            selected: provider.themeMode == ThemeMode.light,
            onTap: () => provider.setThemeMode(ThemeMode.light),
          ),
          GSPickerItem(
            label: 'Dark',
            icon: Icons.dark_mode_rounded,
            selected: provider.themeMode == ThemeMode.dark,
            onTap: () => provider.setThemeMode(ThemeMode.dark),
          ),
          GSPickerItem(
            label: 'Système',
            icon: Icons.computer_rounded,
            selected: provider.themeMode == ThemeMode.system,
            onTap: () => provider.setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, SigmaProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.transparent,
      builder: (_) => GSBottomSheet(
        title: 'LANGUE',
        children: [
          GSPickerItem(
            label: 'English',
            icon: Icons.public_rounded,
            selected: provider.language == 'EN',
            onTap: () => provider.setLanguage('EN'),
          ),
          GSPickerItem(
            label: 'Français',
            icon: Icons.public_rounded,
            selected: provider.language == 'FR',
            onTap: () => provider.setLanguage('FR'),
          ),
        ],
      ),
    );
  }

  void _showPurgeConfirmation(BuildContext context, SigmaProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.transparent,
      builder: (ctx) => GSBottomSheet(
        title: 'VIDER LE CACHE',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Toutes les analyses, rapports et données mises en cache seront supprimés définitivement.',
              style: AppTheme.compactBody(ctx,
                  size: 13,
                  color: AppTheme.getSecondaryText(ctx)),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                          color: AppTheme.getBorder(ctx), width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                    child: Text('Annuler',
                        style: AppTheme.compactBody(ctx, size: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.negative,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      HapticFeedback.vibrate();
                      final messenger = ScaffoldMessenger.of(context);
                      await provider.clearCache();
                      _calculateCacheSize();
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Cache purgé.')));
                    },
                    child: Text('Purger',
                        style: AppTheme.compactTitle(ctx,
                            size: 13, color: AppTheme.white)),
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

// ─── Page header ─────────────────────────────────────────────────────────────

class _ConfigHeader extends StatelessWidget {
  final SigmaProvider provider;

  const _ConfigHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tier = provider.currentTier;
    final isPaid = tier != SigmaTier.free;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 52, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + status
          Row(
            children: [
              Text('CONFIGURATION',
                  style: AppTheme.overline(context, color: AppTheme.accent)),
              const Spacer(),
              GSStatusDot(active: true, label: 'ONLINE'),
            ],
          ),
          const SizedBox(height: 8),
          // Tier card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.mutedSurface(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: isPaid
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : AppTheme.borderShim(context),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.getSurface(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.borderShim(context), width: 0.5),
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.workspace_premium_rounded
                        : Icons.person_outline_rounded,
                    size: 18,
                    color: isPaid
                        ? AppTheme.primary
                        : AppTheme.getSecondaryText(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid ? 'Abonnement actif' : 'Plan gratuit',
                        style: AppTheme.compactTitle(context, size: 13),
                      ),
                      Text(
                        tier.name.toUpperCase() +
                            (isPaid ? ' · Accès complet' : ' · Fonctions limitées'),
                        style: AppTheme.overline(context,
                            color: isPaid
                                ? AppTheme.primary
                                : AppTheme.getSecondaryText(context)),
                      ),
                    ],
                  ),
                ),
                if (!isPaid)
                  TextButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppTheme.transparent,
                      builder: (_) => const SigmaSubscriptionPanel(),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Passer PRO',
                        style: AppTheme.compactTitle(context,
                            size: 11, color: AppTheme.primary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Academy entry card ───────────────────────────────────────────────────────

class _AcademyEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SigmaAcademyLanding()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.mutedSurface(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
              color: AppTheme.borderShim(context), width: 0.5),
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMd),
                  bottomLeft: Radius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.school_rounded,
                  size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('SIGMA ACADÉMIE',
                            style: AppTheme.overline(context,
                                color: AppTheme.primary)),
                        const SizedBox(width: 6),
                        GSBadge('NOUVEAU', color: AppTheme.positive),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('Technique & Fondamentaux',
                        style: AppTheme.compactTitle(context, size: 13)),
                    const SizedBox(height: 2),
                    Text('5 modules · 2–3h de formation',
                        style: AppTheme.compactBody(context,
                            size: 11,
                            color: AppTheme.getSecondaryText(context))),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.getSecondaryText(context)
                      .withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

