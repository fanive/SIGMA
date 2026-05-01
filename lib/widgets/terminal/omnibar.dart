// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../sigma/sigma_favorite_button.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// OMNIBAR — Search field with floating overlay results
// ═══════════════════════════════════════════════════════════════════════════════

class Omnibar extends StatefulWidget {
  const Omnibar({super.key});

  @override
  State<Omnibar> createState() => _OmnibarState();
}

class _OmnibarState extends State<Omnibar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late AnimationController _pulseController;
  bool _isProcessing = false;
  Timer? _debounce;

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _focusNode.addListener(_onFocusChange);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Overlay management ───────────────────────────────────────────────────

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => _ResultsOverlay(
        layerLink: _layerLink,
        onResultTapped: _onResultTapped,
        onDismiss: _hideOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ─── Handlers ─────────────────────────────────────────────────────────────

  void _onFocusChange() {
    context.read<TerminalProvider>().setOmnibarFocus(_focusNode.hasFocus);
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _hideOverlay();
      });
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    setState(() {});
    if (query.trim().isEmpty) {
      _hideOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      context.read<SigmaProvider>().updateSearchResults(query.trim());
      _showOverlay();
    });
  }

  void _onSubmit(String value) {
    final raw = value.trim();
    final query = raw.toUpperCase();
    if (query.isEmpty) return;

    // Autocomplete: if an exact symbol doesn't exist, open the best match.
    final sp = context.read<SigmaProvider>();
    String selected = query;
    if (sp.searchResults.isNotEmpty) {
      final exact = sp.searchResults.firstWhere(
        (r) => (r['symbol'] ?? '').toString().toUpperCase() == query,
        orElse: () => <String, dynamic>{},
      );
      if ((exact['symbol'] ?? '').toString().isEmpty) {
        final prefix = sp.searchResults.firstWhere(
          (r) => (r['symbol'] ?? '').toString().toUpperCase().startsWith(query),
          orElse: () => sp.searchResults.first,
        );
        selected = (prefix['symbol'] ?? query).toString().toUpperCase();
      }
    }

    _controller.clear();
    _focusNode.unfocus();
    _hideOverlay();
    setState(() {});
    _openAnalysis(selected);
  }

  void _onResultTapped(dynamic result) {
    final symbol = (result['symbol'] ?? result['ticker'] ?? '').toString();
    if (symbol.isNotEmpty) {
      _controller.clear();
      _focusNode.unfocus();
      _hideOverlay();
      setState(() {});
      _openAnalysis(symbol);
    }
  }

  void _openAnalysis(String ticker) {
    setState(() => _isProcessing = true);
    _pulseController.repeat(reverse: true);
    final sp = context.read<SigmaProvider>();
    final tp = context.read<TerminalProvider>();
    sp.analyzeTicker(ticker).then((_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _pulseController.stop();
        _pulseController.reset();
      }
    });
    tp.openAnalysis(ticker);
  }

  void _listen() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) return;
    }
    if (_isListening) {
      final text = _controller.text.trim();
      await _speech.stop();
      setState(() => _isListening = false);
      if (text.isNotEmpty) _onSubmit(text);
      return;
    }
    final lang = context.read<SigmaProvider>().language ?? 'EN';
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (r) {
        if (mounted) setState(() => _controller.text = r.recognizedWords);
      },
      localeId: lang == 'FR' ? 'fr_FR' : 'en_US',
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? AppTheme.surfaceDeep
              : AppTheme.lightSurfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: _focusNode.hasFocus
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.getBorder(context).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 16,
                color: AppTheme.getSecondaryText(context)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                onSubmitted: _onSubmit,
                style: AppTheme.compactBody(context,
                    size: 13,
                    color: AppTheme.getPrimaryText(context)),
                decoration: InputDecoration(
                  hintText: 'Société, ticker, thèse…',
                  hintStyle: AppTheme.compactBody(context,
                      size: 12,
                      color: AppTheme.getSecondaryText(context)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            if (_isProcessing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppTheme.primary.withValues(alpha: 0.7),
                ),
              )
            else if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  _hideOverlay();
                  setState(() {});
                },
                child: Icon(Icons.close_rounded,
                    size: 14,
                    color: AppTheme.getSecondaryText(context)),
              ),
            if (_speechEnabled) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _listen,
                child: Icon(
                  _isListening
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  size: 16,
                  color: _isListening
                      ? AppTheme.negative
                      : AppTheme.getSecondaryText(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TickerLogo extends StatelessWidget {
  final String symbol;
  final String? logoUrl;

  const _TickerLogo({required this.symbol, this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        symbol.isNotEmpty ? symbol[0] : '?',
        style: AppTheme.compactTitle(context, size: 10, color: AppTheme.primary),
      ),
    );

    final url = logoUrl?.trim() ?? '';
    if (url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 26,
        height: 26,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

// ─── Floating results overlay ─────────────────────────────────────────────────

class _ResultsOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final ValueChanged<dynamic> onResultTapped;
  final VoidCallback onDismiss;

  const _ResultsOverlay({
    required this.layerLink,
    required this.onResultTapped,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap outside → dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            color: Colors.transparent,
            child: Consumer<SigmaProvider>(
              builder: (context, sp, _) {
                return Container(
                  constraints: const BoxConstraints(
                    maxHeight: 380,
                    minWidth: 280,
                    maxWidth: 520,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurface(context),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: AppTheme.getBorder(context), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    child: sp.isSearching
                        ? const _OmniLoadingState()
                        : sp.searchResults.isEmpty
                            ? const _OmniEmptyState()
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: sp.searchResults.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 0.5,
                                  thickness: 0.5,
                                  color: AppTheme.getBorder(context),
                                ),
                                itemBuilder: (context, i) {
                                  return _OmniResultRow(
                                    result: sp.searchResults[i],
                                    onTap: () => onResultTapped(
                                        sp.searchResults[i]),
                                  );
                                },
                              ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _OmniLoadingState extends StatelessWidget {
  const _OmniLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Text('Recherche en cours…',
              style: AppTheme.compactBody(context, size: 12)),
        ],
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _OmniEmptyState extends StatelessWidget {
  const _OmniEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text('Aucun résultat',
          style: AppTheme.compactBody(context,
              size: 12,
              color: AppTheme.getSecondaryText(context))),
    );
  }
}

// ─── Result row ───────────────────────────────────────────────────────────────

class _OmniResultRow extends StatelessWidget {
  final dynamic result;
  final VoidCallback onTap;

  const _OmniResultRow({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final symbol = result['symbol']?.toString() ?? '';
    final name =
        (result['description'] ?? result['name'] ?? '').toString();
    final exchange =
        (result['stockExchange'] ?? result['exchange'] ?? '').toString();
    final logoUrl = (result['logo'] ?? result['logoUrl']).toString();
    final double price = (result['price'] ?? 0.0).toDouble();
    final double change = (result['change'] ?? 0.0).toDouble();
    final bool isUp = change >= 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Logo + ticker chip
            _TickerLogo(symbol: symbol, logoUrl: logoUrl),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                symbol.length <= 5 ? symbol : symbol.substring(0, 5),
                style: AppTheme.compactTitle(context,
                    size: 10, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            // Name + exchange
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.compactBody(context,
                          size: 13,
                          color: AppTheme.getPrimaryText(context))),
                  if (exchange.isNotEmpty)
                    Text(exchange,
                        style: AppTheme.overline(context,
                            color: AppTheme.getSecondaryText(context))),
                ],
              ),
            ),
            // Price
            if (price > 0) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('\$${price.toStringAsFixed(2)}',
                      style:
                          AppTheme.compactTitle(context, size: 12)),
                  Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}',
                      style: AppTheme.compactBody(context,
                          size: 11,
                          color: isUp
                              ? AppTheme.positive
                              : AppTheme.negative)),
                ],
              ),
            ],
            const SizedBox(width: 6),
            SigmaFavoriteButton(ticker: symbol, size: 14, padding: 6),
          ],
        ),
      ),
    );
  }
}

