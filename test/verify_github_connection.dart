// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🔍 TEST DE CONNEXION GITHUB MODELS (ISOLÉ)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // 1. Lire le fichier .env
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ ERREUR: Fichier .env non trouvé à la racine.');
    return;
  }

  String apiKey = '';
  final lines = envFile.readAsLinesSync();
  for (var line in lines) {
    if (line.startsWith('GITHUB_COPILOT_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
    }
  }

  if (apiKey.isEmpty) {
    print('❌ ERREUR: Clé GITHUB_COPILOT_API_KEY non trouvée dans .env');
    return;
  }

  print('✅ Clé API chargée: ${apiKey.substring(0, 10)}...');

  // 2. Configuration de la requête
  final url = Uri.parse('https://models.github.ai/inference/chat/completions');
  // Note: Si le modèle "gpt-4o" ne fonctionne pas, essayez "gpt-4o-mini" ou "Phi-3-medium-4k-instruct"
  const model = 'gpt-4o';

  print('📡 Tentative de connexion à: $url');
  print('🤖 Modèle testé: $model');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'messages': [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {
            'role': 'user',
            'content':
                'Réponds simplement "CONNEXION RÉUSSIE" si tu me reçois.',
          },
        ],
        'model': model,
        'temperature': 0.7,
        'max_tokens': 50,
      }),
    );

    print('\n📨 Réponse reçue (Code ${response.statusCode})');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      print('\n🎉 SUCCÈS ! Le modèle a répondu :');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print(content);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print(
        '\n✅ Votre clé fonctionne et l\'application peut communiquer avec GitHub Models.',
      );
    } else {
      print('\n❌ ÉCHEC DE LA REQUÊTE');
      print('Erreur: ${response.statusCode}');
      print('Corps de la réponse: ${response.body}');
      print(
        '\n🔍 Vérifiez votre clé API et assurez-vous d\'avoir accès à GitHub Models.',
      );
    }
  } catch (e) {
    print('\n❌ ERREUR TECHNIQUE');
    print(e);
  }
}
