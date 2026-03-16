import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ThingSpeakReading {
  final DateTime createdAt;
  final double ppm;

  ThingSpeakReading({required this.createdAt, required this.ppm});
}

class ThingSpeakService {
  ThingSpeakService._internal();
  static final ThingSpeakService instance = ThingSpeakService._internal();

  /// Fetches the last [results] entries from the specified ThingSpeak channel.
  Future<List<ThingSpeakReading>> fetchHistory({
    required String channelId,
    String? apiKey,
    int results = 100,
    int fieldIndex = 1, // Default to Field 1
  }) async {
    final baseUrl = 'https://api.thingspeak.com/channels/$channelId/feeds.json';
    final queryParameters = {
      'results': results.toString(),
      if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParameters);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List feeds = data['feeds'] ?? [];

        return feeds.map((feed) {
          final rawValue = feed['field$fieldIndex'];
          final ppm = double.tryParse(rawValue?.toString() ?? '0.0') ?? 0.0;
          final time = DateTime.tryParse(feed['created_at']) ?? DateTime.now();
          return ThingSpeakReading(createdAt: time.toLocal(), ppm: ppm);
        }).toList();
      } else {
        debugPrint('[ThingSpeakService] Error: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[ThingSpeakService] Exception: $e');
      return [];
    }
  }
}
