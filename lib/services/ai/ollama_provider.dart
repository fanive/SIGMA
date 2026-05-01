import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../ai_provider_interface.dart';
import 'stream_utils.dart';

// ─── Global queue: Ollama Cloud accepts 1 concurrent request per key ──────────
class _OllamaSemaphore {
  final int maxConcurrent;
  int _running = 0;
  final List<Completer<void>> _waiters = [];

  _OllamaSemaphore(this.maxConcurrent);

  /// Acquire the slot, but give up after [timeoutSeconds] if still waiting.
  Future<void> acquire({int timeoutSeconds = 120}) async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);

    // Timeout so callers never wait forever
    bool completed = false;
    Future.delayed(Duration(seconds: timeoutSeconds), () {
      if (!completed) {
        _waiters.remove(c);
        if (!c.isCompleted) {
          c.completeError(
            TimeoutException(
              'Ollama semaphore: trop de requêtes en attente (>${timeoutSeconds}s). '
              'Réessayez dans quelques secondes.',
            ),
          );
        }
      }
    });

    try {
      await c.future;
      completed = true;
      _running++;
    } catch (_) {
      completed = true;
      rethrow; // propagate TimeoutException
    }
  }

  void release() {
    _running--;
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }
}

/// Internal signal: this model should be skipped, try the next one.
class _TryNextModelException implements Exception {
  final String reason;
  final Object cause;
  _TryNextModelException(this.reason, this.cause);
  @override
  String toString() => 'TryNextModel($reason): $cause';
}

/// Provider pour Ollama Cloud avec fallback automatique de modèles.
///
/// Quand un modèle échoue (timeout, connexion impossible, 404), le suivant
/// dans [fallbackModels] est automatiquement essayé.
///
/// API native Ollama — https://ollama.com/api
class OllamaProvider implements AIProvider {
  final String _apiKey;
  final String _primaryModel;
  final List<String> _fallbackModels;
  final String _baseUrl;

  /// Timeout par modèle avant de basculer sur le suivant (secondes).
  /// Le dernier modèle de la chaîne utilise [_finalModelTimeoutSeconds].
  final int _perModelTimeoutSeconds;
  final int _finalModelTimeoutSeconds;

  // Allow up to 2 concurrent requests; the API handles extra with 429 backoff
  static final _OllamaSemaphore _semaphore = _OllamaSemaphore(2);

  OllamaProvider({
    required String apiKey,
    required String modelName,
    List<String> fallbackModels = const [],
    String baseUrl = 'https://ollama.com/api/chat',
    int perModelTimeoutSeconds = 30,   // bail on each model after 30s
    int finalModelTimeoutSeconds = 90, // last model gets 90s max
  })  : _apiKey = apiKey,
        _primaryModel = modelName,
        _fallbackModels = fallbackModels,
        _baseUrl = baseUrl,
        _perModelTimeoutSeconds = perModelTimeoutSeconds,
        _finalModelTimeoutSeconds = finalModelTimeoutSeconds;

  /// Test the connection to Ollama Cloud.
  /// Returns a map with 'success' (bool), 'message' (String), and optional 'model' (String).
  Future<Map<String, dynamic>> testConnection() async {
    if (_apiKey.isEmpty) {
      return {'success': false, 'message': 'API key is missing. Add OLLAMA_API_KEY to your .env file.'};
    }

    // Validate API key format
    if (_apiKey.length < 10) {
      return {'success': false, 'message': 'API key appears too short. Check OLLAMA_API_KEY in .env.'};
    }

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

      final body = jsonEncode({
        'model': _primaryModel,
        'messages': [
          {'role': 'user', 'content': 'Say hello in one word.'},
        ],
        'stream': false,
      });

      final response = await http
          .post(Uri.parse(_baseUrl), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Connected to Ollama Cloud',
          'model': _primaryModel,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'API key invalid or expired (401). Regenerate at ollama.com → Settings → API Keys.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Model "$_primaryModel" not found (404). Check model name at ollama.com/library.',
        };
      } else {
        return {
          'success': false,
          'message': 'Ollama returned ${response.statusCode}: ${response.body.substring(0, 200)}',
        };
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Connection timed out after 15s. Check your network.'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  @override
  Future<String> generateContent({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = true,
    bool? useThinking,
    List<Map<String, dynamic>>? tools,
    Future<String> Function(String toolName, Map<String, dynamic> arguments)? onToolCall,
    int semaphoreTimeoutSeconds = 90,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'OLLAMA_API_KEY missing. Add your Ollama Cloud key to .env',
      );
    }

    await _semaphore.acquire(timeoutSeconds: semaphoreTimeoutSeconds);
    try {
      return await _generateWithFallback(
        prompt: prompt,
        systemInstruction: systemInstruction,
        jsonMode: jsonMode,
        useThinking: useThinking,
      );
    } finally {
      _semaphore.release();
    }
  }

