import 'package:campusfind_flutter/core/utils/report_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats today, yesterday and older dates', () {
    final now = DateTime(2026, 9, 30, 12);
    expect(reportAge(DateTime(2026, 9, 30), now: now), 'Today');
    expect(reportAge(DateTime(2026, 9, 29, 23), now: now), '1 day ago');
    expect(reportAge(DateTime(2026, 9, 28), now: now), '2 days ago');
    expect(reportAge(DateTime(2026, 9, 1), now: now), '29 days ago');
  });

  test('handles future timestamps without showing a negative age', () {
    expect(
      reportAge(DateTime(2026, 10, 1), now: DateTime(2026, 9, 30)),
      'Today',
    );
  });

  test('converts UTC timestamps to the local calendar date', () {
    final reported = DateTime(2026, 9, 29, 23);
    final now = DateTime(2026, 9, 30, 1);
    expect(reportAge(reported.toUtc(), now: now), '1 day ago');
  });
}
