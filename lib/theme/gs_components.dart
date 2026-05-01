// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA GS COMPONENT LIBRARY
// Goldman Sachs Institutional Design System — shared primitives
// ═══════════════════════════════════════════════════════════════════════════════

// ─── BACK BUTTON ─────────────────────────────────────────────────────────────
/// Bouton Retour conforme Apple HIG + Material Design.
/// Taille minimale 44×44 px. Icône adaptée à la plateforme.
class GSBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;
  final Color? color;

  const GSBackButton({
    super.key,
    this.onPressed,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS
        || Theme.of(context).platform == TargetPlatform.macOS;
    final effectiveColor = color ?? AppTheme.getPrimaryText(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.of(context).maybePop();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Icon(
              isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,
              size: isIOS ? 18 : 20,
              color: effectiveColor,
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: GoogleFonts.lora(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}



/// Standard GS page wrapper. Use as root of every screen.
class GSPageShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;
  final bool showBackButton;
  final EdgeInsetsGeometry padding;

  const GSPageShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 120),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.transparent,
      appBar: showBackButton
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(title),
              actions: actions,
            )
          : null,
      body: ListView(
        padding: showBackButton
            ? const EdgeInsets.fromLTRB(16, 16, 16, 120)
            : padding,
        children: [
          if (!showBackButton) ...[
            _GSPageHeader(title: title, subtitle: subtitle),
          ],
          child,
        ],
      ),
    );
  }
}

/// Standard GS standalone screen (with real AppBar, e.g. pushed screens).
class GSScreen extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const GSScreen({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: body,
    );
  }
}

// ─── PAGE HEADER ──────────────────────────────────────────────────────────────

class _GSPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _GSPageHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 52, 4, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lora(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.getPrimaryText(context),
              letterSpacing: -0.8,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.getSecondaryText(context),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────

/// Gold-accented section label. Replaces all inline section labels.
class GSSectionHeader extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;

  const GSSectionHeader(
    this.label, {
    super.key,
    this.padding = const EdgeInsets.only(left: 4, bottom: 10, top: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.lora(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppTheme.accent,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 0.5,
              color: AppTheme.accent.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CARD ─────────────────────────────────────────────────────────────────────

/// Standard GS card container.
class GSCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const GSCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final surface = color ?? (isDark ? AppTheme.bgSecondary : AppTheme.white);
    final border = isDark ? AppTheme.borderDark : AppTheme.lightBorder;

    final container = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: border, width: 0.5),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: container);
    }
    return container;
  }
}

// ─── SETTINGS GROUP ───────────────────────────────────────────────────────────

/// GS-style settings group — a card containing a list of [GSListTile]s.
class GSSettingsGroup extends StatelessWidget {
  final List<GSListTile> tiles;

  const GSSettingsGroup({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final surface = isDark ? AppTheme.bgSecondary : AppTheme.white;
    final border = isDark ? AppTheme.panelDark : AppTheme.black.withValues(alpha: 0.08);
    final divider = isDark ? AppTheme.dividerSubtle : AppTheme.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        children: tiles.asMap().entries.map((e) {
          final isLast = e.key == tiles.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast)
                Divider(height: 1, thickness: 0.5, color: divider, indent: 44),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── LIST TILE ────────────────────────────────────────────────────────────────

/// Standard GS settings row tile.
class GSListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool destructive;

  const GSListTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppTheme.negative
        : (iconColor ?? AppTheme.primary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.lora(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: destructive
                      ? AppTheme.negative
                      : AppTheme.getPrimaryText(context),
                ),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: GoogleFonts.lora(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getSecondaryText(context),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 13,
                color: AppTheme.getSecondaryText(context).withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── BADGE ────────────────────────────────────────────────────────────────────

/// Small label badge (e.g., PRO, NEW, LIVE).
class GSBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const GSBadge(
    this.label, {
    super.key,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = (color ?? AppTheme.accent).withValues(alpha: 0.15);
    final fg = textColor ?? color ?? AppTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: GoogleFonts.lora(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── TOGGLE ───────────────────────────────────────────────────────────────────

/// Custom GS toggle switch.
class GSToggle extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;

  const GSToggle({super.key, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 22,
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primary
              : AppTheme.textTertiary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: AppTheme.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ICON BUTTON ─────────────────────────────────────────────────────────────

/// Small circular icon action button used inside tiles.
class GSIconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const GSIconAction({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

// ─── BOTTOM SHEET WRAPPER ────────���────────────────────────────────────────────

/// Standard GS bottom sheet layout.
class GSBottomSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const GSBottomSheet({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgSecondary : AppTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppTheme.dividerSubtle
                : AppTheme.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.getSecondaryText(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Text(
              title,
              style: GoogleFonts.lora(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppTheme.accent,
                letterSpacing: 2.0,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── PICKER ITEM ─────────────────────────────────────────────────────────────

/// A single option row for [GSBottomSheet] pickers.
class GSPickerItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const GSPickerItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 16,
        color: selected ? AppTheme.primary : AppTheme.getSecondaryText(context),
      ),
      title: Text(
        label,
        style: GoogleFonts.lora(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppTheme.primary : AppTheme.getPrimaryText(context),
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, size: 14, color: AppTheme.primary)
          : null,
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
    );
  }
}

// ─── STATUS DOT ──────────────────────────────────────────────────────────────

/// Small pulsing status dot indicator.
class GSStatusDot extends StatelessWidget {
  final bool active;
  final String? label;

  const GSStatusDot({super.key, this.active = true, this.label});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.positive : AppTheme.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                : null,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 7),
          Text(
            label!,
            style: GoogleFonts.lora(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppTheme.getSecondaryText(context),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── EMPTY STATE ─────────────────────────────────────────────────────────────

class GSEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const GSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppTheme.getSecondaryText(context).withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.getSecondaryText(context),
                letterSpacing: 0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 11,
                  color: AppTheme.getSecondaryText(context).withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── LOADING STATE ────────────────────────────────────────────────────────────

class GSLoadingState extends StatelessWidget {
  final String? label;

  const GSLoadingState({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppTheme.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(
              label!,
              style: GoogleFonts.lora(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.getSecondaryText(context),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}



