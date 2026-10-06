import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  MatchAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Registra que el estudiante abrió/revisó el match. Las reglas solo dejan
  // al destinatario escribir viewedAt una vez, así que si ya existe no se toca.
  Future<void> trackMatchReviewed({
    required String notificationId,
    required bool alreadyViewed,
  }) async {
    if (alreadyViewed) return;
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'viewedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Evento match_reviewed registrado exitosamente');
    } catch (e) {
      debugPrint('Error al registrar match_reviewed: $e');
    }
  }

  // Calcula el porcentaje de revisión para la Business Question
  Future<double> getMatchReviewPercentage() async {
    final metrics = await getMatchReviewMetrics();
    return metrics.percentage;
  }

  // Enviadas = notificaciones creadas; revisadas = las que tienen viewedAt.
  // Las reglas solo permiten este conteo global a un admin.
  Future<MatchAnalyticsMetrics> getMatchReviewMetrics() async {
    final notifications = _firestore.collection('notifications');
    final sent = await notifications.count().get();
    final reviewed =
        await notifications.where('viewedAt', isNull: false).count().get();

    final totalSent = sent.count ?? 0;
    final totalReviewed = reviewed.count ?? 0;
    if (totalSent == 0) {
      return MatchAnalyticsMetrics(
        percentage: 0.0,
        totalSent: 0,
        totalReviewed: 0,
      );
    }

    return MatchAnalyticsMetrics(
      percentage: (totalReviewed / totalSent) * 100,
      totalSent: totalSent,
      totalReviewed: totalReviewed,
    );
  }
}
