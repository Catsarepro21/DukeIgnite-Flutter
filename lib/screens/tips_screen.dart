import 'package:flutter/material.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Tips'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '• Keep the room ventilated.\n'
          '• Monitor PPM levels regularly.\n'
          '• Avoid prolonged exposure in high PPM areas.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}