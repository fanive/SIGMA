import 'dart:developer' as dev;
import 'dart:convert';
import '../ai_provider_interface.dart';

class FallbackProvider implements AIProvider {
  final List<AIProvider> providers;
  int _activeSectorIndex = 0;

  FallbackProvider(this.providers);

  @override
  String get providerName => providers.isNotEmpty 
      ? providers[_activeSectorIndex].providerName 
      : 'None';

  @override
  String get modelName => providers.isNotEmpty 
      ? providers[_activeSectorIndex].modelName 
      : 'None';

  @override
  Future<String> generateContent({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = true,
    bool? useThinking,
    List<Map<String, dynamic>>? tools,
    Future<String> Function(String toolName, Map<String, dynamic> arguments)? onToolCall,
  }) async {
    if (providers.isEmpty) {
      if (jsonMode) {
        return jsonEncode({
          'ticker': 'N/A',
          'companyProfile':
              'Fallback mode: no AI provider is currently configured.',
          'lastUpdated': DateTime.now().toIso8601String(),
          'price': 'N/A',
          'verdict': 'HOLD',
          'riskLevel': 'MEDIUM',
          'sigmaScore': 50,
          'confidence': 0.0,
          'summary':
              'No AI provider is configured or reachable. Please verify API keys and provider settings.',
          'pros': [],
          'cons': [],
          'hiddenSignals': [],
          'catalysts': [],
          'volatility': {
            'ivRank': 'N/A',
            'beta': 'N/A',
            'interpretation': 'N/A',
          },
          'fearAndGreed': {
            'score': 50,
            'label': 'NEUTRAL',
            'interpretation': 'N/A',
          },
          'marketSentiment': {'score': 50, 'label': 'NEUTRAL'},
          'tradeSetup': {
            'entryZone': 'N/A',
            'targetPrice': 'N/A',
            'stopLoss': 'N/A',
            'riskRewardRatio': 'N/A',
          },
          'institutionalActivity': {
            'smartMoneySentiment': 0.5,
            'retailSentiment': 0.5,
            'darkPoolInterpretation': 'N/A',
          },
          'technicalAnalysis': [],
          'projectedTrend': [],
          'financialMatrix': [],
          'sectorPeers': [],
          'topSources': [],
          'analystRecommendations': {},
        });
      }
      return 'Fallback mode: no AI provider is currently configured.';
    }

    Object? lastError;

    for (int i = 0; i < providers.length; i++) {
      final provider = providers[i];
      try {
        final result = await provider.generateContent(
          prompt: prompt,
          systemInstruction: systemInstruction,
          jsonMode: jsonMode,
          useThinking: useThinking,
          tools: tools,
          onToolCall: onToolCall,
        );
        
        // On mémorise l'index du provider qui a réussi pour l'affichage UI
        _activeSectorIndex = i;
        return result;
      } catch (e) {
        lastError = e;
        dev.log('⚠️ [Fallback] ${provider.providerName} failed: $e', name: 'FallbackProvider');
      }
    }

    throw Exception('All AI providers in the fallback chain failed. Last error: $lastError');
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = false,
  }) async* {
    if (providers.isEmpty) {
      yield 'Fallback mode: no AI provider is currently configured.';
      return;
    }

    for (int i = 0; i < providers.length; i++) {
      final provider = providers[i];
      try {
        await for (final chunk in provider.generateStream(
          prompt: prompt,
          systemInstruction: systemInstruction,
          jsonMode: jsonMode,
        )) {
          _activeSectorIndex = i;
          yield chunk;
        }
        return;
      } catch (e) {
        dev.log('⚠️ [Fallback Stream] ${provider.providerName} failed: $e', name: 'FallbackProvider');
      }
    }
    throw Exception('All AI providers in the fallback chain failed for streaming.');
  }
}
