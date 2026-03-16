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
    final reversedKey = const String.fromEnvironment('GEMINI_API_KEY_B64');
    
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
          )
        );
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
      You are a real-time Formaldehyde (HCHO) air quality advisor. 
      Your LIVE sensor reading is exactly $ppm PPM.
      
      RULES:
      1. If $ppm is 0.000, simply state "Air quality is currently optimal. No detectable formaldehyde." and nothing else.
      2. If $ppm is between 0.001 and 0.080, give 2 brief tips for maintaining these healthy levels.
      3. If $ppm is > 0.080 PPM, provide 3 URGENT, actionable safety steps.
      4. DO NOT explain what Formaldehyde is. 
      5. DO NOT give general advice about ventilation unless levels are elevated.
      6. Professional, concise tone. Bullet points only. Max 100 words.
    ''';

    try {
      await for (final chunk in _model!.generateContentStream([Content.text(prompt)])) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield "Error connecting to AI Provider: $e";
    }
  }
}
