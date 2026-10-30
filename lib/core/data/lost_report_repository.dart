import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_report.dart';

class LostReportRepository {
  const LostReportRepository({this.firestore});

  final FirebaseFirestore? firestore;

  Future<List<LostReport>> getActiveReports(
    String ownerUid, {
    int limit = 5,
  }) async {
    if (ownerUid.trim().isEmpty || limit <= 0) return [];
    // All non-closed statuses in the shared report lifecycle. An equality-list
    // filter permits reportedAt ordering, unlike a status inequality ordering.
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('lostReports')
        .where('ownerUid', isEqualTo: ownerUid)
        .where(
          'status',
          whereIn: ['reported', 'found', 'ready_for_pickup', 'claimed'],
        )
        .orderBy('reportedAt', descending: true)
        .limit(limit.clamp(1, 5))
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => LostReport.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Future<LostReport?> getActiveReport(String ownerUid) async {
    if (ownerUid.trim().isEmpty) return null;

    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('lostReports')
        .where('ownerUid', isEqualTo: ownerUid)
        .get();
    final reports = snapshot.docs
        .where((doc) => doc.data()['status'] != 'closed')
        .map((doc) => LostReport.fromFirestore(doc.id, doc.data()))
        .toList();
    reports.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    return reports.isEmpty ? null : reports.first;
  }
}
