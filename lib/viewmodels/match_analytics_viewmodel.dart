import 'package:cloud_firestore/cloud_firestore.dart';

class MatchAnalyticsMetrics {
  final double percentage;
  final int totalSent;
  final int totalReviewed;

  MatchAnalyticsMetrics({
    required this.percentage,
    required this.totalSent,
    required this.totalReviewed,
  });
}

class MatchAnalyticsViewModel {
  MatchAnalyticsMetrics calculate(List<QueryDocumentSnapshot> docs) {
    int reviewed = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['viewedAt'] != null) {
        reviewed++;
      }
    }

    double percentage = 0;
    if (docs.isNotEmpty) {
      percentage = reviewed / docs.length * 100;
    }

    return MatchAnalyticsMetrics(
      percentage: percentage,
      totalSent: docs.length,
      totalReviewed: reviewed,
    );
  }
}
