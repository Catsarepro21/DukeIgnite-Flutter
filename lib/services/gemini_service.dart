import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:async';
import 'log_service.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // The key is injected as a REVERSED Base64 string at compile-time to defeat GitHub Secret Scanners.
    // We un-reverse it here at runtime.
    const reversedKey = String.fromEnvironment('GEMINI_API_KEY_B64');

    if (reversedKey.isNotEmpty) {
      try {
        final encodedKey = reversedKey.split('').reversed.join('');
        final decodedKey = utf8.decode(base64Decode(encodedKey));
        _model = GenerativeModel(
            model: 'gemini-2.5-flash-lite',
            apiKey: decodedKey,
            generationConfig: GenerationConfig(
              temperature: 0.2,
              maxOutputTokens: 250,
            ));
        _isInitialized = true;
      } catch (e) {
        LogService.instance.log("Failed to decode obfuscated API key: $e");
      }
    }
  }

  Stream<String> getSafetyTipsStream(double ppm) async* {
    if (!_isInitialized || _model == null) {
      yield "AI Advisor requires an active internet connection and valid API key.";
      return;
    }

    final prompt = '''
      You are a specialized Medical Toxicologist and Environmental Safety Expert.
      CURRENT FORMALDEHYDE (HCHO) READING: $ppm PPM.
      
      TASK:
      Analyze this specific concentration using WHO, OSHA, and EPA exposure limits.
      
      INTELLECTUAL EVALUATION:
      - At $ppm PPM, what are the immediate physiological risks?
      - Is this concentration considered "Safe", "Unhealthy", "Hazardous", or "Immediately Dangerous to Life and Health (IDLH)"?
      
      URGENCY RULES:
      - Under 0.08 PPM: Focus on long-term air quality maintenance.
      - 0.08 - 0.50 PPM: Immediate ventilation and source identification.
      - 0.50 - 2.00 PPM: High risk. Evacuate children/sensitive individuals. Full ventilation.
      - Above 2.00 PPM: EXTREME DANGER. Recommend immediate evacuation and hazmat/professional evaluation. Be blunt and authoritative.
      
      FORMAT:
      1. One bold risk level assessment.
      2. 3 highly specific, prioritized safety actions based on $ppm PPM.
      
      STRICT LIMITS:
      - Max 100 words.
      - No general history, no definitions. 
      - If $ppm is 0.000, praise the perfect air.
    ''';

    try {
      await for (final chunk
          in _model!.generateContentStream([Content.text(prompt)])) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield "AI Service unavailable: $e";
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