  /// Essaie chaque modèle dans l'ordre. Bascule au suivant si le courant
  /// est trop lent, introuvable ou inaccessible.
  Future<String> _generateWithFallback({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = true,
    bool? useThinking,
  }) async {
    // Build prioritized model chain: primary first, then fallbacks (dedup)
    final chain = [_primaryModel, ..._fallbackModels]
        .fold<List<String>>([], (acc, m) {
          if (!acc.contains(m)) acc.add(m);
          return acc;
        });

    Object? lastError;

    for (int i = 0; i < chain.length; i++) {
      final model = chain[i];
      final isLastModel = i == chain.length - 1;
      final timeoutSeconds =
          isLastModel ? _finalModelTimeoutSeconds : _perModelTimeoutSeconds;

      dev.log(
        '◆ Ollama: trying model "$model" (timeout ${timeoutSeconds}s, '
        '${i + 1}/${chain.length})',
        name: 'OllamaProvider',
      );

      try {
        final result = await _sendToModel(
          model: model,
          prompt: prompt,
          systemInstruction: systemInstruction,
          jsonMode: jsonMode,
          timeoutSeconds: timeoutSeconds,
          useThinking: useThinking,
        );
        if (i > 0) {
          dev.log(
            '✓ Ollama: succeeded with fallback model "$model"',
            name: 'OllamaProvider',
          );
        }
        return result;
      } on _TryNextModelException catch (e) {
        lastError = e.cause;
        if (!isLastModel) {
          dev.log(
            '⚡ Ollama: "$model" — ${e.reason}. '
            'Switching to "${chain[i + 1]}"...',
            name: 'OllamaProvider',
          );
          continue; // try next model
        }
        // Last model also failed
        throw Exception(
          'Tous les modèles Ollama ont échoué. Dernier: "$model" — ${e.reason}. '
          'Vérifiez votre connexion et la disponibilité des modèles.',
        );
      }
    }

    if (lastError is Exception) throw lastError;
    throw Exception('Ollama: aucun modèle disponible. $lastError');
  }

  /// Envoie la requête à un modèle spécifique avec retry sur 429/5xx.
  /// Lance [_TryNextModelException] pour "model unavailable" errors.
  Future<String> _sendToModel({
    required String model,
    required String prompt,
    required String systemInstruction,
    required bool jsonMode,
    required int timeoutSeconds,
    bool? useThinking,
    int maxRetries = 3,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': prompt},
      ],
      'stream': false,
    };
    if (jsonMode) body['format'] = 'json';
    
    // Note: Ollama Cloud uses native 'think' option, NOT chat_template_kwargs.
    // chat_template_kwargs is NVIDIA-specific and causes errors on Ollama.
    // Ollama thinking models handle this internally.

