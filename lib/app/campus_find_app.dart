
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';

class CampusFindApp extends StatelessWidget {
  const CampusFindApp({super.key});

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
 