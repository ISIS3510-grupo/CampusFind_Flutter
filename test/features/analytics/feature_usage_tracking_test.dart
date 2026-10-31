import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../reports/fake_lost_report_repository.dart';
import 'fake_feature_usage_tracker.dart';

void main() {
  test('feature ids are unique and stable', () {
    final ids = AppFeature.values.map((feature) => feature.id).toList();

    expect(ids.toSet(), hasLength(ids.length));
    expect(AppFeature.reportLostItem.id, 'report_lost_item');
    expect(AppFeature.submitLostReport.id, 'submit_lost_report');
  });

  testWidgets('Home records which action the student uses', (tester) async {
    final tracker = FakeFeatureUsageTracker();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          authService: FakeAuthService(),
          featureUsageTracker: tracker,
          foundItemScreenBuilder: (_) => const Text('Found item form'),
        ),
      ),
    );

    await tester.tap(find.text('Search found items'));
    await tester.tap(find.text('I found an item'));
    await tester.pumpAndSettle();

    expect(find.text('Found item form'), findsOneWidget);

    expect(tracker.tracked, [
      AppFeature.searchFoundItems,
      AppFeature.reportFoundItem,
    ]);
    // Opening a screen has a response time; the search card has nothing to wait for.
    expect(tracker.responseTimes[AppFeature.reportFoundItem], isNotNull);
    expect(tracker.responseTimes[AppFeature.searchFoundItems], isNull);
  });

  testWidgets('a submitted lost report is recorded once', (tester) async {
    final tracker = FakeFeatureUsageTracker();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportLostItemScreen(
          repository: FakeLostReportRepository(),
          featureUsageTracker: tracker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keys').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'Keys');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Red keychain',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Where did you lose it?'),
      'SD',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Detail'),
      '3 keys',
    );
    await tester.scrollUntilVisible(
      find.text('Send report'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    expect(tracker.tracked, [AppFeature.submitLostReport]);
    expect(tracker.responseTimes[AppFeature.submitLostReport], isNotNull);
  });

  testWidgets('a biometric login is recorded', (tester) async {
    final tracker = FakeFeatureUsageTracker();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authService: FakeAuthService(savedSession: true),
          biometricService: FakeBiometricService(),
          homeBuilder: (_) => const Text('Home'),
          featureUsageTracker: tracker,
        ),
      ),
    );

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tracker.tracked, [AppFeature.biometricLogin]);
    expect(tracker.responseTimes[AppFeature.biometricLogin], isNotNull);
  });

  testWidgets('a student password login is recorded', (tester) async {
    final tracker = FakeFeatureUsageTracker();
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authService: FakeAuthService(),
          biometricService: FakeBiometricService(),
          homeBuilder: (_) => const Text('Home'),
          featureUsageTracker: tracker,
        ),
      ),
    );

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'student@uniandes.edu.co');
    await tester.enterText(fields.at(1), 'Password123!');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tracker.tracked, [AppFeature.passwordLogin]);
    expect(tracker.responseTimes[AppFeature.passwordLogin], isNotNull);
  });
}
