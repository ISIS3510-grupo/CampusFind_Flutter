import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/lost_report.dart';
import '../domain/report_bottleneck_summary.dart';
import 'report_bottleneck_service.dart';

class ReportBottleneckAggregationService {
  const ReportBottleneckAggregationService({
    this.firestore,
    this.bottleneckService = const ReportBottleneckService(),
  });

  final FirebaseFirestore? firestore;
  final ReportBottleneckService bottleneckService;

  Future<ReportBottleneckSummary> refresh({required DateTime now}) async {
    final database = firestore ?? FirebaseFirestore.instance;
    final snapshot = await database.collection('lostReports').get();
    final reports = snapshot.docs
        .map((doc) => LostReport.fromFirestore(doc.id, doc.data()))
        .toList();
    final summary = bottleneckService.calculate(reports, now);

    // Replace the document so only anonymous aggregate fields are retained.
    await database.collection('analytics').doc('reportBottleneck').set({
      'reported': summary.counts['reported'],
      'found': summary.counts['found'],
      'ready_for_pickup': summary.counts['ready_for_pickup'],
      'claimed': summary.counts['claimed'],
      'updatedAt': Timestamp.fromDate(now),
    });
    return summary;
  }
}
