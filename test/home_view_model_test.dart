import 'dart:async';

import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/features/home/data/home_cache_repository_impl.dart';
import 'package:campusfind_flutter/features/home/domain/home_cache_snapshot.dart';
import 'package:campusfind_flutter/features/home/domain/active_report_item.dart';
import 'package:campusfind_flutter/features/home/viewmodel/home_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/home_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HomeReports reports;
  late HomeMatches matches;
  late HomeFoundItems found;
  late HomeAuth auth;
  late HomeViewModel model;
  const cache = HomeCacheRepositoryImpl();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reports = HomeReports();
    matches = HomeMatches();
    found = HomeFoundItems();
    auth = HomeAuth();
    model = HomeViewModel(
      authService: auth,
      lostReportRepository: reports,
      persistedMatchRepository: matches,
      foundItemRepository: found,
    );
  });
  tearDown(() => model.dispose());
  test(
    'empty cache loads persisted remote matches and saves snapshot',
    () async {
      await model.loadHome();
      expect(model.activeReports, hasLength(2));
      expect(model.activeReports.first.possibleMatch!.score, .9);
      expect((await cache.load('student-1'))!.items, hasLength(2));
      expect(model.isShowingCachedData, isFalse);
    },
  );
  test('cache displayed before pending remote response replaces it', () async {
    await cache.save(
      'student-1',
      HomeCacheSnapshot(
        items: [ActiveReportItem(report: report('cached'))],
        cachedAt: DateTime.now(),
      ),
    );
    reports.pending = Completer<List<LostReport>>();
    final displayed = Completer<void>();
    model.addListener(() {
      if (model.isShowingCachedData && !displayed.isCompleted) {
        displayed.complete();
      }
    });
    final load = model.loadHome();
    await displayed.future;
    expect(model.activeReports.single.report.id, 'cached');
    reports.pending!.complete([report('fresh')]);
    await load;
    expect(model.activeReports.single.report.id, 'fresh');
    expect(model.isShowingCachedData, isFalse);
  });
  for (final expired in [false, true]) {
    test('offline retains ${expired ? 'expired' : 'fresh'} cache', () async {
      await cache.save(
        'student-1',
        HomeCacheSnapshot(
          items: [ActiveReportItem(report: report('cached'))],
          cachedAt: DateTime.now().subtract(Duration(minutes: expired ? 6 : 0)),
        ),
      );
      reports.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await model.loadHome();
      expect(model.activeReports.single.report.id, 'cached');
      expect(model.isOffline, isTrue);
      expect(model.errorMessage, isNull);
      expect(model.isCacheExpired, expired);
    });
  }
  test('offline without cache preserves error', () async {
    reports.error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await model.loadHome();
    expect(model.errorMessage, isNotNull);
    expect(model.isOffline, isFalse);
  });
  test(
    'refresh replaces reports and clears offline state without logout',
    () async {
      await model.loadHome();
      reports.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await model.refresh();
      expect(model.isOffline, isTrue);
      reports.error = null;
      reports.data = [report('updated')];
      await model.refresh();
      expect(model.activeReports.single.report.id, 'updated');
      expect(model.isOffline, isFalse);
      expect(auth.signOutCalls, 0);
      expect(
        (await cache.load('student-1'))!.items.single.report.id,
        'updated',
      );
    },
  );
  for (final cached in [false, true]) {
    for (final foundFailure in [false, true]) {
      for (final error in [
        const FormatException('bad record'),
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
        ),
      ]) {
        test('isolates $error found=$foundFailure cached=$cached', () async {
          if (cached) await model.loadHome();
          (foundFailure ? found.errors : matches.errors)[foundFailure
                  ? 'found-one'
                  : 'one'] =
              error;
          await model.refresh();
          expect(model.errorMessage, isNull);
          expect(model.activeReports, hasLength(2));
          expect(model.activeReports[0].possibleMatch != null, cached);
          expect(model.activeReports[1].possibleMatch, isNotNull);
        });
      }
    }
  }
  for (final code in ['unavailable', 'permission-denied', 'unauthenticated']) {
    test('$code retains global error handling', () async {
      await model.loadHome();
      matches.errors['one'] = FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
      );
      await model.refresh();
      expect(model.isOffline, code == 'unavailable');
      expect(model.errorMessage != null, code != 'unavailable');
    });
  }
  test('sign out and account changes do not expose prior reports', () async {
    await model.loadHome();
    auth.uid = null;
    await model.loadHome();
    expect(model.activeReports, isEmpty);
    expect(await model.signOut(), isTrue);
  });
}
