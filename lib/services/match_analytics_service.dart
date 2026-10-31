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

  // Devuelve las notificaciones en tiempo real (todas para admin, o filtradas por recipientUid para estudiante)
  Stream<QuerySnapshot> getNotificationsStream({String? recipientUid}) {
    if (recipientUid != null && recipientUid.isNotEmpty) {
      return _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: recipientUid)
          .snapshots();
    }
    return _firestore.collection('notifications').snapshots();
  }
}
