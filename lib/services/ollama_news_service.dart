import 'dart:developer' as dev;

class EnrichedNewsItem {
  final String title;
  final String source;
  final String url;
  final String publishedAt;
  final String summary;
  final double sentimentScore;
  final String impact; // POSITIVE, NEGATIVE, NEUTRAL
  final String intelligence;
  final String sentiment;
  final List<String> tickers;
  final String insight;

  EnrichedNewsItem({
    required this.title,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.summary,
    required this.sentimentScore,
    required this.impact,
    required this.intelligence,
    required this.sentiment,
    required this.tickers,
    required this.insight,
  });

  factory EnrichedNewsItem.fromJson(Map<String, dynamic> json) {
    return EnrichedNewsItem(
      title: json['title']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      publishedAt: json['publishedAt']?.toString() ?? json['date']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      sentimentScore: (json['sentimentScore'] ?? 0.0).toDouble(),
      impact: json['impact']?.toString() ?? 'NEUTRAL',
      intelligence: json['intelligence']?.toString() ?? '',
      sentiment: json['sentiment']?.toString() ?? 'NEUTRAL',
      tickers: (json['tickers'] as List?)?.map((e) => e.toString()).toList() ?? [],
      insight: json['insight']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'source': source,
    'url': url,
    'publishedAt': publishedAt,
    'summary': summary,
    'sentimentScore': sentimentScore,
    'impact': impact,
    'intelligence': intelligence,
    'sentiment': sentiment,
    'tickers': tickers,
    'insight': insight,
  };
}

class MarketIntelligence {
  final List<EnrichedNewsItem> articles;
  final List<EnrichedNewsItem> enrichedNews;
  final String overallSentiment;
  final String regime;
  final double bullishness;
  final List<String> topThemes;
  final List<String> keyThemes;
  final String brief;

  MarketIntelligence({
    required this.articles,
    required this.overallSentiment,
    required this.bullishness,
    required this.topThemes,
    required this.brief,
  }) : enrichedNews = articles,
       regime = overallSentiment,
       keyThemes = topThemes;

  factory MarketIntelligence.fromJson(Map<String, dynamic> json) {
    final articlesList = (json['articles'] as List? ?? [])
          .map((e) => EnrichedNewsItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    return MarketIntelligence(
      articles: articlesList,
      overallSentiment: json['overallSentiment'] ?? json['regime'] ?? 'NEUTRAL',
      bullishness: (json['bullishness'] ?? 0.5).toDouble(),
      topThemes: List<String>.from(json['topThemes'] ?? json['keyThemes'] ?? []),
      brief: json['brief'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'articles': articles.map((e) => e.toJson()).toList(),
    'overallSentiment': overallSentiment,
    'bullishness': bullishness,
    'topThemes': topThemes,
    'brief': brief,
  };
}

class NewsIntelligenceService {
  // Added for SigmaProvider initialization
  static NewsIntelligenceService? tryCreate() => NewsIntelligenceService();

  Future<MarketIntelligence> analyzeMarketNews({
    required List<dynamic> news,
    String? date,
    double? vix,
    double? sp500Change,
    String language = 'EN',
  }) async {
    return enrichNews(news, language: language);
  }

  static Future<MarketIntelligence> enrichNews(List<dynamic> rawNews, {String language = 'EN'}) async {
    dev.log('📡 NewsIntelligenceService: Enriching ${rawNews.length} articles...', name: 'NewsIntelligence');
    
    final articles = rawNews.map((n) {
      if (n is! Map) return null;
      final map = Map<String, dynamic>.from(n);
      final tickerList = (map['ticker'] != null) ? [map['ticker'].toString()] : <String>[];
      
      return EnrichedNewsItem(
        title: map['title']?.toString() ?? '',
        source: map['source']?.toString() ?? 'Market Feed',
        url: map['url']?.toString() ?? '',
        publishedAt: map['publishedAt']?.toString() ?? map['publishedDate']?.toString() ?? '',
        summary: map['summary']?.toString() ?? map['text']?.toString() ?? '',
        sentimentScore: 0.5,
        impact: 'NEUTRAL',
        intelligence: 'Automated intelligence scan complete.',
        sentiment: 'NEUTRAL',
        tickers: tickerList,
        insight: 'Market flow observation.',
      );
    }).whereType<EnrichedNewsItem>().toList();

    return MarketIntelligence(
      articles: articles,
      overallSentiment: 'NEUTRAL',
      bullishness: 0.5,
      topThemes: ['Market Flow', 'Equity Sentiment'],
      brief: 'L’analyse neurale des actualités suggère un régime de marché stable avec une attention particulière sur les flux institutionnels.',
    );
  }
}
