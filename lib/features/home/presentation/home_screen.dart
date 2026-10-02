import 'package:flutter/material.dart';
import '../../../views/report_item_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../views/notification_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.authService = const AuthService()});

  final AuthService authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signingOut = false;
  int _currentIndex = 0;
  String _statusMessage = 'Pantalla principal cargada';

  // Cierre de sesión directo y controlado con banderas de estado simples
  void _signOut() {
    if (_signingOut) return;
    setState(() => _signingOut = true);

    // Llamada sincrónica/directa sin esperar bloques complejos de red si no se requiere
    widget.authService.signOut();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (context) => LoginScreen(authService: widget.authService),
      ),
      (route) => false,
    );
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Si el usuario presiona la pestaña de "Alerts" (índice 2)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        ),
      );
      return;
    }

    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  void _actualizarEstado() {
    setState(() {
      _statusMessage = 'Estado actualizado localmente';
    });
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
              // Encabezado institucional amarillo de Figma
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
                    
                    // Tarjeta de búsqueda
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFE2DEDE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        onTap: () {
                          // Acción de búsqueda
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          height: 122,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(
                                    Icons.search,
                                    size: 31,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 23),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Search found items',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Check if something similar has already been registered.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w300,
                                          color: Color(0xFF999798),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tarjeta "I found an item"
                    Material(
                      color: const Color(0xFFFEFD05),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReportItemScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          height: 104,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 20, 20, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Icon(
                                    Icons.add,
                                    size: 28,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'I found an item',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Report it and see where to deliver it.',
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botón tradicional para refrescar estado en la interfaz
                    OutlinedButton.icon(
                      onPressed: _actualizarEstado,
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      label: const Text(
                        'Actualizar estado en pantalla',
                        style: TextStyle(color: Colors.black),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2DEDE)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999798),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),
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
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
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