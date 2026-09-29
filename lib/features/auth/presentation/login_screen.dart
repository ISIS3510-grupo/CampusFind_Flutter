import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                        onPressed: () {},
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
