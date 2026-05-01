// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class SEs extends S {
  SEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'SIGMA';

  @override
  String get appTagline => 'Análisis Financiero Inteligente';

  @override
  String get navDashboard => 'Panel';

  @override
  String get navDiscover => 'Descubrir';

  @override
  String get navPortfolio => 'Portafolio';

  @override
  String get navNews => 'Noticias';

  @override
  String get navProfile => 'Perfil';

  @override
  String get dashboardTitle => 'VISIÓN DEL MERCADO';

  @override
  String get worldIndices => 'ÍNDICES MUNDIALES';

  @override
  String get commodities => 'MATERIAS PRIMAS';

  @override
  String get yourWatchlist => 'TU WATCHLIST';

  @override
  String get liveData => 'DATOS EN VIVO';

  @override
  String get marketClosed => 'MERCADO CERRADO';

  @override
  String get marketOpen => 'MERCADO ABIERTO';

  @override
  String get preMarket => 'PRE-APERTURA';

  @override
  String get afterHours => 'FUERA DE HORARIO';

  @override
  String get searchHint => 'Buscar ticker, empresa...';

  @override
  String get searchNoResults => 'Sin resultados';

  @override
  String get searchRecent => 'BÚSQUEDAS RECIENTES';

  @override
  String get searchTrending => 'TENDENCIAS';

  @override
  String get analysisTitle => 'ANÁLISIS';

  @override
  String analysisLoading(String ticker) {
    return 'Analizando $ticker...';
  }

  @override
  String get analysisError => 'El análisis falló';

  @override
  String get analysisRetry => 'Reintentar';

  @override
  String analysisCached(int hours) {
    return 'Cached analysis • ${hours}h ago';
  }

  @override
  String get verdictBuy => 'COMPRAR';

  @override
  String get verdictStrongBuy => 'COMPRA FUERTE';

  @override
  String get verdictHold => 'MANTENER';

  @override
  String get verdictSell => 'VENDER';

  @override
  String get verdictStrongSell => 'VENTA FUERTE';

  @override
  String get sigmaScore => 'PUNTUACIÓN SIGMA';

  @override
  String get confidence => 'Confianza';

  @override
  String get riskLevel => 'Nivel de riesgo';

  @override
  String get riskLow => 'Bajo';

  @override
  String get riskMedium => 'Medio';

  @override
  String get riskHigh => 'Alto';

  @override
  String get tabOverview => 'Resumen';

  @override
  String get tabAnalysis => 'Análisis';

  @override
  String get tabFinancials => 'Finanzas';

  @override
  String get tabNews => 'Noticias';

  @override
  String get technicalAnalysis => 'ANÁLISIS TÉCNICO';

  @override
  String get fundamentalAnalysis => 'ANÁLISIS FUNDAMENTAL';

  @override
  String get aiSynthesis => 'SÍNTESIS IA';

  @override
  String get neuralSynthesis => 'SÍNTESIS INSTITUCIONAL';

  @override
  String get companyProfile => 'PERFIL DE LA EMPRESA';

  @override
  String get keyMetrics => 'INDICADORES CLAVE';

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
  String get analystConsensus => 'CONSENSO DE ANALISTAS';

  @override
  String get strongBuy => 'Compra fuerte';

  @override
  String get buy => 'Comprar';

  @override
  String get hold => 'Mantener';

  @override
  String get sell => 'Vender';

  @override
  String get strongSell => 'Venta fuerte';

  @override
  String get analysts => 'analistas';

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
  String get settingsTitle => 'AJUSTES';

  @override
  String get settingsAppearance => 'APPEARANCE';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsLanguage => 'IDIOMA';

  @override
  String get settingsLanguageAuto => 'Detección automática';

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
  String get loading => 'Cargando...';

  @override
  String get noData => 'Sin datos disponibles';

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
  String get save => 'Guardar';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get refresh => 'Actualizar';

  @override
  String get close => 'Cerrar';

  @override
  String get onboardingTitle1 => 'Análisis Inteligente';

  @override
  String get onboardingDesc1 =>
      'Datos en tiempo real de múltiples fuentes combinados con análisis IA para decisiones de inversión más inteligentes.';

  @override
  String get onboardingTitle2 => 'Excelencia Técnica';

  @override
  String get onboardingDesc2 =>
      'Indicadores técnicos de nivel profesional: RSI, MACD, Bandas de Bollinger y más — todos calculados en tiempo real.';

  @override
  String get onboardingTitle3 => 'Inteligencia Global';

  @override
  String get onboardingDesc3 =>
      'Seguimiento de mercados mundiales con datos institucionales, análisis de sentimiento y noticias enriquecidas por IA.';

  @override
  String get onboardingGetStarted => 'Comenzar';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get disclaimer =>
      'SIGMA no proporciona asesoramiento financiero. Todos los datos son solo informativos. Invierta bajo su propio riesgo.';
}
