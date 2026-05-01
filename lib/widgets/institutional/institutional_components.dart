import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';

class InstitutionalSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;
  final bool elevated;

  const InstitutionalSurface({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: padding ?? AppTheme.compactPanelPadding,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDeep : AppTheme.white,
        border: Border.all(
          color: accentColor?.withValues(alpha: 0.35) ??
              AppTheme.getBorder(context),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: child,
    );
  }
}

class InstitutionalPage extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? thesis;
  final IconData icon;
  final List<Widget> children;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;

  const InstitutionalPage({
    super.key,
    required this.eyebrow,
    required this.title,
    this.thesis,
    required this.icon,
    required this.children,
    this.actions,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundShim(context),
      child: ListView(
        padding: padding ?? AppTheme.pagePadding,
        children: [
          InstitutionalHeader(
            eyebrow: eyebrow,
            title: title,
            thesis: thesis,
            icon: icon,
            actions: actions,
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class InstitutionalHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? thesis;
  final IconData icon;
  final List<Widget>? actions;

  const InstitutionalHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.thesis,
    required this.icon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderShim(context), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.mutedSurface(context),
              border:
                  Border.all(color: AppTheme.borderShim(context), width: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.compactTitle(context, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      eyebrow.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.overline(context, color: AppTheme.gold),
                    ),
                  ],
                ),
                if (thesis != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    thesis!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.compactBody(context, size: 11),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 10),
            Wrap(spacing: 6, runSpacing: 6, children: actions!),
          ],
        ],
      ),
    );
  }
}

class InstitutionalSectionTitle extends StatelessWidget {
  final String label;
  final String? detail;
  final Widget? trailing;

  const InstitutionalSectionTitle({
    super.key,
    required this.label,
    this.detail,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTheme.overline(context),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: AppTheme.compactBody(context, size: 11),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class InstitutionalMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? footnote;
  final Color? valueColor;
  final IconData? icon;

  const InstitutionalMetric({
    super.key,
    required this.label,
    required this.value,
    this.footnote,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InstitutionalSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppTheme.gold),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: AppTheme.getSecondaryText(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.getPrimaryText(context),
              height: 1,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 5),
            Text(
              footnote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lora(
                fontSize: 10,
                height: 1.25,
                color: AppTheme.getSecondaryText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class InstitutionalEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const InstitutionalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 34, color: AppTheme.gold.withValues(alpha: 0.75)),
              const SizedBox(height: 18),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                  color: AppTheme.getPrimaryText(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.getSecondaryText(context),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
