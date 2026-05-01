import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../panels/sigma_subscription_panel.dart';
import '../../models/sigma_models.dart';

import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// RESEARCH SIDEBAR — Quick navigation between institutional workspaces
// ═════════════════════════════════════════════════════════════════════════════

class TerminalSidebar extends StatelessWidget {
  final bool isHorizontal;

  const TerminalSidebar({super.key, this.isHorizontal = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<TerminalProvider>(
      builder: (context, tp, _) {
        if (isHorizontal) {
          return Container(
            height: AppTheme.sidebarWidth,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.bgSecondary : AppTheme.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.borderDark : AppTheme.lightBorderSub,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                ...TerminalPanel.values
                    .where((p) => p != TerminalPanel.settings)
                    .map(
                      (panel) => Expanded(
                        child: _SidebarItem(
                          panel: panel,
                          isActive: tp.activePanel == panel,
                          isDark: isDark,
                          isHorizontal: true,
                        ),
                      ),
                    ),
                if (context.watch<SigmaProvider>().currentTier ==
                    SigmaTier.free)
                  _PremiumSidebarItem(isDark: isDark, isHorizontal: true),
                Expanded(
                  child: _SidebarItem(
                    panel: TerminalPanel.settings,
                    isActive: tp.activePanel == TerminalPanel.settings,
                    isDark: isDark,
                    isHorizontal: true,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: AppTheme.sidebarWidth,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.bgSecondary : AppTheme.lightSurface,
            border: Border(
              right: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.lightBorderSub,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              // ── Primary panels (top section) ──────────────────────
              ...TerminalPanel.values
                  .where((p) => p.isPrimary && p != TerminalPanel.settings)
                  .map((panel) => _SidebarItem(
                        panel: panel,
                        isActive: tp.activePanel == panel,
                        isDark: isDark,
                        isHorizontal: false,
                      )),
              // ── Divider ───────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark
                      ? AppTheme.white10
                      : AppTheme.black.withValues(alpha: 0.06),
                ),
              ),
              // ── Extended panels ───────────────────────────────────
              ...TerminalPanel.values
                  .where((p) => !p.isPrimary)
                  .map((panel) => _SidebarItem(
                        panel: panel,
                        isActive: tp.activePanel == panel,
                        isDark: isDark,
                        isHorizontal: false,
                      )),
              const Spacer(),
              if (context.watch<SigmaProvider>().currentTier == SigmaTier.free)
                _PremiumSidebarItem(isDark: isDark, isHorizontal: false),
              const SizedBox(height: 8),
              // ── Settings at the bottom ────────────────────────────
              _SidebarItem(
                panel: TerminalPanel.settings,
                isActive: tp.activePanel == TerminalPanel.settings,
                isDark: isDark,
                isHorizontal: false,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final TerminalPanel panel;
  final bool isActive;
  final bool isDark;
  final bool isHorizontal;

  const _SidebarItem({
    required this.panel,
    required this.isActive,
    required this.isDark,
    required this.isHorizontal,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppTheme.primary;

    final lang = context.watch<SigmaProvider>().language ?? 'EN';
    return Tooltip(
      message: '${widget.panel.getLabel(lang)}  ${widget.panel.shortcutHint}',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () =>
              context.read<TerminalProvider>().switchPanel(widget.panel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.isHorizontal ? null : AppTheme.sidebarWidth,
            height: widget.isHorizontal ? AppTheme.sidebarWidth : 56,
            margin: widget.isHorizontal
                ? const EdgeInsets.symmetric(horizontal: 2)
                : const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? activeColor.withValues(alpha: 0.12)
                  : _isHovered
                      ? (widget.isDark
                          ? AppTheme.bgElevated.withValues(alpha: 0.5)
                          : AppTheme.lightBorderSub.withValues(alpha: 0.3))
                      : AppTheme.transparent,
              borderRadius: null,
              border: widget.isHorizontal
                  ? Border(
                      bottom: BorderSide(
                        color: widget.isActive
                            ? activeColor
                            : AppTheme.transparent,
                        width: 2.5,
                      ),
                    )
                  : Border(
                      left: BorderSide(
                        color: widget.isActive
                            ? activeColor
                            : AppTheme.transparent,
                        width: 2.5,
                      ),
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.panel.icon,
                  size: 20,
                  color: widget.isActive
                      ? activeColor
                      : _isHovered
                          ? (widget.isDark
                              ? AppTheme.textPrimary
                              : AppTheme.lightText)
                          : (widget.isDark
                              ? AppTheme.textTertiary
                              : AppTheme.lightTextMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.panel.getLabel(lang),
                  style: GoogleFonts.lora(
                    color: widget.isActive
                        ? activeColor
                        : _isHovered
                            ? (widget.isDark
                                ? AppTheme.textSecondary
                                : AppTheme.lightTextSecond)
                            : (widget.isDark
                                ? AppTheme.textTertiary
                                : AppTheme.lightTextMuted),
                    fontSize: 7,
                    fontWeight:
                        widget.isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSidebarItem extends StatelessWidget {
  final bool isDark;
  final bool isHorizontal;

  const _PremiumSidebarItem({required this.isDark, required this.isHorizontal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppTheme.transparent,
          builder: (context) => const SigmaSubscriptionPanel(),
        );
      },
      child: Container(
        width: isHorizontal ? null : AppTheme.sidebarWidth,
        height: isHorizontal ? AppTheme.sidebarWidth : 56,
        padding: const EdgeInsets.symmetric(vertical: 4),
        margin: isHorizontal
            ? const EdgeInsets.symmetric(horizontal: 4)
            : const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, color: AppTheme.gold, size: 18),
            const SizedBox(height: 2),
            Text(
              'PRO',
              style: GoogleFonts.lora(
                color: AppTheme.gold,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
