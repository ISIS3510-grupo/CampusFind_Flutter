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

class MatchAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registra que el estudiante abrió/revisó el detalle de un match
  Future<void> trackMatchReviewed({
    required String matchId,
    required String studentUid,
  }) async {
    try {
      await _firestore.collection('analytics').add({
        'feature': 'match_review_bq',
        'matchId': matchId,
        'recipientUid': studentUid,
        'eventType': 'match_reviewed',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Evento match_reviewed registrado exitosamente');
    } catch (e) {
      print('Error al registrar match_reviewed: $e');
    }
  }

  // Calcula el porcentaje de revisión para la Business Question
  Future<double> getMatchReviewPercentage() async {
    final metrics = await getMatchReviewMetrics();
    return metrics.percentage;
  }

  // Obtiene el desglose completo para la interfaz de usuario
  Future<MatchAnalyticsMetrics> getMatchReviewMetrics() async {
    try {
      final snapshot = await _firestore
          .collection('analytics')
          .where('feature', isEqualTo: 'match_review_bq')
          .get();

      final Set<String> sentMatchIds = {};
      final Set<String> reviewedMatchIds = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final matchId = data['matchId'] as String?;
        final eventType = data['eventType'] as String?;

        if (matchId != null && matchId.isNotEmpty) {
          if (eventType == 'notification_sent') {
            sentMatchIds.add(matchId);
          } else if (eventType == 'match_reviewed') {
            reviewedMatchIds.add(matchId);
          }
        }
      }

      if (sentMatchIds.isEmpty) {
        return MatchAnalyticsMetrics(percentage: 0.0,totalSent: 0,totalReviewed: 0,);
      }

      final reviewedCount = reviewedMatchIds.intersection(sentMatchIds).length;
      final percentage = (reviewedCount / sentMatchIds.length) * 100;

      return MatchAnalyticsMetrics(
        percentage: percentage,
        totalSent: sentMatchIds.length,
        totalReviewed: reviewedCount,
      );
    } catch (e) {
      print('Error al calcular el porcentaje: $e');
      return MatchAnalyticsMetrics(
        percentage: 0.0,
        totalSent: 0,
        totalReviewed: 0,
      );
    }
  }
}