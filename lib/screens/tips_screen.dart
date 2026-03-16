import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/gemini_service.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  String _geminiTips = "";
  bool _isGenerating = false;

  void _generateTips(double currentPpm) {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _geminiTips = "";
    });

    try {
      GeminiService.instance.getSafetyTipsStream(currentPpm).listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _geminiTips += chunk;
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isGenerating = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _geminiTips = "Error generating tips: $e";
              _isGenerating = false;
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _geminiTips = "Failed to initialize Gemini: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Tips'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Tips Card
            Consumer<SensorData>(
              builder: (context, sensorData, child) {
                return Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.blueAccent),
                            SizedBox(width: 10),
                            Text(
                              'Tips',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _geminiTips.isEmpty 
                              ? 'Tap below to generate personalized advice based on your live reading (${sensorData.ppm.toStringAsFixed(3)} PPM).'
                              : _geminiTips,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isGenerating ? null : () => _generateTips(sensorData.ppm),
                          icon: _isGenerating 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                            : const Icon(Icons.refresh),
                          label: Text(_isGenerating ? 'Generating...' : 'Get Personalized Tips'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // Default Tips
            const Text(
              'Standard Safety Guidelines',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Keep the room ventilated.\n'
              '• Monitor PPM levels regularly.\n'
              '• Avoid prolonged exposure in high PPM areas.',
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}