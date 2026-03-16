import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

  @override
  void initState() {
    super.initState();
    // Schedule initial generation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sensorData = Provider.of<SensorData>(context, listen: false);
      _generateTips(sensorData.ppm);
    });
  }


  void _generateTips(double currentPpm) {
    if (_isGenerating || !mounted) return;

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
            String errorMsg = e.toString();
            if (errorMsg.contains("429") || errorMsg.contains("quota")) {
              errorMsg = "AI Quota exceeded. Please wait a minute before trying again.";
            }
            setState(() {
              _geminiTips = "Error: $errorMsg";
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                            const SizedBox(width: 10),
                            const Text(
                              'Live AI Advice',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_isGenerating)
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        if (_geminiTips.isEmpty)
                          Text(
                            'Tap below for advice based on your live reading (${sensorData.ppm.toStringAsFixed(3)} PPM).',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16),
                          )
                        else
                          MarkdownBody(
                            data: _geminiTips,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  color: Colors.white70, fontSize: 16),
                              strong: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                              listBullet: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isGenerating
                              ? null
                              : () => _generateTips(sensorData.ppm),
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white54))
                              : const Icon(Icons.refresh),
                          label: Text(_isGenerating
                              ? 'Generating...'
                              : 'Get Personalized Advice'),
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
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text(
              'Formaldehyde (HCHO) is a common indoor air pollutant found in furniture, building materials, and cleaning products. Long-term exposure can lead to respiratory irritation and other health issues.',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 20),
            const Text(
              '• Ventilation: Ensure adequate airflow by opening windows for 15-30 minutes, especially during cleaning or after painting.\n'
              '• Purification: Use air purifiers with activated carbon filters to effectively capture VOCs like formaldehyde.\n'
              '• Monitoring: Keep an eye on PPM levels regularly to detect trends early.\n'
              '• Source Control: Favor low-VOC materials when purchasing new furniture or carpets.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
