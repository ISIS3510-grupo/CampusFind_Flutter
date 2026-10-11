import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:campusfind_flutter/features/analytics/domain/feature_usage_summary.dart';

abstract class FeatureUsageRepository {
  // Null while the Cloud Function has not produced the first aggregate.
  Future<FeatureUsageSummary?> getSummary();
}

class FirestoreFeatureUsageRepository implements FeatureUsageRepository {
  FirestoreFeatureUsageRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<FeatureUsageSummary?> getSummary() async {
    // From the server: the dashboard must not show an old cached ranking.
    final snapshot = await _firestore
        .doc('analytics/featureUsage')
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) return null;
    return FeatureUsageSummary.fromMap(
      data,
      computedAt: (data['computedAt'] as Timestamp?)?.toDate(),
    );
  }
}
