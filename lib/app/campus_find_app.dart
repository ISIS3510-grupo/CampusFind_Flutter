import 'package:flutter/material.dart';

import 'package:campusfind_flutter/core/constants/app_constants.dart';
import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';

class CampusFindApp extends StatelessWidget {
  const CampusFindApp({super.key});

  // Main configuration of the Flutter application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
