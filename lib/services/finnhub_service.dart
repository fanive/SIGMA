import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

/// Finnhub free-tier connector (read-only).
/// Used as a secondary source when Sigma results are missing.
class FinnhubService {
  final String apiKey;
  final String baseUrl;

  const FinnhubService({
    required this.apiKey,
    this.baseUrl = 'https://finnhub.io/api/v1',
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    if (!isConfigured) return null;
    final qp = <String, String>{...?params, 'token': apiKey};
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: qp);
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      dev.log('Finnhub $path => ${resp.statusCode}', name: 'FinnhubService');
    } catch (e) {
      dev.log('Finnhub $path error: $e', name: 'FinnhubService');
    }
    return null;
  }

  /// Search symbols by query.
  Future<List<Map<String, dynamic>>> searchSymbols(String query) async {
    if (!isConfigured || query.trim().isEmpty) return [];
    final data = await _get('/search', params: {'q': query.trim()});
    if (data is! Map || data['result'] is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final row in (data['result'] as List)) {
      if (row is! Map) continue;
      final m = Map<String, dynamic>.from(row);
      out.add({
        'symbol': (m['symbol'] ?? '').toString().toUpperCase(),
        'name': (m['description'] ?? m['displaySymbol'] ?? '').toString(),
        'displaySymbol': (m['displaySymbol'] ?? m['symbol'] ?? '').toString(),
        'type': (m['type'] ?? 'Common Stock').toString(),
        'exchange': (m['mic'] ?? '').toString(),
        'source': 'FINNHUB',
      });
    }
    return out;
  }

  /// Company profile 2 (free endpoint).
  Future<Map<String, dynamic>> companyProfile2(String symbol) async {
    if (!isConfigured || symbol.trim().isEmpty) return {};
    final data = await _get('/stock/profile2', params: {'symbol': symbol.toUpperCase()});
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Quote endpoint (free tier).
  Future<Map<String, dynamic>> quote(String symbol) async {
    if (!isConfigured || symbol.trim().isEmpty) return {};
    final data = await _get('/quote', params: {'symbol': symbol.toUpperCase()});
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Company news endpoint (free tier with date range).
  Future<List<Map<String, dynamic>>> companyNews(
    String symbol, {
    required String from,
    required String to,
  }) async {
    if (!isConfigured || symbol.trim().isEmpty) return [];
    final data = await _get('/company-news', params: {
      'symbol': symbol.toUpperCase(),
      'from': from,
      'to': to,
    });
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Market news (general, forex, crypto, merger).
  Future<List<Map<String, dynamic>>> marketNews({
    String category = 'general',
    int? minId,
  }) async {
    if (!isConfigured) return [];
    final params = <String, String>{'category': category};
    if (minId != null && minId > 0) {
      params['minId'] = minId.toString();
    }

    final data = await _get('/news', params: params);
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Basic financial metrics (free endpoint).
  Future<Map<String, dynamic>> basicFinancials(String symbol) async {
    if (!isConfigured || symbol.trim().isEmpty) return {};
    final data = await _get('/stock/metric', params: {
      'symbol': symbol.toUpperCase(),
      'metric': 'all',
    });
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Analyst recommendation trends (free endpoint).
  Future<List<Map<String, dynamic>>> recommendationTrends(String symbol) async {
    if (!isConfigured || symbol.trim().isEmpty) return [];
    final data = await _get('/stock/recommendation', params: {
      'symbol': symbol.toUpperCase(),
    });
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Historical EPS surprise data (free tier: latest quarters).
  Future<List<Map<String, dynamic>>> earningsSurprises(
    String symbol, {
    int? limit,
  }) async {
    if (!isConfigured || symbol.trim().isEmpty) return [];
    final params = <String, String>{'symbol': symbol.toUpperCase()};
    if (limit != null && limit > 0) {
      params['limit'] = limit.toString();
    }
    final data = await _get('/stock/earnings', params: params);
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Historical and upcoming earnings releases (free endpoint).
  Future<List<Map<String, dynamic>>> earningsCalendar({
    required String from,
    required String to,
    String? symbol,
    bool international = false,
  }) async {
    if (!isConfigured) return [];
    final params = <String, String>{
      'from': from,
      'to': to,
      'international': international.toString(),
    };
    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.toUpperCase();
    }

    final data = await _get('/calendar/earnings', params: params);
    if (data is! Map || data['earningsCalendar'] is! List) return [];
    return (data['earningsCalendar'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

