import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service d'embeddings NVIDIA — llama-nemotron-embed-1b-v2
/// Convertit du texte en vecteurs de dimension 1024 pour la recherche sémantique.
class EmbeddingService {
  static const String _endpoint =
      'https://integrate.api.nvidia.com/v1/embeddings';
  static const String _model = 'nvidia/llama-nemotron-embed-1b-v2';

  final String _apiKey;

  EmbeddingService({required String apiKey}) : _apiKey = apiKey;

  /// Crée une instance à partir des variables d'environnement.
  factory EmbeddingService.fromEnv() {
    final key = dotenv.env['NVIDIA_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception('NVIDIA_API_KEY not set in .env');
    }
    return EmbeddingService(apiKey: key);
  }

  /// Génère un embedding pour une requête utilisateur (input_type: "query").
  Future<List<double>> embedQuery(String text) async {
    return _embed(text, inputType: 'query');
  }

  /// Génère un embedding pour un document à indexer (input_type: "passage").
  Future<List<double>> embedDocument(String text) async {
    return _embed(text, inputType: 'passage');
  }

  /// Génère des embeddings en batch pour plusieurs documents.
  Future<List<List<double>>> embedBatch(List<String> texts,
      {String inputType = 'passage'}) async {
    if (texts.isEmpty) return [];
    // NVIDIA API supports batch input
    final body = {
      'input': texts,
      'model': _model,
      'input_type': inputType,
      'encoding_format': 'float',
      'truncate': 'NONE',
    };

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    _checkResponse(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List;
    return data
        .map((item) => (item['embedding'] as List).cast<num>().map((n) => n.toDouble()).toList())
        .toList();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
        'Accept': 'application/json',
      };

  Future<List<double>> _embed(String text, {required String inputType}) async {
    if (text.trim().isEmpty) return [];

    // Truncate very long texts to avoid API limits (~512 tokens optimal)
    final truncated =
        text.length > 2000 ? text.substring(0, 2000) : text;

    final body = {
      'input': [truncated],
      'model': _model,
      'input_type': inputType,
      'encoding_format': 'float',
      'truncate': 'NONE',
    };

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    _checkResponse(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List;
    if (data.isEmpty) throw Exception('Empty embedding response');

    final embedding = data[0]['embedding'] as List;
    return embedding.cast<num>().map((n) => n.toDouble()).toList();
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception('NVIDIA API key invalid (401).');
    }
    if (response.statusCode == 402) {
      throw Exception('NVIDIA credits exhausted (402).');
    }
    if (response.statusCode == 429) {
      throw Exception('NVIDIA rate limit exceeded (429). Retry later.');
    }
    if (response.statusCode != 200) {
      dev.log('Embedding API error ${response.statusCode}: ${response.body}',
          name: 'EmbeddingService');
      throw Exception(
          'Embedding API Error ${response.statusCode}');
    }
  }
}
