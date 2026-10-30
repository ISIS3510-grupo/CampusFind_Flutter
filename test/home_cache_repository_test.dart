import 'package:campusfind_flutter/features/home/data/home_cache_repository_impl.dart';
import 'package:campusfind_flutter/features/home/domain/home_cache_repository.dart';
import 'package:campusfind_flutter/features/home/domain/home_cache_snapshot.dart';
import 'package:campusfind_flutter/features/home/domain/active_report_item.dart';
import 'package:campusfind_flutter/features/matching/domain/persisted_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/home_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('persistent snapshot roundtrips reports and match flow data', () async {
    const HomeCacheRepository writer = HomeCacheRepositoryImpl();
    final now = DateTime.now();
    await writer.save(
      'student-1',
      HomeCacheSnapshot(
        cachedAt: now,
        items: [
          ActiveReportItem(
            report: report('one'),
            foundItem: foundItem('found-one'),
            possibleMatch: const PersistedMatch(
              reportId: 'one',
              foundItemId: 'found-one',
              score: .9,
            ),
          ),
        ],
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues({
      for (final key in prefs.getKeys()) key: prefs.get(key)!,
    });
    const HomeCacheRepository reader = HomeCacheRepositoryImpl();
    final snapshot = (await reader.load('student-1'))!;
    expect(snapshot.cachedAt, now);
    expect(snapshot.items.single.report.id, 'one');
    expect(snapshot.items.single.report.status, 'reported');
    expect(snapshot.items.single.report.locationName, 'ML');
    expect(snapshot.items.single.possibleMatch!.score, .9);
    expect(snapshot.items.single.foundItem!.id, 'found-one');
    expect(snapshot.isExpired(now.add(const Duration(minutes: 5))), isTrue);
    expect(snapshot.isExpired(now.add(const Duration(minutes: 4))), isFalse);
    expect(await reader.load('other-user'), isNull);
    await reader.clear('student-1');
    expect(await reader.load('student-1'), isNull);
  });
}
