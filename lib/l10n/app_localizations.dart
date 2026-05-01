import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('es'),
    Locale('pt'),
    Locale('de'),
    Locale('it'),
    Locale('ja'),
    Locale('zh'),
    Locale('ko'),
    Locale('ar')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SIGMA'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Institutional Investment Research'**
  String get appTagline;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get navPortfolio;

  /// No description provided for @navNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get navNews;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'MARKET OVERVIEW'**
  String get dashboardTitle;

  /// No description provided for @worldIndices.
  ///
  /// In en, this message translates to:
  /// **'WORLD INDICES'**
  String get worldIndices;

  /// No description provided for @commodities.
  ///
  /// In en, this message translates to:
  /// **'COMMODITIES'**
  String get commodities;

  /// No description provided for @yourWatchlist.
  ///
  /// In en, this message translates to:
  /// **'YOUR CONVICTIONS'**
  String get yourWatchlist;

  /// No description provided for @liveData.
  ///
  /// In en, this message translates to:
  /// **'LIVE DATA'**
  String get liveData;

  /// No description provided for @marketClosed.
  ///
  /// In en, this message translates to:
  /// **'MARKET CLOSED'**
  String get marketClosed;

  /// No description provided for @marketOpen.
  ///
  /// In en, this message translates to:
  /// **'MARKET OPEN'**
  String get marketOpen;

  /// No description provided for @preMarket.
  ///
  /// In en, this message translates to:
  /// **'PRE-MARKET'**
  String get preMarket;

  /// No description provided for @afterHours.
  ///
  /// In en, this message translates to:
  /// **'AFTER HOURS'**
  String get afterHours;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search company, ticker, or thesis...'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'RECENT SEARCHES'**
  String get searchRecent;

  /// No description provided for @searchTrending.
  ///
  /// In en, this message translates to:
  /// **'TRENDING'**
  String get searchTrending;

  /// No description provided for @analysisTitle.
  ///
  /// In en, this message translates to:
  /// **'RESEARCH'**
  String get analysisTitle;

  /// No description provided for @analysisLoading.
  ///
  /// In en, this message translates to:
  /// **'Analyzing {ticker}...'**
  String analysisLoading(String ticker);

  /// No description provided for @analysisError.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed'**
  String get analysisError;

  /// No description provided for @analysisRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get analysisRetry;

  /// No description provided for @analysisCached.
  ///
  /// In en, this message translates to:
  /// **'Cached analysis • {hours}h ago'**
  String analysisCached(int hours);

  /// No description provided for @verdictBuy.
  ///
  /// In en, this message translates to:
  /// **'BUY'**
  String get verdictBuy;

  /// No description provided for @verdictStrongBuy.
  ///
  /// In en, this message translates to:
  /// **'STRONG BUY'**
  String get verdictStrongBuy;

  /// No description provided for @verdictHold.
  ///
  /// In en, this message translates to:
  /// **'HOLD'**
  String get verdictHold;

  /// No description provided for @verdictSell.
  ///
  /// In en, this message translates to:
  /// **'SELL'**
  String get verdictSell;

  /// No description provided for @verdictStrongSell.
  ///
  /// In en, this message translates to:
  /// **'STRONG SELL'**
  String get verdictStrongSell;

  /// No description provided for @sigmaScore.
  ///
  /// In en, this message translates to:
  /// **'SIGMA SCORE'**
  String get sigmaScore;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @riskLevel.
  ///
  /// In en, this message translates to:
  /// **'Risk Level'**
  String get riskLevel;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get riskLow;

  /// No description provided for @riskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get riskMedium;

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get riskHigh;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get tabAnalysis;

  /// No description provided for @tabFinancials.
  ///
  /// In en, this message translates to:
  /// **'Financials'**
  String get tabFinancials;

  /// No description provided for @tabNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get tabNews;

  /// No description provided for @technicalAnalysis.
  ///
  /// In en, this message translates to:
  /// **'TECHNICAL ANALYSIS'**
  String get technicalAnalysis;

  /// No description provided for @fundamentalAnalysis.
  ///
  /// In en, this message translates to:
  /// **'FUNDAMENTAL ANALYSIS'**
  String get fundamentalAnalysis;

  /// No description provided for @aiSynthesis.
  ///
  /// In en, this message translates to:
  /// **'AI SYNTHESIS'**
  String get aiSynthesis;

  /// No description provided for @neuralSynthesis.
  ///
  /// In en, this message translates to:
  /// **'INSTITUTIONAL SYNTHESIS'**
  String get neuralSynthesis;

  /// No description provided for @companyProfile.
  ///
  /// In en, this message translates to:
  /// **'COMPANY PROFILE'**
  String get companyProfile;

  /// No description provided for @keyMetrics.
  ///
  /// In en, this message translates to:
  /// **'KEY METRICS'**
  String get keyMetrics;

  /// No description provided for @financialHealth.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL HEALTH'**
  String get financialHealth;

  /// No description provided for @valuation.
  ///
  /// In en, this message translates to:
  /// **'VALUATION'**
  String get valuation;

  /// No description provided for @growthMetrics.
  ///
  /// In en, this message translates to:
  /// **'GROWTH METRICS'**
  String get growthMetrics;

  /// No description provided for @profitability.
  ///
  /// In en, this message translates to:
  /// **'PROFITABILITY'**
  String get profitability;

  /// No description provided for @rsi.
  ///
  /// In en, this message translates to:
  /// **'RSI'**
  String get rsi;

  /// No description provided for @macd.
  ///
  /// In en, this message translates to:
  /// **'MACD'**
  String get macd;

  /// No description provided for @bollingerBands.
  ///
  /// In en, this message translates to:
  /// **'BOLLINGER BANDS'**
  String get bollingerBands;

  /// No description provided for @movingAverages.
  ///
  /// In en, this message translates to:
  /// **'MOVING AVERAGES'**
  String get movingAverages;

  /// No description provided for @sma.
  ///
  /// In en, this message translates to:
  /// **'SMA'**
  String get sma;

  /// No description provided for @ema.
  ///
  /// In en, this message translates to:
  /// **'EMA'**
  String get ema;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'VOLUME'**
  String get volume;

  /// No description provided for @vwap.
  ///
  /// In en, this message translates to:
  /// **'VWAP'**
  String get vwap;

  /// No description provided for @atr.
  ///
  /// In en, this message translates to:
  /// **'ATR'**
  String get atr;

  /// No description provided for @stochastic.
  ///
  /// In en, this message translates to:
  /// **'STOCHASTIC'**
  String get stochastic;

  /// No description provided for @oversold.
  ///
  /// In en, this message translates to:
  /// **'Oversold'**
  String get oversold;

  /// No description provided for @overbought.
  ///
  /// In en, this message translates to:
  /// **'Overbought'**
  String get overbought;

  /// No description provided for @bullish.
  ///
  /// In en, this message translates to:
  /// **'Bullish'**
  String get bullish;

  /// No description provided for @bearish.
  ///
  /// In en, this message translates to:
  /// **'Bearish'**
  String get bearish;

  /// No description provided for @neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get neutral;

  /// No description provided for @signal.
  ///
  /// In en, this message translates to:
  /// **'SIGNAL'**
  String get signal;

  /// No description provided for @signalBullishCross.
  ///
  /// In en, this message translates to:
  /// **'Bullish Crossover'**
  String get signalBullishCross;

  /// No description provided for @signalBearishCross.
  ///
  /// In en, this message translates to:
  /// **'Bearish Crossover'**
  String get signalBearishCross;

  /// No description provided for @trendUp.
  ///
  /// In en, this message translates to:
  /// **'Uptrend'**
  String get trendUp;

  /// No description provided for @trendDown.
  ///
  /// In en, this message translates to:
  /// **'Downtrend'**
  String get trendDown;

  /// No description provided for @trendSideways.
  ///
  /// In en, this message translates to:
  /// **'Sideways'**
  String get trendSideways;

  /// No description provided for @peRatio.
  ///
  /// In en, this message translates to:
  /// **'P/E Ratio'**
  String get peRatio;

  /// No description provided for @forwardPE.
  ///
  /// In en, this message translates to:
  /// **'Forward P/E'**
  String get forwardPE;

  /// No description provided for @pegRatio.
  ///
  /// In en, this message translates to:
  /// **'PEG Ratio'**
  String get pegRatio;

  /// No description provided for @priceToBook.
  ///
  /// In en, this message translates to:
  /// **'P/B Ratio'**
  String get priceToBook;

  /// No description provided for @priceToSales.
  ///
  /// In en, this message translates to:
  /// **'P/S Ratio'**
  String get priceToSales;

  /// No description provided for @evToEbitda.
  ///
  /// In en, this message translates to:
  /// **'EV/EBITDA'**
  String get evToEbitda;

  /// No description provided for @marketCap.
  ///
  /// In en, this message translates to:
  /// **'Market Cap'**
  String get marketCap;

  /// No description provided for @beta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get beta;

  /// No description provided for @dividendYield.
  ///
  /// In en, this message translates to:
  /// **'Dividend Yield'**
  String get dividendYield;

  /// No description provided for @debtToEquity.
  ///
  /// In en, this message translates to:
  /// **'Debt/Equity'**
  String get debtToEquity;

  /// No description provided for @currentRatio.
  ///
  /// In en, this message translates to:
  /// **'Current Ratio'**
  String get currentRatio;

  /// No description provided for @returnOnEquity.
  ///
  /// In en, this message translates to:
  /// **'ROE'**
  String get returnOnEquity;

  /// No description provided for @profitMargin.
  ///
  /// In en, this message translates to:
  /// **'Profit Margin'**
  String get profitMargin;

  /// No description provided for @revenueGrowth.
  ///
  /// In en, this message translates to:
  /// **'Revenue Growth'**
  String get revenueGrowth;

  /// No description provided for @earningsGrowth.
  ///
  /// In en, this message translates to:
  /// **'Earnings Growth'**
  String get earningsGrowth;

  /// No description provided for @freeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Free Cash Flow'**
  String get freeCashFlow;

  /// No description provided for @eps.
  ///
  /// In en, this message translates to:
  /// **'EPS'**
  String get eps;

  /// No description provided for @targetPrice.
  ///
  /// In en, this message translates to:
  /// **'Target Price'**
  String get targetPrice;

  /// No description provided for @currentPrice.
  ///
  /// In en, this message translates to:
  /// **'Current Price'**
  String get currentPrice;

  /// No description provided for @week52High.
  ///
  /// In en, this message translates to:
  /// **'52W High'**
  String get week52High;

  /// No description provided for @week52Low.
  ///
  /// In en, this message translates to:
  /// **'52W Low'**
  String get week52Low;

  /// No description provided for @avgVolume.
  ///
  /// In en, this message translates to:
  /// **'Avg Volume'**
  String get avgVolume;

  /// No description provided for @sharesOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Shares Outstanding'**
  String get sharesOutstanding;

  /// No description provided for @floatShares.
  ///
  /// In en, this message translates to:
  /// **'Float'**
  String get floatShares;

  /// No description provided for @shortRatio.
  ///
  /// In en, this message translates to:
  /// **'Short Ratio'**
  String get shortRatio;

  /// No description provided for @insiderOwnership.
  ///
  /// In en, this message translates to:
  /// **'Insider Own.'**
  String get insiderOwnership;

  /// No description provided for @institutionalOwnership.
  ///
  /// In en, this message translates to:
  /// **'Inst. Own.'**
  String get institutionalOwnership;

  /// No description provided for @analystConsensus.
  ///
  /// In en, this message translates to:
  /// **'ANALYST CONSENSUS'**
  String get analystConsensus;

  /// No description provided for @strongBuy.
  ///
  /// In en, this message translates to:
  /// **'Strong Buy'**
  String get strongBuy;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @hold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get hold;

  /// No description provided for @sell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sell;

  /// No description provided for @strongSell.
  ///
  /// In en, this message translates to:
  /// **'Strong Sell'**
  String get strongSell;

  /// No description provided for @analysts.
  ///
  /// In en, this message translates to:
  /// **'analysts'**
  String get analysts;

  /// No description provided for @catalysts.
  ///
  /// In en, this message translates to:
  /// **'CATALYSTS'**
  String get catalysts;

  /// No description provided for @impact.
  ///
  /// In en, this message translates to:
  /// **'Impact'**
  String get impact;

  /// No description provided for @newsRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'RECENT NEWS'**
  String get newsRecentTitle;

  /// No description provided for @newsMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'MARKET NEWS'**
  String get newsMarketTitle;

  /// No description provided for @newsNoArticles.
  ///
  /// In en, this message translates to:
  /// **'No news available'**
  String get newsNoArticles;

  /// No description provided for @newsReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get newsReadMore;

  /// No description provided for @newsSentiment.
  ///
  /// In en, this message translates to:
  /// **'Sentiment'**
  String get newsSentiment;

  /// No description provided for @chartInteractive.
  ///
  /// In en, this message translates to:
  /// **'INTERACTIVE CHART'**
  String get chartInteractive;

  /// No description provided for @chartRange1D.
  ///
  /// In en, this message translates to:
  /// **'1D'**
  String get chartRange1D;

  /// No description provided for @chartRange5D.
  ///
  /// In en, this message translates to:
  /// **'5D'**
  String get chartRange5D;

  /// No description provided for @chartRange1M.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get chartRange1M;

  /// No description provided for @chartRange6M.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get chartRange6M;

  /// No description provided for @chartRangeYTD.
  ///
  /// In en, this message translates to:
  /// **'YTD'**
  String get chartRangeYTD;

  /// No description provided for @chartRange1Y.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get chartRange1Y;

  /// No description provided for @chartRange5Y.
  ///
  /// In en, this message translates to:
  /// **'5Y'**
  String get chartRange5Y;

  /// No description provided for @chartRangeMax.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get chartRangeMax;

  /// No description provided for @portfolioTitle.
  ///
  /// In en, this message translates to:
  /// **'PORTFOLIO'**
  String get portfolioTitle;

  /// No description provided for @portfolioEmpty.
  ///
  /// In en, this message translates to:
  /// **'No positions yet'**
  String get portfolioEmpty;

  /// No description provided for @portfolioEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Add stocks from the Discovery tab to start building your portfolio.'**
  String get portfolioEmptySub;

  /// No description provided for @portfolioTotalValue.
  ///
  /// In en, this message translates to:
  /// **'TOTAL VALUE'**
  String get portfolioTotalValue;

  /// No description provided for @portfolioDailyPnl.
  ///
  /// In en, this message translates to:
  /// **'DAILY P&L'**
  String get portfolioDailyPnl;

  /// No description provided for @portfolioTotalReturn.
  ///
  /// In en, this message translates to:
  /// **'TOTAL RETURN'**
  String get portfolioTotalReturn;

  /// No description provided for @portfolioAllocation.
  ///
  /// In en, this message translates to:
  /// **'ALLOCATION'**
  String get portfolioAllocation;

  /// No description provided for @portfolioPositions.
  ///
  /// In en, this message translates to:
  /// **'POSITIONS'**
  String get portfolioPositions;

  /// No description provided for @portfolioAddPosition.
  ///
  /// In en, this message translates to:
  /// **'Add Position'**
  String get portfolioAddPosition;

  /// No description provided for @watchlistTitle.
  ///
  /// In en, this message translates to:
  /// **'CONVICTIONS'**
  String get watchlistTitle;

  /// No description provided for @watchlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'NO CONVICTIONS YET'**
  String get watchlistEmpty;

  /// No description provided for @watchlistEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Add companies you want to follow in your investment universe.'**
  String get watchlistEmptySub;

  /// No description provided for @watchlistAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to Convictions'**
  String get watchlistAdd;

  /// No description provided for @watchlistRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from Convictions'**
  String get watchlistRemove;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'ALERTS'**
  String get alertsTitle;

  /// No description provided for @alertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alerts set'**
  String get alertsEmpty;

  /// No description provided for @alertsEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Set price alerts on any stock to get notified.'**
  String get alertsEmptySub;

  /// No description provided for @alertPrice.
  ///
  /// In en, this message translates to:
  /// **'Price Alert'**
  String get alertPrice;

  /// No description provided for @alertVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume Alert'**
  String get alertVolume;

  /// No description provided for @alertRSI.
  ///
  /// In en, this message translates to:
  /// **'RSI Alert'**
  String get alertRSI;

  /// No description provided for @alertAbove.
  ///
  /// In en, this message translates to:
  /// **'Above'**
  String get alertAbove;

  /// No description provided for @alertBelow.
  ///
  /// In en, this message translates to:
  /// **'Below'**
  String get alertBelow;

  /// No description provided for @alertTriggered.
  ///
  /// In en, this message translates to:
  /// **'Triggered'**
  String get alertTriggered;

  /// No description provided for @alertActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get alertActive;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get settingsLanguageAuto;

  /// No description provided for @settingsAiEngine.
  ///
  /// In en, this message translates to:
  /// **'AI ENGINE'**
  String get settingsAiEngine;

  /// No description provided for @settingsAiProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsAiProvider;

  /// No description provided for @settingsAiModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsAiModel;

  /// No description provided for @settingsAiTest.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settingsAiTest;

  /// No description provided for @settingsAiTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get settingsAiTestSuccess;

  /// No description provided for @settingsAiTestFail.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get settingsAiTestFail;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'DATA'**
  String get settingsData;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get settingsClearCache;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsCacheCleared;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get settingsSystem;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About SIGMA'**
  String get settingsAbout;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal & Disclaimers'**
  String get settingsLegal;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacy;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileTitle;

  /// No description provided for @profileOperator.
  ///
  /// In en, this message translates to:
  /// **'OPERATOR'**
  String get profileOperator;

  /// No description provided for @profileAccessLevel.
  ///
  /// In en, this message translates to:
  /// **'ACCESS LEVEL: STRATEGIST'**
  String get profileAccessLevel;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get profileSettings;

  /// No description provided for @profilePremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get profilePremium;

  /// No description provided for @financialReport.
  ///
  /// In en, this message translates to:
  /// **'FINANCIAL REPORT'**
  String get financialReport;

  /// No description provided for @financialReportGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate Full Report'**
  String get financialReportGenerate;

  /// No description provided for @financialReportGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating report...'**
  String get financialReportGenerating;

  /// No description provided for @financialReportReady.
  ///
  /// In en, this message translates to:
  /// **'Report ready'**
  String get financialReportReady;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about {ticker}...'**
  String chatHint(String ticker);

  /// No description provided for @chatWelcome.
  ///
  /// In en, this message translates to:
  /// **'How can I help you with {ticker}?'**
  String chatWelcome(String ticker);

  /// No description provided for @actionPlan.
  ///
  /// In en, this message translates to:
  /// **'ACTION PLAN'**
  String get actionPlan;

  /// No description provided for @entryZone.
  ///
  /// In en, this message translates to:
  /// **'Entry Zone'**
  String get entryZone;

  /// No description provided for @targetAlpha.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get targetAlpha;

  /// No description provided for @invalidation.
  ///
  /// In en, this message translates to:
  /// **'Invalidation'**
  String get invalidation;

  /// No description provided for @riskRewardRatio.
  ///
  /// In en, this message translates to:
  /// **'Risk/Reward Ratio'**
  String get riskRewardRatio;

  /// No description provided for @projection7D.
  ///
  /// In en, this message translates to:
  /// **'7-DAY PROJECTION'**
  String get projection7D;

  /// No description provided for @sector.
  ///
  /// In en, this message translates to:
  /// **'Sector'**
  String get sector;

  /// No description provided for @industry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get industry;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employees;

  /// No description provided for @headquarters.
  ///
  /// In en, this message translates to:
  /// **'Headquarters'**
  String get headquarters;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @companyDescription.
  ///
  /// In en, this message translates to:
  /// **'Company Description'**
  String get companyDescription;

  /// No description provided for @peersAnalysis.
  ///
  /// In en, this message translates to:
  /// **'PEERS ANALYSIS'**
  String get peersAnalysis;

  /// No description provided for @dividendsHistory.
  ///
  /// In en, this message translates to:
  /// **'DIVIDENDS & HISTORY'**
  String get dividendsHistory;

  /// No description provided for @sharesEstimates.
  ///
  /// In en, this message translates to:
  /// **'SHARES & ESTIMATES'**
  String get sharesEstimates;

  /// No description provided for @supportResistance.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & RESISTANCE'**
  String get supportResistance;

  /// No description provided for @trends.
  ///
  /// In en, this message translates to:
  /// **'TRENDS'**
  String get trends;

  /// No description provided for @shortTerm.
  ///
  /// In en, this message translates to:
  /// **'Short Term'**
  String get shortTerm;

  /// No description provided for @midTerm.
  ///
  /// In en, this message translates to:
  /// **'Mid Term'**
  String get midTerm;

  /// No description provided for @longTerm.
  ///
  /// In en, this message translates to:
  /// **'Long Term'**
  String get longTerm;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get errorTimeout;

  /// No description provided for @errorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get errorRetry;

  /// No description provided for @errorApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key missing or invalid'**
  String get errorApiKey;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Smart Analysis'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Market data from multiple sources organized for disciplined investment decisions.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Technical Excellence'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Professional-grade technical indicators: RSI, MACD, Bollinger Bands, and more — all calculated in real-time.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Global Intelligence'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Track markets worldwide with institutional-grade data, sentiment analysis, and AI-enriched news.'**
  String get onboardingDesc3;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'SIGMA does not provide financial advice. All data is for informational purposes only. Invest at your own risk.'**
  String get disclaimer;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'it',
        'ja',
        'ko',
        'pt',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return SAr();
    case 'de':
      return SDe();
    case 'en':
      return SEn();
    case 'es':
      return SEs();
    case 'fr':
      return SFr();
    case 'it':
      return SIt();
    case 'ja':
      return SJa();
    case 'ko':
      return SKo();
    case 'pt':
      return SPt();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
