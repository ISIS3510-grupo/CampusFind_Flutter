import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';

class CampusFindApp extends StatelessWidget {
  const CampusFindApp({super.key});

  // Main configuration of the Flutter application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      home: const SizedBox.shrink(),
    );
  }
}
