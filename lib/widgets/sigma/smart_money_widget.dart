// ignore_for_file: unnecessary_cast, unused_import
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quantum_invest/theme/app_theme.dart';
import '../../services/sigma_service.dart';

class SmartMoneyWidget extends StatefulWidget {
  final String ticker;

  const SmartMoneyWidget({super.key, required this.ticker});

  @override
  State<SmartMoneyWidget> createState() => _SmartMoneyWidgetState();
}

class _SmartMoneyWidgetState extends State<SmartMoneyWidget> {
  final SigmaService _sigma = SigmaService.fromEnv();
  
  List<dynamic> _holders = [];
  List<dynamic> _insiders = [];
  bool _isLoading = true;
  String _selectedTab = 'holders';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _sigma.fmpService.getInstitutionalHolders(widget.ticker),
        _sigma.fmpService.getInsiderTrading(widget.ticker),
      ]);

      if (mounted) {
        setState(() {
          _holders = results[0];
          _insiders = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurface(context),
        border: Border.all(color: AppTheme.getBorder(context), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTabs(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            _buildContent(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.getBorder(context), width: 0.5)),
      ),
      child: Row(
        children: [
          _tabItem('PROPRIÉTÉ INST.', 'holders'),
          _tabItem('INSIDER TRADING', 'insiders'),
        ],
      ),
    );
  }

  Widget _tabItem(String label, String id) {
    final isSelected = _selectedTab == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = id),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.lora(
              fontSize: 8,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? AppTheme.primary : AppTheme.white38,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedTab == 'holders') return _buildHoldersList();
    return _buildInsidersList();
  }

  Widget _buildHoldersList() {
    if (_holders.isEmpty) return _emptyState();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOP INSTITUTIONAL HOLDERS', style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.white38)),
              Text('SHARES', style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.white38)),
            ],
          ),
        ),
        ..._holders.take(8).map((h) => _holderRow(h)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _holderRow(dynamic h) {
    final name = h['holder']?.toString() ?? 'N/A';
    final shares = (h['shares'] as num?)?.toDouble() ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.getBorder(context).withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: GoogleFonts.lora(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _fmtLarge(shares),
            style: GoogleFonts.lora(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildInsidersList() {
    if (_insiders.isEmpty) return _emptyState();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('INSIDER / ROLE', style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.white38))),
              Expanded(flex: 2, child: Text('TYPE', style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.white38))),
              Expanded(flex: 2, child: Text('SHARES', style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.white38), textAlign: TextAlign.right)),
            ],
          ),
        ),
        ..._insiders.take(8).map((i) => _insiderRow(i)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _insiderRow(dynamic i) {
    final name = i['reportingName']?.toString() ?? 'N/A';
    final role = i['typeOfOwner']?.toString() ?? '';
    final type = i['transactionType']?.toString() ?? '';
    final isBuy = type.toLowerCase().contains('buy') || type.toLowerCase().contains('purchase');
    final shares = (i['securitiesTransacted'] as num?)?.toDouble() ?? 0.0;
    final color = isBuy ? AppTheme.positive : AppTheme.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.getBorder(context).withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toUpperCase(), style: GoogleFonts.lora(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.white), overflow: TextOverflow.ellipsis),
                Text(role.toUpperCase(), style: GoogleFonts.lora(fontSize: 7, fontWeight: FontWeight.w700, color: AppTheme.white38), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(
                isBuy ? 'BUY' : 'SELL',
                style: GoogleFonts.lora(fontSize: 8, fontWeight: FontWeight.w900, color: color),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtLarge(shares),
              style: GoogleFonts.lora(fontSize: 11, fontWeight: FontWeight.w900),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Center(
        child: Text(
          'NO DATA AVAILABLE',
          style: TextStyle(fontSize: 8, color: AppTheme.textTertiary, letterSpacing: 1),
        ),
      ),
    );
  }

  String _fmtLarge(double n) {
    if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(1)}B';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}


