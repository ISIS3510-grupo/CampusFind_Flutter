import 'package:cloud_firestore/cloud_firestore.dart';

class MatchAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //Registra que el estudiante abrió/revisó el detalle de un match
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

  //Calcula el porcentaje de revisión para la Business Question
  Future<double> getMatchReviewPercentage() async {
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

        if (matchId != null) {
          if (eventType == 'notification_sent') {
            sentMatchIds.add(matchId);
          } else if (eventType == 'match_reviewed') {
            reviewedMatchIds.add(matchId);
          }
        }
      }

      if (sentMatchIds.isEmpty) return 0.0;

      final reviewedCount = reviewedMatchIds.intersection(sentMatchIds).length;
      return (reviewedCount / sentMatchIds.length) * 100;
    } catch (e) {
      print('Error al calcular el porcentaje: $e');
      return 0.0;
    }
  }
}