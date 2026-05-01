// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class SDe extends S {
  SDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'SIGMA';

  @override
  String get appTagline => 'Intelligente Finanzanalyse';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDiscover => 'Entdecken';

  @override
  String get navPortfolio => 'Portfolio';

  @override
  String get navNews => 'Nachrichten';

  @override
  String get navProfile => 'Profil';

  @override
  String get dashboardTitle => 'MARKTÜBERSICHT';

  @override
  String get worldIndices => 'WORLD INDICES';

  @override
  String get commodities => 'COMMODITIES';

  @override
  String get yourWatchlist => 'YOUR CONVICTIONS';

  @override
  String get liveData => 'LIVE DATA';

  @override
  String get marketClosed => 'MARKET CLOSED';

  @override
  String get marketOpen => 'MARKET OPEN';

  @override
  String get preMarket => 'PRE-MARKET';

  @override
  String get afterHours => 'AFTER HOURS';

  @override
  String get searchHint => 'Ticker, Unternehmen suchen...';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchRecent => 'RECENT SEARCHES';

  @override
  String get searchTrending => 'TRENDING';

  @override
  String get analysisTitle => 'RESEARCH';

  @override
  String analysisLoading(String ticker) {
    return 'Analyzing $ticker...';
  }

  @override
  String get analysisError => 'Analysis failed';

  @override
  String get analysisRetry => 'Retry';

  @override
  String analysisCached(int hours) {
    return 'Cached analysis • ${hours}h ago';
  }

  @override
  String get verdictBuy => 'KAUFEN';

  @override
  String get verdictStrongBuy => 'STARKER KAUF';

  @override
  String get verdictHold => 'HALTEN';

  @override
  String get verdictSell => 'VERKAUFEN';

  @override
  String get verdictStrongSell => 'STARKER VERKAUF';

  @override
  String get sigmaScore => 'SIGMA SCORE';

  @override
  String get confidence => 'Confidence';

  @override
  String get riskLevel => 'Risk Level';

  @override
  String get riskLow => 'Low';

  @override
  String get riskMedium => 'Medium';

  @override
  String get riskHigh => 'High';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabAnalysis => 'Analysis';

  @override
  String get tabFinancials => 'Financials';

  @override
  String get tabNews => 'News';

  @override
  String get technicalAnalysis => 'TECHNISCHE ANALYSE';

  @override
  String get fundamentalAnalysis => 'FUNDAMENTALANALYSE';

  @override
  String get aiSynthesis => 'AI SYNTHESIS';

  @override
  String get neuralSynthesis => 'INSTITUTIONAL SYNTHESIS';

  @override
  String get companyProfile => 'COMPANY PROFILE';

  @override
  String get keyMetrics => 'KEY METRICS';

  @override
  String get financialHealth => 'FINANCIAL HEALTH';

  @override
  String get valuation => 'VALUATION';

  @override
  String get growthMetrics => 'GROWTH METRICS';

  @override
  String get profitability => 'PROFITABILITY';

  @override
  String get rsi => 'RSI';

  @override
  String get macd => 'MACD';

  @override
  String get bollingerBands => 'BOLLINGER BANDS';

  @override
  String get movingAverages => 'MOVING AVERAGES';

  @override
  String get sma => 'SMA';

  @override
  String get ema => 'EMA';

  @override
  String get volume => 'VOLUME';

  @override
  String get vwap => 'VWAP';

  @override
  String get atr => 'ATR';

  @override
  String get stochastic => 'STOCHASTIC';

  @override
  String get oversold => 'Oversold';

  @override
  String get overbought => 'Overbought';

  @override
  String get bullish => 'Bullish';

  @override
  String get bearish => 'Bearish';

  @override
  String get neutral => 'Neutral';

  @override
  String get signal => 'SIGNAL';

  @override
  String get signalBullishCross => 'Bullish Crossover';

  @override
  String get signalBearishCross => 'Bearish Crossover';

  @override
  String get trendUp => 'Uptrend';

  @override
  String get trendDown => 'Downtrend';

  @override
  String get trendSideways => 'Sideways';

  @override
  String get peRatio => 'P/E Ratio';

  @override
  String get forwardPE => 'Forward P/E';

  @override
  String get pegRatio => 'PEG Ratio';

  @override
  String get priceToBook => 'P/B Ratio';

  @override
  String get priceToSales => 'P/S Ratio';

  @override
  String get evToEbitda => 'EV/EBITDA';

  @override
  String get marketCap => 'Market Cap';

  @override
  String get beta => 'Beta';

  @override
  String get dividendYield => 'Dividend Yield';

  @override
  String get debtToEquity => 'Debt/Equity';

  @override
  String get currentRatio => 'Current Ratio';

  @override
  String get returnOnEquity => 'ROE';

  @override
  String get profitMargin => 'Profit Margin';

  @override
  String get revenueGrowth => 'Revenue Growth';

  @override
  String get earningsGrowth => 'Earnings Growth';

  @override
  String get freeCashFlow => 'Free Cash Flow';

  @override
  String get eps => 'EPS';

  @override
  String get targetPrice => 'Target Price';

  @override
  String get currentPrice => 'Current Price';

  @override
  String get week52High => '52W High';

  @override
  String get week52Low => '52W Low';

  @override
  String get avgVolume => 'Avg Volume';

  @override
  String get sharesOutstanding => 'Shares Outstanding';

  @override
  String get floatShares => 'Float';

  @override
  String get shortRatio => 'Short Ratio';

  @override
  String get insiderOwnership => 'Insider Own.';

  @override
  String get institutionalOwnership => 'Inst. Own.';

  @override
  String get analystConsensus => 'ANALYST CONSENSUS';

  @override
  String get strongBuy => 'Strong Buy';

  @override
  String get buy => 'Buy';

  @override
  String get hold => 'Hold';

  @override
  String get sell => 'Sell';

  @override
  String get strongSell => 'Strong Sell';

  @override
  String get analysts => 'analysts';

  @override
  String get catalysts => 'CATALYSTS';

  @override
  String get impact => 'Impact';

  @override
  String get newsRecentTitle => 'RECENT NEWS';

  @override
  String get newsMarketTitle => 'MARKET NEWS';

  @override
  String get newsNoArticles => 'No news available';

  @override
  String get newsReadMore => 'Read more';

  @override
  String get newsSentiment => 'Sentiment';

  @override
  String get chartInteractive => 'INTERACTIVE CHART';

  @override
  String get chartRange1D => '1D';

  @override
  String get chartRange5D => '5D';

  @override
  String get chartRange1M => '1M';

  @override
  String get chartRange6M => '6M';

  @override
  String get chartRangeYTD => 'YTD';

  @override
  String get chartRange1Y => '1Y';

  @override
  String get chartRange5Y => '5Y';

  @override
  String get chartRangeMax => 'MAX';

  @override
  String get portfolioTitle => 'PORTFOLIO';

  @override
  String get portfolioEmpty => 'No positions yet';

  @override
  String get portfolioEmptySub =>
      'Add stocks from the Discovery tab to start building your portfolio.';

  @override
  String get portfolioTotalValue => 'TOTAL VALUE';

  @override
  String get portfolioDailyPnl => 'DAILY P&L';

  @override
  String get portfolioTotalReturn => 'TOTAL RETURN';

  @override
  String get portfolioAllocation => 'ALLOCATION';

  @override
  String get portfolioPositions => 'POSITIONS';

  @override
  String get portfolioAddPosition => 'Add Position';

  @override
  String get watchlistTitle => 'CONVICTIONS';

  @override
  String get watchlistEmpty => 'NO CONVICTIONS YET';

  @override
  String get watchlistEmptySub =>
      'Add companies you want to follow in your investment universe.';

  @override
  String get watchlistAdd => 'Add to Convictions';

  @override
  String get watchlistRemove => 'Remove from Convictions';

  @override
  String get alertsTitle => 'ALERTS';

  @override
  String get alertsEmpty => 'No alerts set';

  @override
  String get alertsEmptySub => 'Set price alerts on any stock to get notified.';

  @override
  String get alertPrice => 'Price Alert';

  @override
  String get alertVolume => 'Volume Alert';

  @override
  String get alertRSI => 'RSI Alert';

  @override
  String get alertAbove => 'Above';

  @override
  String get alertBelow => 'Below';

  @override
  String get alertTriggered => 'Triggered';

  @override
  String get alertActive => 'Active';

  @override
  String get settingsTitle => 'EINSTELLUNGEN';

  @override
  String get settingsAppearance => 'APPEARANCE';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsLanguage => 'LANGUAGE';

  @override
  String get settingsLanguageAuto => 'Auto-detect';

  @override
  String get settingsAiEngine => 'AI ENGINE';

  @override
  String get settingsAiProvider => 'Provider';

  @override
  String get settingsAiModel => 'Model';

  @override
  String get settingsAiTest => 'Test Connection';

  @override
  String get settingsAiTestSuccess => 'Connection successful';

  @override
  String get settingsAiTestFail => 'Connection failed';

  @override
  String get settingsData => 'DATA';

  @override
  String get settingsClearCache => 'Clear Cache';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsSystem => 'SYSTEM';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsAbout => 'About SIGMA';

  @override
  String get settingsLegal => 'Legal & Disclaimers';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsTerms => 'Terms of Service';

  @override
  String get profileTitle => 'PROFILE';

  @override
  String get profileOperator => 'OPERATOR';

  @override
  String get profileAccessLevel => 'ACCESS LEVEL: STRATEGIST';

  @override
  String get profileSettings => 'App Settings';

  @override
  String get profilePremium => 'Upgrade to Premium';

  @override
  String get financialReport => 'FINANCIAL REPORT';

  @override
  String get financialReportGenerate => 'Generate Full Report';

  @override
  String get financialReportGenerating => 'Generating report...';

  @override
  String get financialReportReady => 'Report ready';

  @override
  String chatHint(String ticker) {
    return 'Ask about $ticker...';
  }

  @override
  String chatWelcome(String ticker) {
    return 'How can I help you with $ticker?';
  }

  @override
  String get actionPlan => 'ACTION PLAN';

  @override
  String get entryZone => 'Entry Zone';

  @override
  String get targetAlpha => 'Target';

  @override
  String get invalidation => 'Invalidation';

  @override
  String get riskRewardRatio => 'Risk/Reward Ratio';

  @override
  String get projection7D => '7-DAY PROJECTION';

  @override
  String get sector => 'Sector';

  @override
  String get industry => 'Industry';

  @override
  String get employees => 'Employees';

  @override
  String get headquarters => 'Headquarters';

  @override
  String get website => 'Website';

  @override
  String get phone => 'Phone';

  @override
  String get companyDescription => 'Company Description';

  @override
  String get peersAnalysis => 'PEERS ANALYSIS';

  @override
  String get dividendsHistory => 'DIVIDENDS & HISTORY';

  @override
  String get sharesEstimates => 'SHARES & ESTIMATES';

  @override
  String get supportResistance => 'SUPPORT & RESISTANCE';

  @override
  String get trends => 'TRENDS';

  @override
  String get shortTerm => 'Short Term';

  @override
  String get midTerm => 'Mid Term';

  @override
  String get longTerm => 'Long Term';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNetwork => 'No internet connection';

  @override
  String get errorTimeout => 'Request timed out';

  @override
  String get errorRetry => 'Retry';

  @override
  String get errorApiKey => 'API key missing or invalid';

  @override
  String get loading => 'Laden...';

  @override
  String get noData => 'No data available';

  @override
  String get readMore => 'Read more';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get refresh => 'Refresh';

  @override
  String get close => 'Schließen';

  @override
  String get onboardingTitle1 => 'Intelligente Analyse';

  @override
  String get onboardingDesc1 =>
      'Echtzeitdaten aus mehreren Quellen kombiniert mit KI-gestützten Erkenntnissen für intelligentere Anlageentscheidungen.';

  @override
  String get onboardingTitle2 => 'Technical Excellence';

  @override
  String get onboardingDesc2 =>
      'Professional-grade technical indicators: RSI, MACD, Bollinger Bands, and more — all calculated in real-time.';

  @override
  String get onboardingTitle3 => 'Global Intelligence';

  @override
  String get onboardingDesc3 =>
      'Track markets worldwide with institutional-grade data, sentiment analysis, and AI-enriched news.';

  @override
  String get onboardingGetStarted => 'Loslegen';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Next';

  @override
  String get disclaimer =>
      'SIGMA bietet keine Finanzberatung. Alle Daten dienen nur zu Informationszwecken. Investieren Sie auf eigenes Risiko.';
}
