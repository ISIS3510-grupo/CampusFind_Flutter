import 'package:campusfind_flutter/features/reports/data/firestore_report_data_source.dart';
import 'package:campusfind_flutter/features/reports/data/lost_report_repository_impl.dart';
import 'package:campusfind_flutter/features/reports/data/report_photo_storage.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:flutter_test/flutter_test.dart';

// Records the calls in order to check the sequence the Storage rules need.
class _FakeDataSource implements FirestoreReportDataSource {
  _FakeDataSource(this.calls);

  final List<String> calls;

  @override
  String get currentUid => 'camilo';

  @override
  String newReportId() => 'report1';

  @override
  Future<List<String>> fetchCategories() async => ['keys'];

  @override
  Future<List<LostReport>> fetchMyReports() async => [];

  @override
  Future<void> createReport(
    String reportId,
    LostReportDraft draft, {
    String? photoPath,
  }) async {
    calls.add('create $reportId');
  }

  @override
  Future<void> attachPhoto(String reportId, String photoPath) async {
    calls.add('attach $photoPath');
  }
}

class _FakePhotoStorage implements ReportPhotoStorage {
  _FakePhotoStorage(this.calls, {this.fail = false});

  final List<String> calls;
  final bool fail;

  @override
  Future<String> upload(String reportId, String localPath) async {
    if (fail) throw Exception('storage');
    calls.add('upload $localPath');
    return ReportPhotoStorage.pathFor(reportId);
  }
}

LostReportDraft _draft({String? imagePath}) => LostReportDraft(
  title: 'Keys',
  category: 'keys',
  description: 'Two keys',
  locationName: 'ML',
  imagePath: imagePath,
);

void main() {
  test(
    'creates the report, uploads the photo and then saves its path',
    () async {
      final calls = <String>[];
      final repository = LostReportRepositoryImpl(
        remote: _FakeDataSource(calls),
        photos: _FakePhotoStorage(calls),
      );

      final result = await repository.submit(
        _draft(imagePath: '/photos/keys.jpg'),
      );

      expect(calls, [
        'create report1',
        'upload /photos/keys.jpg',
        'attach lostReports/report1.jpg',
      ]);
      expect(result.photoFailed, isFalse);
    },
  );

  test('without a photo nothing is uploaded', () async {
    final calls = <String>[];
    final repository = LostReportRepositoryImpl(
      remote: _FakeDataSource(calls),
      photos: _FakePhotoStorage(calls),
    );

    await repository.submit(_draft());

    expect(calls, ['create report1']);
  });

  test('a failed upload keeps the report and reports the photo', () async {
    final calls = <String>[];
    final repository = LostReportRepositoryImpl(
      remote: _FakeDataSource(calls),
      photos: _FakePhotoStorage(calls, fail: true),
    );

    final result = await repository.submit(
      _draft(imagePath: '/photos/keys.jpg'),
    );

    expect(calls, ['create report1']);
    expect(result.reportId, 'report1');
    expect(result.photoFailed, isTrue);
  });
}
