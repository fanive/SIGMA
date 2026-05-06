// ignore_for_file: avoid_print
import 'dart:developer' as dev;
import '../models/sigma_models.dart';
import 'sigma_api_service.dart';

/// SigmaMarketDataService — unified market-data wrapper (Sigma OpenAPI + optional Finnhub fallback).
/// All data comes from https://sigma-yfinance-api.onrender.com/
/// No external API keys required.
class SigmaMarketDataService {
  static const List<String> _universe = [
    'AAPL',
    'MSFT',
    'NVDA',
    'AMZN',
    'META',
    'GOOGL',
    'TSLA',
    'AMD',
    'NFLX',
    'AVGO',
    'JPM',
    'BAC',
    'XOM',
    'CVX',
    'KO',
    'DIS',
    'NKE',
    'INTC',
    'CRM',
    'PLTR',
    'SPY',
    'QQQ',
    'SOFI',
    'COIN',
    'MSTR',
    'BRK-B',
    'LLY',
    'V',
    'MA',
    'UNH',
    'HD',
    'PG',
    'COST',
    'WMT',
    'ORCL',
  ];

  static const Map<String, String> _sectorEtfs = {
    'XLK': 'Technology',
    'XLF': 'Financials',
    'XLE': 'Energy',
    'XLV': 'Health Care',
    'XLY': 'Consumer Discretionary',
    'XLP': 'Consumer Staples',
    'XLI': 'Industrials',
    'XLB': 'Materials',
    'XLU': 'Utilities',
    'XLRE': 'Real Estate',
    'XLC': 'Communication Services',
  };

  static const Map<String, List<String>> _peerByAnchor = {
    'AAPL': ['MSFT', 'GOOGL', 'AMZN', 'META', 'NVDA'],
    'MSFT': ['AAPL', 'GOOGL', 'AMZN', 'META', 'NVDA'],
    'NVDA': ['AMD', 'AVGO', 'INTC', 'TSM', 'QCOM'],
    'AMD': ['NVDA', 'INTC', 'AVGO', 'QCOM', 'MU'],
    'TSLA': ['RIVN', 'GM', 'F', 'NIO', 'LCID'],
    'META': ['GOOGL', 'SNAP', 'PINS', 'AMZN', 'NFLX'],
    'GOOGL': ['META', 'MSFT', 'AMZN', 'SNAP', 'PINS'],
    'AMZN': ['WMT', 'COST', 'TGT', 'BABA', 'SHOP'],
    'JPM': ['BAC', 'C', 'WFC', 'GS', 'MS'],
    'BAC': ['JPM', 'C', 'WFC', 'GS', 'MS'],
    'XOM': ['CVX', 'COP', 'BP', 'SHEL', 'SLB'],
    'CVX': ['XOM', 'COP', 'BP', 'SHEL', 'SLB'],
  };

  // ── quote & profile ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCompanyQuote(String ticker) =>
      SigmaApiService.getQuote(ticker);

  Future<Map<String, dynamic>> getQuoteMap(String ticker) =>
      SigmaApiService.getQuote(ticker);

  Future<Map<String, dynamic>> getCompanyProfile(String ticker) =>
      SigmaApiService.getQuote(ticker);

  Future<Map<String, dynamic>> getCompanyProfileStable(String ticker) =>
      SigmaApiService.getQuote(ticker);

  Future<Map<String, dynamic>> getDetailedProfile(String ticker) =>
      SigmaApiService.getQuote(ticker);

  Future<double> getRealTimePrice(String ticker) async {
    final q = await SigmaApiService.getQuote(ticker);
    return (q['price'] as num?)?.toDouble() ?? 0.0;
  }

