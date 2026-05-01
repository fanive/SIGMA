// ignore_for_file: prefer_const_declarations, unnecessary_import, unused_import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/terminal_provider.dart';
import '../providers/sigma_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../widgets/terminal/omnibar.dart';
import '../widgets/terminal/market_ticker_bar.dart';
import '../widgets/terminal/sigma_logo.dart';
import '../widgets/terminal/terminal_sidebar.dart';
import '../widgets/terminal/status_bar.dart';
import '../widgets/institutional/institutional_components.dart';
import '../widgets/panels/market_overview_panel.dart';
import '../widgets/panels/watchlist_panel.dart';
import '../widgets/panels/news_feed_panel.dart';
import '../widgets/panels/analysis_panel.dart';
import '../widgets/panels/intelligence_hub_panel.dart';
import '../widgets/panels/portfolio_panel.dart';
import '../widgets/panels/chart_panel.dart';
import 'settings_screen.dart';
import '../widgets/sigma/sigma_ai_chatbot.dart';
import 'notifications_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA INSTITUTIONAL WORKSPACE — "Quiet Luxury" Finance Architecture
// ═══════════════════════════════════════════════════════════════════════════════

class TerminalShell extends StatefulWidget {
  const TerminalShell({super.key});

  @override
  State<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends State<TerminalShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = context.read<SigmaProvider>();
      if (sp.marketOverview == null && !sp.isMarketLoading) {
        sp.fetchMarketOverview();
      }
    });
  }

  Widget _buildActivePanel(TerminalPanel panel) {
    switch (panel) {
      case TerminalPanel.marketOverview:
        return const MarketOverviewPanel();
      case TerminalPanel.watchlist:
        return const WatchlistPanel();
      case TerminalPanel.newsFeed:
        return const NewsFeedPanel();
      case TerminalPanel.analysis:
        return const AnalysisPanel();
      case TerminalPanel.settings:
        return const SettingsScreen();
      case TerminalPanel.intelligence:
        return const IntelligencePanel();
      case TerminalPanel.portfolio:
        return const PortfolioPanel();
      case TerminalPanel.charts:
        return const ChartPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: false,
        backgroundColor: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
        body: SafeArea(
          bottom: true,
          child: Consumer2<TerminalProvider, SigmaProvider>(
            builder: (context, tp, sp, _) {
              final width = MediaQuery.of(context).size.width;
              final isMobile = width < 700;
              final showBriefingRail = width >= 1180;

              if (isMobile) {
                return Column(
                  children: [
                    _InvestmentTopBar(
                      trailing: _notificationBell(context),
                      compact: true,
                    ),
                    const MarketTickerBar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppTheme.animNormal,
                        child: _buildActivePanel(tp.activePanel),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  const TerminalSidebar(isHorizontal: false),
                  Expanded(
                    child: Column(
                      children: [
                        _InvestmentTopBar(
                          trailing: _notificationBell(context),
                        ),
                        const MarketTickerBar(),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              14,
                              14,
                              showBriefingRail ? 10 : 14,
                              10,
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              child: AnimatedSwitcher(
                                duration: AppTheme.animNormal,
                                child: _buildActivePanel(tp.activePanel),
                              ),
                            ),
                          ),
                        ),
                        const StatusBar(),
                      ],
                    ),
                  ),
                  if (showBriefingRail)
                    _InvestmentBriefingRail(
                      activePanel: tp.activePanel,
                    ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) return const SizedBox.shrink();
            return Consumer<SigmaProvider>(
              builder: (context, sp, _) {
                if (!sp.showAiFab) return const SizedBox.shrink();
                return _buildAiFab(context, isDark);
              },
            );
          },
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) return const SizedBox.shrink();

            return Consumer<TerminalProvider>(
              builder: (context, tp, _) {
                return _SigmaBottomNav(
                  activePanel: tp.activePanel,
                  isDark: isDark,
                  onTap: (panel) {
                    HapticFeedback.lightImpact();
                    tp.switchPanel(panel);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAiFab(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 114),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showAIAssistant(context, isDark);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E6FD9), Color(0xFF0A2A6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.50),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.15),
                blurRadius: 6,
                spreadRadius: 2,
                offset: Offset.zero,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle inner glow ring
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAIAssistant(BuildContext context, bool isDark) {
    final tp = context.read<TerminalProvider>();
    final ticker = tp.focusedTicker ?? 'MARKET';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        width: double.infinity,
        child: SigmaAIChatbot(
          ticker: ticker,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _notificationBell(BuildContext context) {
    return Consumer<SigmaProvider>(
      builder: (context, sp, _) {
        final count = sp.unreadNotificationsCount;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_none,
                    color: AppTheme.isDark(context)
                        ? AppTheme.white38
                        : AppTheme.black38,
                    size: 22),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.negative,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InvestmentTopBar extends StatelessWidget {
  final Widget trailing;
  final bool compact;

  const _InvestmentTopBar({required this.trailing, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Consumer2<TerminalProvider, SigmaProvider>(
      builder: (context, tp, sp, _) {
        return Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          decoration: BoxDecoration(
            color: AppTheme.getSurface(context),
            border: Border(
              bottom:
                  BorderSide(color: AppTheme.borderShim(context), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // ── Brand mark only ──────────────────────────────────────
              const SigmaLogo(size: 22, showText: false),
              const SizedBox(width: 14),
              // ── Search — takes all remaining space ───────────────────
              const Expanded(child: Omnibar()),
              const SizedBox(width: 10),
              // ── Notification bell ────────────────────────────────────
              trailing,
            ],
          ),
        );
      },
    );
  }
}

class _InvestmentBriefingRail extends StatelessWidget {
  final TerminalPanel activePanel;

  const _InvestmentBriefingRail({required this.activePanel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 304,
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundShim(context),
        border: Border(
          left: BorderSide(color: AppTheme.borderShim(context), width: 0.5),
        ),
      ),
      child: Consumer2<SigmaProvider, TerminalProvider>(
        builder: (context, sp, tp, _) {
          final marketReady = sp.marketOverview != null;
          final focus = tp.focusedTicker ?? sp.currentTicker ?? 'Market';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InstitutionalHeader(
                eyebrow: 'Context',
                title: 'Brief',
                thesis: 'Priorités du workspace actuel.',
                icon: Icons.insights_rounded,
              ),
              const SizedBox(height: 12),
              _BriefRow('Workspace', activePanel.getLabel(sp.language ?? 'EN')),
              _BriefRow('Focus', focus),
              _BriefRow('Convictions', '${sp.favoriteTickers.length}'),
              _BriefRow('Market sync', marketReady ? 'Ready' : 'Loading'),
              const SizedBox(height: 14),
              InstitutionalSectionTitle(
                label: 'Research agenda',
                detail:
                    'Priorités suggérées pour garder une discipline de desk.',
              ),
              _AgendaItem(
                icon: Icons.public_rounded,
                title: 'Macro regime',
                body: marketReady
                    ? 'Lire la rotation secteurs, volatilité et catalyseurs.'
                    : 'Attendre la première synchronisation marché.',
              ),
              _AgendaItem(
                icon: Icons.article_rounded,
                title: 'Briefing flow',
                body: sp.isNewsEnriching
                    ? 'Enrichissement des nouvelles en cours.'
                    : 'Scanner les nouvelles à impact élevé.',
              ),
              _AgendaItem(
                icon: Icons.query_stats_rounded,
                title: 'Single-name work',
                body: tp.focusedTicker == null
                    ? 'Choisir une société à analyser.'
                    : 'Compléter le rapport sur ${tp.focusedTicker}.',
              ),
              const Spacer(),
              Text(
                'Chaque vue doit répondre à une question d’investissement.',
                style: AppTheme.compactBody(context, size: 11),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BriefRow extends StatelessWidget {
  final String label;
  final String value;

  const _BriefRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderShim(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label.toUpperCase(),
                  style: AppTheme.overline(context,
                      color: AppTheme.getSecondaryText(context)))),
          Text(value,
              style: AppTheme.compactBody(context,
                  color: AppTheme.getPrimaryText(context))),
        ],
      ),
    );
  }
}

class _AgendaItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AgendaItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lora(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.getPrimaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.lora(
                    fontSize: 11,
                    height: 1.35,
                    color: AppTheme.getSecondaryText(context),
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

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION — Mobile Investment Office
// ═══════════════════════════════════════════════════════════════════════════════

class _SigmaBottomNav extends StatelessWidget {
  final TerminalPanel activePanel;
  final bool isDark;
  final ValueChanged<TerminalPanel> onTap;

  const _SigmaBottomNav({
    required this.activePanel,
    required this.isDark,
    required this.onTap,
  });

  static const _items = [
    _NavItem(TerminalPanel.marketOverview, Icons.account_balance, 'Macro'),
    _NavItem(TerminalPanel.watchlist, Icons.bookmark_added, 'Ideas'),
    _NavItem(TerminalPanel.newsFeed, Icons.article, 'Brief'),
    _NavItem(TerminalPanel.analysis, Icons.manage_search, 'Research'),
    _NavItem(TerminalPanel.settings, Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppTheme.bgPrimary : AppTheme.lightSurface;
    final borderColor = isDark
        ? AppTheme.borderDark.withValues(alpha: 0.1)
        : AppTheme.black.withValues(alpha: 0.05);
    const activeColor = AppTheme.primary;
    final inactiveColor = isDark ? AppTheme.white24 : AppTheme.black26;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = item.panel == activePanel;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(item.panel),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Active indicator dot
                      AnimatedContainer(
                        duration: AppTheme.animNormal,
                        width: isActive ? 20 : 0,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isActive ? activeColor : AppTheme.transparent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      Icon(item.icon,
                          size: 22,
                          color: isActive ? activeColor : inactiveColor),
                      const SizedBox(height: 4),
                      Text(
                        item.label.toUpperCase(),
                        style: GoogleFonts.lora(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w900 : FontWeight.w600,
                          color: isActive ? activeColor : inactiveColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final TerminalPanel panel;
  final IconData icon;
  final String label;
  const _NavItem(this.panel, this.icon, this.label);
}
