import 'dart:async';

import 'package:campusfind_flutter/core/data/found_item_repository.dart';
import 'package:campusfind_flutter/core/data/lost_report_repository.dart';
import 'package:campusfind_flutter/core/models/found_item.dart';
import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:campusfind_flutter/features/home/viewmodel/home_view_model.dart';
import 'package:campusfind_flutter/features/matching/data/matching_config_repository.dart';
import 'package:campusfind_flutter/features/matching/domain/match_result.dart';
import 'package:campusfind_flutter/features/matching/services/basic_matching_strategy.dart';
import 'package:campusfind_flutter/features/matching/services/matching_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  late FakeAuthService auth;
  late _LostReports reports;
  late _FoundItems items;
  late _MatchingConfig config;
  late HomeViewModel model;
  var disposed = false;

  setUp(() {
    auth = FakeAuthService(savedSession: true);
    reports = _LostReports();
    items = _FoundItems();
    config = _MatchingConfig();
    model = HomeViewModel(
      authService: auth,
      lostReportRepository: reports,
      foundItemRepository: items,
      matchingConfigRepository: config,
    );
    disposed = false;
  });
  tearDown(() {
    if (!disposed) model.dispose();
  });

  test('initial state has no data, loading or errors', () {
    expect(model.activeReport, isNull);
    expect(model.bestMatch, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
    expect(model.isSigningOut, isFalse);
    expect(model.signOutError, isNull);
    expect(reports.calls, 0);
  });

  test('loading notifies listeners and blocks overlapping loads', () async {
    reports.pending = Completer<LostReport?>();
    final states = <bool>[];
    model.addListener(() => states.add(model.isLoading));
    final loading = model.loadHome();
    expect(model.isLoading, isTrue);
    await model.loadHome();
    expect(reports.calls, 1);
    reports.pending!.complete(null);
    await loading;
    expect(model.isLoading, isFalse);
    expect(states, [true, false]);
  });

  test('no session issues no repository calls', () async {
    auth.savedSession = false;
    await model.loadHome();
    expect(reports.calls, 0);
    expect(items.calls, 0);
    expect(config.calls, 0);
    expect(model.activeReport, isNull);
    expect(model.bestMatch, isNull);
    expect(model.isLoading, isFalse);
  });

  test(
    'no active report finishes without candidates or configuration',
    () async {
      await model.loadHome();
      expect(reports.requestedUid, 'student-1');
      expect(model.activeReport, isNull);
      expect(model.bestMatch, isNull);
      expect(model.errorMessage, isNull);
      expect(items.calls, 0);
      expect(config.calls, 0);
    },
  );

  test('an active report without candidates remains visible', () async {
    reports.result = _report();
    await model.loadHome();
    expect(model.activeReport, same(reports.result));
    expect(model.bestMatch, isNull);
    expect(items.calls, 1);
    expect(config.calls, 1);
  });

  test(
    'matching uses the existing engine and does not mutate the models',
    () async {
      final report = _report();
      final found = _item();
      reports.result = report;
      items.result = List.unmodifiable([found]);
      await model.loadHome();
      expect(model.activeReport, same(report));
      expect(model.bestMatch?.foundItem, same(found));
      expect(model.bestMatch?.score, 1.0);
      expect(report.status, 'reported');
      expect(found.status, 'available');
      expect(items.result.single, same(found));
    },
  );

  test(
    'passes the configured threshold and preserves the exact service result',
    () async {
      final report = _report();
      final found = _item();
      final best = MatchResult(foundItem: found, score: 0.95);
      final service = _MatchingService([best]);
      double? receivedThreshold;
      reports.result = report;
      items.result = [found];
      config.threshold = 0.85;
      model.dispose();
      model = HomeViewModel(
        authService: auth,
        lostReportRepository: reports,
        foundItemRepository: items,
        matchingConfigRepository: config,
        createMatchingService: (threshold) {
          receivedThreshold = threshold;
          return service;
        },
      );
      await model.loadHome();
      expect(receivedThreshold, 0.85);
      expect(service.report, same(report));
      expect(service.items, same(items.result));
      expect(model.bestMatch, same(best));
      expect(service.calls, 1);
    },
  );

  test('report failure exposes an error and a later load clears it', () async {
    reports.error = StateError('Offline');
    await model.loadHome();
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, 'Unable to load your active report.');
    expect(model.activeReport, isNull);
    expect(model.bestMatch, isNull);
    reports.error = null;
    reports.result = _report();
    await model.loadHome();
    expect(model.errorMessage, isNull);
    expect(model.activeReport, same(reports.result));
  });

  test('candidate failure retains the real report without a match', () async {
    reports.result = _report();
    items.error = StateError('Offline');
    await model.loadHome();
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, 'Unable to check possible matches.');
    expect(model.activeReport, same(reports.result));
    expect(model.bestMatch, isNull);
  });

  test('subsequent empty loads clear a previous report and match', () async {
    reports.result = _report();
    items.result = [_item()];
    await model.loadHome();
    expect(model.bestMatch, isNotNull);
    reports.result = null;
    await model.loadHome();
    expect(model.activeReport, isNull);
    expect(model.bestMatch, isNull);
    expect(model.errorMessage, isNull);
    expect(reports.calls, 2);
    expect(items.calls, 1);
  });

  test('a changed session discards a pending report', () async {
    reports.pending = Completer<LostReport?>();
    final loading = model.loadHome();
    auth.savedSession = false;
    reports.pending!.complete(_report());
    await loading;
    expect(model.activeReport, isNull);
    expect(model.bestMatch, isNull);
    expect(items.calls, 0);
  });

  test('dispose prevents further work and late notifications', () async {
    reports.pending = Completer<LostReport?>();
    var notifications = 0;
    model.addListener(() => notifications++);
    final loading = model.loadHome();
    model.dispose();
    disposed = true;
    reports.pending!.complete(_report());
    await loading;
    await model.loadHome();
    expect(notifications, 1);
    expect(reports.calls, 1);
    expect(items.calls, 0);
  });

  test(
    'logout success clears report state and returns a navigation result',
    () async {
      reports.result = _report();
      items.result = [_item()];
      await model.loadHome();
      expect(await model.signOut(), isTrue);
      expect(auth.signOutCalls, 1);
      expect(model.isSigningOut, isFalse);
      expect(model.signOutError, isNull);
      expect(model.activeReport, isNull);
      expect(model.bestMatch, isNull);
    },
  );

  test(
    'logout failure preserves the report and exposes the existing message',
    () async {
      reports.result = _report();
      auth.failSignOut = true;
      await model.loadHome();
      expect(await model.signOut(), isFalse);
      expect(model.activeReport, same(reports.result));
      expect(model.signOutError, 'Unable to sign out. Please try again.');
      expect(model.isSigningOut, isFalse);
      auth.failSignOut = false;
      expect(await model.signOut(), isTrue);
      expect(model.signOutError, isNull);
    },
  );

  test('a pending load cannot restore report state after logout', () async {
    reports.pending = Completer<LostReport?>();
    final loading = model.loadHome();
    expect(await model.signOut(), isTrue);
    reports.pending!.complete(_report());
    await loading;
    expect(model.activeReport, isNull);
    expect(model.bestMatch, isNull);
  });

  test('duplicate logout attempts call the service once', () async {
    final pending = Completer<void>();
    final pendingAuth = FakeAuthService(
      savedSession: true,
      pendingSignOut: pending,
    );
    model.dispose();
    model = HomeViewModel(authService: pendingAuth);
    final signingOut = model.signOut();
    expect(model.isSigningOut, isTrue);
    expect(await model.signOut(), isFalse);
    expect(pendingAuth.signOutCalls, 1);
    pending.complete();
    expect(await signingOut, isTrue);
  });

  group('Home ViewModel ownership', () {
    setUpAll(loadTestFonts);
    testWidgets(
      'Home does not reload in build or dispose an injected ViewModel',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(viewModel: model)),
        );
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(400, 800);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpAndSettle();
        expect(reports.calls, 1);
        await tester.pumpWidget(const SizedBox());
        await model.loadHome();
        expect(reports.calls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Home disposes its internal ViewModel while loading', (
      tester,
    ) async {
      reports.pending = Completer<LostReport?>();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            authService: auth,
            lostReportRepository: reports,
            foundItemRepository: items,
            matchingConfigRepository: config,
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      reports.pending!.complete(_report());
      await tester.pumpAndSettle();
      expect(items.calls, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

class _LostReports extends LostReportRepository {
  LostReport? result;
  Object? error;
  Completer<LostReport?>? pending;
  int calls = 0;
  String? requestedUid;

  @override
  Future<LostReport?> getActiveReport(String ownerUid) async {
    calls++;
    requestedUid = ownerUid;
    if (error != null) throw error!;
    return pending == null ? result : await pending!.future;
  }
}

class _FoundItems extends FoundItemRepository {
  List<FoundItem> result = [];
  Object? error;
  int calls = 0;

  @override
  Future<List<FoundItem>> getAvailableItems() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

class _MatchingConfig extends MatchingConfigRepository {
  double threshold = 0.70;
  int calls = 0;

  @override
  Future<double> getMatchingThreshold() async {
    calls++;
    return threshold;
  }
}

class _MatchingService extends MatchingService {
  _MatchingService(this.results)
    : super(strategy: const BasicMatchingStrategy());

  final List<MatchResult> results;
  LostReport? report;
  List<FoundItem>? items;
  int calls = 0;

  @override
  List<MatchResult> findPossibleMatches(
    LostReport lost,
    List<FoundItem> foundItems,
  ) {
    calls++;
    report = lost;
    items = foundItems;
    return results;
  }
}

LostReport _report() => LostReport(
  id: 'report',
  ownerUid: 'student-1',
  category: 'electronics',
  title: 'Black Calculator',
  description: 'Casio',
  status: 'reported',
  locationName: 'ML',
  reportedAt: DateTime.utc(2026, 9, 30),
);

FoundItem _item() => FoundItem(
  id: 'item',
  reporterUid: 'student-2',
  category: 'electronics',
  title: 'Black Calculator',
  publicDescription: 'Casio',
  status: 'available',
  locationName: 'ML',
  semesterId: '2026-2',
  donationEligible: false,
  donationStatus: 'not_eligible',
  createdAt: DateTime.utc(2026, 9, 30),
);
