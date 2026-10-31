import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:campusfind_flutter/features/home/viewmodel/home_view_model.dart';
import 'package:campusfind_flutter/features/matching/presentation/match_alert_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/analytics/fake_feature_usage_tracker.dart';
import 'support/home_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  late HomeReports reports;
  late HomeFoundItems found;
  late HomeAuth auth;
  late HomeViewModel model;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reports = HomeReports()..data = [report('Calculator')];
    found = HomeFoundItems();
    auth = HomeAuth();
    model = HomeViewModel(
      authService: auth,
      lostReportRepository: reports,
      foundItemRepository: found,
      persistedMatchRepository: HomeMatches(),
    );
  });
  tearDown(() => model.dispose());
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          viewModel: model,
          featureUsageTracker: FakeFeatureUsageTracker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('showing my report is recorded once with its load time', (
    tester,
  ) async {
    final tracker = FakeFeatureUsageTracker();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(viewModel: model, featureUsageTracker: tracker),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(tracker.tracked, [AppFeature.viewMyReport]);
    expect(tracker.responseTimes[AppFeature.viewMyReport], isNotNull);
  });

  testWidgets('pull refresh replaces report without logout', (tester) async {
    await pumpHome(tester);
    expect(find.text('Calculator'), findsOneWidget);
    reports.data = [report('Updated')];
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget);
    expect(auth.signOutCalls, 0);
  });
  testWidgets('persisted match opens and returning refreshes Home', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.ensureVisible(find.text('Possible match'));
    await tester.tap(find.text('Possible match'));
    await tester.pumpAndSettle();
    final screen = tester.widget<MatchAlertScreen>(
      find.byType(MatchAlertScreen),
    );
    expect(screen.matchResult.score, .9);
    expect(screen.matchResult.foundItem.id, 'found-Calculator');
    final previousCalls = reports.calls;
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(reports.calls, greaterThan(previousCalls));
  });
  for (final missing in [true, false]) {
    testWidgets('match failure shows friendly snackbar missing=$missing', (
      tester,
    ) async {
      await pumpHome(tester);
      if (missing) {
        found.missing.add('found-Calculator');
      } else {
        found.errors['found-Calculator'] = StateError('private details');
      }
      await tester.ensureVisible(find.text('Possible match'));
      await tester.tap(find.text('Possible match'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          missing
              ? 'This possible match is no longer available.'
              : 'Unable to open this match. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private details'), findsNothing);
      expect(find.byType(MatchAlertScreen), findsNothing);
    });
  }
  testWidgets('offline banner has readable punctuation', (tester) async {
    await model.loadHome();
    reports.error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await pumpHome(tester);
    expect(
      find.text('Offline: showing previously loaded information'),
      findsOneWidget,
    );
    expect(find.text('Calculator'), findsOneWidget);
  });
  testWidgets('empty Home can still refresh', (tester) async {
    reports.data = [];
    await pumpHome(tester);
    reports.data = [report('New report')];
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('New report'), findsOneWidget);
  });
}
