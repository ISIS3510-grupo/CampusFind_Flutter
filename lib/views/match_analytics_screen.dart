import 'package:campusfind_flutter/services/match_analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:campusfind_flutter/viewmodels/match_analytics_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class MatchAnalyticsScreen extends StatelessWidget {
  const MatchAnalyticsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final service = MatchAnalyticsService();
    final viewModel = MatchAnalyticsViewModel();

    return Scaffold(
      appBar: AppBar(title: const Text('Métricas de Negocio (BQ)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final m = viewModel.calculate(snapshot.data!.docs);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'What percentage of students review a possible match after receiving a notification?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                Text(
                  '${m.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.bold,
                    color: m.percentage >= 50 ? Colors.green : Colors.orange,
                  ),
                ),
                Text('${m.totalReviewed} de ${m.totalSent} notificaciones revisadas'),
              ],
            ),
          );
        },
      ),
    );
  }
}