import 'package:campusfind_flutter/features/analytics/data/feature_usage_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_summary.dart';
import 'package:campusfind_flutter/features/analytics/presentation/feature_usage_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Same shape the aggregateFeatureUsage Cloud Function writes.
final _aggregate = <String, dynamic>{
  'eventCount': 14,
  'mostUsedFeature': 'search_found_items',
  'ranking': [
    {'feature': 'search_found_items', 'count': 8},
    {'feature': 'report_lost_item', 'count': 2},
    {'feature': 'submit_lost_report', 'count': 2},
    {'feature': 'report_found_item', 'count': 2},
    {'feature': 'password_login', 'count': 0},
    {'feature': 'unknown_feature', 'count': 5},
  ],
  'last7Days': {'search_found_items': 8, 'report_lost_item': 2},
  'byPlatform': {
    'flutter': {'search_found_items': 8, 'report_lost_item': 2},
    'kotlin': {'search_found_items': 0},
  },
};

class _FakeRepository implements FeatureUsageRepository {
  _FakeRepository(this.result, {this.fail = false});

  final FeatureUsageSummary? result;
  final bool fail;
  int calls = 0;

  @override
  Future<FeatureUsageSummary?> getSummary() async {
    calls++;
    if (fail) throw Exception('network');
    return result;
  }
}

Future<void> _pump(WidgetTester tester, FeatureUsageRepository repository) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FeatureUsagePanel(repository: repository),
        ),
      ),
    ),
  );
}

void main() {
  test('reads the Cloud Function aggregate', () {
    final summary = FeatureUsageSummary.fromMap(_aggregate);

    expect(summary.eventCount, 14);
    expect(summary.mostUsed!.feature, AppFeature.searchFoundItems);
    // Unknown ids from a newer app version are ignored, not shown.
    expect(summary.ranking.map((item) => item.feature), isNot(contains(null)));
    expect(summary.ranking, hasLength(5));
    expect(summary.byPlatform, {'flutter': 10, 'kotlin': 0});
    expect(summary.shareOf(summary.ranking.first), closeTo(8 / 14, 0.001));
  });

  test('no events means no most used feature', () {
    final summary = FeatureUsageSummary.fromMap({
      'eventCount': 0,
      'ranking': [
        {'feature': 'search_found_items', 'count': 0},
      ],
    });

    expect(summary.mostUsed, isNull);
    expect(summary.shareOf(summary.ranking.first), 0);
  });

  testWidgets('shows the ranking of the most used features', (tester) async {
    await _pump(
      tester,
      _FakeRepository(FeatureUsageSummary.fromMap(_aggregate)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Most used features'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('feature-usage-most-used')))
          .data,
      'Search found items',
    );
    expect(find.text('14 events'), findsOneWidget);
    expect(find.text('57 %'), findsOneWidget);
    expect(find.text('8 in the last 7 days'), findsOneWidget);
    expect(find.text('By platform: flutter 10 · kotlin 0'), findsOneWidget);
  });

  testWidgets('explains when there is no aggregate yet', (tester) async {
    await _pump(tester, _FakeRepository(null));
    await tester.pumpAndSettle();

    expect(find.text('No usage has been aggregated yet.'), findsOneWidget);
  });

  testWidgets('shows an error and reloads on demand', (tester) async {
    final repository = _FakeRepository(null, fail: true);
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load feature usage. Please try again.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reload'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
  });
}
