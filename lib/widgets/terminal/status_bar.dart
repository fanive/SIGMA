import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/sigma_provider.dart';
import '../../providers/terminal_provider.dart';
import 'package:quantum_invest/theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// STATUS BAR — Bottom information bar (clock, connection, system info)
// ═════════════════════════════════════════════════════════════════════════════

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late Timer _clockTimer;
  String _localTime = '';
  String _nyTime = '';
  String _londonTime = '';

  @override
  void initState() {
    super.initState();
    _updateClocks();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClocks(),
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _updateClocks() {
    final now = DateTime.now();
    final utcNow = now.toUtc();
    // EST/EDT offset (simplified: UTC-5 / UTC-4)
    final nyOffset = _isDST(utcNow) ? -4 : -5;
    final nyNow = utcNow.add(Duration(hours: nyOffset));
    // GMT/BST offset
    final londonOffset = _isUKDST(utcNow) ? 1 : 0;
    final londonNow = utcNow.add(Duration(hours: londonOffset));

    if (mounted) {
      setState(() {
        _localTime = DateFormat('HH:mm:ss').format(now);
        _nyTime = DateFormat('HH:mm').format(nyNow);
        _londonTime = DateFormat('HH:mm').format(londonNow);
      });
    }
  }

  bool _isDST(DateTime utcDate) {
    // US DST: 2nd Sunday March - 1st Sunday November
    final marchSecondSunday = _nthSunday(utcDate.year, 3, 2);
    final novFirstSunday = _nthSunday(utcDate.year, 11, 1);
    return utcDate.isAfter(marchSecondSunday) &&
        utcDate.isBefore(novFirstSunday);
  }

  bool _isUKDST(DateTime utcDate) {
    // UK BST: last Sunday March - last Sunday October
    final marchLastSunday = _lastSunday(utcDate.year, 3);
    final octLastSunday = _lastSunday(utcDate.year, 10);
    return utcDate.isAfter(marchLastSunday) && utcDate.isBefore(octLastSunday);
  }

  DateTime _nthSunday(int year, int month, int n) {
    var d = DateTime.utc(year, month, 1);
    int count = 0;
    while (count < n) {
      if (d.weekday == DateTime.sunday) count++;
      if (count < n) d = d.add(const Duration(days: 1));
    }
    return d.add(const Duration(hours: 2));
  }

  DateTime _lastSunday(int year, int month) {
    var d = DateTime.utc(year, month + 1, 0); // last day
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d.add(const Duration(hours: 1));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = context.watch<TerminalProvider>();

    return Container(
      height: AppTheme.statusBarHeight,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.background : AppTheme.lightSurfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.border : AppTheme.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Connection status
            _statusDot(true, isDark),
            const SizedBox(width: 4),
            _label('SYNC OK', isDark),
            _separator(isDark),
            _label(
              tp.activePanel
                  .getLabel(context.watch<SigmaProvider>().language ?? "EN"),
              isDark,
            ),
            _separator(isDark),
            // Focused ticker
            if (tp.focusedTicker != null) ...[
              Text(
                tp.focusedTicker!,
                style: GoogleFonts.lora(
                  color: AppTheme.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _separator(isDark),
            ],
            const SizedBox(width: 32),
            // World clocks
            _clockLabel('NYC', _nyTime, isDark),
            _separator(isDark),
            _clockLabel('LON', _londonTime, isDark),
            _separator(isDark),
            // Local time
            Text(
              _localTime,
              style: GoogleFonts.lora(
                color:
                    isDark ? AppTheme.textPrimary : AppTheme.lightTextPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            _separator(isDark),
            _label('RESEARCH ONLINE', isDark),
            _separator(isDark),
            _label('SIGMA RESEARCH', isDark),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(bool connected, bool isDark) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? AppTheme.positive : AppTheme.negative,
        boxShadow: [
          BoxShadow(
            color: (connected ? AppTheme.positive : AppTheme.negative)
                .withValues(alpha: 0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.lora(
        color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _clockLabel(String city, String time, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$city ',
          style: GoogleFonts.lora(
            color: isDark ? AppTheme.textMuted : AppTheme.lightTextMuted,
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          time,
          style: GoogleFonts.lora(
            color:
                isDark ? AppTheme.textSecondary : AppTheme.lightTextSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _separator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 1,
        height: 10,
        color: isDark
            ? AppTheme.border.withValues(alpha: 0.5)
            : AppTheme.lightBorder.withValues(alpha: 0.5),
      ),
    );
  }
}
