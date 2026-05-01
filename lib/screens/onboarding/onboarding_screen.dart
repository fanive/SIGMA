import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quantum_invest/theme/app_theme.dart';
import '../terminal_shell.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SIGMA ONBOARDING — Immersive full-bleed slides (Revolut / Brex style)
// ═══════════════════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const List<_Slide> _slides = [
    _Slide(
      tag: 'COVERAGE',
      title: 'Construisez\nvotre univers',
      body:
          'Regroupez sociétés, secteurs, catalyseurs et priorités de recherche dans un espace structuré.',
      kind: _Kind.coverage,
    ),
    _Slide(
      tag: 'RESEARCH',
      title: 'Formez une\nconviction solide',
      body:
          'Reliez fondamentaux, graphiques, actualités et sentiment dans une lecture claire avant de décider.',
      kind: _Kind.research,
    ),
    _Slide(
      tag: 'RISK',
      title: 'Gardez\nle contrôle',
      body:
          'Alertes, expositions et signaux qui modifient la qualité d\'un dossier en temps réel.',
      kind: _Kind.risk,
    ),
    _Slide(
      tag: 'ALLOCATION',
      title: 'Décidez avec\ndiscipline',
      body:
          'Transformez l\'information en décisions mesurées, cohérentes avec votre mandat d\'investissement.',
      kind: _Kind.allocation,
    ),
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TerminalShell(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 360),
      ),
    );
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _complete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimary : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              currentPage: _currentPage,
              total: _slides.length,
              onSkip: _complete,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: _Footer(
                count: _slides.length,
                current: _currentPage,
                label: _currentPage == _slides.length - 1
                    ? 'Entrer dans SIGMA'
                    : 'Continuer',
                onNext: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentPage;
  final int total;
  final VoidCallback onSkip;

  const _TopBar({
    required this.currentPage,
    required this.total,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 10, 6),
      child: Row(
        children: [
          Text(
            'SIGMA',
            style: AppTheme.compactTitle(context, size: 14),
          ),
          const Spacer(),
          Text(
            '${currentPage + 1} / $total',
            style: AppTheme.overline(
              context,
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.getSecondaryText(context),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'Passer',
              style: AppTheme.overline(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Slide ───────────────────────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bg = isDark ? AppTheme.bgPrimary : AppTheme.lightBg;

    return LayoutBuilder(builder: (context, constraints) {
      final ilH = (constraints.maxHeight * 0.58).clamp(200.0, 380.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-bleed illustration — no border, no card wrapper ─────────
          Stack(
            children: [
              SizedBox(
                height: ilH,
                width: double.infinity,
                child: CustomPaint(
                  painter: _Painter(kind: slide.kind, dark: isDark),
                ),
              ),
              // Gradient fade from illustration into background color
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bg.withValues(alpha: 0),
                        bg,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Typography ───────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.tag,
                    style: AppTheme.overline(context, color: AppTheme.gold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.title,
                    style: AppTheme.serif(
                      context,
                      size: 27,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    slide.body,
                    style: AppTheme.compactBody(
                      context,
                      size: 15,
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

// ─── Footer ──────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final int count;
  final int current;
  final String label;
  final VoidCallback onNext;

  const _Footer({
    required this.count,
    required this.current,
    required this.label,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: List.generate(count, (i) {
            final active = i == current;
            return AnimatedContainer(
              duration: AppTheme.animNormal,
              width: active ? 24 : 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: active ? AppTheme.gold : AppTheme.borderShim(context),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onNext,
          icon: Icon(
            current == count - 1
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
            size: 18,
          ),
          label: Text(label),
        ),
      ],
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

enum _Kind { coverage, research, risk, allocation }

class _Slide {
  final String tag;
  final String title;
  final String body;
  final _Kind kind;

  const _Slide({
    required this.tag,
    required this.title,
    required this.body,
    required this.kind,
  });
}

// ─── Illustration painter ─────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  final _Kind kind;
  final bool dark;

  const _Painter({required this.kind, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final navy = dark ? const Color(0xFF162033) : const Color(0xFFE8EEF7);
    final blue = dark ? const Color(0xFF4F8CFF) : const Color(0xFF2454A6);
    const gold = AppTheme.gold;
    final green = dark ? const Color(0xFF44D07B) : const Color(0xFF1C8B4E);
    final red = dark ? const Color(0xFFFF6B6B) : const Color(0xFFD64646);
    final ink = dark ? const Color(0xFFEAF0FF) : const Color(0xFF172033);
    final soft = dark ? const Color(0xFF233149) : const Color(0xFFF5F7FB);

    // Background gradient
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [const Color(0xFF101827), const Color(0xFF0B0E14)]
            : [const Color(0xFFFFFFFF), const Color(0xFFEFF4FA)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    _blob(canvas, Offset(size.width * .18, size.height * .2),
        size.width * .28, gold.withValues(alpha: .13));
    _blob(canvas, Offset(size.width * .82, size.height * .18),
        size.width * .22, blue.withValues(alpha: .13));
    _blob(canvas, Offset(size.width * .78, size.height * .82),
        size.width * .32, green.withValues(alpha: .10));

    switch (kind) {
      case _Kind.coverage:
        _drawCoverage(canvas, size, navy, blue, gold, green, ink, soft);
        break;
      case _Kind.research:
        _drawResearch(canvas, size, navy, blue, gold, green, ink, soft);
        break;
      case _Kind.risk:
        _drawRisk(canvas, size, navy, blue, gold, red, ink, soft);
        break;
      case _Kind.allocation:
        _drawAllocation(canvas, size, navy, blue, gold, green, ink, soft);
        break;
    }
  }

  void _drawCoverage(Canvas canvas, Size size, Color navy, Color blue,
      Color gold, Color green, Color ink, Color soft) {
    final center = Offset(size.width * .5, size.height * .46);
    final radius = size.shortestSide * .24;
    final line = Paint()
      ..color = blue.withValues(alpha: .35)
      ..strokeWidth = 2;
    final points = [
      center + Offset(-radius * 1.25, -radius * .35),
      center + Offset(radius * 1.05, -radius * .55),
      center + Offset(radius * 1.2, radius * .62),
      center + Offset(-radius * .9, radius * .78),
    ];
    for (final point in points) {
      canvas.drawLine(center, point, line);
      _node(canvas, point, radius * .23, soft, blue, ink);
    }
    _node(canvas, center, radius * .32, navy, gold, ink, label: 'Σ');
    _miniBar(canvas, Offset(size.width * .18, size.height * .72),
        size.width * .26, green);
    _miniBar(canvas, Offset(size.width * .58, size.height * .28),
        size.width * .22, gold);
  }

  void _drawResearch(Canvas canvas, Size size, Color navy, Color blue,
      Color gold, Color green, Color ink, Color soft) {
    final sheet = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .18, size.height * .14, size.width * .5,
          size.height * .58),
      const Radius.circular(18),
    );
    canvas.drawRRect(sheet, Paint()..color = soft);
    canvas.drawRRect(
        sheet,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = blue.withValues(alpha: .28));
    for (var i = 0; i < 5; i++) {
      final y = size.height * (.24 + i * .08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              size.width * .25, y, size.width * (.28 + i * .025), 7),
          const Radius.circular(8),
        ),
        Paint()..color = ink.withValues(alpha: i == 0 ? .45 : .18),
      );
    }
    final chart = Path()
      ..moveTo(size.width * .24, size.height * .60)
      ..cubicTo(size.width * .34, size.height * .52, size.width * .38,
          size.height * .65, size.width * .48, size.height * .50)
      ..cubicTo(size.width * .54, size.height * .41, size.width * .59,
          size.height * .43, size.width * .64, size.height * .34);
    canvas.drawPath(
        chart,
        Paint()
          ..color = gold
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    _magnifier(canvas, Offset(size.width * .66, size.height * .54),
        size.shortestSide * .13, blue, ink);
    _node(canvas, Offset(size.width * .72, size.height * .26),
        size.shortestSide * .08, navy, gold, ink,
        label: '%');
  }

  void _drawRisk(Canvas canvas, Size size, Color navy, Color blue, Color gold,
      Color red, Color ink, Color soft) {
    final shield = Path()
      ..moveTo(size.width * .5, size.height * .12)
      ..lineTo(size.width * .72, size.height * .22)
      ..cubicTo(size.width * .7, size.height * .54, size.width * .62,
          size.height * .70, size.width * .5, size.height * .80)
      ..cubicTo(size.width * .38, size.height * .70, size.width * .3,
          size.height * .54, size.width * .28, size.height * .22)
      ..close();
    canvas.drawPath(shield, Paint()..color = soft);
    canvas.drawPath(
        shield,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = blue.withValues(alpha: .45));
    canvas.drawLine(
        Offset(size.width * .5, size.height * .26),
        Offset(size.width * .5, size.height * .56),
        Paint()
          ..color = gold
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        Offset(size.width * .5, size.height * .64), 4.5, Paint()..color = gold);
    _riskPill(canvas, Offset(size.width * .14, size.height * .60), 'LOW', blue);
    _riskPill(
        canvas, Offset(size.width * .60, size.height * .40), 'WATCH', red);
    _miniBar(canvas, Offset(size.width * .16, size.height * .30),
        size.width * .24, gold);
  }

  void _drawAllocation(Canvas canvas, Size size, Color navy, Color blue,
      Color gold, Color green, Color ink, Color soft) {
    final base = Offset(size.width * .5, size.height * .48);
    final radius = size.shortestSide * .22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .28
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: base, radius: radius), -1.55, 2.3,
        false, paint..color = blue);
    canvas.drawArc(Rect.fromCircle(center: base, radius: radius), .9, 1.45,
        false, paint..color = gold);
    canvas.drawArc(Rect.fromCircle(center: base, radius: radius), 2.55, 1.05,
        false, paint..color = green);
    _node(canvas, base, radius * .46, soft, navy, ink, label: 'NAV');
    _riskPill(
        canvas, Offset(size.width * .14, size.height * .26), 'CORE', blue);
    _riskPill(
        canvas, Offset(size.width * .60, size.height * .68), 'SAT', green);
    _miniBar(canvas, Offset(size.width * .62, size.height * .22),
        size.width * .2, gold);
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  void _node(Canvas canvas, Offset center, double radius, Color fill,
      Color stroke, Color textColor,
      {String? label}) {
    canvas.drawCircle(center, radius, Paint()..color = fill);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = stroke.withValues(alpha: .65));
    if (label == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: radius * .72),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _miniBar(Canvas canvas, Offset origin, double width, Color color) {
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              origin.dx, origin.dy + i * 12, width * (1 - i * .13), 6),
          const Radius.circular(8),
        ),
        Paint()..color = color.withValues(alpha: .72 - i * .1),
      );
    }
  }

  void _magnifier(
      Canvas canvas, Offset center, double radius, Color stroke, Color ink) {
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = stroke);
    canvas.drawLine(
        center + Offset(radius * .68, radius * .68),
        center + Offset(radius * 1.35, radius * 1.35),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = stroke);
    canvas.drawCircle(
        center, radius * .28, Paint()..color = ink.withValues(alpha: .16));
  }

  void _riskPill(Canvas canvas, Offset origin, String text, Color color) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, 74, 26),
      const Radius.circular(99),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: .16));
    canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: .45));
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: .8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas,
        Offset(origin.dx + 37 - painter.width / 2,
            origin.dy + 13 - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.dark != dark;
  }
}
