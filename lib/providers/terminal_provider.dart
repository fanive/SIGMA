// ignore_for_file: unreachable_switch_default
import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// WORKSPACE PROVIDER — State management for the institutional research layout
// ═════════════════════════════════════════════════════════════════════════════

/// Available research workspaces
enum TerminalPanel {
  // ── Primary panels (mobile bottom nav, indices 0-4) ──────────────────────
  marketOverview,
  watchlist,
  newsFeed,
  analysis,
  settings,
  // ── Extended panels (desktop sidebar, Phase 2) ────────────────────────────
  intelligence,
  portfolio,
  charts,
}

/// Layout modes
enum TerminalLayout {
  single, // One panel fills the content area
  split2, // Two panels side by side (future)
  split4, // Four panels in a grid (future)
}

extension TerminalPanelInfo on TerminalPanel {
  String getLabel(String lang) {
    final isFr = lang == 'FR';
    switch (this) {
      case TerminalPanel.marketOverview:
        return isFr ? 'MACRO' : 'MACRO';
      case TerminalPanel.watchlist:
        return isFr ? 'CONVICTIONS' : 'CONVICTIONS';
      case TerminalPanel.newsFeed:
        return isFr ? 'BRIEFING' : 'BRIEFING';
      case TerminalPanel.analysis:
        return isFr ? 'RECHERCHE' : 'RESEARCH';
      case TerminalPanel.settings:
        return isFr ? 'PROFIL' : 'PROFILE';
      case TerminalPanel.intelligence:
        return isFr ? 'SIGNALS' : 'SIGNALS';
      case TerminalPanel.portfolio:
        return isFr ? 'ALLOCATION' : 'ALLOCATION';
      case TerminalPanel.charts:
        return isFr ? 'MARCHÉS' : 'MARKETS';
      default:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case TerminalPanel.marketOverview:
        return Icons.account_balance_rounded;
      case TerminalPanel.watchlist:
        return Icons.bookmark_added_rounded;
      case TerminalPanel.newsFeed:
        return Icons.article_rounded;
      case TerminalPanel.analysis:
        return Icons.manage_search_rounded;
      case TerminalPanel.settings:
        return Icons.person_outline_rounded;
      case TerminalPanel.intelligence:
        return Icons.auto_graph_rounded;
      case TerminalPanel.portfolio:
        return Icons.pie_chart_rounded;
      case TerminalPanel.charts:
        return Icons.query_stats_rounded;
      default:
        return Icons.help_outline;
    }
  }

  /// True = part of the 5 primary tabs (mobile bottom nav + top of desktop sidebar)
  bool get isPrimary {
    switch (this) {
      case TerminalPanel.marketOverview:
      case TerminalPanel.watchlist:
      case TerminalPanel.newsFeed:
      case TerminalPanel.analysis:
      case TerminalPanel.settings:
        return true;
      default:
        return false;
    }
  }

  /// Keyboard shortcut hint
  String get shortcutHint {
    switch (this) {
      case TerminalPanel.marketOverview:
        return '⌘1';
      case TerminalPanel.watchlist:
        return '⌘2';
      case TerminalPanel.newsFeed:
        return '⌘3';
      case TerminalPanel.analysis:
        return '⌘4';
      case TerminalPanel.settings:
        return '⌘5';
      case TerminalPanel.intelligence:
        return '⌘6';
      case TerminalPanel.portfolio:
        return '⌘7';
      case TerminalPanel.charts:
        return '⌘8';
      default:
        return '';
    }
  }
}

class TerminalProvider extends ChangeNotifier {
  // ─── Current State ─────────────────────────────────────────────────────────
  TerminalPanel _activePanel = TerminalPanel.marketOverview;
  TerminalLayout _layoutMode = TerminalLayout.single;
  final List<String> _commandHistory = [];
  bool _sidebarExpanded = false;
  bool _omnibarFocused = false;

  // ─── Ticker for analysis context ───────────────────────────────────────────
  String? _focusedTicker;

  // ─── Getters ───────────────────────────────────────────────────────────────
  TerminalPanel get activePanel => _activePanel;
  TerminalLayout get layoutMode => _layoutMode;
  List<String> get commandHistory => List.unmodifiable(_commandHistory);
  bool get sidebarExpanded => _sidebarExpanded;
  bool get omnibarFocused => _omnibarFocused;
  String? get focusedTicker => _focusedTicker;

  // ─── Panel Navigation ──────────────────────────────────────────────────────
  void switchPanel(TerminalPanel panel) {
    if (_activePanel != panel) {
      _activePanel = panel;
      notifyListeners();
    }
  }

  /// Navigate to analysis panel with a specific ticker
  void openAnalysis(String ticker) {
    _focusedTicker = ticker;
    _activePanel = TerminalPanel.analysis;
    notifyListeners();
  }

  // ─── Layout ────────────────────────────────────────────────────────────────
  void setLayout(TerminalLayout layout) {
    if (_layoutMode != layout) {
      _layoutMode = layout;
      notifyListeners();
    }
  }

  // ─── Sidebar ───────────────────────────────────────────────────────────────
  void toggleSidebar() {
    _sidebarExpanded = !_sidebarExpanded;
    notifyListeners();
  }

  // ─── Omnibar ───────────────────────────────────────────────────────────────
  void setOmnibarFocus(bool focused) {
    _omnibarFocused = focused;
    notifyListeners();
  }

  void addToHistory(String command) {
    _commandHistory.insert(0, command);
    if (_commandHistory.length > 100) {
      _commandHistory.removeLast();
    }
  }

  // ─── Ticker Context ────────────────────────────────────────────────────────
  void setFocusedTicker(String? ticker) {
    _focusedTicker = ticker;
    notifyListeners();
  }
}
