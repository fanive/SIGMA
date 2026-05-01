import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FmpService {
  final String _apiKey = dotenv.env['FMP_API_KEY'] ?? '';
  final String _baseUrl = 'https://financialmodelingprep.com/api/v3';
  final String _backendUrl = dotenv.env['YF_BACKEND_URL'] ?? '';
  final String _yahooQuoteUrl =
      'https://query1.finance.yahoo.com/v7/finance/quote';

  bool get _hasFmpKey =>
      _apiKey.isNotEmpty && !_apiKey.contains('MISSING') && !_apiKey.contains('example');

  bool get _hasBackend => _backendUrl.trim().isNotEmpty;

  Future<Map<String, dynamic>> getCompanyQuote(String ticker) async {
    if (!_hasFmpKey) {
      return getQuoteMap(ticker);
    }
    final url = Uri.parse('$_baseUrl/quote/$ticker?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) return Map<String, dynamic>.from(data[0]);
        dev.log('⚠️ FMP Quote empty for $ticker');
      } else {
        dev.log('❌ FMP Quote Error: ${response.statusCode} for $ticker');
      }
    } catch (e) {
      dev.log('FMP Quote Exception: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getKeyMetricsTTM(String ticker) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/key-metrics-ttm?symbol=$ticker&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded[0]);
        } else if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      dev.log('FMP Key Metrics TTM Error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getRatiosTTM(String ticker) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/ratios-ttm?symbol=$ticker&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded[0]);
        } else if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      dev.log('FMP Ratios TTM Error: $e');
    }
    return {};
  }

  Future<List<dynamic>> getIncomeStatement(
    String ticker, {
    int limit = 5,
  }) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/income-statement?symbol=$ticker&limit=$limit&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Income Statement Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getBalanceSheet(String ticker, {int limit = 5}) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/balance-sheet-statement?symbol=$ticker&limit=$limit&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Balance Sheet Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getCashFlowStatement(
    String ticker, {
    int limit = 5,
  }) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/cash-flow-statement?symbol=$ticker&limit=$limit&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Cash Flow Error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getCompanyProfileStable(String ticker) async {
    final endpoints = [
      'https://financialmodelingprep.com/stable/profile?symbol=$ticker&apikey=$_apiKey',
      '$_baseUrl/profile/$ticker?apikey=$_apiKey',
    ];

    for (final urlStr in endpoints) {
      try {
        final url = Uri.parse(urlStr);
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is List && decoded.isNotEmpty) {
            return Map<String, dynamic>.from(decoded[0]);
          }
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        dev.log('FMP Stable Profile Exception: $e');
      }
    }
    return {};
  }

  Future<List<dynamic>> getDividendsStable(String ticker) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/dividends?symbol=$ticker&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Dividends Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getEconomicIndicators(String name) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/economic-indicators?name=$name&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Economic Indicators Error: $e');
    }
    return [];
  }

  Future<String> getFmpContext(String ticker) async {
    final profile = await getCompanyProfileStable(ticker);
    final metricsTTM = await getKeyMetricsTTM(ticker);
    final ratiosTTM = await getRatiosTTM(ticker);
    final income = await getIncomeStatement(ticker, limit: 1);
    final instHolders = (await getInstitutionalHolders(
      ticker,
    )).take(5).toList();
    final insiderTrading = (await getInsiderTrading(ticker)).take(5).toList();

    final buffer = StringBuffer();
    buffer.writeln('--- FMP STABLE HIGH-FIDELITY CORE DATA ---');

    if (profile.isNotEmpty) {
      buffer.writeln('=== COMPANY_IDENTITY ===');
      buffer.writeln('SYMBOL: ${profile['symbol']}');
      buffer.writeln('NAME: ${profile['companyName']}');
      buffer.writeln('EXCHANGE: ${profile['exchangeFullName']}');
      buffer.writeln('SECTOR: ${profile['sector']}');
      buffer.writeln('INDUSTRY: ${profile['industry']}');
      buffer.writeln('MARKET_CAP: ${profile['mktCap'] ?? profile['marketCap']}');
      buffer.writeln('BETA: ${profile['beta']}');
      buffer.writeln('PRICE: ${profile['price']}');
    }

    if (instHolders.isNotEmpty) {
      buffer.writeln('\n=== INSTITUTIONAL_HOLDERS ===');
      for (var h in instHolders) {
        buffer.writeln(
          'HOLDER: ${h['holder']}, SHARES: ${h['shares']}, PCT: ${h['sharesPercentage']}%',
        );
      }
    }

    if (insiderTrading.isNotEmpty) {
      buffer.writeln('\n=== INSIDER_TRADING ===');
      for (var t in insiderTrading) {
        buffer.writeln(
          'DATE: ${t['transactionDate']}, FILER: ${t['reportingName']}, TYPE: ${t['transactionType']}, SHARES: ${t['securitiesTransacted']}',
        );
      }
    }

    if (metricsTTM.isNotEmpty) {
      buffer.writeln('\n=== FUNDAMENTAL_TTM_METRICS ===');
      buffer.writeln('PE_RATIO: ${metricsTTM['peRatioTTM']}');
      buffer.writeln('ROE: ${metricsTTM['roeTTM']}');
      buffer.writeln('ROIC: ${metricsTTM['roicTTM']}');
      buffer.writeln('DEBT_TO_EQUITY: ${metricsTTM['debtToEquityTTM']}');
      buffer.writeln(
        'FREE_CASH_FLOW_YIELD: ${metricsTTM['freeCashFlowYieldTTM']}',
      );
    }

    if (ratiosTTM.isNotEmpty) {
      buffer.writeln('\n=== PROFITABILITY_RATIOS ===');
      buffer.writeln(
        'GROSS_PROFIT_MARGIN: ${ratiosTTM['grossProfitMarginTTM']}',
      );
      buffer.writeln('NET_PROFIT_MARGIN: ${ratiosTTM['netProfitMarginTTM']}');
    }

    if (income.isNotEmpty) {
      final i = income[0];
      buffer.writeln('\n=== INCOME_STATEMENT_LATEST ===');
      buffer.writeln('REVENUE: ${i['revenue']}');
      buffer.writeln('NET_INCOME: ${i['netIncome']}');
      buffer.writeln('EPS: ${i['eps']}');
    }

    return buffer.toString();
  }

  Future<double> getRealTimePrice(String ticker) async {
    final quote = await getCompanyQuote(ticker);
    return (quote['price'] ?? 0.0).toDouble();
  }

  Future<List<dynamic>> getInstitutionalHolders(String ticker) async {
    final url = Uri.parse(
      '$_baseUrl/institutional-holder/$ticker?apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Inst Holders Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getInsiderTrading(String ticker) async {
    final url = Uri.parse(
      '$_baseUrl/insider-trading/$ticker?limit=10&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Insider Trading Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getBulkInsiderTrading({int limit = 100}) async {
    final url = Uri.parse(
      '$_baseUrl/insider-trading-rss-feed?limit=$limit&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Bulk Insider Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getSectorPerformance() async {
    final url = Uri.parse('$_baseUrl/sector-performance?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Sector Perf Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getMostActive() async {
    if (!_hasFmpKey) {
      return _getYahooUniverseMovers();
    }
    final url = Uri.parse('$_baseUrl/stock_market/actives?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Most Active Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getIposCalendar() async {
    final now = DateTime.now();
    final fromDate = now.toIso8601String().split('T')[0];
    final toDate = now
        .add(const Duration(days: 90))
        .toIso8601String()
        .split('T')[0];
    final url = Uri.parse(
      '$_baseUrl/ipo_calendar?from=$fromDate&to=$toDate&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP IPO Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getGainers() async {
    if (!_hasFmpKey) {
      final movers = await _getYahooUniverseMovers();
      movers.sort((a, b) =>
          ((b['changesPercentage'] ?? 0) as num).compareTo((a['changesPercentage'] ?? 0) as num));
      return movers.take(30).toList();
    }
    final url = Uri.parse('$_baseUrl/stock_market/gainers?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Gainers Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getLosers() async {
    if (!_hasFmpKey) {
      final movers = await _getYahooUniverseMovers();
      movers.sort((a, b) =>
          ((a['changesPercentage'] ?? 0) as num).compareTo((b['changesPercentage'] ?? 0) as num));
      return movers.take(30).toList();
    }
    final url = Uri.parse('$_baseUrl/stock_market/losers?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Losers Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getQuotes(List<String> tickers) async {
    if (tickers.isEmpty) return [];
    if (_hasBackend) {
      try {
        final response = await http.get(
          Uri.parse(
              '$_backendUrl/multi-quote?symbols=${Uri.encodeQueryComponent(tickers.join(','))}'),
        );
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as List<dynamic>;
        }
      } catch (e) {
        dev.log('Local backend getQuotes Error: $e');
      }
    }

    if (!_hasFmpKey) {
      return _getYahooQuotes(tickers);
    }
    final tStr = tickers.join(',');
    final url = Uri.parse('$_baseUrl/quote/$tStr?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Multi Quotes Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getEarningsHistorical(String ticker) async {
    final url = Uri.parse(
      '$_baseUrl/historical/earnings-calendar/$ticker?limit=10&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Earnings Hist Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getEconomicCalendar() async {
    final url = Uri.parse('$_baseUrl/economic_calendar?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Eco Cal Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getFmpArticles(String ticker) async {
    final url = Uri.parse(
      '$_baseUrl/fmp/articles?symbol=$ticker&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['content'] ?? [];
      }
    } catch (e) {
      dev.log('FMP Articles Error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getCompanyProfile(String ticker) async {
    final url = Uri.parse('$_baseUrl/profile/$ticker?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) return Map<String, dynamic>.from(data[0]);
      }
    } catch (e) {
      dev.log('FMP Profile Error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> getDetailedProfile(String ticker) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/search-exchange-variants?symbol=$ticker&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) return Map<String, dynamic>.from(data[0]);
      }
    } catch (e) {
      dev.log('FMP Detailed Profile Error: $e');
    }
    return {};
  }

  Future<List<dynamic>> searchExchangeVariants(String query) async {
    final url = Uri.parse(
      'https://financialmodelingprep.com/stable/search-exchange-variants?symbol=$query&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Variants Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getDividends(String ticker) async {
    final url = Uri.parse(
      '$_baseUrl/historical-price-full/stock_dividend/$ticker?apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['historical'] ?? [];
      }
    } catch (e) {
      dev.log('FMP Dividends Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getGeneralNews({int limit = 50}) async {
    final url = Uri.parse('$_baseUrl/stock_news?limit=$limit&apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List? ?? [];
      }
    } catch (e) {
      dev.log('FMP General News Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getStockNews(String symbol, {int limit = 10}) async {
    final url = Uri.parse('$_baseUrl/stock_news?tickers=$symbol&limit=$limit&apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List? ?? [];
      }
    } catch (e) {
      dev.log('FMP Stock News Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getMergersAndAcquisitions() async {
    final url = Uri.parse(
      '$_baseUrl/mergers-acquisitions-rss-feed?limit=50&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List? ?? [];
      }
    } catch (e) {
      dev.log('FMP M&A Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getIndustryPerformance() async {
    final url = Uri.parse(
      '$_baseUrl/sectors-performance?apikey=$_apiKey',
    ); // Use sectors if industry is unavailable or similar
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List? ?? [];
      }
    } catch (e) {
      dev.log('FMP Industry Performance Error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchSymbol(String query) async {
    if (_hasBackend) {
      try {
        final response = await http.get(
          Uri.parse('$_backendUrl/search?q=${Uri.encodeQueryComponent(query)}'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data
              .map<Map<String, dynamic>>(
                (item) => {
                  'symbol': item['symbol'],
                  'name': item['name'] ?? item['longName'] ?? item['symbol'],
                  'currency': item['currency'] ?? 'USD',
                  'stockExchange':
                      item['stockExchange'] ?? item['exchange'] ?? '',
                  'exchangeShortName':
                      item['exchangeShortName'] ?? item['exchange'] ?? '',
                },
              )
              .toList();
        }
      } catch (e) {
        dev.log('Local backend searchSymbol Error: $e');
      }
    }

    if (!_hasFmpKey) {
      return searchTickerSymbols(query);
    }

    final url = Uri.parse(
      '$_baseUrl/search?query=$query&limit=10&apikey=$_apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map<Map<String, dynamic>>(
              (item) => {
                'symbol': item['symbol'],
                'name': item['name'],
                'currency': item['currency'],
                'stockExchange': item['stockExchange'],
                'exchangeShortName': item['exchangeShortName'],
              },
            )
            .toList();
      }
    } catch (e) {
      dev.log('FMP Search Error: $e');
    }
    return searchTickerSymbols(query);
  }

  /// Screen stocks by sector and market cap using FMP stock screener API
  Future<List<dynamic>> screenStocks({
    String? sector,
    double? minMarketCap,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'apikey': _apiKey,
      'limit': limit.toString(),
    };
    if (sector != null) params['sector'] = sector;
    if (minMarketCap != null) {
      params['marketCapMoreThan'] = minMarketCap.toStringAsFixed(0);
    }

    final url = Uri.parse(
      '$_baseUrl/stock-screener',
    ).replace(queryParameters: params);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
    } catch (e) {
      dev.log('FMP Stock Screener Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getMarketMovers() async {
    try {
      final actives = await getMostActive();
      final gainers = await getGainers();
      final losers = await getLosers();
      
      // Merge all and return
      return [...actives, ...gainers, ...losers];
    } catch (e) {
      dev.log('FMP getMarketMovers Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getAnalystEstimates(String ticker) async {
    final url = Uri.parse('$_baseUrl/v3/analyst-estimates/$ticker?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Analyst Estimates Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getPriceTargets(String ticker) async {
    final url = Uri.parse('$_baseUrl/v3/price-target?symbol=$ticker&apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Price Target Error: $e');
    }
    return [];
  }

  Future<List<String>> getPeers(String ticker) async {
    final url = Uri.parse('https://financialmodelingprep.com/api/v4/stock_peers?symbol=$ticker&apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return List<String>.from(data[0]['peersList'] ?? []);
        }
      }
    } catch (e) {
      dev.log('FMP Peers Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> getFullQuotes(List<String> tickers) async {
    if (tickers.isEmpty) return [];
    final tStr = tickers.join(',');
    final url = Uri.parse('$_baseUrl/quote/$tStr?apikey=$_apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      dev.log('FMP Full Quotes Error: $e');
    }
    return [];
  }

  /// Fetches OHLCV historical data for a given ticker and range string.
  /// Supports ranges: 1D, 5D, 1M, 3M, 6M, 1Y, 2Y, 5Y, MAX
  /// Returns: List of {date, open, high, low, close, volume}
  Future<List<Map<String, dynamic>>> getHistoricalOHLCV(
      String ticker, String range) async {
    if (_hasBackend) {
      final rangeMap = {
        '1D': {'range': '1d', 'interval': '5m'},
        '5D': {'range': '5d', 'interval': '15m'},
        '1W': {'range': '5d', 'interval': '1d'},
        '1M': {'range': '1mo', 'interval': '1d'},
        '3M': {'range': '3mo', 'interval': '1d'},
        '6M': {'range': '6mo', 'interval': '1d'},
        '1Y': {'range': '1y', 'interval': '1d'},
        '2Y': {'range': '2y', 'interval': '1d'},
        '5Y': {'range': '5y', 'interval': '1wk'},
        'MAX': {'range': 'max', 'interval': '1mo'},
      };
      final params =
          rangeMap[range.toUpperCase()] ?? {'range': '1mo', 'interval': '1d'};
      try {
        final response = await http.get(
          Uri.parse(
              '$_backendUrl/history/${ticker.toUpperCase()}?range=${params['range']}&interval=${params['interval']}'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> raw = jsonDecode(response.body);
          return raw.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (e) {
        dev.log('Local backend getHistoricalOHLCV Error: $e');
      }
    }

    if (!_hasFmpKey) {
      return _getYahooHistoricalOHLCV(ticker, range);
    }
    try {
      final now = DateTime.now();
      final rangeUpper = range.toUpperCase();

      // Intraday (1D, 5D): use 5min chart
      if (rangeUpper == '1D' || rangeUpper == '5D') {
        final interval = rangeUpper == '1D' ? '5min' : '15min';
        final url = Uri.parse(
            '$_baseUrl/historical-chart/$interval/$ticker?apikey=$_apiKey');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List<dynamic> raw = jsonDecode(response.body);
          final limit = rangeUpper == '1D' ? 78 : 130;
          return raw
              .take(limit)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return [];
      }

      // Daily historical
      String fromStr = '';
      switch (rangeUpper) {
        case '1W':
          fromStr = now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
          break;
        case '1M':
          fromStr = DateTime(now.year, now.month - 1, now.day)
              .toIso8601String()
              .split('T')[0];
          break;
        case '3M':
          fromStr = DateTime(now.year, now.month - 3, now.day)
              .toIso8601String()
              .split('T')[0];
          break;
        case '6M':
          fromStr = DateTime(now.year, now.month - 6, now.day)
              .toIso8601String()
              .split('T')[0];
          break;
        case '1Y':
          fromStr = DateTime(now.year - 1, now.month, now.day)
              .toIso8601String()
              .split('T')[0];
          break;
        case '2Y':
          fromStr = DateTime(now.year - 2, now.month, now.day)
              .toIso8601String()
              .split('T')[0];
          break;
        case '5Y':
          fromStr = DateTime(now.year - 5, now.month, now.day)
              .toIso8601String()
              .split('T')[0];
          break;
        default: // MAX — no from parameter
          fromStr = '';
      }

      final toStr = now.toIso8601String().split('T')[0];
      final fromParam = fromStr.isNotEmpty ? '&from=$fromStr&to=$toStr' : '';
      final url = Uri.parse(
          '$_baseUrl/historical-price-full/$ticker?$fromParam&apikey=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final historical = body['historical'] as List? ?? [];
        return historical.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      dev.log('FMP Historical OHLCV Error ($ticker): $e');
    }
    return [];
  }

  /// Fetches macro indicator data: TNX (10Y yield), DXY, Gold, Oil, VIX
  /// Returns: {tnx, dxy, gold, oil, vix} with keys: symbol, price, change, changePercent
  Future<Map<String, dynamic>> getMacroData() async {
    if (_hasBackend) {
      try {
        final response = await http.get(Uri.parse('$_backendUrl/macro'));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        dev.log('Local backend getMacroData Error: $e');
      }
    }

    if (!_hasFmpKey) {
      return _getYahooMacroData();
    }
    try {
      final tickers = ['%5ETNX', 'DX-Y.NYB', 'GC%3DF', 'CL%3DF', '%5EVIX'];
      final url = Uri.parse(
          '$_baseUrl/quote/${tickers.join(',')}?apikey=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);
        final result = <String, dynamic>{};
        for (final item in raw) {
          final symbol = (item['symbol'] ?? '').toString().toUpperCase();
          if (symbol.contains('TNX') || symbol == '^TNX') {
            result['tnx'] = item;
          } else if (symbol.contains('DX-Y') || symbol.contains('DXY')) {
            result['dxy'] = item;
          } else if (symbol.contains('GC') || symbol.contains('GOLD')) {
            result['gold'] = item;
          } else if (symbol.contains('CL') || symbol.contains('OIL')) {
            result['oil'] = item;
          } else if (symbol.contains('VIX')) {
            result['vix'] = item;
          }
        }
        return result;
      }
    } catch (e) {
      dev.log('FMP MacroData Error: $e');
    }
    return {};
  }

  /// Searches for ticker symbols matching [query].
  /// Returns: List of {symbol, name, currency, stockExchange, exchangeShortName}
  Future<List<Map<String, dynamic>>> searchTickerSymbols(String query) async {
    if (query.isEmpty) return [];
    if (_hasBackend) {
      try {
        final response = await http.get(
          Uri.parse('$_backendUrl/search?q=${Uri.encodeQueryComponent(query)}'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> raw = jsonDecode(response.body);
          return raw.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (e) {
        dev.log('Local backend searchTickerSymbols Error: $e');
      }
    }

    if (!_hasFmpKey) {
      try {
        final url = Uri.parse(
            'https://query1.finance.yahoo.com/v1/finance/search?q=${Uri.encodeComponent(query)}');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final Map<String, dynamic> raw = jsonDecode(response.body);
          final List<dynamic> quotes = raw['quotes'] as List? ?? [];
          return quotes
              .map<Map<String, dynamic>>((e) => {
                    'symbol': e['symbol'],
                    'name': e['shortname'] ?? e['longname'] ?? e['symbol'],
                    'currency': e['currency'] ?? 'USD',
                    'stockExchange': e['exchange'],
                    'exchangeShortName': e['exchange'],
                  })
              .toList();
        }
      } catch (e) {
        dev.log('Yahoo SearchTickerSymbols Error: $e');
      }
      return [];
    }
    try {
      final url = Uri.parse(
          '$_baseUrl/search?query=${Uri.encodeComponent(query)}&limit=20&apikey=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);
        return raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      dev.log('FMP SearchTickerSymbols Error: $e');
    }
    return [];
  }

  /// Returns a real-time quote map for [ticker] with price, change, changePercent, etc.
  Future<Map<String, dynamic>> getQuoteMap(String ticker) async {
    if (_hasBackend) {
      try {
        final response =
            await http.get(Uri.parse('$_backendUrl/quote/${ticker.toUpperCase()}'));
        if (response.statusCode == 200) {
          return Map<String, dynamic>.from(jsonDecode(response.body));
        }
      } catch (e) {
        dev.log('Local backend getQuoteMap Error ($ticker): $e');
      }
    }

    if (!_hasFmpKey) {
      final results = await _getYahooQuotes([ticker]);
      return results.isNotEmpty ? Map<String, dynamic>.from(results.first) : {};
    }
    try {
      final url = Uri.parse('$_baseUrl/quote/$ticker?apikey=$_apiKey');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);
        if (raw.isNotEmpty) return Map<String, dynamic>.from(raw.first);
      }
    } catch (e) {
      dev.log('FMP QuoteMap Error ($ticker): $e');
    }
    return {};
  }

  Future<List<dynamic>> _getYahooQuotes(List<String> tickers) async {
    final normalized = tickers
        .where((t) => t.trim().isNotEmpty)
        .map((t) => t.trim().toUpperCase())
        .toList();
    if (normalized.isEmpty) return [];

    try {
      final url = Uri.parse('$_yahooQuoteUrl?symbols=${normalized.join(',')}');
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> raw = body['quoteResponse']?['result'] as List? ?? [];
      return raw.map((item) => _yahooQuoteToFmpShape(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      dev.log('Yahoo getQuotes Error: $e');
      return [];
    }
  }

  Map<String, dynamic> _yahooQuoteToFmpShape(Map<String, dynamic> item) {
    final price = (item['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
    final change = (item['regularMarketChange'] as num?)?.toDouble() ?? 0.0;
    final changePct = (item['regularMarketChangePercent'] as num?)?.toDouble() ?? 0.0;

    return {
      'symbol': item['symbol'],
      'name': item['shortName'] ?? item['longName'] ?? item['symbol'],
      'price': price,
      'change': change,
      'changesPercentage': changePct,
      'changePercent': changePct,
      'dayLow': item['regularMarketDayLow'] ?? item['regularMarketPreviousClose'],
      'dayHigh': item['regularMarketDayHigh'] ?? item['regularMarketPreviousClose'],
      'volume': (item['regularMarketVolume'] as num?)?.toDouble() ?? 0.0,
      'marketCap': (item['marketCap'] as num?)?.toDouble() ?? 0.0,
      'exchange': item['fullExchangeName'] ?? item['exchange'] ?? '',
      'currency': item['currency'] ?? 'USD',
      'timestamp': item['regularMarketTime'],
    };
  }

  Future<List<dynamic>> _getYahooUniverseMovers() async {
    const universe = [
      'AAPL', 'MSFT', 'NVDA', 'AMZN', 'META', 'GOOGL', 'TSLA', 'AMD',
      'NFLX', 'AVGO', 'JPM', 'BAC', 'XOM', 'CVX', 'KO', 'DIS', 'NKE',
      'INTC', 'CRM', 'PLTR', 'SPY', 'QQQ'
    ];
    return _getYahooQuotes(universe);
  }

  Future<List<Map<String, dynamic>>> _getYahooHistoricalOHLCV(
      String ticker, String range) async {
    try {
      final rangeMap = {
        '1D': {'range': '1d', 'interval': '5m'},
        '5D': {'range': '5d', 'interval': '15m'},
        '1W': {'range': '5d', 'interval': '1d'},
        '1M': {'range': '1mo', 'interval': '1d'},
        '3M': {'range': '3mo', 'interval': '1d'},
        '6M': {'range': '6mo', 'interval': '1d'},
        '1Y': {'range': '1y', 'interval': '1d'},
        '2Y': {'range': '2y', 'interval': '1d'},
        '5Y': {'range': '5y', 'interval': '1wk'},
        'MAX': {'range': 'max', 'interval': '1mo'},
      };
      final params = rangeMap[range.toUpperCase()] ?? {'range': '1mo', 'interval': '1d'};
      final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/${ticker.toUpperCase()}?range=${params['range']}&interval=${params['interval']}');
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> results = body['chart']?['result'] as List? ?? [];
      if (results.isEmpty) return [];

      final Map<String, dynamic> first = Map<String, dynamic>.from(results.first);
      final List<dynamic> timestamps = first['timestamp'] as List? ?? [];
      final Map<String, dynamic> indicators =
          Map<String, dynamic>.from((first['indicators']?['quote'] as List?)?.first ?? {});

      final List<dynamic> opens = indicators['open'] as List? ?? [];
      final List<dynamic> highs = indicators['high'] as List? ?? [];
      final List<dynamic> lows = indicators['low'] as List? ?? [];
      final List<dynamic> closes = indicators['close'] as List? ?? [];
      final List<dynamic> volumes = indicators['volume'] as List? ?? [];

      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < timestamps.length; i++) {
        final ts = timestamps[i];
        if (ts == null) continue;
        out.add({
          'date': DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000, isUtc: true)
              .toIso8601String(),
          'open': (i < opens.length ? opens[i] : null),
          'high': (i < highs.length ? highs[i] : null),
          'low': (i < lows.length ? lows[i] : null),
          'close': (i < closes.length ? closes[i] : null),
          'volume': (i < volumes.length ? volumes[i] : null),
        });
      }
      return out;
    } catch (e) {
      dev.log('Yahoo Historical OHLCV Error ($ticker): $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getYahooMacroData() async {
    final quotes = await _getYahooQuotes(['^TNX', 'DX-Y.NYB', 'GC=F', 'CL=F', '^VIX']);
    if (quotes.isEmpty) return {};

    final result = <String, dynamic>{};
    for (final q in quotes) {
      final symbol = (q['symbol'] ?? '').toString().toUpperCase();
      if (symbol.contains('TNX')) {
        result['tnx'] = q;
      } else if (symbol.contains('DX-Y') || symbol.contains('DXY')) {
        result['dxy'] = q;
      } else if (symbol.contains('GC')) {
        result['gold'] = q;
      } else if (symbol.contains('CL')) {
        result['oil'] = q;
      } else if (symbol.contains('VIX')) {
        result['vix'] = q;
      }
    }
    return result;
  }
}
