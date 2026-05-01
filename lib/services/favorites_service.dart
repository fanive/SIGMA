// ignore_for_file: avoid_print
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _key = 'favorite_tickers';
  static const String _stickerPrefix = 'sticker_';

  // Static stream controller to notify listeners across the app
  static final _updateController = StreamController<void>.broadcast();
  Stream<void> get updateStream => _updateController.stream;

  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<bool> isFavorite(String ticker) async {
    final favorites = await getFavorites();
    return favorites.contains(ticker.toUpperCase());
  }

  Future<void> toggleFavorite(String ticker) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_key) ?? [];
    final upperTicker = ticker.toUpperCase();

    if (favorites.contains(upperTicker)) {
      favorites.remove(upperTicker);
      // Also remove sticker if ticker is removed
      await prefs.remove(_stickerPrefix + upperTicker);
      print('FavoritesService: Removed $upperTicker');
    } else {
      favorites.add(upperTicker);
      print('FavoritesService: Added $upperTicker');
    }

    await prefs.setStringList(_key, favorites);
    print('FavoritesService: Saved list $favorites');
    _updateController.add(null); // Notify all listeners
  }

  Future<String?> getSticker(String ticker) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_stickerPrefix + ticker.toUpperCase());
  }

  Future<void> setSticker(String ticker, String sticker) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stickerPrefix + ticker.toUpperCase(), sticker);
    _updateController.add(null); // Notify all listeners
  }
}
