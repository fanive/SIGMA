import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sigma_provider.dart';

class SigmaLocalization {
  static String translate(BuildContext context, String key) {
    final lang =
        Provider.of<SigmaProvider>(context, listen: false).language ?? 'EN';
    final isFr = lang == 'FR';

    switch (key) {
      // General
      case 'market':
        return isFr ? 'MACRO' : 'MACRO';
      case 'chart':
        return isFr ? 'MARCHÉS' : 'MARKETS';
      case 'watchlist':
        return isFr ? 'CONVICTIONS' : 'CONVICTIONS';
      case 'news':
        return isFr ? 'BRIEFING' : 'BRIEFING';
      case 'analysis':
        return isFr ? 'RECHERCHE' : 'RESEARCH';
      case 'portfolio':
        return isFr ? 'ALLOCATION' : 'ALLOCATION';
      case 'calendar':
        return isFr ? 'CALENDRIER' : 'CALENDAR';
      case 'heatmap':
        return isFr ? 'HEATMAP' : 'HEATMAP';
      case 'settings':
        return isFr ? 'PROFIL' : 'PROFILE';

      // Market Overview
      case 'market_overview_title':
        return isFr ? 'VUE D\'ENSEMBLE DU MARCHÉ' : 'MARKET OVERVIEW';
      case 'world_indices':
        return isFr ? 'INDICES MONDIAUX' : 'WORLD INDICES';
      case 'top_movers':
        return isFr ? 'TOP MOVERS' : 'TOP MOVERS';
      case 'loading_market_data':
        return isFr
            ? 'CHARGEMENT DES DONNÉES DE MARCHÉ...'
            : 'LOADING MARKET DATA...';
      case 'no_data_available':
        return isFr ? 'Aucune donnée disponible' : 'No data available';
      case 'no_news_available':
        return isFr ? 'Aucune actualité' : 'No news available';
      case 'catalyst_radar':
        return isFr ? 'RADAR CATALYSEURS' : 'CATALYST RADAR';
      case 'sector_performance':
        return isFr ? 'PERFORMANCE SECTORIELLE' : 'SECTOR PERFORMANCE';
      case 'most_active':
        return isFr ? 'PLUS ACTIFS' : 'MOST ACTIVE';
      case 'gainers':
        return isFr ? 'GAGNANTS' : 'GAINERS';
      case 'losers':
        return isFr ? 'PERDANTS' : 'LOSERS';

      // Analysis
      case 'no_ticker_selected':
        return isFr ? 'AUCUN ACTIF' : 'NO ASSET';
      case 'search_ticker_prompt':
        return isFr
            ? 'Recherchez une société ou une thèse'
            : 'Search for a company or thesis';
      case 'analysis_in_progress':
        return isFr
            ? 'ANALYSE DE {ticker} EN COURS...'
            : 'ANALYZING {ticker}...';
      case 'no_analysis_available':
        return isFr ? 'Aucune analyse disponible' : 'No analysis available';
      case 'ai_synthesis':
        return isFr ? 'SYNTHÈSE IA' : 'AI SYNTHESIS';
      case 'company_profile':
        return isFr ? 'PROFIL DE L\'ENTREPRISE' : 'COMPANY PROFILE';
      case 'recent_news':
        return isFr ? 'ACTUALITÉS RÉCENTES' : 'RECENT NEWS';
      case 'confidence_level':
        return isFr ? '{value}% confiance' : '{value}% confidence';
      case 'target_price':
        return isFr ? 'CIBLE' : 'TARGET';
      case 'current_price':
        return isFr ? 'PRIX' : 'PRICE';

      // Watchlist
      case 'empty_watchlist':
        return isFr ? 'AUCUNE CONVICTION' : 'NO CONVICTIONS YET';
      case 'add_favorites_prompt':
        return isFr
            ? 'Ajoutez des sociétés à votre univers d’investissement'
            : 'Add companies to your investment universe';
      case 'symbol':
        return isFr ? 'SYMBOLE' : 'SYMBOL';
      case 'price':
        return isFr ? 'PRIX' : 'PRICE';
      case 'change':
        return isFr ? 'CHG %' : 'CHG %';

      // Settings
      case 'appearance':
        return isFr ? 'APPARENCE' : 'APPEARANCE';
      case 'theme':
        return isFr ? 'Thème' : 'Theme';
      case 'dark':
        return isFr ? 'SOMBRE' : 'DARK';
      case 'light':
        return isFr ? 'CLAIR' : 'LIGHT';
      case 'language':
        return isFr ? 'LANGUE' : 'LANGUAGE';
      case 'analysis_language':
        return isFr ? 'Langue d\'analyse' : 'Analysis Language';
      case 'data':
        return isFr ? 'DONNÉES' : 'DATA';
      case 'clear_cache':
        return isFr ? 'Vider le cache' : 'Clear Cache';
      case 'system':
        return isFr ? 'SYSTÈME' : 'SYSTEM';
      case 'version':
        return isFr ? 'Version' : 'Version';
      case 'ai_engine':
        return isFr ? 'Moteur IA' : 'AI Engine';
      case 'analyst_consensus':
        return isFr ? 'CONSENSUS ANALYSTES' : 'ANALYST CONSENSUS';
      case 'catalysts':
        return isFr ? 'CATALYSEURS' : 'CATALYSTS';
      case 'strong_buy':
        return isFr ? 'Achat Fort' : 'Strong Buy';
      case 'buy':
        return isFr ? 'Achat' : 'Buy';
      case 'hold':
        return isFr ? 'Neutre' : 'Hold';
      case 'sell':
        return isFr ? 'Vente' : 'Sell';
      case 'strong_sell':
        return isFr ? 'Vente Forte' : 'Strong Sell';
      case 'impact':
        return isFr ? 'Impact' : 'Impact';

      default:
        return key;
    }
  }
}

extension LocalizationExt on BuildContext {
  String t(String key, {Map<String, String>? args}) {
    String text = SigmaLocalization.translate(this, key);
    if (args != null) {
      args.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }
}
