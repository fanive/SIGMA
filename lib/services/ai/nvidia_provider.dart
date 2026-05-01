// ignore_for_file: prefer_const_declarations
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import '../ai_provider_interface.dart';
import 'stream_utils.dart' as utils;

/// ══════════════════════════════════════════════════════════════════════════════
/// NVIDIA NIM Provider — Institutional Grade AI Engine
/// ══════════════════════════════════════════════════════════════════════════════
/// Uses the OpenAI-compatible API at integrate.api.nvidia.com.
/// Incorporates fallback mechanisms when the primary model fails or times out.
/// ══════════════════════════════════════════════════════════════════════════════
class NvidiaProvider implements AIProvider {
  final String apiKey;
  final String _modelName;
  final String baseUrl;
  final List<String> fallbackModels;
  final AIProvider? crossProviderFallback;

  NvidiaProvider({
    required this.apiKey,
    required String modelName,
    required this.baseUrl,
    this.fallbackModels = const [],
    this.crossProviderFallback,
  }) : _modelName = modelName;

  @override
  String get providerName => 'NVIDIA';

  @override
  String get modelName => _modelName;

  @override
  Future<String> generateContent({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = true,
    bool? useThinking,
    List<Map<String, dynamic>>? tools,
    Future<String> Function(String toolName, Map<String, dynamic> arguments)? onToolCall,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('NVIDIA_API_KEY is missing. Add it to .env');
    }

    final chain = [_modelName, ...fallbackModels]
        .fold<List<String>>([], (acc, m) {
          if (!acc.contains(m)) acc.add(m);
          return acc;
        });

    Object? lastError;

    for (int i = 0; i < chain.length; i++) {
      final model = chain[i];
      // On donne 150 secondes à chaque modèle. Avec les gros LLM (120B+ et 405B) sans stream, 
      // le serveur met parfois 60s à 120s entières avant de renvoyer le body JSON final.
      const timeoutLimit = 150; 

      dev.log(
        '◆ NVIDIA: trying model "$model" (timeout ${timeoutLimit}s, '
        '${i + 1}/${chain.length})',
        name: 'NvidiaProvider',
      );

      try {
        final result = await _sendToModelUniversal(
          model: model,
          prompt: prompt,
          systemInstruction: systemInstruction,
          jsonMode: jsonMode,
          useThinking: useThinking,
          timeoutSeconds: timeoutLimit,
        );
        if (i > 0) {
          dev.log(
            '✓ NVIDIA: succeeded with fallback model "$model"',
            name: 'NvidiaProvider',
          );
        }
        return result;
      } on TimeoutException catch (e) {
        lastError = e;
        dev.log(
          '⚡ NVIDIA: "$model" — Timeout après ${timeoutLimit}s. Switching...',
          name: 'NvidiaProvider',
        );
        continue;
      } catch (e) {
        lastError = e;
        dev.log(
          '⚡ NVIDIA: "$model" — Erreur: $e. Switching...',
          name: 'NvidiaProvider',
        );
        continue;
      }
    }

    if (crossProviderFallback != null) {
      dev.log('⚠️ NVIDIA exhausted. Delegating to ${crossProviderFallback!.providerName} (${crossProviderFallback!.modelName})...', name: 'NvidiaProvider');
      return crossProviderFallback!.generateContent(
        prompt: prompt,
        systemInstruction: systemInstruction,
        jsonMode: jsonMode,
        useThinking: useThinking,
        tools: tools,
        onToolCall: onToolCall,
      );
    }

    throw Exception('NVIDIA: aucun modèle ne répond. Dernier erreur: $lastError');
  }

  @override
  Stream<String> generateStream({
    required String prompt,
    required String systemInstruction,
    bool jsonMode = false,
  }) {
    final rawController = StreamController<String>();
    _runNvidiaStream(
      prompt: prompt,
      systemInstruction: systemInstruction,
      jsonMode: jsonMode,
      controller: rawController,
    );
    return utils.stripThinkBlocks(rawController.stream);
  }


