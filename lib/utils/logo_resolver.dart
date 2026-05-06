class LogoResolver {
  static const String _backendBase = 'https://sigma-yfinance-api.onrender.com';

  static String endpoint(String ticker, {bool json = false}) {
    final symbol = ticker.toUpperCase().trim();
    if (symbol.isEmpty) return '';
    final encoded = Uri.encodeComponent(symbol);
    final suffix = json ? '?json=true' : '';
    return '$_backendBase/search/logo/$encoded$suffix';
  }

  /// Resolves the best available logo URL for a given ticker.
  /// Uses SIGMA's backend logo endpoint first so every UI surface shares the same source.
  static String resolve(String ticker, {String? providedUrl}) {
    final symbol = ticker.toUpperCase().trim();
    if (symbol.isEmpty) return '';

    final normalized = normalizeUrl(providedUrl);
    if (normalized.isNotEmpty) {
      return normalized;
    }

    return 'https://assets.parqet.com/logos/symbol/$symbol?format=png';
  }

  static String normalizeUrl(String? url) {
    final clean = url?.trim() ?? '';
    if (clean.isEmpty || !clean.startsWith('http')) return '';
    if (clean.contains('eodhd.com')) return '';
    if (clean.contains('assets.parqet.com') && clean.contains('format=svg')) {
      return clean.replaceAll('format=svg', 'format=png');
    }
    if (clean.toLowerCase().endsWith('.svg')) return '';
    return clean;
  }

  /// Returns a list of fallback URLs to try in order.
  static List<String> getFallbackChain(String ticker) {
    final symbol = ticker.toUpperCase().trim();
    final baseSymbol = symbol.split('.').first;

    return [
      'https://assets.parqet.com/logos/symbol/$symbol?format=png',
      'https://financialmodelingprep.com/image-stock/$baseSymbol.png',
      endpoint(symbol),
      'https://logo.clearbit.com/$baseSymbol.com',
    ];
  }
}
