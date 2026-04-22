import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// Service to handle local file logging on Windows/Mobile.
class LocalLogger {
  static File? _logFile;
  static bool _initialized = false;

  /// Initialize the log file in the Documents directory.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final Directory? directory;
      if (Platform.isWindows) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getExternalStorageDirectory();
      }

      if (directory != null) {
        final logDir = Directory('${directory.path}/SmartApply');
        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
        
        _logFile = File('${logDir.path}/automation_logs.txt');
        
        // Add a session separator
        await log('--- NEW SESSION STARTED: ${DateTime.now()} ---');
        _initialized = true;
      }
    } catch (e) {
      debugPrint('Failed to initialize local logger: $e');
    }
  }

  /// Write a message to the local log file.
  static Future<void> log(String message) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final entry = '[$timestamp] $message\n';
      
      // Also print to console for development
      debugPrint('[SmartApplyLog] $entry');

      if (_logFile != null) {
        await _logFile!.writeAsString(entry, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      // Silent fail to avoid crashing the app if disk is full/locked
    }
  }

  /// Clear the log file.
  static Future<void> clear() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}
