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

  /// Modèles Ollama Cloud — https://ollama.com/search?c=cloud
  /// Mis à jour: 20 Mars 2026
  static const Map<String, String> ollamaModels = {
    'minimax-m2.7-cloud': 'minimax-m2.7:cloud',
    'nemotron-3-super-cloud': 'nemotron-3-super:cloud',
    'qwen3.5-cloud': 'qwen3.5:cloud',
  };

  static const Map<String, String> nvidiaModels = {
    'deepseek-v4-flash': 'deepseek-ai/deepseek-v4-flash',
    'mistral': 'mistralai/mistral-medium-3.5-128b',
    'mistral-small': 'mistralai/mistral-medium-3.5-128b',
    'glm-5.1': 'z-ai/glm-5.1',
    'gemma4-31b': 'google/gemma-4-31b-it',
    'llama3.3-70b': 'nvidia/llama-3.1-nemotron-70b-instruct',
  };

  /// Chaîne de fallback automatique pour NVIDIA NIM avec timeout rapide (10s)
  static const List<String> nvidiaFallbackChain = [
    'deepseek-ai/deepseek-v4-flash',
    'mistralai/mistral-small-24b-instruct-2501',
    'nvidia/llama-3.1-nemotron-70b-instruct',
    'mistralai/mistral-large-2-instruct',
  ];

  /// Modèles Ollama avec accès web/cloud (données en temps réel)
  static const Set<String> ollamaWebCapableModels = {
    'minimax-m2.7:cloud',
    'nemotron-3-super:cloud',
    'qwen3.5:cloud',
    'qwen3.5:122b',
    'nemotron-3-nano:cloud',
  };

  /// Vérifie si un modèle Ollama a l'accès web/cloud
  static bool isOllamaWebCapable(String modelName) =>
      ollamaWebCapableModels.contains(modelName) ||
      modelName.contains(':cloud');

  /// Chaîne de fallback automatique pour Ollama Cloud.
  static const List<String> ollamaFallbackChain = [
    'minimax-m2.7:cloud',
    'glm-5.1:cloud',
    'qwen3.5:122b',
    'kimi-k2.5:cloud',
  ];

  /// Retourne le nom d'affichage d'un modèle pour l'UI
  static String ollamaModelDisplayName(String modelId) {
    if (modelId.contains('minimax-m2.7')) return 'MiniMax M2.7';
    if (modelId.contains('nemotron-3-super')) return 'Nemotron 3 Super (120B)';
    if (modelId.contains('nemotron-3-nano')) return 'Nemotron 3 Nano';
    if (modelId.contains('qwen3.5')) return 'Qwen3.5';
    if (modelId.contains('kimi-k2.5')) return 'Kimi K2.5';
    if (modelId.contains('glm-5.1')) return 'GLM-5.1 (Reasoning)';
    if (modelId.contains('deepseek-v3.2')) return 'DeepSeek V3.2';
    return modelId;
  }

  /// Retourne le nom d'affichage d'un modèle NVIDIA pour l'UI
  static String nvidiaModelDisplayName(String modelId) {
    if (modelId.contains('deepseek-v4')) return 'DeepSeek V4 Flash';
    if (modelId.contains('minimax')) return 'MiniMax M2.7 (NVIDIA)';
    if (modelId.contains('mistral-small')) return 'Mistral Small (119B)';
    if (modelId.contains('llama-3.1-nemotron')) return 'Llama 3.1 Nemotron';
    if (modelId.contains('mistral-large')) return 'Mistral Large';
    if (modelId.contains('glm')) return 'GLM-5.1 (Reasoning)';
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
