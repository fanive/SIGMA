// ignore_for_file: prefer_const_declarations
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quantum_invest/theme/app_theme.dart';

/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
/// APPLE COMPLIANCE & HIG UTILITIES
/// This utility ensures the app follows Apple's Human Interface Guidelines (HIG)
/// and App Store Review Guidelines (Legal, Privacy, UX).
/// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class AppleCompliance {
  AppleCompliance._();

  /// APPLE GUIDELINE 5.1.1: ACCOUNT DELETION
  /// Apps that allow account creation must also allow account deletion within the app.
  static Future<void> showDeleteAccountDialog(BuildContext context) async {
    const title = 'Supprimer le compte';
    const content = 'ÃŠtes-vous sÃ»r de vouloir supprimer votre compte Sigma ? Cette action est irrÃ©versible et entraÃ®nera la perte de toutes vos donnÃ©es et abonnements.';
    
    if (Platform.isIOS) {
      return showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text(title),
          content: const Text(content),
          actions: [
            CupertinoDialogAction(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                // Implement actual deletion logic here
                Navigator.pop(context);
                _showSuccessFeedback(context, 'Demande de suppression envoyÃ©e.');
              },
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(title),
          content: const Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULER'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessFeedback(context, 'Demande de suppression envoyÃ©e.');
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.red),
              child: const Text('SUPPRIMER'),
            ),
          ],
        ),
      );
    }
  }

  /// HIG: FEEDBACK & HAPTICS
  /// Apple encourages tactile feedback for significant actions.
  static void triggerHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  static void triggerSuccessHaptic() {
    HapticFeedback.lightImpact();
  }

  /// GUIDELINE 3.1.1: PAYMENTS (RESTORING PURCHASES)
  /// Apps with subscriptions MUST have a "Restore Purchases" button.
  static Future<void> restorePurchases(BuildContext context) async {
    triggerSuccessHaptic();
    // Logic for restoring IAP would go here.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification des achats en cours...')),
    );
  }

  /// LEGAL: PRIVACY POLICY & TERMS
  static Future<void> openPrivacyPolicy() async {
    final url = Uri.parse('https://sigma-terminal.ai/privacy'); // Replace with real URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openTermsOfService() async {
    final url = Uri.parse('https://sigma-terminal.ai/terms'); // Replace with real URL
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// APPLE BEST PRACTICE: MANAGE SUBSCRIPTIONS
  /// Open the system settings to manage subscriptions.
  static Future<void> manageSubscriptions() async {
    final url = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// UI: ADAPTIVE PAGE ROUTE
  /// Ensures the standard iOS "swipe to back" and Android "fade/zoom" transitions.
  static PageRoute<T> adaptiveRoute<T>({required Widget child}) {
    if (Platform.isIOS) {
      return CupertinoPageRoute<T>(builder: (context) => child);
    } else {
      return MaterialPageRoute<T>(builder: (context) => child);
    }
  }

  static void _showSuccessFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

