import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service pour effectuer des recherches web en temps réel (Alpha)
/// Supporte Serper.dev ou Tavily AI
class WebSearchService {
  final String? _serperKey = dotenv.env['SERPER_API_KEY'];
  final String? _tavilyKey = dotenv.env['TAVILY_API_KEY'];

  // Cache mémoire pour éviter les requêtes redondantes
  static final Map<String, _CachedSearch> _cache = {};
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Effectue une recherche web et retourne un condensé de résultats
  Future<String> search(String query) async {
    final now = DateTime.now();
    
    // 1. Vérification du cache
    if (_cache.containsKey(query)) {
      final cached = _cache[query]!;
      if (now.difference(cached.timestamp) < _cacheDuration) {
        dev.log('⚡ WEB SEARCH CACHE HIT: $query', name: 'WebSearchService');
        return cached.result;
      }
    }

    final serper = _serperKey;
    if (serper != null && serper.isNotEmpty) {
      try {
        final result = await _searchSerper(query);
        if (result.isNotEmpty && !result.contains('ERROR')) {
          _cache[query] = _CachedSearch(result, now);
          return result;
        }
      } catch (e) {
        dev.log('⚠️ Serper failed, falling back to Tavily: $e');
      }
    }

    final tavily = _tavilyKey;
    if (tavily != null && tavily.isNotEmpty) {
      try {
        final result = await _searchTavily(query);
        _cache[query] = _CachedSearch(result, now);
        return result;
      } catch (e) {
        dev.log('❌ Tavily fallback also failed: $e');
      }
    }

    dev.log('⚠️ Aucune recherche web n\'a abouti (Serper/Tavily)');
    return 'WEB SEARCH UNAVAILABLE: No valid API responses.';
  }

  /// Vide le cache des recherches web
  static void clearCache() {
    _cache.clear();
    dev.log('🗑️ WEB SEARCH CACHE CLEARED', name: 'WebSearchService');
  }

  Future<String> _searchSerper(String query) async {
    try {
      final response = await http.post(
        Uri.parse('https://google.serper.dev/search'),
        headers: {
          'X-API-KEY': _serperKey!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'q': query,
          'num': 5,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final organic = data['organic'] as List? ?? [];
        
        String result = '### WEB RESULTS FOR: $query\n';
        for (var item in organic) {
          result += '- ${item['title']}: ${item['snippet']} (${item['link']})\n';
        }

        // Mettre en cache
        _cache[query] = _CachedSearch(result, DateTime.now());
        
        return result;
      }
      return 'Serper.dev error: ${response.statusCode}';
    } catch (e) {
      return 'Serper.dev Exception: $e';
    }
  }

  Future<String> _searchTavily(String query) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.tavily.com/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': _tavilyKey!,
          'query': query,
          'search_depth': 'basic',
          'max_results': 5,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        
        String result = '### TAVILY ANALYSIS FOR: $query\n';
        for (var item in results) {
          result += '- ${item['title']}: ${item['content']} (${item['url']})\n';
        }

        // Mettre en cache
        _cache[query] = _CachedSearch(result, DateTime.now());

        return result;
      }
      return 'Tavily error: ${response.statusCode}';
    } catch (e) {
      return 'Tavily Exception: $e';
    }
  }
}

class _CachedSearch {
  final String result;
  final DateTime timestamp;
  _CachedSearch(this.result, this.timestamp);
}
