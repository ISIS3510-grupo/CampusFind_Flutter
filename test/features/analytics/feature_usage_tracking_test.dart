import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
