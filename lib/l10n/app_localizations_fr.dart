// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class SFr extends S {
  SFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'SIGMA';

  @override
  String get appTagline => 'Recherche d\'Investissement Institutionnelle';

  @override
  String get navDashboard => 'Tableau de bord';

  @override
  String get navDiscover => 'Découvrir';

  @override
  String get navPortfolio => 'Portefeuille';

  @override
  String get navNews => 'Actualités';

  @override
  String get navProfile => 'Profil';

  @override
  String get dashboardTitle => 'VUE D\'ENSEMBLE DU MARCHÉ';

  @override
  String get worldIndices => 'INDICES MONDIAUX';

  @override
  String get commodities => 'MATIÈRES PREMIÈRES';

  @override
  String get yourWatchlist => 'VOS CONVICTIONS';

  @override
  String get liveData => 'DONNÉES EN DIRECT';

  @override
  String get marketClosed => 'MARCHÉ FERMÉ';

  @override
  String get marketOpen => 'MARCHÉ OUVERT';

  @override
  String get preMarket => 'PRÉ-OUVERTURE';

  @override
  String get afterHours => 'APRÈS-MARCHÉ';

  @override
  String get searchHint => 'Rechercher une société, un ticker, une thèse...';

  @override
  String get searchNoResults => 'Aucun résultat trouvé';

  @override
  String get searchRecent => 'RECHERCHES RÉCENTES';

  @override
  String get searchTrending => 'TENDANCES';

  @override
  String get analysisTitle => 'RECHERCHE';

  @override
  String analysisLoading(String ticker) {
    return 'Analyse de $ticker en cours...';
  }

  @override
  String get analysisError => 'L\'analyse a échoué';

  @override
  String get analysisRetry => 'Réessayer';

  @override
  String analysisCached(int hours) {
    return 'Analyse en cache • il y a ${hours}h';
  }

  @override
  String get verdictBuy => 'ACHETER';

  @override
  String get verdictStrongBuy => 'ACHAT FORT';

  @override
  String get verdictHold => 'CONSERVER';

  @override
  String get verdictSell => 'VENDRE';

  @override
  String get verdictStrongSell => 'VENTE FORTE';

  @override
  String get sigmaScore => 'SCORE SIGMA';

  @override
  String get confidence => 'Confiance';

  @override
  String get riskLevel => 'Niveau de risque';

  @override
  String get riskLow => 'Faible';

  @override
  String get riskMedium => 'Moyen';

  @override
  String get riskHigh => 'Élevé';

  @override
  String get tabOverview => 'Vue d\'ensemble';

  @override
  String get tabAnalysis => 'Analyse';

  @override
  String get tabFinancials => 'Financiers';

  @override
  String get tabNews => 'Actualités';

  @override
  String get technicalAnalysis => 'ANALYSE TECHNIQUE';

  @override
  String get fundamentalAnalysis => 'ANALYSE FONDAMENTALE';

  @override
  String get aiSynthesis => 'SYNTHÈSE IA';

  @override
  String get neuralSynthesis => 'SYNTHÈSE INSTITUTIONNELLE';

  @override
  String get companyProfile => 'PROFIL DE L\'ENTREPRISE';

  @override
  String get keyMetrics => 'INDICATEURS CLÉS';

  @override
  String get financialHealth => 'SANTÉ FINANCIÈRE';

  @override
  String get valuation => 'VALORISATION';

  @override
  String get growthMetrics => 'INDICATEURS DE CROISSANCE';

  @override
  String get profitability => 'RENTABILITÉ';

  @override
  String get rsi => 'RSI';

  @override
  String get macd => 'MACD';

  @override
  String get bollingerBands => 'BANDES DE BOLLINGER';

  @override
  String get movingAverages => 'MOYENNES MOBILES';

  @override
  String get sma => 'MMS';

  @override
  String get ema => 'MME';

  @override
  String get volume => 'VOLUME';

  @override
  String get vwap => 'VWAP';

  @override
  String get atr => 'ATR';

  @override
  String get stochastic => 'STOCHASTIQUE';

  @override
  String get oversold => 'Survendu';

  @override
  String get overbought => 'Suracheté';

  @override
  String get bullish => 'Haussier';

  @override
  String get bearish => 'Baissier';

  @override
  String get neutral => 'Neutre';

  @override
  String get signal => 'SIGNAL';

  @override
  String get signalBullishCross => 'Croisement haussier';

  @override
  String get signalBearishCross => 'Croisement baissier';

  @override
  String get trendUp => 'Tendance haussière';

  @override
  String get trendDown => 'Tendance baissière';

  @override
  String get trendSideways => 'Range';

  @override
  String get peRatio => 'Ratio C/B';

  @override
  String get forwardPE => 'C/B prévisionnel';

  @override
  String get pegRatio => 'Ratio PEG';

  @override
  String get priceToBook => 'Ratio P/A';

  @override
  String get priceToSales => 'Ratio P/V';

  @override
  String get evToEbitda => 'VE/EBITDA';

  @override
  String get marketCap => 'Capitalisation';

  @override
  String get beta => 'Bêta';

  @override
  String get dividendYield => 'Rendement div.';

  @override
  String get debtToEquity => 'Dette/Fonds propres';

  @override
  String get currentRatio => 'Ratio de liquidité';

  @override
  String get returnOnEquity => 'ROE';

  @override
  String get profitMargin => 'Marge nette';

  @override
  String get revenueGrowth => 'Croissance du CA';

  @override
  String get earningsGrowth => 'Croissance des bénéfices';

  @override
  String get freeCashFlow => 'Flux de trésorerie libre';

  @override
  String get eps => 'BPA';

  @override
  String get targetPrice => 'Prix cible';

  @override
  String get currentPrice => 'Prix actuel';

  @override
  String get week52High => 'Plus haut 52 sem.';

  @override
  String get week52Low => 'Plus bas 52 sem.';

  @override
  String get avgVolume => 'Volume moyen';

  @override
  String get sharesOutstanding => 'Actions en circulation';

  @override
  String get floatShares => 'Flottant';

  @override
  String get shortRatio => 'Ratio de VAD';

  @override
  String get insiderOwnership => 'Détention dirigeants';

  @override
  String get institutionalOwnership => 'Détention institutionnelle';

  @override
  String get analystConsensus => 'CONSENSUS ANALYSTES';

  @override
  String get strongBuy => 'Achat fort';

  @override
  String get buy => 'Acheter';

  @override
  String get hold => 'Conserver';

  @override
  String get sell => 'Vendre';

  @override
  String get strongSell => 'Vente forte';

  @override
  String get analysts => 'analystes';

  @override
  String get catalysts => 'CATALYSEURS';

  @override
  String get impact => 'Impact';

  @override
  String get newsRecentTitle => 'ACTUALITÉS RÉCENTES';

  @override
  String get newsMarketTitle => 'ACTUALITÉS DU MARCHÉ';

  @override
  String get newsNoArticles => 'Aucune actualité disponible';

  @override
  String get newsReadMore => 'Lire la suite';

  @override
  String get newsSentiment => 'Sentiment';

  @override
  String get chartInteractive => 'GRAPHIQUE INTERACTIF';

  @override
  String get chartRange1D => '1J';

  @override
  String get chartRange5D => '5J';

  @override
  String get chartRange1M => '1M';

  @override
  String get chartRange6M => '6M';

  @override
  String get chartRangeYTD => 'YTD';

  @override
  String get chartRange1Y => '1A';

  @override
  String get chartRange5Y => '5A';

  @override
  String get chartRangeMax => 'MAX';

  @override
  String get portfolioTitle => 'PORTEFEUILLE';

  @override
  String get portfolioEmpty => 'Aucune position';

  @override
  String get portfolioEmptySub =>
      'Ajoutez des actions depuis l\'onglet Découvrir pour commencer à construire votre portefeuille.';

  @override
  String get portfolioTotalValue => 'VALEUR TOTALE';

  @override
  String get portfolioDailyPnl => 'P&L JOURNALIER';

  @override
  String get portfolioTotalReturn => 'RENDEMENT TOTAL';

  @override
  String get portfolioAllocation => 'ALLOCATION';

  @override
  String get portfolioPositions => 'POSITIONS';

  @override
  String get portfolioAddPosition => 'Ajouter une position';

  @override
  String get watchlistTitle => 'CONVICTIONS';

  @override
  String get watchlistEmpty => 'AUCUNE CONVICTION';

  @override
  String get watchlistEmptySub =>
      'Ajoutez les sociétés que vous souhaitez suivre dans votre univers d\'investissement.';

  @override
  String get watchlistAdd => 'Ajouter aux convictions';

  @override
  String get watchlistRemove => 'Retirer des convictions';

  @override
  String get alertsTitle => 'ALERTES';

  @override
  String get alertsEmpty => 'Aucune alerte définie';

  @override
  String get alertsEmptySub =>
      'Définissez des alertes de prix sur n\'importe quelle action pour être notifié.';

  @override
  String get alertPrice => 'Alerte prix';

  @override
  String get alertVolume => 'Alerte volume';

  @override
  String get alertRSI => 'Alerte RSI';

  @override
  String get alertAbove => 'Au-dessus';

  @override
  String get alertBelow => 'En dessous';

  @override
  String get alertTriggered => 'Déclenchée';

  @override
  String get alertActive => 'Active';

  @override
  String get settingsTitle => 'PARAMÈTRES';

  @override
  String get settingsAppearance => 'APPARENCE';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsLanguage => 'LANGUE';

  @override
  String get settingsLanguageAuto => 'Détection automatique';

  @override
  String get settingsAiEngine => 'MOTEUR IA';

  @override
  String get settingsAiProvider => 'Fournisseur';

  @override
  String get settingsAiModel => 'Modèle';

  @override
  String get settingsAiTest => 'Tester la connexion';

  @override
  String get settingsAiTestSuccess => 'Connexion réussie';

  @override
  String get settingsAiTestFail => 'Connexion échouée';

  @override
  String get settingsData => 'DONNÉES';

  @override
  String get settingsClearCache => 'Vider le cache';

  @override
  String get settingsCacheCleared => 'Cache vidé';

  @override
  String get settingsSystem => 'SYSTÈME';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsAbout => 'À propos de SIGMA';

  @override
  String get settingsLegal => 'Mentions légales';

  @override
  String get settingsPrivacy => 'Politique de confidentialité';

  @override
  String get settingsTerms => 'Conditions d\'utilisation';

  @override
  String get profileTitle => 'PROFIL';

  @override
  String get profileOperator => 'OPÉRATEUR';

  @override
  String get profileAccessLevel => 'NIVEAU D\'ACCÈS : STRATÉGISTE';

  @override
  String get profileSettings => 'Paramètres de l\'application';

  @override
  String get profilePremium => 'Passer à Premium';

  @override
  String get financialReport => 'RAPPORT FINANCIER';

  @override
  String get financialReportGenerate => 'Générer le rapport complet';

  @override
  String get financialReportGenerating => 'Génération du rapport...';

  @override
  String get financialReportReady => 'Rapport prêt';

  @override
  String chatHint(String ticker) {
    return 'Poser une question sur $ticker...';
  }

  @override
  String chatWelcome(String ticker) {
    return 'Comment puis-je vous aider avec $ticker ?';
  }

  @override
  String get actionPlan => 'PLAN D\'ACTION';

  @override
  String get entryZone => 'Zone d\'entrée';

  @override
  String get targetAlpha => 'Cible';

  @override
  String get invalidation => 'Invalidation';

  @override
  String get riskRewardRatio => 'Ratio risque/récompense';

  @override
  String get projection7D => 'PROJECTION 7 JOURS';

  @override
  String get sector => 'Secteur';

  @override
  String get industry => 'Industrie';

  @override
  String get employees => 'Employés';

  @override
  String get headquarters => 'Siège social';

  @override
  String get website => 'Site web';

  @override
  String get phone => 'Téléphone';

  @override
  String get companyDescription => 'Description de l\'entreprise';

  @override
  String get peersAnalysis => 'ANALYSE DES PAIRS';

  @override
  String get dividendsHistory => 'DIVIDENDES & HISTORIQUE';

  @override
  String get sharesEstimates => 'ACTIONS & ESTIMATIONS';

  @override
  String get supportResistance => 'SUPPORT & RÉSISTANCE';

  @override
  String get trends => 'TENDANCES';

  @override
  String get shortTerm => 'Court terme';

  @override
  String get midTerm => 'Moyen terme';

  @override
  String get longTerm => 'Long terme';

  @override
  String get errorGeneric => 'Une erreur est survenue';

  @override
  String get errorNetwork => 'Pas de connexion internet';

  @override
  String get errorTimeout => 'Délai de requête dépassé';

  @override
  String get errorRetry => 'Réessayer';

  @override
  String get errorApiKey => 'Clé API manquante ou invalide';

  @override
  String get loading => 'Chargement...';

  @override
  String get noData => 'Aucune donnée disponible';

  @override
  String get readMore => 'Lire la suite';

  @override
  String get showMore => 'Voir plus';

  @override
  String get showLess => 'Voir moins';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get share => 'Partager';

  @override
  String get refresh => 'Actualiser';

  @override
  String get close => 'Fermer';

  @override
  String get onboardingTitle1 => 'Analyse Intelligente';

  @override
  String get onboardingDesc1 =>
      'Données en temps réel de sources multiples combinées avec des analyses IA pour des décisions d\'investissement plus éclairées.';

  @override
  String get onboardingTitle2 => 'Excellence Technique';

  @override
  String get onboardingDesc2 =>
      'Indicateurs techniques de niveau professionnel : RSI, MACD, Bandes de Bollinger et plus — tous calculés en temps réel.';

  @override
  String get onboardingTitle3 => 'Intelligence Mondiale';

  @override
  String get onboardingDesc3 =>
      'Suivez les marchés mondiaux avec des données de qualité institutionnelle, l\'analyse de sentiment et des actualités enrichies par l\'IA.';

  @override
  String get onboardingGetStarted => 'Commencer';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get disclaimer =>
      'SIGMA ne fournit pas de conseils financiers. Toutes les données sont à titre informatif uniquement. Investissez à vos propres risques.';
}
