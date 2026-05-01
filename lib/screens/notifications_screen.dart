import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../providers/sigma_provider.dart';
import '../providers/terminal_provider.dart';
import '../widgets/institutional/institutional_components.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SigmaProvider>().markNotificationsAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sp = context.watch<SigmaProvider>();
    final catalysts = sp.catalystInsights;
    final dim = isDark ? AppTheme.white24 : AppTheme.black26;

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: AppTheme.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: catalysts.isNotEmpty ? AppTheme.positive : dim,
                shape: BoxShape.circle,
                boxShadow: catalysts.isNotEmpty
                    ? [
                        BoxShadow(
                            color: AppTheme.positive.withValues(alpha: 0.5),
                            blurRadius: 6)
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SIGNAL FEED',
              style: GoogleFonts.lora(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${catalysts.length}',
              style: GoogleFonts.lora(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.getSecondaryText(context),
              ),
            ),
          ],
        ),
      ),
      body: catalysts.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
              itemCount: catalysts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: InstitutionalHeader(
                      eyebrow: 'Catalyst monitoring',
                      title: 'Signal Feed',
                      thesis:
                          'Alertes classées par impact potentiel sur la thèse, le risque ou le calendrier d’investissement.',
                      icon: Icons.radar_rounded,
                    ),
                  );
                }
                final catalyst = catalysts[index - 1];
                return _signalRow(context, catalyst, index - 1);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const InstitutionalEmptyState(
      icon: Icons.radar_rounded,
      title: 'Aucun signal actif',
      message:
          'Ajoutez des convictions et des sociétés à surveiller pour recevoir les catalyseurs importants dans ce centre d’alertes.',
    );
  }

  Widget _signalRow(BuildContext context, dynamic catalyst, int index) {
    final isDark = AppTheme.isDark(context);
    final Color color =
        catalyst.isNegative ? AppTheme.negative : AppTheme.positive;
    final txt = AppTheme.getPrimaryText(context);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        context.read<TerminalProvider>().openAnalysis(catalyst.ticker);
        context.read<SigmaProvider>().analyzeTicker(catalyst.ticker);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: isDark
                      ? AppTheme.white.withValues(alpha: 0.03)
                      : AppTheme.black.withValues(alpha: 0.03))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity bar
            Container(
              width: 3,
              height: 40,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(catalyst.ticker,
                          style: GoogleFonts.lora(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: color)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          catalyst.isNegative ? 'RISK' : 'CATALYST',
                          style: GoogleFonts.lora(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          size: 12, color: AppTheme.getSecondaryText(context)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(catalyst.title,
                      style: GoogleFonts.lora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: txt,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (catalyst.description != null &&
                      catalyst.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(catalyst.description!,
                        style: GoogleFonts.lora(
                            fontSize: 11,
                            color: AppTheme.getSecondaryText(context),
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 30))
        .fadeIn(duration: 200.ms);
  }
}
