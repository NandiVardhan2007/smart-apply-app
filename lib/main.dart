import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/utils/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local logging for Windows/Mobile debugging
  await LocalLogger.init();
  await LocalLogger.log('App Startup initiated');
  
  runApp(
    const ProviderScope(
      child: SmartApplyApp(),
    ),
  );
}
