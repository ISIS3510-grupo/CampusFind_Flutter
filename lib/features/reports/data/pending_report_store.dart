import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';

// A report saved on the device while there was no connection. It keeps the id
// generated on the device, so sending it again never creates a duplicate.
class PendingReport {
  const PendingReport(this.reportId, this.draft);

  final String reportId;
  final LostReportDraft draft;

  Map<String, dynamic> toJson() => {
    'reportId': reportId,
    'draft': draft.toJson(),
  };

  factory PendingReport.fromJson(Map<String, dynamic> json) => PendingReport(
    json['reportId'] as String,
    LostReportDraft.fromJson(json['draft'] as Map<String, dynamic>),
  );
}

abstract class PendingReportStore {
  Future<List<PendingReport>> load();

  Future<void> add(PendingReport report);

  Future<void> remove(String reportId);
}

// Keeps the queue in SharedPreferences and the photo in the app folder, because
// the camera's cache folder can be cleaned before the report is sent.
class LocalPendingReportStore implements PendingReportStore {
  static const _key = 'pending_lost_reports';

  @override
  Future<List<PendingReport>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? const [];
    return saved
        .map((item) => PendingReport.fromJson(jsonDecode(item)))
        .toList();
  }

  @override
  Future<void> add(PendingReport report) async {
    final draft = report.draft;
    final photo = draft.imagePath;
    final kept = PendingReport(
      report.reportId,
      LostReportDraft(
        title: draft.title,
        category: draft.category,
        description: draft.description,
        locationName: draft.locationName,
        privateVerificationDetail: draft.privateVerificationDetail,
        imagePath: photo == null
            ? null
            : await _keepPhoto(report.reportId, photo),
      ),
    );

    final reports = await load()
      ..removeWhere((item) => item.reportId == report.reportId)
      ..add(kept);
    await _save(reports);
  }

  @override
  Future<void> remove(String reportId) async {
    final reports = await load();
    for (final report in reports.where((item) => item.reportId == reportId)) {
      final photo = report.draft.imagePath;
      if (photo != null) {
        final file = File(photo);
        if (await file.exists()) await file.delete();
      }
    }
    reports.removeWhere((item) => item.reportId == reportId);
    await _save(reports);
  }

  Future<void> _save(List<PendingReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      reports.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<String?> _keepPhoto(String reportId, String path) async {
    final source = File(path);
    if (!await source.exists()) return null;
    final folder = Directory(
      '${(await getApplicationSupportDirectory()).path}/pending_photos',
    );
    await folder.create(recursive: true);
    return (await source.copy('${folder.path}/$reportId.jpg')).path;
  }
}
