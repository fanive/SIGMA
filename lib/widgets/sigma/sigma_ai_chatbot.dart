// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:quantum_invest/theme/app_theme.dart';

import '../../services/sigma_service.dart';
import '../../models/sigma_models.dart';
import '../../providers/sigma_provider.dart';

class SigmaAIChatbot extends StatefulWidget {
  final String ticker;
  final Map<String, dynamic>? stockData;
  final AnalysisData? analysis;
  final VoidCallback? onClose;

  const SigmaAIChatbot({
    super.key,
    required this.ticker,
    this.stockData,
    this.analysis,
    this.onClose,
  });

  @override
  State<SigmaAIChatbot> createState() => _SigmaAIChatbotState();
}

class _SigmaAIChatbotState extends State<SigmaAIChatbot> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isStreamingResponse = false;
  SigmaService? _sigmaService;
  final ScrollController _scrollController = ScrollController();

  // Voice State
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isTtsActive = true;
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _initService();
    _initVoice();
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    _flutterTts.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech Status: $status');
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('Speech Error: $error');
          if (mounted) setState(() => _isListening = false);
        },
      );

      // Configure TTS
      await _flutterTts.setLanguage(
          context.read<SigmaProvider>().language == 'FR' ? 'fr-FR' : 'en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech Initialization Failed: $e');
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      // Re-attempt init if it failed earlier
      await _initVoice();
      if (!_speechEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<SigmaProvider>().language == 'FR'
                    ? 'Reconnaissance vocale non disponible sur cet appareil'
                    : 'Speech recognition not available on this device',
              ),
              backgroundColor: AppTheme.negative,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    final lang =
        context.read<SigmaProvider>().language == 'FR' ? 'fr_FR' : 'en_US';

    setState(() => _isListening = true);

    await _speechToText.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _messageController.text = result.recognizedWords;
          // Move cursor to end
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
      },
      onSoundLevelChange: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 30),
      localeId: lang,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _stopAndSend() async {
    final text = _messageController.text.trim();
    await _stopListening();
    if (text.isNotEmpty) {
      _sendMessage();
    }
  }

  Future<void> _speak(String text) async {
    if (!_isTtsActive) return;

    // Clean text for speech (remove some technical markers if any)
    String cleanText = text.replaceAll(RegExp(r'[*#_]'), '');
    await _flutterTts.speak(cleanText);
  }

  void _addWelcomeMessage() {
    final lang = context.read<SigmaProvider>().language ?? 'EN';
    final welcome = lang == 'FR'
        ? 'Assistant Quantum en ligne. Analyste pour ${widget.ticker}. Prêt pour l\'analyse haute-fidélité.'
        : 'Quantum Assistant active. Analyst for ${widget.ticker}. Standing by for high-fidelity session.';
    _messages.add({'role': 'bot', 'text': welcome});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
  }

  Future<void> _initService() async {
    try {
      final service = SigmaService.fromEnv();
      setState(() => _sigmaService = service);
    } catch (e) {
      debugPrint('Error initializing SigmaService: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping || _sigmaService == null) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final lang = context.read<SigmaProvider>().language ?? 'EN';

      // --- DISCOVERY AGENT ROUTING ---
      final lower = text.toLowerCase();
      final discoveryWords = [
        'stratégie',
        'strategy',
        'trouve',
        'find',
        'cherche',
        'search',
        'actions',
        'stocks'
      ];
      if (discoveryWords.any((w) => lower.contains(w))) {
        final results = await _sigmaService!.searchTickersByStrategy(text);
        if (mounted) {
          String discoveryResp = lang == 'FR'
              ? "Voici des opportunités détectées par mon moteur stratégique :\n\n"
              : "Here are opportunities detected by my strategic engine:\n\n";
          for (var res in results) {
            discoveryResp += "• ${res['ticker']} : ${res['reason']}\n";
          }
          setState(() {
            _messages.add({'role': 'bot', 'text': discoveryResp});
            _isTyping = false;
          });
          _scrollToBottom();
          _speak(discoveryResp);
        }
        return;
      }

      final realAnalysis =
          widget.analysis ?? context.read<SigmaProvider>().currentAnalysis;

      final analysisContext = realAnalysis ??
          AnalysisData(
            ticker: widget.ticker,
            companyProfile:
                widget.stockData?['profile']?['description'] ?? 'N/A',
            lastUpdated: DateTime.now().toString(),
            price: widget.stockData?['ratios']?['current_price']?.toString() ??
                'N/A',
            verdict: 'Analyzing...',
            riskLevel: 'N/A',
            pros: [],
            cons: [],
            sigmaScore: 0,
            confidence: 0,
            summary:
                widget.stockData?['summary'] ?? 'Stock analysis in progress.',
            hiddenSignals: [],
            catalysts: [],
            volatility: VolatilityData(
                ivRank: 'N/A', beta: 'N/A', interpretation: 'N/A'),
            fearAndGreed: StockSentiment(
                score: 50, label: 'Neutral', interpretation: 'N/A'),
            marketSentiment: MarketSentiment(score: 50, label: 'Neutral'),
            tradeSetup: TradeSetup(
                entryZone: 'N/A',
                targetPrice: 'N/A',
                stopLoss: 'N/A',
                riskRewardRatio: 'N/A'),
            institutionalActivity: InstitutionalActivity(
                smartMoneySentiment: 0.5,
                retailSentiment: 0.5,
                darkPoolInterpretation: 'N/A'),
            technicalAnalysis: [],
            projectedTrend: [],
            financialMatrix: [],
            sectorPeers: [],
            topSources: [],
            analystRecommendations: AnalystRecommendation(
                buy: 0,
                hold: 0,
                sell: 0,
                strongBuy: 0,
                strongSell: 0,
                period: 'Current'),
            insiderTransactions: [],
          );

      // Create a placeholder bot message
      setState(() {
        _messages.add({'role': 'bot', 'text': ''});
        _isTyping = false;
        _isStreamingResponse = true;
      });
      final botMessageIndex = _messages.length - 1;

      // RAG: Retrieve relevant past context (non-blocking fallback)
      String ragContext = '';
      final rag = context.read<SigmaProvider>().ragService;
      if (rag != null) {
        try {
          ragContext = await rag.retrieveContext(
            text,
            ticker: widget.ticker,
            topK: 3,
          );
        } catch (_) {}
      }

      final stream = _sigmaService!.chatWithSigmaStream(
        ticker: widget.ticker,
        question: text,
        context: analysisContext,
        history: _messages.sublist(0,
            _messages.length - 1), // passing history excluding the placeholder
        language: lang,
        ragContext: ragContext,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        if (!mounted) break;
        fullResponse += chunk;
        setState(() {
          _messages[botMessageIndex]['text'] = fullResponse;
        });
        _scrollToBottom();
      }

      if (mounted) {
        setState(() => _isStreamingResponse = false);
        _speak(fullResponse);
        // RAG: Index this chat exchange for future memory
        rag?.indexChatExchange(widget.ticker, text, fullResponse);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty &&
              _messages.last['role'] == 'bot' &&
              _messages.last['text'] == '') {
            _messages.last['text'] =
                'Connection error: research service unavailable. Please retry shortly.';
          } else {
            _messages.add({
              'role': 'bot',
              'text':
                  'Connection error: research service unavailable. Please retry shortly.',
            });
          }
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index], isDark);
              },
            ),
          ),
          if (_isTyping) _buildTypingIndicator(isDark),
          _buildInput(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgSecondary : AppTheme.lightSurface,
        border: Border(
            bottom: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.lightBorderSub,
                width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.manage_search,
                      color: AppTheme.gold, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'RESEARCH ANALYST',
                    style: GoogleFonts.lora(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.gold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.positive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: AppTheme.positive.withValues(alpha: 0.2),
                          width: 0.5),
                    ),
                    child: Text('ACTIVE',
                        style: GoogleFonts.lora(
                            fontSize: 5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.positive)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'MARKET DATA & RESEARCH CONTEXT',
                style: GoogleFonts.lora(
                  fontSize: 6,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? AppTheme.textTertiary : AppTheme.lightTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              setState(() => _isTtsActive = !_isTtsActive);
              if (!_isTtsActive) _flutterTts.stop();
            },
            child: Icon(_isTtsActive ? Icons.volume_up : Icons.volume_off,
                color: _isTtsActive
                    ? AppTheme.gold
                    : (isDark
                        ? AppTheme.textTertiary
                        : AppTheme.lightTextMuted),
                size: 16),
          ),
          const SizedBox(width: 16),
          if (widget.onClose != null)
            GestureDetector(
              onTap: widget.onClose,
              child: Icon(Icons.close,
                  color:
                      isDark ? AppTheme.textTertiary : AppTheme.lightTextMuted,
                  size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isDark) {
    final isBot = msg['role'] == 'bot';
    final isLastBot = isBot && _messages.isNotEmpty && _messages.last == msg;
    final showCursor = isLastBot && _isStreamingResponse;
    final displayText =
        showCursor ? '${msg['text'] ?? ''} █' : (msg['text'] ?? '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBot
            ? (isDark ? AppTheme.bgSecondary : AppTheme.lightSurface)
            : AppTheme.gold.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(
            color: isBot
                ? AppTheme.gold
                : (isDark ? AppTheme.white10 : AppTheme.black12),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBot ? Icons.manage_search : Icons.person,
                size: 11,
                color: isBot
                    ? AppTheme.gold
                    : (isDark
                        ? AppTheme.textTertiary
                        : AppTheme.lightTextMuted),
              ),
              const SizedBox(width: 8),
              Text(
                isBot ? 'RESEARCH ASSISTANT' : 'USER INQUIRY',
                style: GoogleFonts.lora(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: isBot
                      ? AppTheme.gold
                      : (isDark
                          ? AppTheme.textTertiary
                          : AppTheme.lightTextMuted),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayText,
            style: GoogleFonts.lora(
              fontSize: 13,
              height: 1.6,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppTheme.gold),
          ),
          const SizedBox(width: 10),
          Text(
            'ANALYZING QUANTUM FLOWS...',
            style: GoogleFonts.lora(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppTheme.goldDim,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.bgSecondary : AppTheme.lightSurface,
        border: Border(
            top: BorderSide(
                color: isDark ? AppTheme.borderDark : AppTheme.lightBorderSub,
                width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isListening ? _stopAndSend : _startListening,
            icon: Stack(
              alignment: Alignment.center,
              children: [
                if (_isListening)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.negative.withValues(
                          alpha: 0.1 + (_soundLevel.clamp(0, 10) / 20)),
                    ),
                  ),
                Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  color: _isListening ? AppTheme.negative : AppTheme.gold,
                  size: 18,
                ),
              ],
            ),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'LISTENING...',
                style: GoogleFonts.lora(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.negative,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.lora(
                  fontSize: 13,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightText),
              decoration: InputDecoration(
                hintText: 'TYPE MESSAGE...',
                hintStyle: GoogleFonts.lora(
                  fontSize: 10,
                  color:
                      isDark ? AppTheme.textDisabled : AppTheme.lightTextMuted,
                  letterSpacing: 1.0,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: AppTheme.gold, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
