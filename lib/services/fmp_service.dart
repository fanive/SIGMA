// ignore_for_file: avoid_print
import 'dart:developer' as dev;
import 'sigma_api_service.dart';

/// FmpService — thin compatibility wrapper around SigmaApiService.
/// All data comes from https://sigma-yfinance-api.onrender.com/
/// No external API keys required.
class FmpService {
  static const List<String> _universe = [
    'AAPL', 'MSFT', 'NVDA', 'AMZN', 'META', 'GOOGL', 'TSLA', 'AMD',
    'NFLX', 'AVGO', 'JPM', 'BAC', 'XOM', 'CVX', 'KO', 'DIS', 'NKE',
    'INTC', 'CRM', 'PLTR', 'SPY', 'QQQ', 'SOFI', 'COIN', 'MSTR',
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
      '1D':  {'range': '1d',  'interval': '5m'},
      '5D':  {'range': '5d',  'interval': '15m'},
      '1W':  {'range': '5d',  'interval': '1d'},
      '1MO': {'range': '1mo', 'interval': '1d'},
      '1M':  {'range': '1mo', 'interval': '1d'},
      '3M':  {'range': '3mo', 'interval': '1d'},
      '6M':  {'range': '6mo', 'interval': '1d'},
      '6MO': {'range': '6mo', 'interval': '1d'},
      '1Y':  {'range': '1y',  'interval': '1d'},
      '2Y':  {'range': '2y',  'interval': '1d'},
      '5Y':  {'range': '5y',  'interval': '1wk'},
      'MAX': {'range': 'max', 'interval': '1mo'},
    };
    final params = rangeMap[range.toUpperCase()] ??
        {'range': range.toLowerCase(), 'interval': '1d'};
    return SigmaApiService.getHistory(
        ticker, params['range']!, params['interval']!);
  }

  // ── macro ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMacroData() => SigmaApiService.getMacro();

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

  Future<List<dynamic>> getBalanceSheet(String ticker,
      {int limit = 5}) async {
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
    final q = await SigmaApiService.getQuote(ticker);
    return {
      'peRatioTTM': q['pe'],
      'roeTTM': q['returnOnEquity'],
      'roicTTM': q['returnOnAssets'],
      'debtToEquityTTM': q['debtToEquity'],
      'freeCashFlowYieldTTM': q['freeCashflow'],
      ...q,
    };
  }

  Future<Map<String, dynamic>> getRatiosTTM(String ticker) async {
    final q = await SigmaApiService.getQuote(ticker);
    return {
      'grossProfitMarginTTM': q['grossMargins'],
      'netProfitMarginTTM': q['profitMargins'],
      'operatingProfitMarginTTM': q['operatingMargins'],
      'returnOnEquityTTM': q['returnOnEquity'],
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
        'dateReported': m['dateReported'] ?? m['Date Reported'],
      };
    }).toList();
  }

  Future<List<dynamic>> getInsiderTrading(String ticker) async {
    final data = await SigmaApiService.getInsider(ticker);
    final trades = (data['trades'] as List?) ?? [];
    return trades.map((t) {
      if (t is! Map) return t;
      final m = Map<String, dynamic>.from(t);
      return {
        ...m,
        'reportingName': m['reportingName'] ?? m['insider_name'],
        'typeOfOwner': m['typeOfOwner'] ?? m['title'],
        'transactionType': m['transactionType'] ?? m['transaction_type'],
        'securitiesTransacted':
            m['securitiesTransacted'] ?? (m['qty'] is num ? (m['qty'] as num).abs() : 0),
        'transactionDate': m['transactionDate'] ?? m['trade_date'],
      };
    }).toList();
  }

  Future<List<dynamic>> getBulkInsiderTrading({int limit = 100}) async => [];

  // ── news ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getStockNews(String symbol, {int limit = 10}) async {
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
    final list = await SigmaApiService.getNews('SPY');
    return list.take(limit).map((n) {
      final m = Map<String, dynamic>.from(n);
      return {
        ...m,
        'site': m['site'] ?? m['publisher'] ?? 'yfinance',
        'url': m['url'] ?? m['link'] ?? '',
        'publishedDate': m['publishedDate'] ?? m['publishedAt'] ?? '',
        'text': m['text'] ?? m['summary'] ?? m['title'] ?? '',
        'image': m['image'] ?? m['thumbnail'],
      };
    }).toList();
  }

  Future<List<dynamic>> getFmpArticles(String ticker) =>
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

  Future<List<dynamic>> getEconomicCalendar() async {
    final watch = ['AAPL', 'MSFT', 'NVDA', 'AMZN', 'META', 'TSLA'];
    final out = <Map<String, dynamic>>[];
    for (final t in watch) {
      final events = await SigmaApiService.getEvents(t);
      final cal = (events['calendar'] as Map?)?.cast<String, dynamic>() ?? {};
      final earnings = cal['Earnings Date'];
      final earningsDate = earnings is List && earnings.isNotEmpty
          ? earnings.first?.toString()
          : cal['Earnings Date']?.toString();
      if (earningsDate != null && earningsDate.isNotEmpty) {
        out.add({
          'date': earningsDate,
          'event': '$t Earnings',
          'impact': 'HIGH',
          'country': 'US',
          'actual': null,
          'estimate': cal['Earnings Average']?.toString(),
          'previous': null,
        });
      }
    }
    out.sort((a, b) => (a['date']?.toString() ?? '')
        .compareTo(b['date']?.toString() ?? ''));
    return out;
  }

  Future<List<dynamic>> getIposCalendar() async => [];
  Future<List<dynamic>> getEconomicIndicators(String name) async => [];
  Future<List<dynamic>> getMergersAndAcquisitions() async => [];

  // ── sector / industry performance ─────────────────────────────────────────

  Future<List<dynamic>> getSectorPerformance() async {
    final quotes = await SigmaApiService.getMultiQuote(_sectorEtfs.keys.toList());
    return quotes.map((q) {
      final symbol = q['symbol']?.toString() ?? '';
      return {
        'sector': _sectorEtfs[symbol] ?? symbol,
        'changesPercentage': q['changesPercentage'] ?? 0,
        'symbol': symbol,
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
    quotes.sort((a, b) =>
        ((b['volume'] ?? 0) as num).compareTo((a['volume'] ?? 0) as num));
    return quotes.take(20).toList();
  }

  Future<List<dynamic>> getGainers() async {
    final quotes = await SigmaApiService.getMultiQuote(_universe);
    quotes.sort((a, b) => ((b['changesPercentage'] ?? 0) as num)
        .compareTo((a['changesPercentage'] ?? 0) as num));
    return quotes.take(20).toList();
  }

  Future<List<dynamic>> getLosers() async {
    final quotes = await SigmaApiService.getMultiQuote(_universe);
    quotes.sort((a, b) => ((a['changesPercentage'] ?? 0) as num)
        .compareTo((b['changesPercentage'] ?? 0) as num));
    return quotes.take(20).toList();
  }

  Future<List<dynamic>> getMarketMovers() async =>
      SigmaApiService.getMultiQuote(_universe);

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

  // ── search ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchTickerSymbols(String query) async {
    final results = await SigmaApiService.search(query);
    return results
        .map((e) => {
              'symbol': e['symbol'],
              'name': e['name'] ?? e['longName'] ?? e['symbol'],
              'currency': e['currency'] ?? 'USD',
              'stockExchange': e['stockExchange'] ?? e['exchange'] ?? '',
              'exchangeShortName': e['exchangeShortName'] ?? e['exchange'] ?? '',
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

  Future<String> getFmpContext(String ticker) async {
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

      final instHolders =
          (ownership['institutionalHolders'] as List? ??
                  ownership['institutional'] as List?)
              ?.take(5)
              .toList() ??
          [];
      if (instHolders.isNotEmpty) {
        buffer.writeln('\n=== INSTITUTIONAL_HOLDERS ===');
        for (var h in instHolders) {
          buffer.writeln(
              'HOLDER: ${h['holder'] ?? h['Holder'] ?? h['name']}, '
              'SHARES: ${h['shares'] ?? h['Shares']}, '
              'PCT: ${h['sharesPercentage'] ?? h['pctHeld']}%');
        }
      }

      final insiderTrades =
          (insider['trades'] as List?)?.take(5).toList() ?? [];
      if (insiderTrades.isNotEmpty) {
        buffer.writeln('\n=== INSIDER_TRADING ===');
        for (var t in insiderTrades) {
          buffer.writeln(
              'DATE: ${t['trade_date'] ?? t['transactionDate']}, '
              'FILER: ${t['insider_name'] ?? t['reportingName']}, '
              'TYPE: ${t['transaction_type'] ?? t['transactionType']}, '
              'SHARES: ${t['qty'] ?? t['securitiesTransacted']}');
        }
      }

      final incomeQ =
          (financials['quarterlyIncomeStatement'] as List?) ??
            (financials['quarterly']?['income_statement'] as List?) ??
            [];
      if (incomeQ.isNotEmpty) {
        final i = incomeQ.first;
        buffer.writeln('\n=== INCOME_STATEMENT_LATEST ===');
        buffer.writeln('REVENUE: ${i['TotalRevenue'] ?? i['revenue']}');
        buffer.writeln('NET_INCOME: ${i['NetIncomeLoss'] ?? i['netIncome']}');
        buffer.writeln('EPS: ${i['EarningsPerShareBasic'] ?? i['eps']}');
      }

      return buffer.toString();
    } catch (e) {
      dev.log('getFmpContext error: $e', name: 'FmpService');
      return '';
    }
  }
}
