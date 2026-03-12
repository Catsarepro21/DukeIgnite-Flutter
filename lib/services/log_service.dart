import 'package:flutter/foundation.dart';

/// A simple service to capture and store application logs for in-app viewing.
class LogService extends ChangeNotifier {
  // Singleton pattern
  static final LogService instance = LogService._internal();
  LogService._internal();

  final List<String> _logs = [];
  static const int _maxLogs = 200;

  List<String> get logs => List.unmodifiable(_logs);

  void log(String message) {
    final timestamp = DateTime.now().toString().split(' ').last.substring(0, 12);
    final formatted = '[$timestamp] $message';
    
    // Always print to system console
    debugPrint(formatted);
    
    _logs.add(formatted);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    log('Logs cleared.');
    notifyListeners();
  }
}
