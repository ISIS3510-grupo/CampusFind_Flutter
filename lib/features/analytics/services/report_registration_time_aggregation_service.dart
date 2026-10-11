import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/report_registration_time_summary.dart';

class ReportRegistrationTimeAggregationService {
  const ReportRegistrationTimeAggregationService({this.firestore});

  final FirebaseFirestore? firestore;

  Future<ReportRegistrationTimeSummary> refresh({required DateTime now}) async {
    final database = firestore ?? FirebaseFirestore.instance;
    // Do not replace the aggregate with a potentially incomplete offline cache.
    final snapshot = await database
        .collection('performanceMetrics')
        .where('metricType', isEqualTo: 'report_registration')
        .get(const GetOptions(source: Source.server));
    var sampleCount = 0;
    var lostCount = 0;
    var foundCount = 0;
    double? averageMs;
    double? lostAverageMs;
    double? foundAverageMs;
    for (final document in snapshot.docs) {
      final data = document.data();
      final type = data['reportType'];
      final duration = data['durationMs'];
      if (data['metricType'] != 'report_registration' ||
          data['platform'] != 'flutter' ||
          (type != 'lost' && type != 'found') ||
          duration is! num ||
          !duration.isFinite ||
          duration < 0) {
        continue;
      }
      final milliseconds = duration.toDouble();
      averageMs = _nextAverage(averageMs, milliseconds, ++sampleCount);
      if (type == 'lost') {
        lostAverageMs = _nextAverage(lostAverageMs, milliseconds, ++lostCount);
      } else {
        foundAverageMs = _nextAverage(
          foundAverageMs,
          milliseconds,
          ++foundCount,
        );
      }
    }
    final summary = ReportRegistrationTimeSummary(
      sampleCount: sampleCount,
      averageMs: averageMs,
      lostCount: lostCount,
      lostAverageMs: lostAverageMs,
      foundCount: foundCount,
      foundAverageMs: foundAverageMs,
    );
    await database.collection('analytics').doc('reportRegistrationTime').set({
      ...summary.toMap(),
      'updatedAt': Timestamp.fromDate(now),
    });
    return summary;
  }

  // Running means avoid overflowing a sum of otherwise valid finite durations.
  static double _nextAverage(double? previous, double value, int count) =>
      previous == null ? value : previous + (value - previous) / count;
}
