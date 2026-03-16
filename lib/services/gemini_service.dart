import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );
      _isInitialized = true;
    }
  }

  Stream<String> getSafetyTipsStream(double ppm) async* {
    if (!_isInitialized || _model == null) {
       yield "Gemini API key not configured. Add GEMINI_API_KEY to your .env file.";
       return;
    }

    final prompt = '''
      You are an expert indoor air quality advisor embedded in a health and safety app tracking formaldehyde (HCHO) levels.
      The current live sensor reading is $ppm PPM.
      
      Briefly explain the health impact of this level (safe is < 0.1 PPM) and provide 3 immediate, practical, and actionable tips for the user in a short, bulleted list. 
      Keep the tone helpful and professional. Do not use markdown headers, just bullet points.
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
