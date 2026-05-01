import '../config/ai_config.dart';
import 'ai_provider_interface.dart';
import 'ai/ollama_provider.dart';
import 'ai/nvidia_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Factory pour créer le bon provider selon la configuration
class AIProviderFactory {
  /// Crée un provider pour l'analyse de stocks
  static AIProvider createStockProvider({
    required String provider,
    required String apiKey,
    String? modelKey,
    String? baseUrlOverride,
  }) {
    final model = modelKey ?? AIConfig.defaultStockModel;
    return _createProvider(provider, apiKey, model, baseUrlOverride: baseUrlOverride);
  }

  /// Crée un provider pour l'analyse de marché
  static AIProvider createMarketProvider({
    required String provider,
    required String apiKey,
    String? modelKey,
    String? baseUrlOverride,
  }) {
    final model = modelKey ?? AIConfig.defaultMarketModel;
    return _createProvider(provider, apiKey, model, baseUrlOverride: baseUrlOverride);
  }

  /// Logique interne de création
  static AIProvider _createProvider(
    String provider,
    String apiKey,
    String modelKey, {
    String? baseUrlOverride,
  }) {
    final modelName = AIConfig.getModelName(provider, modelKey);
    final baseUrl = baseUrlOverride ?? AIConfig.getEndpoint(provider);

    switch (provider) {
      case AIConfig.providerOllama:
        final fallbacks = AIConfig.ollamaFallbackChain
            .where((m) => m != modelName)
            .toList();
        return OllamaProvider(
          apiKey: apiKey,
          modelName: modelName,
          fallbackModels: fallbacks,
          baseUrl: baseUrl,
        );
      
      case AIConfig.providerNvidia:
        final strictEnvModel =
            (dotenv.env['STRICT_ENV_MODEL'] ?? 'true').toLowerCase() == 'true';
        final fallbacks = strictEnvModel
            ? <String>[]
            : AIConfig.nvidiaFallbackChain.where((m) => m != modelName).toList();
        
        final ollamaKey = dotenv.env['OLLAMA_API_KEY'] ?? '';
        final ollamaUrl =
            dotenv.env['OLLAMA_BASE_URL'] ?? AIConfig.ollamaBaseUrl;
        final ollamaModel = dotenv.env['OLLAMA_MODEL'] ?? 'minimax-m2.7-cloud';
        
        final ollamaFallback = OllamaProvider(
          apiKey: ollamaKey,
          modelName: AIConfig.getModelName(AIConfig.providerOllama, ollamaModel),
          fallbackModels: AIConfig.ollamaFallbackChain.where((m) => m != ollamaModel).toList(),
          baseUrl: ollamaUrl,
        );

        return NvidiaProvider(
          apiKey: apiKey,
          modelName: modelName,
          fallbackModels: fallbacks,
          baseUrl: baseUrl,
          crossProviderFallback: strictEnvModel ? null : ollamaFallback,
        );

      default:
        return NvidiaProvider(
          apiKey: apiKey,
          modelName: AIConfig.getModelName(
              AIConfig.providerNvidia, AIConfig.defaultNvidiaModel),
          fallbackModels: AIConfig.nvidiaFallbackChain,
          baseUrl: AIConfig.nvidiaBaseUrl,
        );
    }
  }

  /// Valide qu'une clé API est compatible avec le provider
  static bool validateApiKey(String provider, String apiKey) {
    return apiKey.length > 10;
  }
}
