import 'dart:developer' as dev;
import '../models/sigma_models.dart';
import 'embedding_service.dart';
import 'vector_store.dart';

/// RAG Service — Retrieval-Augmented Generation pour SIGMA.
///
/// Orchestre l'embedding, le stockage et la recherche sémantique
/// pour donner une mémoire persistante à l'assistant IA.
class RAGService {
  final EmbeddingService _embedding;
  final VectorStore _vectorStore;

  RAGService({
    required EmbeddingService embedding,
    required VectorStore vectorStore,
  })  : _embedding = embedding,
        _vectorStore = vectorStore;

  /// Nombre de documents en mémoire.
  int get documentCount => _vectorStore.count;

  // ═══════════════════════════════════════════════════════════════════════════
  // INDEXATION — Stocke les données sous forme de vecteurs
  // ═══════════════════════════════════════════════════════════════════════════

  /// Indexe une analyse complète pour un ticker.
  Future<void> indexAnalysis(AnalysisData analysis) async {
    try {
      final ticker = analysis.ticker;
      final text = _buildAnalysisText(analysis);
      if (text.length < 20) return;

      final embedding = await _embedding.embedDocument(text);
      if (embedding.isEmpty) return;

      final doc = VectorDocument(
        id: 'analysis_${ticker}_${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        embedding: embedding,
        type: DocumentType.analysis,
        ticker: ticker,
        createdAt: DateTime.now(),
        metadata: {
          'verdict': analysis.verdict,
          'score': analysis.sigmaScore,
          'price': analysis.price,
        },
      );

      await _vectorStore.add(doc);
      dev.log('Indexed analysis for $ticker (${text.length} chars)',
          name: 'RAGService');
    } catch (e) {
      dev.log('Failed to index analysis: $e', name: 'RAGService');
    }
  }

  /// Indexe un rapport financier généré.
  Future<void> indexReport(String ticker, String reportText,
      {String? rating, double? priceTarget}) async {
    try {
      if (reportText.length < 30) return;

      // Truncate for embedding but store full text
      final embedding = await _embedding.embedDocument(reportText);
      if (embedding.isEmpty) return;

      final doc = VectorDocument(
        id: 'report_${ticker}_${DateTime.now().millisecondsSinceEpoch}',
        content: reportText,
        embedding: embedding,
        type: DocumentType.report,
        ticker: ticker,
        createdAt: DateTime.now(),
        metadata: {
          if (rating != null) 'rating': rating,
          if (priceTarget != null) 'priceTarget': priceTarget,
        },
      );

      await _vectorStore.add(doc);
      dev.log('Indexed report for $ticker', name: 'RAGService');
    } catch (e) {
      dev.log('Failed to index report: $e', name: 'RAGService');
    }
  }

  /// Indexe un échange de chat (question + réponse).
  Future<void> indexChatExchange(
      String ticker, String userMessage, String botResponse) async {
    try {
      final text = 'Q: $userMessage\nA: $botResponse';
      if (text.length < 20) return;

      final embedding = await _embedding.embedDocument(text);
      if (embedding.isEmpty) return;

      final doc = VectorDocument(
        id: 'chat_${ticker}_${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        embedding: embedding,
        type: DocumentType.chat,
        ticker: ticker,
        createdAt: DateTime.now(),
        metadata: {'question': userMessage},
      );

      await _vectorStore.add(doc);
    } catch (e) {
      dev.log('Failed to index chat: $e', name: 'RAGService');
    }
  }

  /// Indexe une news de marché pour un ticker.
  Future<void> indexNews(String ticker, NewsArticle news) async {
    try {
      final text = '${news.title}\n${news.summary}';
      if (text.length < 20) return;

      final embedding = await _embedding.embedDocument(text);
      if (embedding.isEmpty) return;

      final doc = VectorDocument(
        id: 'news_${ticker}_${news.url.hashCode}',
        content: text,
        embedding: embedding,
        type: DocumentType.news,
        ticker: ticker,
        createdAt: DateTime.now(),
        metadata: {
          'source': news.source,
          'url': news.url,
          'publishedAt': news.publishedAt,
        },
      );

      await _vectorStore.add(doc);
    } catch (e) {
      dev.log('Failed to index news: $e', name: 'RAGService');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RETRIEVAL — Recherche sémantique de contexte pertinent
  // ═══════════════════════════════════════════════════════════════════════════

  /// Recherche les documents les plus pertinents pour une requête.
  /// Renvoie le texte contextuel formaté pour injection dans le prompt AI.
  Future<String> retrieveContext(
    String query, {
    int topK = 5,
    double minScore = 0.35,
    String? ticker,
    DocumentType? type,
  }) async {
    try {
      final queryEmbedding = await _embedding.embedQuery(query);
      if (queryEmbedding.isEmpty) return '';

      final results = _vectorStore.search(
        queryEmbedding,
        topK: topK,
        minScore: minScore,
        filterTicker: ticker,
        filterType: type,
      );

      if (results.isEmpty) return '';

      final buffer = StringBuffer();
      buffer.writeln('RELEVANT MEMORY (from past interactions):');

      for (final result in results) {
        final doc = result.document;
        final typeLabel = _typeLabel(doc.type);
        final ago = _timeAgo(doc.createdAt);

        buffer.writeln('--- $typeLabel [${doc.ticker}] ($ago, relevance: ${(result.score * 100).toInt()}%) ---');
        // Limit content length per document to avoid bloating the prompt
        final content = doc.content.length > 500
            ? '${doc.content.substring(0, 500)}…'
            : doc.content;
        buffer.writeln(content);
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      dev.log('RAG retrieval error: $e', name: 'RAGService');
      return '';
    }
  }

  /// Recherche rapide — renvoie les résultats bruts pour affichage UI.
  Future<List<SearchResult>> search(
    String query, {
    int topK = 10,
    String? ticker,
  }) async {
    try {
      final queryEmbedding = await _embedding.embedQuery(query);
      if (queryEmbedding.isEmpty) return [];
      return _vectorStore.search(
        queryEmbedding,
        topK: topK,
        minScore: 0.3,
        filterTicker: ticker,
      );
    } catch (e) {
      dev.log('RAG search error: $e', name: 'RAGService');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAINTENANCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Nettoie les documents périmés (>30 jours par défaut).
  Future<int> cleanup({Duration maxAge = const Duration(days: 30)}) async {
    return _vectorStore.cleanup(maxAge: maxAge);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _buildAnalysisText(AnalysisData analysis) {
    final parts = <String>[];
    parts.add('${analysis.ticker} - ${analysis.companyName ?? ""}');
    parts.add('Verdict: ${analysis.verdict} | Score: ${analysis.sigmaScore}/100');
    parts.add('Price: ${analysis.price} | Risk: ${analysis.riskLevel}');

    if (analysis.summary.isNotEmpty) {
      parts.add('Summary: ${analysis.summary}');
    }

    if (analysis.pros.isNotEmpty) {
      parts.add('Pros: ${analysis.pros.take(5).join(", ")}');
    }
    if (analysis.cons.isNotEmpty) {
      parts.add('Cons: ${analysis.cons.take(5).join(", ")}');
    }

    if (analysis.catalysts.isNotEmpty) {
      parts.add('Catalysts: ${analysis.catalysts.take(3).map((c) => c.event).join(", ")}');
    }

    return parts.join('\n');
  }

  String _typeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.analysis:
        return 'ANALYSIS';
      case DocumentType.report:
        return 'REPORT';
      case DocumentType.chat:
        return 'CHAT';
      case DocumentType.news:
        return 'NEWS';
      case DocumentType.catalyst:
        return 'CATALYST';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
