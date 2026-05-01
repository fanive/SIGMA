// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:quantum_invest/theme/app_theme.dart';
import 'providers/sigma_provider.dart';
import 'providers/terminal_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/cache_service.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Keep screen on
    await WakelockPlus.enable();

    // Initialize Hive
    await Hive.initFlutter();

    // Initialize smart cache (granular TTLs per data type)
    await CacheService.initialize();

    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print("Warning: .env file not found.");
    }

    // Initialize Stripe
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? "pk_test_xxxxxxxxxxxxxxxxxxxxxxxx";
    await Stripe.instance.applySettings();

    // Check if onboarding is complete
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_v2_complete') ?? false;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SigmaProvider()),
          ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ],
        child: SigmaApp(showOnboarding: !onboardingDone),
      ),
    );
  } catch (e, stack) {
    print("FATAL STARTUP ERROR: $e");
    print(stack);
  }
}

class SigmaApp extends StatelessWidget {
  final bool showOnboarding;

  const SigmaApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return Consumer<SigmaProvider>(
      builder: (context, sigmaProvider, _) {
        // Determine locale from provider or auto-detect
        Locale? appLocale;
        final lang = sigmaProvider.language;
        if (lang != null && lang != 'AUTO') {
          appLocale = _langToLocale(lang);
        }
        // If null, Flutter auto-detects from device

        return MaterialApp(
          title: 'SIGMA',
          debugShowCheckedModeBanner: false,

          // â”€â”€â”€ Theme (driven by SigmaProvider) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: sigmaProvider.themeMode,

          // â”€â”€â”€ Internationalization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          locale: appLocale,
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
            Locale('es'),
            Locale('pt'),
            Locale('de'),
            Locale('it'),
            Locale('ja'),
            Locale('zh'),
            Locale('ko'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // â”€â”€â”€ Entry Point â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          home: SplashScreen(showOnboarding: showOnboarding),
        );
      },
    );
  }

  Locale? _langToLocale(String lang) {
    switch (lang.toUpperCase()) {
      case 'EN': return const Locale('en');
      case 'FR': return const Locale('fr');
      case 'ES': return const Locale('es');
      case 'PT': return const Locale('pt');
      case 'DE': return const Locale('de');
      case 'IT': return const Locale('it');
      case 'JA': return const Locale('ja');
      case 'ZH': return const Locale('zh');
      case 'KO': return const Locale('ko');
      case 'AR': return const Locale('ar');
      default: return null; // Auto-detect
    }
  }
}

