// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sigma_models.dart';

class SentimentService {
  static const String _baseUrl = 'https://feargreedchart.com/api';

  Future<FearGreedData?> fetchFearGreed() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FearGreedData.fromJson(data);
      }
    } catch (e) {
      print('Error fetching sentiment: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/?action=history'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error fetching sentiment history: $e');
    }
    return [];
  }

  Future<List<SentimentNews>> fetchNews() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/?action=news'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => SentimentNews.fromJson(e)).toList();
      }
    } catch (e) {
      print('Error fetching sentiment news: $e');
    }
    return [];
  }
}
