import 'package:flutter/material.dart';

class LogoResolver {
  /// Resolves the best available logo URL for a given ticker.
  /// Priority: 
  /// 1. Provided URL (if high quality)
  /// 2. Clearbit API (very reliable for US stocks)
  /// 3. Logo.dev (backup)
  /// 4. FMP (backup)
  static String resolve(String ticker, {String? providedUrl}) {
    final symbol = ticker.toUpperCase().trim();
    if (symbol.isEmpty) return '';

    // If we have a high-quality provided URL, use it
    if (providedUrl != null && 
        providedUrl.isNotEmpty && 
        !providedUrl.contains('financialmodelingprep.com') &&
        !providedUrl.contains('eodhd.com')) {
      return providedUrl;
    }

    // Clean symbol for external APIs (remove exchange suffixes)
    final baseSymbol = symbol.split('.').first;

    // We use a multi-stage fallback approach in the UI if possible, 
    // but here we return the most likely candidate.
    // Clearbit is excellent for major tickers.
    return 'https://logo.clearbit.com/$baseSymbol.com?size=128&format=png';
  }

  /// Returns a list of fallback URLs to try in order.
  static List<String> getFallbackChain(String ticker) {
    final symbol = ticker.toUpperCase().trim();
    final baseSymbol = symbol.split('.').first;
    
    return [
      'https://logo.clearbit.com/$baseSymbol.com',
      'https://financialmodelingprep.com/image-stock/$baseSymbol.png',
      'https://img.logo.dev/ticker/$baseSymbol?token=pk_test_placeholder', // Requires token in production
    ];
  }
}
