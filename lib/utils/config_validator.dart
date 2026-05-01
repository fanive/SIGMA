// ignore_for_file: avoid_print
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/ai_config.dart';

/// Script de test pour vérifier la configuration .env
class ConfigValidator {
  static Future<void> validate() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 SIGMA Research - Validation de Configuration');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // 1. Vérifier le provider
    final provider = dotenv.env['AI_PROVIDER'] ?? AIConfig.defaultProvider;
    print('📌 Provider sélectionné: $provider');

    // 2. Vérifier les clés API
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final copilotKey = dotenv.env['GITHUB_COPILOT_API_KEY'] ?? '';

    print('\n🔑 Clés API:');
    print(
      '  - Gemini: ${geminiKey.isNotEmpty ? "✅ Configurée (${geminiKey.substring(0, 10)}...)" : "❌ Manquante"}',
    );
    print(
      '  - GitHub Copilot: ${copilotKey.isNotEmpty ? "✅ Configurée (${copilotKey.length} caractères)" : "❌ Manquante"}',
    );

    // 3. Vérifier les modèles
    final stockModel = dotenv.env['STOCK_MODEL'] ?? AIConfig.defaultStockModel;
    final marketModel =
        dotenv.env['MARKET_MODEL'] ?? AIConfig.defaultMarketModel;

    print('\n🤖 Modèles configurés:');
    print('  - Stocks: $stockModel');
    print('  - Market: $marketModel');

    // 4. Résolution des modèles
    final stockModelFull = AIConfig.getModelName(provider, stockModel);
    final marketModelFull = AIConfig.getModelName(provider, marketModel);

    print('\n📊 Modèles résolus:');
    print('  - Stocks: $stockModelFull');
    print('  - Market: $marketModelFull');

    // 5. Validation
    print('\n✅ Statut de Configuration:\n');

    bool isValid = true;

    if (provider == 'gemini' && geminiKey.isEmpty) {
      print('❌ ERREUR: Provider Gemini sélectionné mais clé manquante!');
      print('   → Ajoutez GEMINI_API_KEY dans .env');
      isValid = false;
    }

    if ((provider == 'github-copilot' ||
            provider == 'openai' ||
            provider == 'claude') &&
        copilotKey.isEmpty) {
      print(
        '❌ ERREUR: Provider GitHub Copilot sélectionné mais clé manquante!',
      );
      print('   → Ajoutez GITHUB_COPILOT_API_KEY dans .env');
      isValid = false;
    }

    if (isValid) {
      print('✅ Configuration valide!');
      print('✅ Provider: $provider');
      print('✅ Modèle Stocks: $stockModelFull');
      print('✅ Modèle Market: $marketModelFull');
      print('\n🚀 Vous pouvez lancer l\'application!');
    } else {
      print('\n⚠️  Corrigez les erreurs ci-dessus dans votre fichier .env');
      print('   Consultez .env.example pour voir un exemple de configuration');
    }

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Affiche des suggestions selon la configuration
  static void showSuggestions() {
    final provider = dotenv.env['AI_PROVIDER'] ?? AIConfig.defaultProvider;

    print('💡 SUGGESTIONS:\n');

    if (provider == 'gemini') {
      print('  ℹ️  Vous utilisez Gemini (gratuit)');
      print(
        '  💰 Pour tester GPT-4 ou Claude, ajoutez votre clé GitHub Copilot',
      );
      print('     et changez AI_PROVIDER=github-copilot dans .env\n');
    }

    if (provider == 'github-copilot') {
      final stockModel = dotenv.env['STOCK_MODEL'] ?? 'gpt-4o';
      print('  ⚡ Modèles recommandés pour GitHub Copilot:');
      print('     - gpt-4o (meilleur rapport qualité/vitesse)');
      print('     - sonnet (Claude 3.5 Sonnet - excellent raisonnement)');
      print('     - gpt-4o-mini (économique)\n');

      if (stockModel == 'gpt-3.5') {
        print('  ⚠️  GPT-3.5 peut donner des résultats moins précis.');
        print('     Essayez gpt-4o pour de meilleurs résultats.\n');
      }
    }
  }
}
