import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/interactive_stock_chart.dart';

class FullscreenChartScreen extends StatefulWidget {
  final String ticker;

  const FullscreenChartScreen({super.key, required this.ticker});

  @override
  State<FullscreenChartScreen> createState() => _FullscreenChartScreenState();
}

class _FullscreenChartScreenState extends State<FullscreenChartScreen> {
  @override
  void initState() {
    super.initState();
    // Force Landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide status bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Reset Orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            child: InteractiveStockChart(ticker: widget.ticker, isFullscreen: true),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, color: AppTheme.white38, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}


