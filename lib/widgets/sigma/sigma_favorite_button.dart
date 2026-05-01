// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/sigma_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';

class SigmaFavoriteButton extends StatefulWidget {
  final String ticker;
  final double size;
  final double padding;

  const SigmaFavoriteButton({
    super.key,
    required this.ticker,
    this.size = 18,
    this.padding = 10,
  });

  @override
  State<SigmaFavoriteButton> createState() => _SigmaFavoriteButtonState();
}

class _SigmaFavoriteButtonState extends State<SigmaFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _showFeedback(BuildContext context, String message, bool isSuccess) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: isSuccess ? AppTheme.positive : AppTheme.negative,
              size: 16,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.lora(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.bgSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleToggle(BuildContext context, SigmaProvider sp, bool isFav) async {
    await sp.toggleFavorite(widget.ticker);
    _scaleCtrl.forward(from: 0);
    
    if (mounted) {
      _showFeedback(
        context, 
        isFav ? '${widget.ticker} REMOVED' : '${widget.ticker} ADDED TO WATCHLIST', 
        !isFav
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    
    return Consumer<SigmaProvider>(
      builder: (context, sp, _) {
        final isFav = sp.isFavorite(widget.ticker);
        
        const gold = AppTheme.goldBright;

        return ScaleTransition(
          scale: _scaleAnim,
          child: Material(
            color: AppTheme.transparent,
            child: InkWell(
              onTap: () => _handleToggle(context, sp, isFav),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.all(widget.padding),
                decoration: BoxDecoration(
                  color: isFav
                      ? gold.withValues(alpha: 0.2)
                      : AppTheme.sectionBackground(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFav
                        ? gold.withValues(alpha: 0.6)
                        : AppTheme.getBorder(context),
                    width: isFav ? 1.5 : 1.0,
                  ),
                  boxShadow: isFav ? [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ] : null,
                ),
                child: Icon(
                  isFav ? Icons.star : Icons.star,
                  color: isFav
                      ? gold
                      : (isDark ? AppTheme.white24 : AppTheme.black26),
                  size: widget.size,
                  fill: isFav ? 1.0 : 0.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


