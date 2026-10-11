import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/report_registration_time_summary.dart';

class ReportRegistrationTimeRepository {
  const ReportRegistrationTimeRepository({this.firestore});

  final FirebaseFirestore? firestore;

  Future<ReportRegistrationTimeSummary> getSummary() async {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('analytics')
        .doc('reportRegistrationTime')
        .get();
    final data = snapshot.data();
    if (data == null) throw ReportRegistrationTimeNotGeneratedException();
    return ReportRegistrationTimeSummary.fromMap(data);
  }
}

class ReportRegistrationTimeNotGeneratedException extends StateError {
  ReportRegistrationTimeNotGeneratedException()
    : super('Analytics document analytics/reportRegistrationTime is missing.');
}
