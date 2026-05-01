// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class SPt extends S {
  SPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'SIGMA';

  @override
  String get appTagline => 'Análise Financeira Inteligente';

  @override
  String get navDashboard => 'Painel';

  @override
  String get navDiscover => 'Descobrir';

  @override
  String get navPortfolio => 'Portfólio';

  @override
  String get navNews => 'Notícias';

  @override
  String get navProfile => 'Perfil';

  @override
  String get dashboardTitle => 'VISÃO DO MERCADO';

  @override
  String get worldIndices => 'ÍNDICES MUNDIAIS';

  @override
  String get commodities => 'COMMODITIES';

  @override
  String get yourWatchlist => 'SUA WATCHLIST';

  @override
  String get liveData => 'DADOS AO VIVO';

  @override
  String get marketClosed => 'MARKET CLOSED';

  @override
  String get marketOpen => 'MARKET OPEN';

  @override
  String get preMarket => 'PRE-MARKET';

  @override
  String get afterHours => 'AFTER HOURS';

  @override
  String get searchHint => 'Buscar ticker, empresa...';

  @override
  String get searchNoResults => 'Nenhum resultado encontrado';

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
  String get verdictBuy => 'COMPRAR';

  @override
  String get verdictStrongBuy => 'COMPRA FORTE';

  @override
  String get verdictHold => 'MANTER';

  @override
  String get verdictSell => 'VENDER';

  @override
  String get verdictStrongSell => 'VENDA FORTE';

  @override
  String get sigmaScore => 'PONTUAÇÃO SIGMA';

  @override
  String get confidence => 'Confiança';

  @override
  String get riskLevel => 'Nível de risco';

  @override
  String get riskLow => 'Baixo';

  @override
  String get riskMedium => 'Médio';

  @override
  String get riskHigh => 'Alto';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabAnalysis => 'Analysis';

  @override
  String get tabFinancials => 'Financials';

  @override
  String get tabNews => 'News';

  @override
  String get technicalAnalysis => 'ANÁLISE TÉCNICA';

  @override
  String get fundamentalAnalysis => 'ANÁLISE FUNDAMENTAL';

  @override
  String get aiSynthesis => 'SÍNTESE IA';

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
  String get settingsTitle => 'CONFIGURAÇÕES';

  @override
  String get settingsAppearance => 'APPEARANCE';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsLanguage => 'IDIOMA';

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
  String get loading => 'Carregando...';

  @override
  String get noData => 'Sem dados disponíveis';

  @override
  String get readMore => 'Read more';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get refresh => 'Refresh';

  @override
  String get close => 'Fechar';

  @override
  String get onboardingTitle1 => 'Análise Inteligente';

  @override
  String get onboardingDesc1 =>
      'Dados em tempo real de múltiplas fontes combinados com insights de IA para decisões de investimento mais inteligentes.';

  @override
  String get onboardingTitle2 => 'Excelência Técnica';

  @override
  String get onboardingDesc2 =>
      'Indicadores técnicos de nível profissional: RSI, MACD, Bandas de Bollinger e mais — todos calculados em tempo real.';

  @override
  String get onboardingTitle3 => 'Inteligência Global';

  @override
  String get onboardingDesc3 =>
      'Acompanhe mercados mundiais com dados institucionais, análise de sentimento e notícias enriquecidas por IA.';

  @override
  String get onboardingGetStarted => 'Começar';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get onboardingNext => 'Próximo';

  @override
  String get disclaimer =>
      'SIGMA não fornece aconselhamento financeiro. Todos os dados são apenas para fins informativos. Invista por sua conta e risco.';
}
