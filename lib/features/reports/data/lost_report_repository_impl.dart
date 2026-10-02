import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';
import 'package:campusfind_flutter/features/reports/data/firestore_report_data_source.dart';

class LostReportRepositoryImpl implements LostReportRepository {
  LostReportRepositoryImpl({FirestoreReportDataSource? remote})
    : _remote = remote ?? FirestoreReportDataSource();

  final FirestoreReportDataSource _remote;

  @override
  Future<List<String>> getCategories() => _remote.fetchCategories();

  @override
  Future<List<LostReport>> getMyActiveReports() async {
    final reports = await _remote.fetchMyReports();
    return reports.where((report) => report.isActive).toList();
  }

  @override
  Future<SubmitResult> submit(LostReportDraft draft) async {
    final reportId = _remote.newReportId();
    await _remote.createReport(reportId, draft);
    return SubmitResult(reportId, SubmitStatus.submitted);
  }
}
