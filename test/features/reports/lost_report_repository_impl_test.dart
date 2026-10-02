import 'dart:async';

import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/reports/data/firestore_report_data_source.dart';
import 'package:campusfind_flutter/features/reports/data/lost_report_repository_impl.dart';
import 'package:campusfind_flutter/features/reports/data/pending_report_store.dart';
import 'package:campusfind_flutter/features/reports/data/report_photo_storage.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:flutter_test/flutter_test.dart';

// Records the calls in order to check the sequence the Storage rules need.
class _FakeDataSource implements FirestoreReportDataSource {
  _FakeDataSource(this.calls);

  final List<String> calls;
  final Set<String> created = {};

  // Simulates a connection that says "online" but never answers.
  bool hang = false;

  @override
  String get currentUid => 'camilo';

  @override
  String newReportId() => 'report${created.length + calls.length + 1}';

  @override
  Future<List<String>> fetchCategories() async => ['keys'];

  @override
  Future<List<LostReport>> fetchMyReports() async => [];

  @override
  Future<bool> reportExists(String reportId) async {
    if (hang) return Completer<bool>().future;
    return created.contains(reportId);
  }

  @override
  Future<void> createReport(
    String reportId,
    LostReportDraft draft, {
    String? photoPath,
  }) async {
    created.add(reportId);
    calls.add('create $reportId');
  }

  @override
  Future<void> attachPhoto(String reportId, String photoPath) async {
    calls.add('attach $photoPath');
  }
}

class _FakePhotoStorage implements ReportPhotoStorage {
  _FakePhotoStorage(this.calls);

  final List<String> calls;
  bool fail = false;

  @override
  Future<String> upload(String reportId, String localPath) async {
    if (fail) throw Exception('storage');
    calls.add('upload $localPath');
    return ReportPhotoStorage.pathFor(reportId);
  }
}

class _MemoryPendingStore implements PendingReportStore {
  final List<PendingReport> reports = [];

  @override
  Future<List<PendingReport>> load() async => List.of(reports);

  @override
  Future<void> add(PendingReport report) async {
    reports
      ..removeWhere((item) => item.reportId == report.reportId)
      ..add(report);
  }

  @override
  Future<void> remove(String reportId) async =>
      reports.removeWhere((item) => item.reportId == reportId);
}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity();

  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

LostReportDraft _draft({String? imagePath}) => LostReportDraft(
  title: 'Keys',
  category: 'keys',
  description: 'Two keys',
  locationName: 'ML',
  imagePath: imagePath,
);

void main() {
  late List<String> calls;
  late _FakeDataSource remote;
  late _FakePhotoStorage photos;
  late _MemoryPendingStore pending;
  late _FakeConnectivity connectivity;
  late LostReportRepositoryImpl repository;

  setUp(() {
    calls = [];
    remote = _FakeDataSource(calls);
    photos = _FakePhotoStorage(calls);
    pending = _MemoryPendingStore();
    connectivity = _FakeConnectivity();
    repository = LostReportRepositoryImpl(
      remote: remote,
      photos: photos,
      pending: pending,
      connectivity: connectivity,
      sendTimeout: const Duration(milliseconds: 50),
    );
  });

  test(
    'creates the report, uploads the photo and then saves its path',
    () async {
      final result = await repository.submit(
        _draft(imagePath: '/photos/keys.jpg'),
      );

      expect(calls, [
        'create report1',
        'upload /photos/keys.jpg',
        'attach lostReports/report1.jpg',
      ]);
      expect(result.status, SubmitStatus.submitted);
      expect(result.photoFailed, isFalse);
      expect(pending.reports, isEmpty);
    },
  );

  test('without a photo nothing is uploaded', () async {
    await repository.submit(_draft());

    expect(calls, ['create report1']);
  });

  test('offline: the report is queued and nothing is sent', () async {
    connectivity.online = false;

    final result = await repository.submit(_draft());

    expect(result.status, SubmitStatus.queuedOffline);
    expect(calls, isEmpty);
    expect(pending.reports.single.reportId, result.reportId);
  });

  test('a connection that never answers also queues the report', () async {
    remote.hang = true;

    final result = await repository.submit(_draft());

    expect(result.status, SubmitStatus.queuedOffline);
    expect(pending.reports, hasLength(1));
  });

  test('sync sends the queue with the same id when back online', () async {
    connectivity.online = false;
    final queued = await repository.submit(
      _draft(imagePath: '/photos/keys.jpg'),
    );

    connectivity.online = true;
    final sent = await repository.syncPending();

    expect(sent, 1);
    expect(calls, [
      'create ${queued.reportId}',
      'upload /photos/keys.jpg',
      'attach lostReports/${queued.reportId}.jpg',
    ]);
    expect(pending.reports, isEmpty);
  });

  test('sync does nothing while offline', () async {
    connectivity.online = false;
    await repository.submit(_draft());

    expect(await repository.syncPending(), 0);
    expect(pending.reports, hasLength(1));
  });

  test(
    'a failed photo keeps the report and the sync retries only the photo',
    () async {
      photos.fail = true;
      final result = await repository.submit(
        _draft(imagePath: '/photos/keys.jpg'),
      );

      expect(result.status, SubmitStatus.submitted);
      expect(result.photoFailed, isTrue);
      expect(pending.reports, hasLength(1));

      photos.fail = false;
      await repository.syncPending();

      // The report is not created twice; only the photo is sent.
      expect(calls, [
        'create report1',
        'upload /photos/keys.jpg',
        'attach lostReports/report1.jpg',
      ]);
      expect(pending.reports, isEmpty);
    },
  );
}
