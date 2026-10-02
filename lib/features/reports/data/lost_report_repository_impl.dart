import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';
import 'package:campusfind_flutter/features/reports/data/firestore_report_data_source.dart';
import 'package:campusfind_flutter/features/reports/data/report_photo_storage.dart';

class LostReportRepositoryImpl implements LostReportRepository {
  LostReportRepositoryImpl({
    FirestoreReportDataSource? remote,
    ReportPhotoStorage? photos,
  }) : _remote = remote ?? FirestoreReportDataSource(),
       _photos = photos ?? ReportPhotoStorage();

  final FirestoreReportDataSource _remote;
  final ReportPhotoStorage _photos;

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

    // Order required by the Storage rules: report first, then photo, then path.
    final imagePath = draft.imagePath;
    if (imagePath == null) {
      return SubmitResult(reportId, SubmitStatus.submitted);
    }
    try {
      final photoPath = await _photos.upload(reportId, imagePath);
      await _remote.attachPhoto(reportId, photoPath);
      return SubmitResult(reportId, SubmitStatus.submitted);
    } catch (_) {
      // The report is already saved; only the photo is missing.
      return SubmitResult(reportId, SubmitStatus.submitted, photoFailed: true);
    }
  }
}
