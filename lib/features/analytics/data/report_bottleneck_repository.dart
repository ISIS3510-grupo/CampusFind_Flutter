import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/report_bottleneck_summary.dart';

class ReportBottleneckRepository {
  const ReportBottleneckRepository({this.firestore});

  final FirebaseFirestore? firestore;

  Future<ReportBottleneckSummary> getSummary() async {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('analytics')
        .doc('reportBottleneck')
        .get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError(
        'Analytics document analytics/reportBottleneck is missing.',
      );
    }

    final counts = <String, int>{};
    for (final stage in ReportBottleneckSummary.stages) {
      final value = data[stage];
      counts[stage] = value is int && value >= 0 ? value : 0;
    }
    return ReportBottleneckSummary.fromCounts(counts);
  }
}
