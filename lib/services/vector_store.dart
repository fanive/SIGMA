import 'dart:math';
import 'dart:developer' as dev;
import 'package:hive_flutter/hive_flutter.dart';

/// Types de documents stockés dans le VectorStore.
enum DocumentType { analysis, report, chat, news, catalyst }

/// Un document vectorisé avec ses métadonnées.
class VectorDocument {
  final String id;
  final String content;
  final List<double> embedding;
  final DocumentType type;
  final String ticker;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  VectorDocument({
    required this.id,
    required this.content,
    required this.embedding,
    required this.type,
    required this.ticker,
    required this.createdAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'embedding': embedding,
        'type': type.index,
        'ticker': ticker,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
      };

  factory VectorDocument.fromJson(Map<String, dynamic> json) {
    return VectorDocument(
      id: json['id'] as String,
      content: json['content'] as String,
      embedding: (json['embedding'] as List).cast<num>().map((n) => n.toDouble()).toList(),
      type: DocumentType.values[json['type'] as int],
      ticker: json['ticker'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// Résultat d'une recherche vectorielle avec score de similarité.
class SearchResult {
  final VectorDocument document;
  final double score; // 0.0 to 1.0 (cosine similarity)

  SearchResult({required this.document, required this.score});
}

/// VectorStore local basé sur Hive.
/// Stocke les embeddings et effectue des recherches par similarité cosinus.
class VectorStore {
  static const String _boxName = 'sigma_vectors_v1';
  Box? _box;
  final List<VectorDocument> _cache = [];

  /// Initialise le VectorStore — doit être appelé au démarrage.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadCache();
    dev.log('VectorStore initialized: ${_cache.length} documents', name: 'VectorStore');
  }

  void _loadCache() {
    _cache.clear();
    for (final key in _box!.keys) {
      try {
        final data = Map<String, dynamic>.from(_box!.get(key) as Map);
        _cache.add(VectorDocument.fromJson(data));
      } catch (e) {
        dev.log('Failed to load doc $key: $e', name: 'VectorStore');
      }
    }
  }

  /// Nombre de documents stockés.
  int get count => _cache.length;

  /// Ajoute un document vectorisé. Remplace si même ID existe.
  Future<void> add(VectorDocument doc) async {
    await _box?.put(doc.id, doc.toJson());
    _cache.removeWhere((d) => d.id == doc.id);
    _cache.add(doc);
  }

  /// Ajoute plusieurs documents en batch.
  Future<void> addAll(List<VectorDocument> docs) async {
    final entries = <String, Map<String, dynamic>>{};
    for (final doc in docs) {
      entries[doc.id] = doc.toJson();
      _cache.removeWhere((d) => d.id == doc.id);
      _cache.add(doc);
    }
    await _box?.putAll(entries);
  }

  /// Supprime un document par ID.
  Future<void> remove(String id) async {
    await _box?.delete(id);
    _cache.removeWhere((d) => d.id == id);
  }

  /// Recherche les documents les plus similaires au vecteur query.
  ///
  /// [topK] — nombre de résultats max
  /// [minScore] — score minimum de similarité (0.0 à 1.0)
  /// [filterType] — filtre optionnel par type de document
  /// [filterTicker] — filtre optionnel par ticker
  List<SearchResult> search(
    List<double> queryEmbedding, {
    int topK = 5,
    double minScore = 0.3,
    DocumentType? filterType,
    String? filterTicker,
  }) {
    if (_cache.isEmpty || queryEmbedding.isEmpty) return [];

    final results = <SearchResult>[];

    for (final doc in _cache) {
      // Apply filters
      if (filterType != null && doc.type != filterType) continue;
      if (filterTicker != null &&
          doc.ticker.toUpperCase() != filterTicker.toUpperCase()) {
        continue;
      }

      final score = _cosineSimilarity(queryEmbedding, doc.embedding);
      if (score >= minScore) {
        results.add(SearchResult(document: doc, score: score));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(topK).toList();
  }

  /// Récupère tous les documents pour un ticker donné.
  List<VectorDocument> getByTicker(String ticker) {
    return _cache
        .where((d) => d.ticker.toUpperCase() == ticker.toUpperCase())
        .toList();
  }

  /// Supprime les documents plus vieux que [maxAge].
  Future<int> cleanup({Duration maxAge = const Duration(days: 30)}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    final toRemove = _cache.where((d) => d.createdAt.isBefore(cutoff)).toList();
    for (final doc in toRemove) {
      await _box?.delete(doc.id);
    }
    _cache.removeWhere((d) => d.createdAt.isBefore(cutoff));
    if (toRemove.isNotEmpty) {
      dev.log('Cleaned up ${toRemove.length} expired documents', name: 'VectorStore');
    }
    return toRemove.length;
  }

  /// Supprime tout le contenu du store.
  Future<void> clear() async {
    await _box?.clear();
    _cache.clear();
  }

  // ── Cosine Similarity ───────────────────────────────────────────────────

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 0.0;

    return dotProduct / denominator;
  }
}
