import 'package:cloud_firestore/cloud_firestore.dart';

class MatchingConfigRepository {
  const MatchingConfigRepository({this.firestore});

  final FirebaseFirestore? firestore;

  Future<double> getMatchingThreshold() async {
    try {
      final document = await (firestore ?? FirebaseFirestore.instance)
          .collection('appConfig')
          .doc('general')
          .get();
      final value = document.data()?['matchingThreshold'];
      if (value is num && value.isFinite && value >= 0 && value <= 1) {
        return value.toDouble();
      }
    } catch (_) {
      // Matching can continue with the default when configuration is unavailable.
    }
    return 0.70;
  }
}
