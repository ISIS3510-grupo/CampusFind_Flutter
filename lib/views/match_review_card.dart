import 'package:campusfind_flutter/services/match_analytics_service.dart';
import 'package:campusfind_flutter/viewmodels/match_analytics_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MatchReviewCard extends StatelessWidget {
  const MatchReviewCard({super.key});

  static const _yellow = Color(0xFFFEFD05);
  static const _border = Color(0xFFE2DEDE);
  static const _grey = Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    final service = MatchAnalyticsService();
    final viewModel = MatchAnalyticsViewModel();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: service.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('No se pudo cargar la métrica.');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final m = viewModel.calculate(snapshot.data!.docs);
          final pending = m.totalSent - m.totalReviewed;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Match review rate',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'What percentage of students review a possible match '
                'after receiving a notification?',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const Divider(height: 32, color: _border),
              Text(
                '${m.percentage.toStringAsFixed(1)} %',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: m.percentage / 100,
                  minHeight: 8,
                  color: Colors.black,
                  backgroundColor: _yellow.withValues(alpha: 0.35),
                ),
              ),

              const SizedBox(height: 2),
              Text(
                '${m.totalReviewed} of ${m.totalSent} notifications reviewed',
              ),
              Text(
                '$pending pending',
                style: const TextStyle(color: _grey, fontSize: 13),
              ),
            ],
          );
        },
      ),
    );
  }
}