    final bodyEncoded = jsonEncode(body);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(Uri.parse(_baseUrl), headers: headers, body: bodyEncoded)
            .timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 429) {
          final retryAfter = int.tryParse(
                response.headers['retry-after'] ?? '',
              ) ??
              (4 * (attempt + 1));
          if (attempt < maxRetries) {
            dev.log(
              '⏳ Ollama 429 on "$model" — retrying in ${retryAfter}s '
              '(attempt ${attempt + 1}/$maxRetries)...',
              name: 'OllamaProvider',
            );
            await Future.delayed(Duration(seconds: retryAfter));
            continue;
          }
          // Rate limit exhausted — don't switch model, propagate
          throw Exception(
            'Ollama 429 — rate limit atteint pour "$model". '
            'Attendez quelques secondes.',
          );
        }

        if (response.statusCode == 401) {
          throw Exception(
            'Clé API Ollama invalide ou expirée (401). '
            'Vérifiez OLLAMA_API_KEY dans votre .env',
          );
        }

        if (response.statusCode == 404) {
          // Model not available on this account — switch model
          throw _TryNextModelException(
            'modèle introuvable (404)',
            Exception(
              'Modèle "$model" introuvable sur Ollama Cloud. '
              'Vérifiez sur https://ollama.com/library',
            ),
          );
        }

        if (response.statusCode >= 500) {
          if (attempt < maxRetries) {
            final delay = 3 * (attempt + 1);
            dev.log(
              '⏳ Ollama ${response.statusCode} on "$model" — '
              'retrying in ${delay}s...',
              name: 'OllamaProvider',
            );
            await Future.delayed(Duration(seconds: delay));
            continue;
          }
          // Persistent 5xx — switch model
          throw _TryNextModelException(
            'erreur serveur (${response.statusCode})',
            Exception('Ollama ${response.statusCode}: ${response.body}'),
          );
        }

        if (response.statusCode != 200) {
          throw Exception(
            'Erreur Ollama Cloud (${response.statusCode}): ${response.body}',
          );
        }

        // ── Parse response ────────────────────────────────────────────────
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception(
            'Format de réponse invalide Ollama Cloud: ${response.body}',
          );
        }

        // Format natif Ollama : message.content
        final message = decoded['message'] as Map<String, dynamic>?;
        if (message == null) {
          final choices = decoded['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              return _stripReasoningBlocks(content);
            }
          }
          throw Exception('Réponse vide de Ollama Cloud (model: $model)');
        }

        final content = message['content'] as String?;
        if (content == null || content.isEmpty) {
          throw Exception(
            'Contenu vide dans la réponse Ollama Cloud (model: $model)',
          );
        }

        return _stripReasoningBlocks(content);
      } on _TryNextModelException {
        rethrow; // propagate to _generateWithFallback
      } on TimeoutException catch (e) {
        // Timeout → switch to next model
        throw _TryNextModelException(
          'timeout après ${timeoutSeconds}s',
          e,
        );
      } on http.ClientException catch (e) {
        // Connection failure — retry once, then switch model
        if (attempt < 1) {
          dev.log(
            '⚠️ Ollama connection error on "$model" (attempt ${attempt + 1}), '
            'retrying once...',
            name: 'OllamaProvider',
          );
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        throw _TryNextModelException(
          'connexion impossible',
          Exception(
            'Impossible de joindre Ollama Cloud pour "$model". '
            'Détail: $e',
          ),
        );
      }
    }
    throw _TryNextModelException(
      'max retries atteint',
      Exception('Ollama "$model": max retries reached'),
    );
  }

  /// Strips <think>...</think> and similar reasoning blocks.
  static String _stripReasoningBlocks(String content) {
    String s = content;
    s = s.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
    s = s.replaceAll(
        RegExp(r'<thinking>.*?</thinking>', dotAll: true), '').trim();
    if (!s.startsWith('{') && s.contains('{')) {
      final idx = s.indexOf('{');
      if (idx < 2000) s = s.substring(idx);
    }
    return s;
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = false,
  }) {
    final rawController = StreamController<String>();
    _runOllamaStream(
      prompt: prompt,
      systemInstruction: systemInstruction,
      jsonMode: jsonMode,
      controller: rawController,
    );
    return stripThinkBlocks(rawController.stream);
  }

  Future<void> _runOllamaStream({
    required String prompt,
    required String systemInstruction,
    required bool jsonMode,
    required StreamController<String> controller,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = {
      'model': _primaryModel,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': prompt},
      ],
      'stream': true,
    };
    if (jsonMode) body['format'] = 'json';

    final request = http.Request('POST', Uri.parse(_baseUrl))
      ..headers.addAll(headers)
      ..body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        controller.addError(
            Exception('Ollama Stream Error ${response.statusCode}'));
        return;
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final decoded = jsonDecode(line);
          final content = (decoded['message']?['content'] as String?) ?? '';
          if (content.isNotEmpty) controller.add(content);
          if (decoded['done'] == true) break;
        } catch (_) {}
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      client.close();
      await controller.close();
    }
  }

  @override
  String get providerName => 'Ollama Cloud';

  @override
  String get modelName => _primaryModel;
}
