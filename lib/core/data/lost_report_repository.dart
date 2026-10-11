import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_report.dart';

class LostReportRepository {
  const LostReportRepository({this.firestore});

  final FirebaseFirestore? firestore;

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
