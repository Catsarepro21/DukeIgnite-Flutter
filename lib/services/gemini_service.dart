import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'log_service.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  DateTime? _lastErrorTime;
  static const _cooldown = Duration(minutes: 1);

  Future<void> initialize() async {
    if (_isInitialized) return;

    const reversedKey = String.fromEnvironment('GEMINI_API_KEY_B64');

    if (reversedKey.isNotEmpty) {
      try {
        final encodedKey = reversedKey.split('').reversed.join('');
        final decodedKey = utf8.decode(base64Decode(encodedKey));
        // Use Gemini 3.1 Flash-Lite - March 2026 release.
        _model = GenerativeModel(
            model: 'gemini-3.1-flash-lite',
            apiKey: decodedKey,
            generationConfig: GenerationConfig(
              temperature: 0.4, // Adjusted for better flow
              maxOutputTokens: 1024, // High limit to ensure no truncation
            ));
        _isInitialized = true;
      } catch (e) {
        LogService.instance.log("Failed to initialize Gemini: $e");
      }
    }
  }

  bool get _isInCooldown {
    if (_lastErrorTime == null) return false;
    return DateTime.now().difference(_lastErrorTime!) < _cooldown;
  }

  Stream<String> getSafetyTipsStream(double ppm) async* {
    if (!_isInitialized || _model == null) {
      yield "AI Advisor is not initialized.";
      return;
    }

    if (_isInCooldown) {
      final remains = _cooldown.inSeconds - DateTime.now().difference(_lastErrorTime!).inSeconds;
      yield "AI is cooling down from quota limits. Please wait $remains seconds.";
      return;
    }

    final prompt = '''
      Analyze the formaldehyde (HCHO) level: $ppm PPM.
      
      1. **Risk Level**: Provide a clear, bolded risk assessment (WHO/OSHA standards).
      2. **Safety Actions**: List 3 prioritized actions to take now.
      
      Keep the response direct, authoritative, and under 100 words. Use markdown.
    ''';

    try {
      await for (final chunk
          in _model!.generateContentStream([Content.text(prompt)])) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
      _lastErrorTime = null; // Reset on success
    } catch (e) {
      if (e.toString().contains("429")) {
        _lastErrorTime = DateTime.now();
      }
      yield "AI Service error: $e";
    }
  }

  /// Fetches the list of available models from the Gemini API.
  Future<List<String>> listModels() async {
    const reversedKey = String.fromEnvironment('GEMINI_API_KEY_B64');
    if (reversedKey.isEmpty) return ["API Key not found."];

    try {
      final encodedKey = reversedKey.split('').reversed.join('');
      final apiKey = utf8.decode(base64Decode(encodedKey));
      
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List models = data['models'] ?? [];
        return models.map((m) => m['name']?.toString() ?? 'unknown').toList();
      } else {
        return ["Error: HTTP ${response.statusCode}", response.body];
      }
    } catch (e) {
      return ["Exception: $e"];
    }
  }

  /// Returns a single, punchy safety sentence for the dashboard alert.
  /// Optimized for extreme reactivity and awareness.
  Future<String> getFlashAdvice(double ppm) async {
    if (!_isInitialized || _model == null) return "High levels detected. Please ventilate.";

    final prompt =
        'Reading: $ppm PPM of HCHO. '
        'Judge the danger level (WHO/OSHA). '
        'Provide ONE single, ultra-short safety command (max 8 words). '
        'If levels are > 2.0 PPM, command immediate evacuation in all caps. '
        'No quotes, just the command.';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "High levels detected. Please ventilate.";
    } catch (e) {
      return "High levels detected. Please ventilate.";
    }
  }
}
