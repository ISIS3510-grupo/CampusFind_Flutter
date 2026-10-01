import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../viewmodel/report_bottleneck_view_model.dart';
import '../viewmodel/report_registration_time_view_model.dart';
import 'report_bottleneck_panel.dart';
import 'report_registration_time_panel.dart';

// Staff Access opens this screen after admin validation.
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({
    super.key,
    this.reportBottleneckViewModel,
    this.reportRegistrationTimeViewModel,
    this.additionalPanels = const [],
    this.authService = const AuthService(),
    this.loginBuilder,
  });

  final ReportBottleneckViewModel? reportBottleneckViewModel;
  final ReportRegistrationTimeViewModel? reportRegistrationTimeViewModel;
  final List<Widget> additionalPanels;
  final AuthService authService;
  final WidgetBuilder? loginBuilder;

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  bool _signingOut = false;

  Future<void> _returnToLogin() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.authService.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    final authService = widget.authService;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder:
            widget.loginBuilder ??
            (context) => LoginScreen(authService: authService),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _signingOut ? null : _returnToLogin,
        ),
        title: const Text('Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReportBottleneckPanel(
                    viewModel: widget.reportBottleneckViewModel,
                  ),
                  const SizedBox(height: 20),
                  ReportRegistrationTimePanel(
                    viewModel: widget.reportRegistrationTimeViewModel,
                  ),
                  for (final panel in widget.additionalPanels)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: panel,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
