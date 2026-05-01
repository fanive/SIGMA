/// Interface abstraite pour tous les providers AI
/// Permet de supporter Gemini, OpenAI, Claude, etc.
abstract class AIProvider {
  /// Génère du contenu à partir d'un prompt
  /// Retourne une réponse JSON string
  Future<String> generateContent({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = true,
    bool? useThinking,
    List<Map<String, dynamic>>? tools,
    Future<String> Function(String toolName, Map<String, dynamic> arguments)? onToolCall,
  });

  /// Génère un stream de contenu (pour le streaming)
  Stream<String> generateStream({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = false,
  });

  /// Nom du provider (pour logs et analytics)
  String get providerName;

  /// Nom du modèle utilisé
  String get modelName;
}
