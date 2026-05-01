// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../models/sigma_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PaymentService — Non-blocking modal bottom sheet payment flow
// Uses flutter_stripe CardField for card UI.
// Since no live backend is available, shows a graceful "unavailable" state
// rather than blocking or crashing.
// ═══════════════════════════════════════════════════════════════════════════════

class PaymentService {
  /// Opens a dismissible payment bottom sheet.
  /// Returns true if payment was confirmed, false otherwise.
  static Future<bool> processPayment({
    required BuildContext context,
    required SigmaTier tier,
    required double amount,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _PaymentSheet(tier: tier, amount: amount),
    );
    return result == true;
  }
}

// ─── Payment sheet ────────────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final SigmaTier tier;
  final double amount;

  const _PaymentSheet({required this.tier, required this.amount});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

enum _SheetStep { entry, processing, success, error }

class _PaymentSheetState extends State<_PaymentSheet> {
  _SheetStep _step = _SheetStep.entry;
  CardFieldInputDetails? _cardDetails;
  String? _errorMessage;

  String get _planLabel {
    switch (widget.tier) {
      case SigmaTier.pro:
        return 'SIGMA PRO';
      case SigmaTier.elite:
        return 'SIGMA ELITE';
      default:
        return 'SIGMA CORE';
    }
  }

  Future<void> _confirmPayment() async {
    if (_cardDetails == null || !(_cardDetails!.complete)) return;

    setState(() {
      _step = _SheetStep.processing;
      _errorMessage = null;
    });

    // No live backend — show unavailable message instead of crashing
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _step = _SheetStep.error;
      _errorMessage =
          'Service de paiement non disponible.\nVeuillez réessayer ultérieurement.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getSurface(context),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: AppTheme.getBorder(context), width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ABONNEMENT',
                          style: AppTheme.overline(context,
                              color: AppTheme.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _planLabel,
                          style: AppTheme.heading(context, size: 18),
                        ),
                        Text(
                          '\$${widget.amount.toStringAsFixed(2)} / mois',
                          style: AppTheme.compactBody(context,
                              size: 13,
                              color: AppTheme.getSecondaryText(context)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                    color: AppTheme.getSecondaryText(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            Divider(
              height: 24,
              thickness: 0.5,
              color: AppTheme.getBorder(context),
              indent: 20,
              endIndent: 20,
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_step) {
      case _SheetStep.entry:
        return _EntryBody(
          key: const ValueKey('entry'),
          onCardChanged: (d) => setState(() => _cardDetails = d),
          onConfirm: _confirmPayment,
          isCardComplete: _cardDetails?.complete == true,
        );

      case _SheetStep.processing:
        return const _ProcessingBody(key: ValueKey('processing'));

      case _SheetStep.success:
        return _SuccessBody(
          key: const ValueKey('success'),
          onDone: () => Navigator.pop(context, true),
        );

      case _SheetStep.error:
        return _ErrorBody(
          key: const ValueKey('error'),
          message: _errorMessage ?? 'Une erreur est survenue.',
          onRetry: () => setState(() {
            _step = _SheetStep.entry;
            _errorMessage = null;
          }),
          onDismiss: () => Navigator.pop(context, false),
        );
    }
  }
}

// ─── Entry step ───────────────────────────────────────────────────────────────

class _EntryBody extends StatelessWidget {
  final void Function(CardFieldInputDetails?) onCardChanged;
  final VoidCallback onConfirm;
  final bool isCardComplete;

  const _EntryBody({
    super.key,
    required this.onCardChanged,
    required this.onConfirm,
    required this.isCardComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Informations de paiement',
          style: AppTheme.compactBody(context,
              size: 12, color: AppTheme.getSecondaryText(context)),
        ),
        const SizedBox(height: 12),
        // Stripe CardField — native secure input
        CardField(
          onCardChanged: onCardChanged,
          style: TextStyle(
            color: AppTheme.getPrimaryText(context),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.isDark(context)
                ? AppTheme.surfaceDeep
                : AppTheme.lightSurfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide:
                  BorderSide(color: AppTheme.getBorder(context), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide:
                  BorderSide(color: AppTheme.getBorder(context), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide:
                  BorderSide(color: AppTheme.primary, width: 0.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isCardComplete ? onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            disabledBackgroundColor:
                AppTheme.primary.withValues(alpha: 0.3),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
          child: Text(
            'Confirmer le paiement',
            style: AppTheme.compactTitle(context,
                size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 12,
                color: AppTheme.getSecondaryText(context)),
            const SizedBox(width: 4),
            Text(
              'Paiement sécurisé via Stripe',
              style: AppTheme.overline(context,
                  color: AppTheme.getSecondaryText(context)),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Processing step ──────────────────────────────────────────────────────────

class _ProcessingBody extends StatelessWidget {
  const _ProcessingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Traitement en cours…',
            style: AppTheme.compactBody(context, size: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Success step ─────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessBody({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle_outline_rounded,
            color: AppTheme.positive, size: 44),
        const SizedBox(height: 12),
        Text('Abonnement activé',
            style: AppTheme.heading(context, size: 16)),
        const SizedBox(height: 4),
        Text(
          'Votre accès est maintenant actif.',
          style: AppTheme.compactBody(context,
              size: 13,
              color: AppTheme.getSecondaryText(context)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.positive,
            minimumSize: const Size(160, 44),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSm)),
          ),
          child: Text('Continuer',
              style: AppTheme.compactTitle(context,
                  size: 14, color: Colors.white)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Error step ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _ErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.error_outline_rounded,
            color: AppTheme.negative, size: 40),
        const SizedBox(height: 12),
        Text(
          message,
          style: AppTheme.compactBody(context,
              size: 13,
              color: AppTheme.getSecondaryText(context)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: onDismiss,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppTheme.getBorder(context), width: 0.5),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm)),
                minimumSize: const Size(110, 42),
              ),
              child: Text('Fermer',
                  style: AppTheme.compactBody(context, size: 13)),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm)),
                minimumSize: const Size(110, 42),
              ),
              child: Text('Réessayer',
                  style: AppTheme.compactTitle(context,
                      size: 13, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

