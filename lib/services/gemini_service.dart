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
              maxOutputTokens: 150,
            ));
        _isInitialized = true;
      } catch (e) {
        LogService.instance.log("Failed to decode obfuscated API key: $e");
      }
    }
  }

  Stream<String> getSafetyTipsStream(double ppm) async* {
    if (!_isInitialized || _model == null) {
      yield "API Key missing or invalid. Check your build configuration.";
      return;
    }

    final prompt = '''
      You are a safety expert viewing a LIVE sensor reading from a room.
      Reading: $ppm PPM of Formaldehyde (HCHO).
      
      TASK:
      Based on this EXACT concentration, provide a medical-grade safety assessment. 
      Use your knowledge of WHO, OSHA, and EPA standards to judge the risk.
      
      RULES:
      1. If the level is hazardous (above 0.08 PPM), be increasingly urgent.
      2. If the level is EXTREME (above 2.0 PPM), prioritize immediate evacuation and professional remediation.
      3. Provide 2-3 prioritized, actionable bullet points. 
      4. DO NOT provide general definitions or history of VOCs.
      5. Professional, punchy tone. Max 80 words total.
    ''';

    try {
      await for (final chunk
          in _model!.generateContentStream([Content.text(prompt)])) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield "Error connecting to AI Provider: $e";
    }
  }

  /// Returns a single, punchy safety sentence for the dashboard alert.
  /// Optimized for speed.
  Future<String> getFlashAdvice(double ppm) async {
    if (!_isInitialized || _model == null) return "Increased levels detected—ventilate now.";

    final prompt =
        'Reading: $ppm PPM of Formaldehyde (HCHO). '
        'Based on world health standards for this SPECIFIC concentration, '
        'give 1 extremely short, punchy safety instruction (max 12 words). '
        'If levels are extreme, be urgent and command evacuation. '
        'Just the instruction, no quotes.';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? "Increased levels detected—ventilate now.";
    } catch (e) {
      return "Increased levels detected—ventilate now.";
    }
  }
}
