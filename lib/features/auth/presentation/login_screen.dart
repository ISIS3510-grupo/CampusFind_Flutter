import 'package:flutter/material.dart';

import '../../analytics/presentation/analytics_dashboard_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../data/auth_service.dart';
import '../data/biometric_service.dart';
import '../viewmodel/auth_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authService = const AuthService(),
    this.biometricService,
    this.homeBuilder,
    this.staffDashboardBuilder,
    this.viewModel,
  });

  final AuthService authService;
  final BiometricService? biometricService;
  final WidgetBuilder? homeBuilder;
  final WidgetBuilder? staffDashboardBuilder;
  // Injected ViewModels remain owned by the caller.
  final AuthViewModel? viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _showingSignInDialog = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel =
        widget.viewModel ??
        AuthViewModel(
          authService: widget.authService,
          biometricService: widget.biometricService,
        );
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  Future<void> _handleStudentAccess() async {
    if (_viewModel.isBusy || _showingSignInDialog) return;
    await _viewModel.requestStudentAccess();
    if (!mounted) return;
    if (_viewModel.needsPasswordSignIn) {
      await _showSignInDialog();
    } else if (_viewModel.isAuthenticated) {
      _openHome();
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_viewModel.errorMessage!)));
    }
  }

  Future<void> _handleStaffAccess() async {
    if (_viewModel.isBusy || _showingSignInDialog) return;
    _viewModel.clearError();
    await _showSignInDialog(isStaff: true);
  }

  Future<void> _showSignInDialog({bool isStaff = false}) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _showingSignInDialog = true);
    try {
      final signedIn = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _SignInDialog(viewModel: _viewModel, isStaff: isStaff),
      );
      if (signedIn == true && mounted) {
        if (isStaff) {
          _openStaffDashboard();
        } else {
          _openHome();
        }
      }
    } finally {
      if (mounted) setState(() => _showingSignInDialog = false);
    }
  }

  void _openHome() {
    final authService = _viewModel.authService;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            widget.homeBuilder ??
            (context) => HomeScreen(authService: authService),
      ),
    );
  }

  void _openStaffDashboard() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder:
            widget.staffDashboardBuilder ??
            (context) => const AnalyticsDashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) => _buildLogin(context),
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yellow header with the app information
              Container(
                height: 250,
                color: const Color(0xFFFEFD05),
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'uniandes',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 31,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Lost & Found',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 39,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 9),
                    SizedBox(
                      width: 330,
                      child: Text(
                        'Recover and return campus belongings with more certainty and traceability.',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 38, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Institutional access card
                    Container(
                      height: 142,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2DEDE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lock, size: 26, color: Colors.black),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Institutional access',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Sign in with your Uniandes account to report, search and verify items.',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Student login button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _viewModel.isBusy || _showingSignInDialog
                            ? null
                            : _handleStudentAccess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        child: const Text('Enter with Uniandes'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Staff uses the same email/password dialog with admin validation.
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _viewModel.isBusy || _showingSignInDialog
                            ? null
                            : _handleStaffAccess,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: const BorderSide(width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        child: const Text('Staff access'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: SizedBox(
                        width: 318,
                        child: Text(
                          'Access is limited to the university community.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF999798),
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInDialog extends StatefulWidget {
  const _SignInDialog({required this.viewModel, required this.isStaff});

  final AuthViewModel viewModel;
  final bool isStaff;

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (widget.viewModel.isBusy) return;

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(
        () => _validationMessage = 'Please enter your email and password.',
      );
      return;
    }

    setState(() => _validationMessage = null);

    final signIn = widget.isStaff
        ? widget.viewModel.signInAdmin
        : widget.viewModel.signInStudent;
    final signedIn = await signIn(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (signedIn) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, child) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final isSigningIn = widget.viewModel.isBusy;
    final errorMessage = _validationMessage ?? widget.viewModel.errorMessage;
    return PopScope(
      canPop: !isSigningIn,
      child: AlertDialog(
        title: Text(widget.isStaff ? 'Staff sign in' : 'Student sign in'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                enabled: !isSigningIn,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !isSigningIn,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSigningIn ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: isSigningIn ? null : _signIn,
            child: isSigningIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Signing in',
                    ),
                  )
                : const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}
