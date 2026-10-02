import 'dart:async';

import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report_repository.dart';
import 'package:campusfind_flutter/features/reports/data/firestore_report_data_source.dart';
import 'package:campusfind_flutter/features/reports/data/pending_report_store.dart';
import 'package:campusfind_flutter/features/reports/data/report_photo_storage.dart';

class LostReportRepositoryImpl implements LostReportRepository {
  LostReportRepositoryImpl({
    FirestoreReportDataSource? remote,
    ReportPhotoStorage? photos,
    PendingReportStore? pending,
    ConnectivityService? connectivity,
    this.sendTimeout = const Duration(seconds: 10),
  }) : _remote = remote ?? FirestoreReportDataSource(),
       _photos = photos ?? ReportPhotoStorage(),
       _pending = pending ?? LocalPendingReportStore(),
       _connectivity = connectivity ?? DeviceConnectivityService();

  final FirestoreReportDataSource _remote;
  final ReportPhotoStorage _photos;
  final PendingReportStore _pending;
  final ConnectivityService _connectivity;

  // A weak connection can report "online" but never answer; after this time
  // the report goes to the offline queue instead of leaving the student waiting.
  final Duration sendTimeout;

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

    if (!await _connectivity.isOnline()) {
      await _pending.add(PendingReport(reportId, draft));
      return SubmitResult(reportId, SubmitStatus.queuedOffline);
    }

    try {
      await _createIfMissing(reportId, draft);
    } on TimeoutException {
      await _pending.add(PendingReport(reportId, draft));
      return SubmitResult(reportId, SubmitStatus.queuedOffline);
    }

    final photoSaved = await _uploadPhoto(reportId, draft);
    if (!photoSaved) {
      // The report is saved; the queue retries only the photo later.
      await _pending.add(PendingReport(reportId, draft));
    }
    return SubmitResult(
      reportId,
      SubmitStatus.submitted,
      photoFailed: !photoSaved,
    );
  }

  @override
  Future<int> syncPending() async {
    if (!await _connectivity.isOnline()) return 0;

    var sent = 0;
    for (final report in await _pending.load()) {
      try {
        await _createIfMissing(report.reportId, report.draft);
        if (!await _uploadPhoto(report.reportId, report.draft)) break;
        await _pending.remove(report.reportId);
        sent++;
      } catch (_) {
        // Still offline or signed out: the rest waits for the next try.
        break;
      }
    }
    return sent;
  }

  // Same id on every try: if a previous try reached Firestore, it is not
  // created again (the rules would reject it as an update anyway).
  Future<void> _createIfMissing(String reportId, LostReportDraft draft) async {
    if (await _remote.reportExists(reportId).timeout(sendTimeout)) return;
    await _remote.createReport(reportId, draft).timeout(sendTimeout);
  }

  // Order required by the Storage rules: report first, then photo, then path.
  Future<bool> _uploadPhoto(String reportId, LostReportDraft draft) async {
    final imagePath = draft.imagePath;
    if (imagePath == null) return true;
    try {
      final photoPath = await _photos.upload(reportId, imagePath);
      await _remote.attachPhoto(reportId, photoPath);
      return true;
    } catch (_) {
      return false;
    }
  }
}
