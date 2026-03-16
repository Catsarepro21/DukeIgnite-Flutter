import 'package:google_generative_ai/google_generative_ai.dart';
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
        // Use Gemini 2.5 Flash - latest stable model for 2026.
        _model = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: decodedKey,
            generationConfig: GenerationConfig(
              temperature: 0.3, // Slightly higher for better flow
              maxOutputTokens: 512, // Increased to prevent truncation
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
      You are a specialized Medical Toxicologist and Environmental Health Expert. 
      CURRENT FORMALDEHYDE (HCHO) READING: $ppm PPM.
      
      TASK:
      Provide a concise 2-part safety brief.
      
      FORMAT:
      1. **[RISK LEVEL]**: One bold risk assessment based on WHO/OSHA standards.
      2. **[ACTIONS]**: A numbered list of 3 specific, prioritized safety actions.
      
      GUIDELINES:
      - Be direct and authoritative.
      - Total length must be under 100 words.
      - Do not include introductory text or general definitions.
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

  /// Returns a single, punchy safety sentence for the dashboard alert.
  /// Note: This is currently unused in favor of local safety ranges.
  Future<String> getFlashAdvice(double ppm) async {
    return "Please view personalized tips for detailed advice.";
  }
}
