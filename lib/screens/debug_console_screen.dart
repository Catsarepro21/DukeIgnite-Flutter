import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';
import 'dashboard_screen.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final ScrollController _scrollController = ScrollController();

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
              LogService.instance.log('[Debug] Bypassing connection for testing.');
              // Push replacement so going back doesn't take them back to debug console instantly
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            tooltip: 'Bypass Connection (Test)',
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
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
    );
  }
}
