import 'package:campusfind_flutter/services/match_analytics_service.dart';
import 'package:campusfind_flutter/viewmodels/match_analytics_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MatchAnalyticsScreen extends StatelessWidget {
  const MatchAnalyticsScreen({super.key});

  static const _yellow = Color(0xFFFEFD05);
  static const _border = Color(0xFFE2DEDE);

  @override
  Widget build(BuildContext context) {
    final service = MatchAnalyticsService();
    final viewModel = MatchAnalyticsViewModel();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Métricas de Negocio (BQ3)',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        backgroundColor: _yellow,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escucha las notificaciones del estudiante actual para pruebas
        stream: service.getNotificationsStream(recipientUid: currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final m = viewModel.calculate(docs);
          final pending = m.totalSent - m.totalReviewed;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Review Rate',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'What percentage of students review a possible match after receiving a notification?',
                        style: TextStyle(fontSize: 14, color: Color(0xFF999798)),
                      ),
                      const Divider(height: 32, color: _border),
                      Text(
                        '${m.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: m.percentage >= 50 ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: m.totalSent > 0 ? (m.percentage / 100).clamp(0.0, 1.0) : 0.0,
                          minHeight: 10,
                          color: Colors.black,
                          backgroundColor: _yellow.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${m.totalReviewed} de ${m.totalSent} notificaciones revisadas',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pending pendientes por revisar',
                        style: const TextStyle(color: Color(0xFF999798), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
