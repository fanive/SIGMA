import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:quantum_invest/services/fmp_service.dart';
import 'package:quantum_invest/services/sentiment_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Keep tests runnable even when .env is missing on CI/device.
    }
  });

  testWidgets('Yahoo Finance chart endpoint responds', (tester) async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1mo&interval=1d',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    expect(response.statusCode, 200);

    final dynamic decoded = jsonDecode(response.body);
    expect(decoded is Map<String, dynamic>, true);

    final result = decoded['chart']?['result'];
    expect(result is List && result.isNotEmpty, true);
  });

  testWidgets('Fear & Greed provider responds', (tester) async {
    final service = SentimentService();
    final fearGreed = await service
      .fetchFearGreed()
      .timeout(const Duration(seconds: 20), onTimeout: () => null);

    expect(fearGreed != null, true,
        reason: 'Sentiment endpoint should return a non-null payload');
  });

  testWidgets('FMP quote works when API key is configured', (tester) async {
    final key = dotenv.env['FMP_API_KEY'] ?? '';
    if (key.isEmpty || key == 'MISSING' || key.contains('example')) {
      return;
    }

    final service = FmpService();
    final quote = await service
        .getCompanyQuote('AAPL')
        .timeout(const Duration(seconds: 20), onTimeout: () => <String, dynamic>{});
    expect(quote.isNotEmpty, true,
        reason: 'FMP_API_KEY is set but quote payload is empty');
  });
}
