/// Configuration centralisée pour les providers AI
/// Support: NVIDIA NIM, Ollama Cloud
class AIConfig {
  // ========================================
  // PROVIDERS DISPONIBLES
  // ========================================

  static const String providerOllama = 'ollama';
  static const String providerNvidia = 'nvidia';

  // ========================================
  // MODÈLES PAR PROVIDER
  // ========================================

  static const Map<String, String> ollamaModels = {
    'minimax-m2.7-cloud': 'minimax-m2.7:cloud',
  };

  static const Map<String, String> nvidiaModels = {
    'deepseek-v4-flash': 'deepseek-ai/deepseek-v4-flash',
  };

  /// Fallback désactivé: NVIDIA NIM est prioritaire et unique.
  static const List<String> nvidiaFallbackChain = [];

  /// Modèles Ollama avec accès web/cloud (données en temps réel)
  static const Set<String> ollamaWebCapableModels = {
    'minimax-m2.7:cloud',
  };

  /// Vérifie si un modèle Ollama a l'accès web/cloud
  static bool isOllamaWebCapable(String modelName) =>
      ollamaWebCapableModels.contains(modelName) ||
      modelName.contains(':cloud');

  /// Fallback désactivé: un seul modèle Ollama conservé.
  static const List<String> ollamaFallbackChain = [];

  /// Retourne le nom d'affichage d'un modèle pour l'UI
  static String ollamaModelDisplayName(String modelId) {
    if (modelId.contains('minimax-m2.7')) return 'MiniMax M2.7';
    return modelId;
  }

  /// Retourne le nom d'affichage d'un modèle NVIDIA pour l'UI
  static String nvidiaModelDisplayName(String modelId) {
    if (modelId.contains('deepseek-v4')) return 'DeepSeek V4 Flash';
    return modelId.split('/').last;
  }

  // ========================================
  // CONFIGURATION PAR DÉFAUT
  // ========================================

  static const String defaultProvider = providerNvidia;
  static const String defaultStockModel = 'deepseek-v4-flash';
  static const String defaultMarketModel = 'deepseek-v4-flash';
  static const String defaultNvidiaModel = 'deepseek-v4-flash';

  // ========================================
  // ENDPOINTS
  // ========================================

  /// Ollama Cloud — https://ollama.com/api
  static const String ollamaBaseUrl = 'https://ollama.com/api/chat';

  static const String nvidiaBaseUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  // ========================================
  // MÉTHODES UTILITAIRES
  // ========================================

  /// Récupère le nom complet du modèle selon le provider
  static String getModelName(String provider, String modelKey) {
    switch (provider) {
      case providerOllama:
        return ollamaModels[modelKey] ?? modelKey;
      case providerNvidia:
        return nvidiaModels[modelKey] ?? modelKey;
      default:
        return modelKey;
    }
  }

  /// Récupère l'endpoint pour un provider donné
  static String getEndpoint(String provider) {
    switch (provider) {
      case providerOllama:
        return ollamaBaseUrl;
      case providerNvidia:
        return nvidiaBaseUrl;
      default:
        return nvidiaBaseUrl;
    }
  }
}
