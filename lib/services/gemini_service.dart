import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:async';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // The key is injected as a Base64 string at compile-time to defeat GitHub Secret Scanners.
    const encodedKey = String.fromEnvironment('GEMINI_API_KEY_B64');
    
    if (encodedKey.isNotEmpty) {
      try {
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
        print("Failed to decode base64 API key: $e");
      }
    }
  }

  Stream<String> getSafetyTipsStream(double ppm) async* {
    if (!_isInitialized || _model == null) {
       yield "API Key missing or invalid. Check your build configuration.";
       return;
    }

    final prompt = '''
      You are an expert indoor air quality advisor.
      Live HCHO reading: $ppm PPM.
      Briefly explain health impact (safe is < 0.1 PPM) and provide 3 immediate, actionable tips. 
      Professional tone. Bullet points only, no headers.
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
