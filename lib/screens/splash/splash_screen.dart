import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantum_invest/theme/app_theme.dart';

import '../../widgets/terminal/sigma_logo.dart';
import '../onboarding/onboarding_screen.dart';
import '../terminal_shell.dart';

class SplashScreen extends StatefulWidget {
  final bool showOnboarding;

  const SplashScreen({super.key, this.showOnboarding = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppTheme.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.showOnboarding
              ? const OnboardingScreen()
              : const TerminalShell(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 360),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: AppTheme.pagePadding,
          child: FadeTransition(
            opacity: _opacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const SigmaLogo(size: 74),
                const SizedBox(height: 28),
                Text(
                  'Private Markets Intelligence',
                  style: AppTheme.compactTitle(
                    context,
                    size: 22,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Research, convictions, catalysts and allocation in one disciplined workspace.',
                  style: AppTheme.compactBody(
                    context,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => LinearProgressIndicator(
                    value: _progress.value,
                    minHeight: 2,
                    backgroundColor: AppTheme.borderDark,
                    color: AppTheme.gold,
                  ),
                ),
                const Spacer(),
                Text(
                  'SIGMA RESEARCH · v2.0.0',
                  style: AppTheme.overline(
                    context,
                    color: AppTheme.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