  Future<void> _runNvidiaStream({
    required String prompt,
    required String systemInstruction,
    required bool jsonMode,
    required StreamController<String> controller,
  }) async {
    if (apiKey.isEmpty) {
      controller.addError(Exception('NVIDIA_API_KEY is missing.'));
      await controller.close();
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'Accept': 'text/event-stream',
    };

    final isMinimax = _modelName.toLowerCase().contains('minimax');
    final isMistral = _modelName.toLowerCase().contains('mistral');
    final isNemotronSuper = _modelName.toLowerCase().contains('nemotron-3-super');
    final isGemma = _modelName.toLowerCase().contains('gemma');
    final isGlm = _modelName.toLowerCase().contains('glm');

    final body = <String, dynamic>{
      'model': _modelName,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': (isGemma || isNemotronSuper || isMinimax) ? 1.00 : (isMistral ? 0.05 : 0.7),
      'top_p': 0.95,
      'max_tokens': (isGemma || isMinimax) ? 8192 : (isMistral ? 12000 : 16384),
      'stream': true,
      if (isMistral) 'reasoning_effort': 'medium',
      if (isGlm) 'chat_template_kwargs': {'enable_thinking': true, 'clear_thinking': false},
    };

    if ((isGemma || isNemotronSuper) && !isGlm) {
      body['chat_template_kwargs'] = {"enable_thinking": false};
    }

    if (jsonMode) {
      body['response_format'] = {'type': 'json_object'};
    }

    final request = http.Request('POST', Uri.parse(baseUrl))
      ..headers.addAll(headers)
      ..body = jsonEncode(body);

    final client = http.Client();
    try {
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final error = await response.stream.bytesToString();
        controller.addError(
            Exception('NVIDIA Stream Error ${response.statusCode}: $error'));
        return;
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          if (line.startsWith('data: ')) {
            final String data = line.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final Map<String, dynamic> decoded = jsonDecode(data);
              final delta = decoded['choices']?[0]?['delta'];
              
              // We EXPLICITLY ignore anything that looks like reasoning (DeepSeek etc.)
              if (delta != null) {
                if (delta['reasoning_content'] != null || delta['reasoning'] != null) {
                  continue; 
                }
                
                final String content = (delta['content'] as String?) ?? '';
                if (content.isNotEmpty) {
                   controller.add(content);
                }
              }
            } catch (e) {
              dev.log('Error decoding SSE data: $e');
            }
          }
        }
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      client.close();
      await controller.close();
    }
  }

  /// Exécute la requête avec un système adaptatif pour supporter N'IMPORTE QUEL MODÈLE.
  /// Si le modèle refuse les paramètres enrichis (Erreur 400 ou 422),
  /// on bascule automatiquement sur un Payload RESTRICTIF et STANDARD.
  Future<String> _sendToModelUniversal({
    required String model,
    required String prompt,
    required String systemInstruction,
    required bool jsonMode,
    required int timeoutSeconds,
    bool? useThinking,
  }) async {
    try {
      // Tentative 1 : Paramètres enrichis spécifiques (Nemotron, Minimax, Gemma)
      return await _makeHttpRequest(
        model: model,
        prompt: prompt,
        systemInstruction: systemInstruction,
        jsonMode: jsonMode,
        useThinking: useThinking,
        timeoutSeconds: timeoutSeconds,
        safeMode: false,
      );
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('400') || errorStr.contains('422')) {
        dev.log('⚠️ NVIDIA: "$model" a refusé les paramètres avancés (400/422). Essai en mode de compatibilité universelle (Safe Mode)...', name: 'NvidiaProvider');
        // Tentative 2 : Standard strict OpenAI sans fioritures
        return await _makeHttpRequest(
          model: model,
          prompt: prompt,
          systemInstruction: systemInstruction,
          jsonMode: jsonMode,
          useThinking: false, // Force désactivé en safe mode
          timeoutSeconds: timeoutSeconds,
          safeMode: true,
        );
      }
      rethrow;
    }
  }

  Future<String> _makeHttpRequest({
    required String model,
    required String prompt,
    required String systemInstruction,
    required bool jsonMode,
    required int timeoutSeconds,
    bool? useThinking,
    required bool safeMode,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
    };

    final modelLower = model.toLowerCase();
    final isGemma = modelLower.contains('gemma');
    final isMinimax = modelLower.contains('minimax');
    final isNemotronSuper = modelLower.contains('nemotron-3-super');
    final isMistral = modelLower.contains('mistral');
    final isGlm = modelLower.contains('glm');
    
    // En Safe Mode, on se limite volontairement à 4096 tokens max 
    final maxTokens = safeMode ? 4096 : (isMinimax ? 8192 : 16384);
    final temp = safeMode ? 0.7 : ((isGemma || isMinimax || isNemotronSuper) ? 1.0 : (isMistral ? 0.10 : 0.2));

    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': temp,
      'max_tokens': (isGemma || isMinimax) ? 8192 : maxTokens,
      'stream': false,
    };

    if (!safeMode) {
      body['top_p'] = 0.95;

      if (isMistral) {
        body['reasoning_effort'] = 'medium';
      }

      if (isMinimax) {
        body['frequency_penalty'] = 0;
        body['presence_penalty'] = 0;
      }

      final capableOfThinking = isGemma || isNemotronSuper || isGlm;
      final shouldThink = useThinking ?? (capableOfThinking && !jsonMode);
      
      if (shouldThink && capableOfThinking && !jsonMode) {
        if (isGlm) {
           body['chat_template_kwargs'] = {"enable_thinking": true, "clear_thinking": false};
        } else {
           body['chat_template_kwargs'] = {"enable_thinking": false};
        }
        
        if (isNemotronSuper) {
          body['reasoning_budget'] = 1024; // Capped for faster response time
        }
      }

      if (jsonMode) {
        body['response_format'] = {'type': 'json_object'};
        if (!prompt.toLowerCase().contains('json')) {
          prompt += '\n\nIMPORTANT: Respond strictly in valid JSON format.';
          body['messages'] = [
            {'role': 'system', 'content': systemInstruction},
            {'role': 'user', 'content': prompt},
          ];
        }
      }
    } else {
      // En Safe Mode, JSON Mode natif désactivé, on force le prompt
      if (jsonMode && !prompt.toLowerCase().contains('json')) {
        prompt += '\n\nIMPORTANT: You must respond in strictly valid JSON format only, starting with { or [. No conversational text.';
        body['messages'] = [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': prompt},
        ];
      }
    }

    final response = await http
        .post(
          Uri.parse(baseUrl),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: timeoutSeconds));

    if (response.statusCode == 401) throw Exception('NVIDIA API key invalid or expired (401).');
    if (response.statusCode == 402) throw Exception('NVIDIA credits exhausted (402).');
    if (response.statusCode == 404) throw Exception('NVIDIA model "$model" not found (404).');
    if (response.statusCode == 429) throw Exception('NVIDIA rate limit exceeded (429).');

    if (response.statusCode != 200) {
      final errorBody = response.body.length > 500 ? response.body.substring(0, 500) : response.body;
      throw Exception('NVIDIA API Error ${response.statusCode}: $errorBody');
    }

    final decoded = jsonDecode(response.body);
    final choices = decoded['choices'] as List?;

    if (choices == null || choices.isEmpty) {
      throw Exception('NVIDIA returned no choices');
    }

    String content = choices[0]['message']?['content']?.toString() ?? '';

    if (content.isEmpty) {
      throw Exception('NVIDIA returned empty content');
    }

    content = _stripThinkingBlocks(content);
    return content;
  }

  /// Strip <think>...</think> and <thinking>...</thinking> blocks
  static String _stripThinkingBlocks(String content) {
    String s = content;
    s = s.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
    s = s.replaceAll(RegExp(r'<thinking>.*?</thinking>', dotAll: true), '').trim();
    
    // Nettoyer tous les marqueurs Markdown si c'est censé être du JSON. 
    // On s'assure de ne pas avoir de ```json au début
    if (!s.startsWith('{') && !s.startsWith('[')) {
      if (s.contains('```json')) {
        s = s.split('```json').last;
        s = s.split('```').first.trim();
      } else if (s.contains('{')) {
        s = s.substring(s.indexOf('{'));
      }
    }
    
    return s;
  }
}
