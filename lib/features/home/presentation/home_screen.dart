import 'package:flutter/material.dart';

import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/home/presentation/widgets/home_action_card.dart';
import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.authService = const AuthService()});

  final AuthService authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);

    try {
      await widget.authService.signOut();
      if (!mounted) return;

      // Removes Home so the back button cannot reopen the signed-out session.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (context) => LoginScreen(authService: widget.authService),
        ),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yellow header from the Figma design
              Container(
                height: 92,
                color: const Color(0xFFFEFD05),
                padding: const EdgeInsets.only(left: 22, right: 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'uniandes',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Lost & Found',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Find or return an item',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _signingOut ? null : _signOut,
                      tooltip: 'Sign out',
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 28,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'What do you need?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    HomeActionCard(
                      icon: Icons.search,
                      title: 'Search found items',
                      subtitle: 'Check if something similar has already been registered.',
                      large: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    HomeActionCard(
                      icon: Icons.report_outlined,
                      title: 'I lost an item',
                      subtitle: 'Report it and get notified if it is found.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const ReportLostItemScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    HomeActionCard(
                      icon: Icons.add,
                      title: 'I found an item',
                      subtitle: 'Report it and see where to deliver it.',
                      highlighted: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'My active report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 13),
                    // Temporary UI data; the report team will connect this later.
                    Container(
                      height: 116,
                      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2DEDE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 92,
                            height: 96,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2DEDE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.image,
                              size: 26,
                              color: Color(0xFF999798),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                const Text(
                                  'Scientific calculator',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                const Text(
                                  'Lost in ML · 2 days ago',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF999798),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 120,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEFD05),
                                    border: Border.all(
                                      color: const Color(0xFFE2DEDE),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Possible match',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2DEDE))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 61,
            child: BottomNavigationBar(
              currentIndex: 0,
              onTap: (_) {},
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: Colors.black,
              unselectedItemColor: const Color(0xFF999798),
              selectedFontSize: 10,
              unselectedFontSize: 10,
              iconSize: 22,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
