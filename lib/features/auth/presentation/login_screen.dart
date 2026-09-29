import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../data/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _showSignInDialog(BuildContext context) async {
    final signedIn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _StudentSignInDialog(),
    );

    if (signedIn == true && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        onPressed: () => _showSignInDialog(context),
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
                    // Visual placeholder for staff access
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {},
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

class _StudentSignInDialog extends StatefulWidget {
  const _StudentSignInDialog();

  @override
  State<_StudentSignInDialog> createState() => _StudentSignInDialogState();
}

class _StudentSignInDialogState extends State<_StudentSignInDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningIn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return;

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    final error = await AuthService().signInStudent(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSigningIn = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSigningIn,
      child: AlertDialog(
        title: const Text('Student sign in'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                enabled: !_isSigningIn,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isSigningIn,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSigningIn ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _isSigningIn ? null : _signIn,
            child: _isSigningIn
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