  // ── multi-quote ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getQuotes(List<String> tickers) async {
    if (tickers.isEmpty) return [];
    return SigmaApiService.getMultiQuote(tickers);
  }

  Future<List<dynamic>> getFullQuotes(List<String> tickers) =>
      getQuotes(tickers);

  // ── history & charts ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHistoricalOHLCV(
      String ticker, String range) async {
    const rangeMap = <String, Map<String, String>>{
      '1D': {'range': '1d', 'interval': '5m'},
      '5D': {'range': '5d', 'interval': '15m'},
      '1W': {'range': '5d', 'interval': '1d'},
      '1MO': {'range': '1mo', 'interval': '1d'},
      '1M': {'range': '1mo', 'interval': '1d'},
      '3M': {'range': '3mo', 'interval': '1d'},
      '6M': {'range': '6mo', 'interval': '1d'},
      '6MO': {'range': '6mo', 'interval': '1d'},
      '1Y': {'range': '1y', 'interval': '1d'},
      '2Y': {'range': '2y', 'interval': '1d'},
      '5Y': {'range': '5y', 'interval': '1wk'},
      'MAX': {'range': 'max', 'interval': '1mo'},
    };
    final params = rangeMap[range.toUpperCase()] ??
        {'range': range.toLowerCase(), 'interval': '1d'};
    return SigmaApiService.getHistory(
        ticker, params['range']!, params['interval']!);
  }

  Future<List<Map<String, dynamic>>> getIntradayOHLCV(
    String ticker, {
    String range = '1d',
    String interval = '5m',
    bool prepost = true,
  }) {
    return SigmaApiService.getIntraday(
      ticker,
      range,
      interval,
      prepost: prepost,
    );
  }

  Future<Map<String, dynamic>> getOptionsChain(
    String ticker, {
    String? expiration,
  }) {
    return SigmaApiService.getOptions(
      ticker,
      expiration: expiration,
    );
  }

  // ── macro ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMacroData() => SigmaApiService.getMacro();

  Future<Map<String, dynamic>> getEvents(String ticker) =>
      SigmaApiService.getEvents(ticker);

  Future<Map<String, dynamic>> getSecFacts(String ticker) =>
      SigmaApiService.getSec(ticker);

  Future<Map<String, dynamic>> getYFinanceCoverage(String ticker) =>
      SigmaApiService.getYFinanceCoverage(ticker);

  // ── financials ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getIncomeStatement(String ticker,
      {int limit = 5}) async {
    final data = await SigmaApiService.getFinancials(ticker);
    final q = (data['quarterlyIncomeStatement'] as List?) ??
        (data['quarterly']?['income_statement'] as List?) ??
        [];
    final a = (data['annualIncomeStatement'] as List?) ??
        (data['annual']?['income_statement'] as List?) ??
        [];
    return [...q, ...a].take(limit).toList();
  }

  Future<List<dynamic>> getBalanceSheet(String ticker, {int limit = 5}) async {
    final data = await SigmaApiService.getFinancials(ticker);
    final q = (data['quarterlyBalanceSheet'] as List?) ??
        (data['quarterly']?['balance_sheet'] as List?) ??
        [];
    final a = (data['annualBalanceSheet'] as List?) ??
        (data['annual']?['balance_sheet'] as List?) ??
        [];
    return [...q, ...a].take(limit).toList();
  }

  Future<List<dynamic>> getCashFlowStatement(String ticker,
      {int limit = 5}) async {
    final data = await SigmaApiService.getFinancials(ticker);
    final q = (data['quarterlyCashFlow'] as List?) ??
        (data['quarterly']?['cash_flow'] as List?) ??
        [];
    final a = (data['annualCashFlow'] as List?) ??
        (data['annual']?['cash_flow'] as List?) ??
        [];
    return [...q, ...a].take(limit).toList();
  }

  // ── analysis / metrics ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getKeyMetricsTTM(String ticker) async {
    final results = await Future.wait([
      SigmaApiService.getQuote(ticker),
      SigmaApiService.getSec(ticker),
      SigmaApiService.getFinancials(ticker),
    ]);
    final q = results[0];
    final sec = results[1];
    final financials = results[2];
    final derived = (sec['derived'] as Map?)?.cast<String, dynamic>() ?? {};
    final latest =
        (derived['latest_values'] as Map?)?.cast<String, dynamic>() ?? {};
    final annualCash = (financials['annualCashFlow'] as List?) ?? [];
    final annualBalance = (financials['annualBalanceSheet'] as List?) ?? [];
    final lastCash = annualCash.isNotEmpty && annualCash.first is Map
        ? Map<String, dynamic>.from(annualCash.first as Map)
        : <String, dynamic>{};
    final lastBalance = annualBalance.isNotEmpty && annualBalance.first is Map
        ? Map<String, dynamic>.from(annualBalance.first as Map)
        : <String, dynamic>{};
    final marketCap = AnalysisData.parseNum(q['marketCap']);
    final revenue = AnalysisData.parseNum(latest['revenue']);
    final equity = AnalysisData.parseNum(latest['stockholders_equity']);
    final assets = AnalysisData.parseNum(latest['total_assets']);
    final netIncome = AnalysisData.parseNum(latest['net_income']);
    return {
      'peRatioTTM': q['pe'],
      'marketCap': marketCap,
      'trailingPE': q['pe'],
      'beta': q['beta'],
      'dividendYield': q['dividendYield'],
      'trailingEps': q['eps'],
      'fiftyTwoWeekHigh': q['fiftyTwoWeekHigh'],
      'fiftyTwoWeekLow': q['fiftyTwoWeekLow'],
      'revenue': revenue,
      'revenueGrowth': AnalysisData.parseNum(
            derived['revenue_yoy_growth_pct'],
          ) /
          100,
      'profitMargins': AnalysisData.parseNum(derived['net_margin_pct']) / 100,
      'operatingMargins':
          AnalysisData.parseNum(derived['operating_margin_pct']) / 100,
      'grossMargins': AnalysisData.parseNum(derived['gross_margin_pct']) / 100,
      'roeTTM': equity > 0 ? netIncome / equity : 0,
      'roaTTM': assets > 0 ? netIncome / assets : 0,
      'returnOnEquity': equity > 0 ? netIncome / equity : 0,
      'returnOnAssets': assets > 0 ? netIncome / assets : 0,
      'priceToSales': revenue > 0 && marketCap > 0 ? marketCap / revenue : 0,
      'priceToBook': equity > 0 && marketCap > 0 ? marketCap / equity : 0,
      'debtToEquityTTM': derived['debt_to_equity'],
      'debtToEquity': derived['debt_to_equity'],
      'freeCashflow': lastCash['Free Cash Flow'],
      'operatingCashflow': lastCash['Operating Cash Flow'],
      'totalDebt': lastBalance['Total Debt'],
      'totalCash': lastBalance['Cash And Cash Equivalents'],
      ...q,
    };
  }

  Future<Map<String, dynamic>> getRatiosTTM(String ticker) async {
    final q = await SigmaApiService.getQuote(ticker);
    final sec = await SigmaApiService.getSec(ticker);
    final derived = (sec['derived'] as Map?)?.cast<String, dynamic>() ?? {};
    return {
      'grossProfitMarginTTM':
          AnalysisData.parseNum(derived['gross_margin_pct']) / 100,
      'netProfitMarginTTM':
          AnalysisData.parseNum(derived['net_margin_pct']) / 100,
      'operatingProfitMarginTTM':
          AnalysisData.parseNum(derived['operating_margin_pct']) / 100,
      'returnOnEquityTTM': q['returnOnEquity'],
      'debtToEquityTTM': derived['debt_to_equity'],
      ...q,
    };
  }

  Future<List<dynamic>> getAnalystEstimates(String ticker) async {
    final a = await SigmaApiService.getAnalysis(ticker);
    final out = <Map<String, dynamic>>[];

    void appendList(String key, String type) {
      final list = a[key] as List?;
      if (list == null) return;
      for (final item in list) {
        if (item is Map) {
          out.add({'type': type, ...Map<String, dynamic>.from(item)});
        }
      }
    }

    appendList('earningsEstimate', 'earningsEstimate');
    appendList('revenueEstimate', 'revenueEstimate');
    appendList('epsTrend', 'epsTrend');
    appendList('growthEstimates', 'growthEstimates');

    if (out.isNotEmpty) return out;
    return (a['estimates'] as List?) ?? [];
  }

  Future<List<dynamic>> getPriceTargets(String ticker) async {
    final a = await SigmaApiService.getAnalysis(ticker);
    final target = a['analystPriceTargets'] ?? a['target'];
    if (target is Map) return [target];
    return [];
  }

  // ── ownership ─────────────────────────────────────────────────────────────

  Future<List<dynamic>> getInstitutionalHolders(String ticker) async {
    final data = await SigmaApiService.getOwnership(ticker);
    final raw = (data['institutionalHolders'] as List?) ??
        (data['institutional'] as List?) ??
        [];
    return raw.map((h) {
      if (h is! Map) return h;
      final m = Map<String, dynamic>.from(h);
      return {
        ...m,
        'holder': m['holder'] ?? m['Holder'],
        'shares': m['shares'] ?? m['Shares'],
        'totalValue': m['totalValue'] ?? m['Value'],
        'marketValue': m['marketValue'] ?? m['Value'],
        'position': m['position'] ?? m['Shares'],
        'pctHeld': m['pctHeld'],
        'sharesByPercentage': m['sharesByPercentage'] ?? m['pctHeld'],
        'dateReported': m['dateReported'] ?? m['Date Reported'],
      };
    }).toList();
  }

  /// Returns a bundle from /ownership with all three arrays normalized:
  /// - 'institutions' → ready for HoldersData.fromJson (MajorHolder)
  /// - 'funds'        → ready for HoldersData.fromJson (MajorHolder)
  /// - 'insiderTransactions' → normalized for InsiderTransaction.fromJson
  /// - 'institutionsList'    → legacy list for prompt context (same as getInstitutionalHolders)
  Future<Map<String, dynamic>> getHoldersBundle(String ticker) async {
    final data = await SigmaApiService.getOwnership(ticker);

    List<Map<String, dynamic>> _normalizeHolders(String key) {
      final raw = (data[key] as List?) ?? [];
      return raw.map((h) {
        if (h is! Map) return <String, dynamic>{};
        final m = Map<String, dynamic>.from(h);
        return <String, dynamic>{
          'organization': m['Holder'] ?? m['holder'] ?? 'N/A',
          'pctHeld': m['pctHeld'] ?? 0.0,
          'position': (m['Shares'] ?? m['shares'] ?? 0).toDouble(),
          'value': (m['Value'] ?? m['value'] ?? 0).toDouble(),
          'reportDate': m['Date Reported']?.toString() ??
              m['dateReported']?.toString() ??
              '',
        };
      }).toList();
    }

    final rawInsiders = (data['insiderTransactions'] as List?) ?? [];
    final insiders = rawInsiders.map((t) {
      if (t is! Map) return <String, dynamic>{};
      final m = Map<String, dynamic>.from(t);
      final shares = m['Shares'] ?? m['shares'] ?? 0;
      final value = m['Value'] ?? m['value'] ?? 0;
      final text = m['Text']?.toString() ?? '';
      // Extract price from "Sale at price X.XX per share." or Value/Shares
      double price = 0;
      final priceMatch = RegExp(r'at price ([\d.]+)').firstMatch(text);
      if (priceMatch != null) {
        price = double.tryParse(priceMatch.group(1) ?? '0') ?? 0;
      } else if ((shares is num) && (value is num) && shares > 0 && value > 0) {
        price = value / shares;
      }
      return <String, dynamic>{
        'name': m['Insider'] ?? m['insider'] ?? 'N/A',
        'share': shares.toString(),
        'change': shares.toString(),
        'filingDate':
            m['Start Date']?.toString() ?? m['startDate']?.toString() ?? '',
        'transactionDate':
            m['Start Date']?.toString() ?? m['startDate']?.toString() ?? '',
        'transactionPrice': price.toStringAsFixed(2),
        // Extra fields for enrichedContext in prompt
        'position': m['Position'] ?? m['position'] ?? '',
        'text': text,
        'ownership': m['Ownership'] ?? m['ownership'] ?? '',
      };
    }).toList();

    // Legacy list format for prompt context
    final institutionsList =
        (data['institutionalHolders'] as List? ?? []).map((h) {
      if (h is! Map) return h;
      final m = Map<String, dynamic>.from(h);
      return {
        ...m,
        'holder': m['holder'] ?? m['Holder'],
        'shares': m['shares'] ?? m['Shares'],
        'totalValue': m['totalValue'] ?? m['Value'],
        'marketValue': m['marketValue'] ?? m['Value'],
        'position': m['position'] ?? m['Shares'],
        'pctHeld': m['pctHeld'],
        'sharesByPercentage': m['sharesByPercentage'] ?? m['pctHeld'],
        'dateReported': m['dateReported'] ?? m['Date Reported'],
      };
    }).toList();

    return {
      'institutions': _normalizeHolders('institutionalHolders'),
      'funds': _normalizeHolders('mutualFundHolders'),
      'insiderTransactions': insiders,
      'institutionsList': institutionsList,
      'majorHolders': data['majorHolders'] ?? [],
      'insiderPurchases': data['insiderPurchases'] ?? [],
      'sustainability': data['sustainability'] ?? [],
      'sharesOutstandingHistory': data['sharesOutstandingHistory'] ?? [],
      'isin': data['isin'],
      'fundsData': data['fundsData'] ?? <String, dynamic>{},
    };
  }

  Future<List<dynamic>> getInsiderTrading(String ticker) async {
    final data = await SigmaApiService.getInsider(ticker);
    final trades = (data['trades'] as List?) ?? [];
    return trades.map((t) {
      if (t is! Map) return t;
      final m = Map<String, dynamic>.from(t);
      return {
        ...m,
        'ownerName': m['ownerName'] ?? m['reportingName'] ?? m['insider_name'],
        'reportingName': m['reportingName'] ?? m['insider_name'],
        'filingDate': m['filingDate'] ?? m['filing_date'],
        'typeOfOwner': m['typeOfOwner'] ?? m['title'],
        'transactionType': m['transactionType'] ?? m['transaction_type'],
        'transactionPrice': m['transactionPrice'] ?? m['price'],
        'securitiesTransacted': m['securitiesTransacted'] ??
            (m['qty'] is num ? (m['qty'] as num).abs() : 0),
        'transactionDate': m['transactionDate'] ?? m['trade_date'],
      };
    }).toList();
  }

  /// Returns the full /insider response including summary (sentiment, buy/sell counts, net value)
  /// and normalized trades list. Use this instead of getInsiderTrading() when you need the summary.
  Future<Map<String, dynamic>> getInsiderFull(String ticker) async {
    final data = await SigmaApiService.getInsider(ticker);
    final trades = (data['trades'] as List?) ?? [];
    final normalized = trades.map((t) {
      if (t is! Map) return t;
      final m = Map<String, dynamic>.from(t);
      return {
        ...m,
        'ownerName': m['ownerName'] ?? m['reportingName'] ?? m['insider_name'],
        'reportingName': m['reportingName'] ?? m['insider_name'],
        'filingDate': m['filingDate'] ?? m['filing_date'],
        'typeOfOwner': m['typeOfOwner'] ?? m['title'],
        'transactionType': m['transactionType'] ?? m['transaction_type'],
        'transactionPrice': m['transactionPrice'] ?? m['price'],
        'securitiesTransacted': m['securitiesTransacted'] ??
            (m['qty'] is num ? (m['qty'] as num).abs() : 0),
        'transactionDate': m['transactionDate'] ?? m['trade_date'],
      };
    }).toList();
    return {
      'trades': normalized,
      'summary': (data['summary'] as Map?)?.cast<String, dynamic>() ?? {},
      'count': data['count'] ?? normalized.length,
      'days': data['days'] ?? 90,
    };
  }

  Future<List<dynamic>> getBulkInsiderTrading({
    int limit = 100,
    List<String>? symbols,
  }) async {
    final scan = <String>{
      ...(symbols ?? const <String>[])
          .map((s) => s.toUpperCase().trim())
          .where((s) => s.isNotEmpty),
      ..._universe.take(18),
    }.where((s) => !s.contains('SPY') && !s.contains('QQQ')).take(24).toList();

    final results = await Future.wait(
      scan.map((symbol) async {
        final data = await SigmaApiService.getInsider(symbol);
        final trades = (data['trades'] as List?) ?? [];
        return trades.map((trade) {
          final m = trade is Map
              ? Map<String, dynamic>.from(trade)
              : <String, dynamic>{};
          final shares = AnalysisData.parseNum(
            m['shares'] ?? m['securitiesTransacted'] ?? m['qty'],
          ).abs();
          final price = AnalysisData.parseNum(
            m['price'] ?? m['transactionPrice'] ?? m['pricePerShare'],
          );
          return {
            ...m,
            'symbol': m['symbol'] ?? symbol,
            'ticker': m['ticker'] ?? symbol,
            'name': m['name'] ??
                m['reportingName'] ??
                m['insider_name'] ??
                'Insider',
            'title': m['title'] ?? m['typeOfOwner'] ?? '',
            'shares': shares,
            'price': price,
            'pricePerShare': price,
            'value': AnalysisData.parseNum(m['value']) > 0
                ? AnalysisData.parseNum(m['value'])
                : shares * price,
            'date': m['date'] ??
                m['transactionDate'] ??
                m['trade_date'] ??
                m['filingDate'],
            'transactionType':
                m['transactionType'] ?? m['transaction_type'] ?? m['type'],
          };
        }).toList();
      }),
    );

    final flat = results.expand((x) => x).where((row) {
      final value = AnalysisData.parseNum(row['value']);
      final symbol = row['symbol']?.toString() ?? '';
      return symbol.isNotEmpty && value > 0;
    }).toList();

    flat.sort((a, b) {
      final byDate =
          (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? '');
      if (byDate != 0) return byDate;
      return AnalysisData.parseNum(b['value'])
          .compareTo(AnalysisData.parseNum(a['value']));
    });
    return flat.take(limit).toList();
  }

  // ── news ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getStockNews(String symbol, {int limit = 25}) async {
    final list = await SigmaApiService.getNews(symbol);
    return list.take(limit).map((n) {
      final m = Map<String, dynamic>.from(n);
      return {
        ...m,
        // Legacy compatibility fields still used across SigmaService/UI.
        'site': m['site'] ?? m['publisher'] ?? 'yfinance',
        'url': m['url'] ?? m['link'] ?? '',
        'publishedDate': m['publishedDate'] ?? m['publishedAt'] ?? '',
        'text': m['text'] ?? m['summary'] ?? m['title'] ?? '',
        'image': m['image'] ?? m['thumbnail'],
      };
    }).toList();
  }

  Future<List<dynamic>> getGeneralNews({int limit = 50}) async {
    // Try aggregated market news endpoint first (SPY+QQQ+DIA)
    List<Map<String, dynamic>> list =
        await SigmaApiService.getMarketNews(limit: limit);

    // Fallback to single-ticker news if aggregated endpoint returns empty
    if (list.isEmpty) {
      list = await SigmaApiService.getNews('SPY');
    }

    return list.take(limit).map((n) {
      final m = Map<String, dynamic>.from(n);
      return {
        ...m,
        'site': m['site'] ?? m['source'] ?? m['publisher'] ?? 'SIGMA',
        'url': m['url'] ?? m['link'] ?? '',
        'publishedDate': m['publishedDate'] ?? m['publishedAt'] ?? '',
        'text': m['text'] ?? m['summary'] ?? m['title'] ?? '',
        'image': m['image'] ?? m['thumbnail'],
      };
    }).toList();
  }

  Future<List<dynamic>> getMarketArticles(String ticker) =>
      getStockNews(ticker);

  // ── events / dividends / calendar ─────────────────────────────────────────

  Future<List<dynamic>> getDividends(String ticker) async {
    final data = await SigmaApiService.getEvents(ticker);
    return (data['dividends'] as List?) ?? [];
  }

  Future<List<dynamic>> getDividendsStable(String ticker) =>
      getDividends(ticker);

  Future<List<dynamic>> getEarningsHistorical(String ticker) async {
    final analysis = await SigmaApiService.getAnalysis(ticker);
    final hist = (analysis['earningsHistory'] as List?) ?? [];
    return hist.map((e) {
      if (e is! Map) return e;
      final m = Map<String, dynamic>.from(e);
      return {
        ...m,
        'date': m['date'] ?? m['quarter'],
        'actualEps': m['actualEps'] ?? m['epsActual'],
        'estimatedEps': m['estimatedEps'] ?? m['epsEstimate'],
        'epsEstimated': m['epsEstimated'] ?? m['epsEstimate'],
      };
    }).toList();
  }

  Future<List<dynamic>> getEconomicCalendar({List<String>? symbols}) async {
    final watch = <String>{
      ...(symbols ?? const <String>[])
          .map((s) => s.toUpperCase().trim())
          .where((s) => s.isNotEmpty),
      'AAPL',
      'MSFT',
      'NVDA',
      'AMZN',
      'META',
      'TSLA',
      'JPM',
      'XOM',
    }.take(12).toList();
    final out = <Map<String, dynamic>>[];

    final eventResults = await Future.wait(watch.map((t) async {
      final events = await SigmaApiService.getEvents(t);
      final cal = (events['calendar'] as Map?)?.cast<String, dynamic>() ?? {};
      final earnings = cal['Earnings Date'];
      final earningsDate = earnings is List && earnings.isNotEmpty
          ? earnings.first?.toString()
          : cal['Earnings Date']?.toString();
      if (earningsDate != null && earningsDate.isNotEmpty) {
        return {
          'date': earningsDate,
          'event': '$t Earnings release',
          'impact': 'HIGH',
          'country': 'US',
          'actual': null,
          'estimate': cal['Earnings Average']?.toString(),
          'previous': cal['Earnings Low']?.toString(),
        };
      }
      return <String, dynamic>{};
    }));

    out.addAll(eventResults.where((e) => e.isNotEmpty));
    out.addAll([
      {
        'date': 'Next release',
        'event': 'US CPI / inflation watch',
        'impact': 'HIGH',
        'country': 'US',
        'actual': null,
        'estimate': 'Monitor FRED CPIAUCSL',
        'previous': null,
      },
      {
        'date': 'Next FOMC window',
        'event': 'Federal Reserve policy rate',
        'impact': 'HIGH',
        'country': 'US',
        'actual': null,
        'estimate': 'Monitor FEDFUNDS',
        'previous': null,
      },
      {
        'date': 'Monthly',
        'event': 'US unemployment rate',
        'impact': 'MEDIUM',
        'country': 'US',
        'actual': null,
        'estimate': 'Monitor UNRATE',
        'previous': null,
      },
    ]);
    out.sort((a, b) =>
        (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''));
    return out;
  }

  Future<List<dynamic>> getIposCalendar() async => [];
  Future<List<dynamic>> getEconomicIndicators(String name) async => [];
  Future<List<dynamic>> getMergersAndAcquisitions() async => [];

  // ── sector / industry performance ─────────────────────────────────────────

  Future<List<dynamic>> getSectorPerformance() async {
    final quotes =
        await SigmaApiService.getMultiQuote(_sectorEtfs.keys.toList());
    return quotes.map((q) {
      final symbol = q['symbol']?.toString() ?? '';
      final change = q['changesPercentage'] ?? q['changePercent'] ?? 0;
      return {
        'sector': _sectorEtfs[symbol] ?? symbol,
        'changesPercentage': change,
        'symbol': symbol,
        'price': q['price'],
      };
    }).toList();
  }

  Future<List<dynamic>> getIndustryPerformance() async {
    final sectors = await getSectorPerformance();
    return sectors
        .map((s) => {
              'industry': '${s['sector']} (proxy)',
              'changesPercentage': s['changesPercentage'],
              'symbol': s['symbol'],
            })
        .toList();
  }

  // ── market movers ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getMostActive() async {
    final quotes = await SigmaApiService.getMultiQuote(_universe);
    quotes.sort((a, b) => AnalysisData.parseNum(b['volume'])
        .compareTo(AnalysisData.parseNum(a['volume'])));
    return quotes;
  }

  Future<List<dynamic>> getGainers() async {
    final quotes = await SigmaApiService.getMultiQuote(_universe);
    quotes.sort((a, b) => AnalysisData.parseNum(b['changesPercentage'])
        .compareTo(AnalysisData.parseNum(a['changesPercentage'])));
    return quotes
        .where((q) => AnalysisData.parseNum(q['changesPercentage']) > 0)
        .toList();
  }

  Future<List<dynamic>> getLosers() async {
    final quotes = await SigmaApiService.getMultiQuote(_universe);
    quotes.sort((a, b) => AnalysisData.parseNum(a['changesPercentage'])
        .compareTo(AnalysisData.parseNum(b['changesPercentage'])));
    return quotes
        .where((q) => AnalysisData.parseNum(q['changesPercentage']) < 0)
        .toList();
  }

  Future<List<dynamic>> getMarketMovers() async => getGainers();

  // ── peers / screener ──────────────────────────────────────────────────────

  Future<List<String>> getPeers(String ticker) async {
    final sym = ticker.toUpperCase();
    final direct = _peerByAnchor[sym];
    if (direct != null) return direct;
    return _universe.where((s) => s != sym).take(5).toList();
  }

  Future<List<dynamic>> screenStocks({
    String? sector,
    double? minMarketCap,
    int limit = 20,
  }) async {
    final quotes = await SigmaApiService.getMultiQuote(_universe);
    final filtered = <Map<String, dynamic>>[];

    for (final q in quotes) {
      final symbol = q['symbol']?.toString() ?? '';
      if (symbol.isEmpty) continue;
      if (sector != null && sector.isNotEmpty) {
        final profile = await SigmaApiService.getQuote(symbol);
        final qSector = profile['sector']?.toString().toLowerCase() ?? '';
        if (!qSector.contains(sector.toLowerCase())) continue;
      }
      if (minMarketCap != null) {
        final profile = await SigmaApiService.getQuote(symbol);
        final cap = (profile['marketCap'] as num?)?.toDouble() ?? 0;
        if (cap < minMarketCap) continue;
      }
      filtered.add(Map<String, dynamic>.from(q));
      if (filtered.length >= limit) break;
    }

    return filtered;
  }

  Future<List<Map<String, dynamic>>> screenAnalystRatings({
    List<String>? symbols,
    int limit = 20,
  }) async {
    final scan = _screenSymbols(symbols, limit: limit);
    final quotes = await SigmaApiService.getMultiQuote(scan);
    final quoteBySymbol = {
      for (final quote in quotes)
        (quote['symbol']?.toString().toUpperCase() ?? ''): quote,
    };

    final rows = await Future.wait(scan.map((symbol) async {
      try {
        final analysis = await SigmaApiService.getAnalysis(symbol);
        final quote =
            quoteBySymbol[symbol] ?? await SigmaApiService.getQuote(symbol);
        final price = AnalysisData.parseNum(
            quote['price'] ?? quote['regularMarketPrice']);
        final targets =
            _asMap(analysis['analystPriceTargets'] ?? analysis['target']);
        final targetMean = _firstNum([
          targets['mean'],
          targets['targetMeanPrice'],
          targets['targetMean'],
          analysis['targetMeanPrice'],
        ]);
        final targetHigh = _firstNum([
          targets['high'],
          targets['targetHighPrice'],
          analysis['targetHighPrice'],
        ]);
        final targetLow = _firstNum([
          targets['low'],
          targets['targetLowPrice'],
          analysis['targetLowPrice'],
        ]);
        final recommendationMean = _firstNum([
          analysis['recommendationMean'],
          analysis['recommendationScore'],
          targets['recommendationMean'],
        ]);
        final upsidePct = price > 0 && targetMean > 0
            ? ((targetMean - price) / price) * 100
            : 0.0;
        final latest = _latestAnalystEvent(analysis);
        final ratingScore = recommendationMean > 0
            ? (6 - recommendationMean).clamp(0, 5) * 14
            : 35.0;
        final score = (ratingScore + upsidePct.clamp(-30, 80)).clamp(0, 100);
        return <String, dynamic>{
          'symbol': symbol,
          'name': quote['shortName'] ??
              quote['longName'] ??
              quote['companyName'] ??
              symbol,
          'price': price,
          'changePercent': AnalysisData.parseNum(
            quote['changesPercentage'] ?? quote['changePercent'],
          ),
          'marketCap': AnalysisData.parseNum(quote['marketCap']),
          'recommendation':
              analysis['recommendationKey'] ?? latest['rating'] ?? '',
          'recommendationMean': recommendationMean,
          'analystCount': _firstNum([
            targets['numberOfAnalystOpinions'],
            targets['numberOfAnalysts'],
            analysis['numberOfAnalystOpinions'],
          ]),
          'targetMeanPrice': targetMean,
          'targetHighPrice': targetHigh,
          'targetLowPrice': targetLow,
          'targetUpsidePct': upsidePct,
          'latestFirm': latest['firm'] ?? '',
          'latestAction': latest['action'] ?? '',
          'latestRating': latest['rating'] ?? '',
          'latestDate': latest['date'] ?? '',
          'score': score,
        };
      } catch (error) {
        dev.log('Analyst screener failed for $symbol: $error',
            name: 'SigmaMarketDataService');
        return null;
      }
    }));

    final filtered = rows.whereType<Map<String, dynamic>>().toList();
    filtered.sort((left, right) => AnalysisData.parseNum(right['score'])
        .compareTo(AnalysisData.parseNum(left['score'])));
    return filtered.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> screenSmartMoney({
    List<String>? symbols,
    int limit = 20,
  }) async {
    final scan = _screenSymbols(symbols, limit: limit);
    final rows = await Future.wait(scan.map((symbol) async {
      try {
        final results = await Future.wait([
          SigmaApiService.getQuote(symbol),
          SigmaApiService.getOwnership(symbol),
          SigmaApiService.getInsider(symbol),
        ]);
        final quote = results[0];
        final ownership = results[1];
        final insider = results[2];
        final institutions = _asList(ownership['institutionalHolders']);
        final funds = _asList(ownership['mutualFundHolders']);
        final topHolder = institutions.isNotEmpty
            ? _asMap(institutions.first)
            : <String, dynamic>{};
        final insiderSummary = _asMap(insider['summary']);
        final insiderPurchases = _asList(ownership['insiderPurchases']);
        final buyCount = _firstNum([
          insiderSummary['buy_count'],
          insiderSummary['buyCount'],
          _countRowsContaining(insiderPurchases, ['purchase', 'buy']),
        ]);
        final sellCount = _firstNum([
          insiderSummary['sell_count'],
          insiderSummary['sellCount'],
          _countRowsContaining(_asList(insider['trades']), ['sale', 'sell']),
        ]);
        final buyRatio =
            buyCount + sellCount > 0 ? buyCount / (buyCount + sellCount) : 0.5;
        final institutionalValue = institutions.fold<double>(0, (sum, row) {
          final holder = _asMap(row);
          return sum +
              AnalysisData.parseNum(
                  holder['Value'] ?? holder['value'] ?? holder['marketValue']);
        });
        final holderPct = _firstNum([
          topHolder['pctHeld'],
          topHolder['sharesPercentage'],
          topHolder['% Out'],
        ]);
        final score = (buyRatio * 45 +
                institutions.length.clamp(0, 20) * 1.5 +
                funds.length.clamp(0, 20) +
                holderPct.clamp(0, 20))
            .clamp(0, 100);
        return <String, dynamic>{
          'symbol': symbol,
          'name': quote['shortName'] ??
              quote['longName'] ??
              quote['companyName'] ??
              symbol,
          'price': AnalysisData.parseNum(
              quote['price'] ?? quote['regularMarketPrice']),
          'changePercent': AnalysisData.parseNum(
            quote['changesPercentage'] ?? quote['changePercent'],
          ),
          'topHolder': topHolder['Holder'] ??
              topHolder['holder'] ??
              topHolder['organization'] ??
              '',
          'topHolderPct': holderPct,
          'institutionalHoldersCount': institutions.length,
          'fundHoldersCount': funds.length,
          'institutionalMarketValue': institutionalValue,
          'insiderBuyCount': buyCount,
          'insiderSellCount': sellCount,
          'insiderBuyRatio': buyRatio,
          'insiderNetValue': _firstNum([
            insiderSummary['net_value'],
            insiderSummary['netValue'],
            insiderSummary['net_insider_value'],
          ]),
          'score': score,
        };
      } catch (error) {
        dev.log('Smart money screener failed for $symbol: $error',
            name: 'SigmaMarketDataService');
        return null;
      }
    }));

    final filtered = rows.whereType<Map<String, dynamic>>().toList();
    filtered.sort((left, right) => AnalysisData.parseNum(right['score'])
        .compareTo(AnalysisData.parseNum(left['score'])));
    return filtered.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> screenTopHoldings({
    List<String>? symbols,
    int limit = 25,
  }) async {
    final scan = _screenSymbols(symbols, limit: limit);
    final rows = <Map<String, dynamic>>[];
    for (final symbol in scan) {
      try {
        final ownership = await SigmaApiService.getOwnership(symbol);
        for (final source in ['institutionalHolders', 'mutualFundHolders']) {
          for (final row in _asList(ownership[source])) {
            final holder = _asMap(row);
            final name = _textOf(
                holder['Holder'] ?? holder['holder'] ?? holder['organization']);
            if (name.isEmpty) continue;
            rows.add({
              'symbol': symbol,
              'holder': name,
              'source': source == 'mutualFundHolders' ? 'fund' : 'institution',
              'shares': _firstNum(
                  [holder['Shares'], holder['shares'], holder['position']]),
              'value': _firstNum(
                  [holder['Value'], holder['value'], holder['marketValue']]),
              'pctHeld': _firstNum([
                holder['pctHeld'],
                holder['sharesPercentage'],
                holder['% Out']
              ]),
              'dateReported': holder['Date Reported'] ??
                  holder['dateReported'] ??
                  holder['reportDate'] ??
                  '',
            });
          }
        }
      } catch (error) {
        dev.log('Top holdings screener failed for $symbol: $error',
            name: 'SigmaMarketDataService');
      }
    }
    rows.sort((left, right) {
      final byValue = AnalysisData.parseNum(right['value'])
          .compareTo(AnalysisData.parseNum(left['value']));
      if (byValue != 0) return byValue;
      return AnalysisData.parseNum(right['pctHeld'])
          .compareTo(AnalysisData.parseNum(left['pctHeld']));
    });
    return rows.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getResearchStockPicks({
    List<String>? symbols,
    int limit = 12,
  }) async {
    final scan = _screenSymbols(symbols, limit: limit + 8);
    final analystRows =
        await screenAnalystRatings(symbols: scan, limit: scan.length);
    final smartRows = await screenSmartMoney(symbols: scan, limit: scan.length);
    final smartBySymbol = {
      for (final row in smartRows) row['symbol']?.toString(): row
    };
    final picks = analystRows
        .map((analyst) {
          final symbol = analyst['symbol']?.toString() ?? '';
          final smart = smartBySymbol[symbol] ?? <String, dynamic>{};
          final analystScore = AnalysisData.parseNum(analyst['score']);
          final smartScore = AnalysisData.parseNum(smart['score']);
          final upsidePct = AnalysisData.parseNum(analyst['targetUpsidePct']);
          final score = (analystScore * 0.55 +
                  smartScore * 0.30 +
                  upsidePct.clamp(0, 45) * 0.15)
              .clamp(0, 100);
          return <String, dynamic>{
            ...analyst,
            'smartMoneyScore': smartScore,
            'topHolder': smart['topHolder'] ?? '',
            'insiderBuyRatio': smart['insiderBuyRatio'] ?? 0.5,
            'convictionScore': score,
            'pickType': score >= 75
                ? 'high conviction'
                : score >= 60
                    ? 'watch closely'
                    : 'research candidate',
          };
        })
        .where((row) => _textOf(row['symbol']).isNotEmpty)
        .toList();
    picks.sort((left, right) => AnalysisData.parseNum(right['convictionScore'])
        .compareTo(AnalysisData.parseNum(left['convictionScore'])));
    return picks.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getAnalystRatingAlerts({
    List<String>? symbols,
    int limit = 25,
  }) async {
    final scan = _screenSymbols(symbols, limit: limit + 8);
    final rows = <Map<String, dynamic>>[];
    for (final symbol in scan) {
      try {
        final analysis = await SigmaApiService.getAnalysis(symbol);
        final explicitEvents = [
          ..._asList(analysis['upgradesDowngrades']),
          ..._asList(analysis['recommendations']),
          ..._asList(analysis['recommendationsSummary']),
        ];
        for (final event in explicitEvents) {
          final row = _asMap(event);
          if (row.isEmpty) continue;
          rows.add({
            'symbol': symbol,
            'date': row['date'] ?? row['Date'] ?? row['period'] ?? '',
            'firm': row['firm'] ?? row['Firm'] ?? row['brokerage'] ?? '',
            'action': row['action'] ?? row['Action'] ?? row['strongBuy'] ?? '',
            'fromGrade':
                row['fromGrade'] ?? row['FromGrade'] ?? row['from'] ?? '',
            'toGrade': row['toGrade'] ??
                row['ToGrade'] ??
                row['rating'] ??
                row['recommendation'] ??
                '',
            'targetPrice': _firstNum([
              row['targetPrice'],
              row['priceTarget'],
              row['targetMeanPrice']
            ]),
          });
        }
        if (explicitEvents.isEmpty) {
          final latest = _latestAnalystEvent(analysis);
          final recommendation =
              analysis['recommendationKey'] ?? latest['rating'];
          if (_textOf(recommendation).isNotEmpty) {
            rows.add({
              'symbol': symbol,
              'date': latest['date'] ?? '',
              'firm': latest['firm'] ?? 'Consensus',
              'action': latest['action'] ?? 'rating snapshot',
              'fromGrade': latest['fromGrade'] ?? '',
              'toGrade': recommendation,
              'targetPrice': _firstNum(
                  [_asMap(analysis['analystPriceTargets'])['targetMeanPrice']]),
            });
          }
        }
      } catch (error) {
        dev.log('Analyst alerts failed for $symbol: $error',
            name: 'SigmaMarketDataService');
      }
    }
    rows.sort((left, right) =>
        _textOf(right['date']).compareTo(_textOf(left['date'])));
    return rows.take(limit).toList();
  }

  List<String> _screenSymbols(List<String>? symbols, {int limit = 20}) {
    final source = symbols == null || symbols.isEmpty ? _universe : symbols;
    return source
        .map((symbol) => symbol.trim().toUpperCase())
        .where((symbol) => symbol.isNotEmpty)
        .toSet()
        .take(limit.clamp(1, _universe.length))
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['data'] is List) return value['data'] as List;
    if (value is Map && value['rows'] is List) return value['rows'] as List;
    return const [];
  }

  double _firstNum(Iterable<dynamic> values) {
    for (final value in values) {
      final parsed = AnalysisData.parseNum(value);
      if (parsed != 0) return parsed;
    }
    return 0;
  }

  String _textOf(dynamic value) => value?.toString().trim() ?? '';

  double _countRowsContaining(List<dynamic> rows, List<String> needles) {
    return rows
        .where((row) {
          final text = _asMap(row).values.join(' ').toLowerCase();
          return needles.any(text.contains);
        })
        .length
        .toDouble();
  }

  Map<String, dynamic> _latestAnalystEvent(Map<String, dynamic> analysis) {
    final events = [
      ..._asList(analysis['upgradesDowngrades']),
      ..._asList(analysis['recommendations']),
      ..._asList(analysis['recommendationsSummary']),
    ];
    if (events.isEmpty) return <String, dynamic>{};
    final row = _asMap(events.first);
    return {
      'date': row['date'] ?? row['Date'] ?? row['period'] ?? '',
      'firm': row['firm'] ?? row['Firm'] ?? row['brokerage'] ?? '',
      'action': row['action'] ?? row['Action'] ?? row['period'] ?? '',
      'rating': row['rating'] ??
          row['toGrade'] ??
          row['ToGrade'] ??
          row['recommendation'] ??
          '',
      'fromGrade': row['fromGrade'] ?? row['FromGrade'] ?? row['from'] ?? '',
    };
  }

  // ── search ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchTickerSymbols(String query) async {
    final results = await SigmaApiService.search(query);
    return results
        .map((e) => {
              'symbol': e['symbol'],
              'name': e['name'] ?? e['longName'] ?? e['symbol'],
              'description': e['description'] ?? e['name'] ?? e['longName'],
              'currency': e['currency'] ?? 'USD',
              'stockExchange': e['stockExchange'] ?? e['exchange'] ?? '',
              'exchangeShortName':
                  e['exchangeShortName'] ?? e['exchange'] ?? '',
              'exchange': e['exchange'] ?? e['exchangeShortName'] ?? '',
              'type': e['type'] ?? e['quoteType'] ?? 'EQUITY',
              'quoteType': e['quoteType'] ?? e['type'] ?? 'EQUITY',
              'logoUrl': e['logoUrl'] ?? e['logo'] ?? e['image'],
              if (e['logoUrls'] != null) 'logoUrls': e['logoUrls'],
              'source': e['source'] ?? 'SIGMA',
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchSymbol(String query) =>
      searchTickerSymbols(query);

  Future<List<dynamic>> searchExchangeVariants(String query) =>
      SigmaApiService.search(query);

  Future<Map<String, dynamic>> getLogo(String ticker) =>
      SigmaApiService.getLogo(ticker);

  // ── AI context builder ────────────────────────────────────────────────────

  Future<String> getSigmaContext(String ticker) async {
    try {
      final results = await Future.wait([
        SigmaApiService.getQuote(ticker),
        SigmaApiService.getOwnership(ticker),
        SigmaApiService.getInsider(ticker),
        SigmaApiService.getFinancials(ticker),
      ]);

      final profile = results[0];
      final ownership = results[1];
      final insider = results[2];
      final financials = results[3];

      final buffer = StringBuffer();
      buffer.writeln('--- SIGMA API HIGH-FIDELITY CORE DATA ---');

      if (profile.isNotEmpty) {
        buffer.writeln('=== COMPANY_IDENTITY ===');
        buffer.writeln('SYMBOL: ${profile['symbol']}');
        buffer.writeln('NAME: ${profile['companyName'] ?? profile['name']}');
        buffer.writeln(
            'EXCHANGE: ${profile['exchangeFullName'] ?? profile['exchange']}');
        buffer.writeln('SECTOR: ${profile['sector']}');
        buffer.writeln('INDUSTRY: ${profile['industry']}');
        buffer.writeln('MARKET_CAP: ${profile['marketCap']}');
        buffer.writeln('BETA: ${profile['beta']}');
        buffer.writeln('PRICE: ${profile['price']}');
        buffer.writeln('PE: ${profile['pe']}');
        buffer.writeln('EPS: ${profile['eps']}');
        buffer.writeln('GROSS_MARGIN: ${profile['grossMargins']}');
        buffer.writeln('PROFIT_MARGIN: ${profile['profitMargins']}');
        buffer.writeln('CEO: ${profile['ceo']}');
        buffer.writeln('EMPLOYEES: ${profile['fullTimeEmployees']}');
      }

      final instHolders = (ownership['institutionalHolders'] as List? ??
                  ownership['institutional'] as List?)
              ?.take(5)
              .toList() ??
          [];
      if (instHolders.isNotEmpty) {
        buffer.writeln('\n=== INSTITUTIONAL_HOLDERS ===');
        for (var h in instHolders) {
          buffer.writeln('HOLDER: ${h['holder'] ?? h['Holder'] ?? h['name']}, '
              'SHARES: ${h['shares'] ?? h['Shares']}, '
              'PCT: ${h['sharesPercentage'] ?? h['pctHeld']}%');
        }
      }

      final insiderTrades =
          (insider['trades'] as List?)?.take(5).toList() ?? [];
      if (insiderTrades.isNotEmpty) {
        buffer.writeln('\n=== INSIDER_TRADING ===');
        for (var t in insiderTrades) {
          buffer.writeln('DATE: ${t['trade_date'] ?? t['transactionDate']}, '
              'FILER: ${t['insider_name'] ?? t['reportingName']}, '
              'TYPE: ${t['transaction_type'] ?? t['transactionType']}, '
              'SHARES: ${t['qty'] ?? t['securitiesTransacted']}');
        }
      }

      final incomeQ = (financials['quarterlyIncomeStatement'] as List?) ??
          (financials['quarterly']?['income_statement'] as List?) ??
          [];
      if (incomeQ.isNotEmpty) {
        final i = incomeQ.first;
        buffer.writeln('\n=== INCOME_STATEMENT_LATEST ===');
        buffer.writeln(
            'REVENUE: ${i['Total Revenue'] ?? i['TotalRevenue'] ?? i['revenue']}');
        buffer.writeln(
            'NET_INCOME: ${i['Net Income'] ?? i['NetIncomeLoss'] ?? i['netIncome']}');
        buffer.writeln(
            'EPS: ${i['Basic EPS'] ?? i['Diluted EPS'] ?? i['EarningsPerShareBasic'] ?? i['eps']}');
      }

      return buffer.toString();
    } catch (e) {
      dev.log('getSigmaContext error: $e', name: 'SigmaMarketDataService');
      return '';
    }
  }

  // ── google finance ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getGoogleFinanceInfo(String ticker) =>
      SigmaApiService.getGoogleFinance(ticker);
}
