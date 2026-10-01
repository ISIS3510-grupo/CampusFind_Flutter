import 'package:campusfind_flutter/views/report_item_screen.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';

class CampusFindApp extends StatelessWidget {
  const CampusFindApp({super.key});

  // Main configuration of the Flutter application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ReportItemScreen(),
      //home: const LoginScreen(),
    );
  }
}
 