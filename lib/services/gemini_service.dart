import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('gemini_api_key') ?? const String.fromEnvironment('GEMINI_API_KEY');
    
    if (apiKey.isNotEmpty) {
      _setupModel(apiKey);
    }
  }

  void _setupModel(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 150,
      )
    );
    _isInitialized = true;
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', apiKey);
    _setupModel(apiKey);
  }

  bool get hasKey => _isInitialized && _model != null;

  Stream<String> getSafetyTipsStream(double ppm) async* {
    if (!hasKey) {
       yield "API Key missing. Please provide your Gemini API key.";
       return;
    }

    final prompt = '''
      You are an expert indoor air quality advisor.
      Live HCHO reading: $ppm PPM.
      Provide 3 immediate, actionable tips based ONLY on this reading. 
      DO NOT provide any general information, explanations, health impact summaries, or headers. 
      JUST 3 bullet points. Professional tone.
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
