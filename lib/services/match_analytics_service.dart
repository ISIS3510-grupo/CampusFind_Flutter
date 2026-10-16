import 'package:cloud_firestore/cloud_firestore.dart';

class MatchAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Marca la notificación como revisada (solo si aún no lo estaba)
  void trackMatchReviewed(String notificationId, bool alreadyViewed) {
    if (alreadyViewed) return;

    _firestore.collection('notifications').doc(notificationId).update({
      'viewedAt': FieldValue.serverTimestamp(),
    });
  }

  // Devuelve las notificaciones en tiempo real
  Stream<QuerySnapshot> getNotificationsStream() {
    return _firestore.collection('notifications').snapshots();
  }
}
