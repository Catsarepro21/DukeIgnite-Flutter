import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';
import '../services/thingspeak_service.dart';
import 'dashboard_screen.dart';

import 'package:provider/provider.dart';
import '../models/sensor_data.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    LogService.instance.addListener(_update);
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    LogService.instance.removeListener(_update);
    _scrollController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _update() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleCommand(String input) async {
    if (input.trim().isEmpty) return;

    final parts = input.trim().toLowerCase().split(' ');
    final command = parts[0];
    final sensorData = Provider.of<SensorData>(context, listen: false);

    LogService.instance.log('> $input');

    try {
      switch (command) {
        case 'help':
          LogService.instance.log('[System] Available Commands:\n'
              '  - ppm <val>: Set HCHO reading\n'
              '  - threshold <val>: Set alarm limit\n'
              '  - volume <0-100>: Set alarm volume\n'
              '  - contrast <0-100>: Set LCD contrast\n'
              '  - status <on|off>: Toggle connection UI\n'
              '  - log <msg>: Print custom message\n'
              '  - ts <ppm>: Push PPM to ThingSpeak\n'
              '  - clear: Wipe console history');
          break;
        case 'ppm':
          if (parts.length > 1) {
            final val = double.parse(parts[1]);
            sensorData.updatePpm(val);
            LogService.instance.log('[Debug] Set PPM to $val');
          }
          break;
        case 'threshold':
          if (parts.length > 1) {
            final val = double.parse(parts[1]);
            sensorData.updatePpmThreshold(val);
            LogService.instance.log('[Debug] Set Threshold to $val');
          }
          break;
        case 'volume':
          if (parts.length > 1) {
            final val = int.parse(parts[1]);
            sensorData.updateVolume(val);
            LogService.instance.log('[Debug] Set Volume to $val');
          }
          break;
        case 'contrast':
          if (parts.length > 1) {
            final val = int.parse(parts[1]);
            sensorData.updateLcdContrast(val);
            LogService.instance.log('[Debug] Set Contrast to $val');
          }
          break;
        case 'status':
          if (parts.length > 1) {
            final val = parts[1] == 'on';
            sensorData.setConnectionStatus(val);
            LogService.instance.log('[Debug] Connection status set to $val');
          }
          break;
        case 'ts':
          if (parts.length > 1) {
            final val = double.parse(parts[1]);
            final success = await ThingSpeakService.instance.updateField(
              writeApiKey: 'GUA6KB0HVB22T7M0',
              value: val,
            );
            if (success) {
              LogService.instance.log('[Debug] Pushed $val to ThingSpeak');
            } else {
              LogService.instance.log('[Error] Failed to push to ThingSpeak');
            }
          }
          break;
        case 'log':
          if (parts.length > 1) {
            LogService.instance.log('[User] ${parts.sublist(1).join(' ')}');
          }
          break;
        case 'clear':
          LogService.instance.clear();
          break;
        default:
          LogService.instance
              .log('[Error] Unknown command: $command. Type "help" for list.');
      }
    } catch (e) {
      LogService.instance.log('[Error] Invalid value: $e');
    }

    _commandController.clear();
  }

  void _copyToClipboard() {
    final allLogs = LogService.instance.logs.join('\n');
    Clipboard.setData(ClipboardData(text: allLogs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = LogService.instance.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copy all logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => LogService.instance.clear(),
            tooltip: 'Clear logs',
          ),
          IconButton(
            icon: const Icon(Icons.rocket_launch),
            onPressed: () {
              LogService.instance
                  .log('[Debug] Bypassing connection for testing.');
              final sensorData = Provider.of<SensorData>(context, listen: false);
              sensorData.setBypassMode(true);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (context) => const DashboardScreen()),
              );
            },
            tooltip: 'Bypass Connection (Test)',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    logs[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('>',
                    style: TextStyle(
                        color: Colors.greenAccent, fontFamily: 'Courier')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Enter command (ppm 0.1)...',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                    onSubmitted: _handleCommand,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () => _handleCommand(_commandController.text),
                ),
              ],
            ),
          ),
          // Bottom safe area padding
          Container(
              height: MediaQuery.of(context).padding.bottom,
              color: Colors.grey[900]),
        ],
      ),
    );
  }
}
