// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/sigma_provider.dart';
import '../../services/ollama_news_service.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../institutional/institutional_components.dart';

class NewsFeedPanel extends StatelessWidget {
  const NewsFeedPanel({super.key});

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      color: AppTheme.backgroundShim(context),
      child: Consumer<SigmaProvider>(
        builder: (context, sp, _) {
          final overview = sp.marketOverview;
          final intel = sp.marketIntelligence;
          final rawNews = overview?.news ?? [];

          if (sp.isMarketLoading) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 1.5),
            );
          }

          if (rawNews.isEmpty && !sp.isNewsEnriching) {
            return _emptyState(isDark);
          }

          final enrichedNews = intel?.enrichedNews ?? [];
          final hasEnrichment = enrichedNews.isNotEmpty;

          return RefreshIndicator(
            onRefresh: () => sp.fetchMarketOverview(forceRefresh: true),
            color: AppTheme.gold,
            backgroundColor: AppTheme.backgroundShim(context),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: InstitutionalHeader(
                      eyebrow: 'Market briefing',
                      title: 'News & Catalyst Flow',
                      thesis:
                          'Un flux éditorial orienté impact : comprendre quelles nouvelles changent les hypothèses, les multiples ou le calendrier.',
                      icon: Icons.article_rounded,
                    ),
                  ),
                ),

                if (sp.isNewsEnriching)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildEnrichingIndicator(context),
                    ),
                  ),

                // Main News Stream
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        if (hasEnrichment && i < enrichedNews.length) {
                          return _buildEnrichedNewsItem(
                              enrichedNews[i], context);
                        }
                        if (i < rawNews.length) {
                          return _buildRawNewsItem(rawNews[i], context);
                        }
                        return null;
                      },
                      childCount:
                          hasEnrichment ? enrichedNews.length : rawNews.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(bool isDark) {
    return const InstitutionalEmptyState(
      icon: Icons.article_outlined,
      title: 'Briefing indisponible',
      message:
          'Le flux d’actualités sera affiché ici avec priorisation par impact, thème et catalyseur dès la prochaine synchronisation.',
    );
  }

  Widget _buildQuantumIntelBrief(
      MarketIntelligence intel, BuildContext context) {
    final dark = AppTheme.isDark(context);
    final regimeColor = intel.regime.contains('RISK-OFF')
        ? AppTheme.negative
        : AppTheme.positive;

    return AppTheme.editorialTile(
      accentColor: AppTheme.gold,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('QUANTUM INTELLIGENCE', style: AppTheme.label(context)),
                const Spacer(),
                Text(intel.regime.toUpperCase(),
                    style: GoogleFonts.lora(
                        fontSize: 10,
                        color: regimeColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              intel.brief,
              style: AppTheme.body(context).copyWith(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: dark
                    ? AppTheme.white.withValues(alpha: 0.9)
                    : AppTheme.black.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: intel.keyThemes
                  .take(4)
                  .map((t) => _flatPill(t, context))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flatPill(String text, BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark
            ? AppTheme.white.withValues(alpha: 0.03)
            : AppTheme.black.withValues(alpha: 0.03),
        border: Border.all(
            color: dark
                ? AppTheme.white.withValues(alpha: 0.05)
                : AppTheme.black.withValues(alpha: 0.05),
            width: 0.5),
      ),
      child: Text(text.toUpperCase(),
          style: GoogleFonts.lora(
              fontSize: 9,
              color: dark ? AppTheme.white38 : AppTheme.black38,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0)),
    );
  }

  Widget _buildEnrichingIndicator(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(AppTheme.gold))),
        const SizedBox(width: 12),
        Text(
          'SYNCHRONIZING...',
          style: GoogleFonts.lora(
            fontSize: 9,
            color: AppTheme.gold.withValues(alpha: 0.6),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEnrichedNewsItem(EnrichedNewsItem item, BuildContext context) {
    final dark = AppTheme.isDark(context);
    final dim = dark ? AppTheme.white24 : AppTheme.black26;
    final sentColor = item.sentiment == 'BULLISH'
        ? AppTheme.positive
        : (item.sentiment == 'BEARISH' ? AppTheme.negative : dim);

    return InkWell(
      onTap: item.url.isNotEmpty ? () => _openUrl(item.url) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: dark
                      ? AppTheme.white.withValues(alpha: 0.04)
                      : AppTheme.black.withValues(alpha: 0.04),
                  width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source + sentiment row
            Row(
              children: [
                Text(item.source.toUpperCase(),
                    style: GoogleFonts.lora(
                        color: dim,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: sentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(item.sentiment,
                      style: GoogleFonts.lora(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: sentColor)),
                ),
                const Spacer(),
                Text(_formatDate(item.publishedAt),
                    style: GoogleFonts.lora(
                        color: dim.withValues(alpha: 0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                if (item.tickers.isNotEmpty)
                  ...item.tickers.take(3).map((t) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(t,
                            style: GoogleFonts.lora(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color:
                                    AppTheme.primary.withValues(alpha: 0.6))),
                      )),
              ],
            ),
            const SizedBox(height: 8),
            // Headline
            Text(
              item.title,
              style: GoogleFonts.lora(
                color: dark
                    ? AppTheme.white.withValues(alpha: 0.87)
                    : AppTheme.black.withValues(alpha: 0.87),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.insight.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.insight,
                style: GoogleFonts.lora(
                  fontSize: 12,
                  color: dark ? AppTheme.white38 : AppTheme.black38,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRawNewsItem(Map<String, String> n, BuildContext context) {
    final dark = AppTheme.isDark(context);
    final dim = dark ? AppTheme.white24 : AppTheme.black26;
    final title = n['title'] ?? n['headline'] ?? '';
    final source = n['source'] ?? n['publisher'] ?? '';

    return InkWell(
      onTap: (n['url'] ?? '').isNotEmpty ? () => _openUrl(n['url']!) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: dark
                      ? AppTheme.white.withValues(alpha: 0.04)
                      : AppTheme.black.withValues(alpha: 0.04),
                  width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (source.isNotEmpty) ...[
              Row(
                children: [
                  Text(source.toUpperCase(),
                      style: GoogleFonts.lora(
                          color: dim,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0)),
                  const Spacer(),
                  Text(_formatDate(n['publishedAt']),
                      style: GoogleFonts.lora(
                          color: dim.withValues(alpha: 0.5),
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              style: GoogleFonts.lora(
                color: dark
                    ? AppTheme.white.withValues(alpha: 0.8)
                    : AppTheme.black.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'NOW';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return 'NOW';
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'NOW';
      if (diff.inMinutes < 60) return '${diff.inMinutes}min';
      if (diff.inHours < 24) return '${diff.inHours}H';
      if (diff.inDays < 7) return '${diff.inDays}D';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return 'NOW';
    }
  }
}
