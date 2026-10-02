import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_lost_report_repository.dart';

void main() {
  Future<void> openScreen(
    WidgetTester tester,
    FakeLostReportRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ReportLostItemScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(WidgetTester tester, {bool withDetail = true}) async {
    // Picks the category first, while the dropdown is still on screen.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electronics').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item'),
      'Calculator',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Black Casio',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Where did you lose it?'),
      'ML building',
    );
    if (withDetail) {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Detail'),
        'Name on the back',
      );
    }
  }

  Future<void> tapSend(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Send report'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation errors and does not submit an empty form', (
    tester,
  ) async {
    final repository = FakeLostReportRepository();
    await openScreen(tester, repository);

    await tapSend(tester);

    expect(find.text('This field is required.'), findsWidgets);
    expect(repository.submitted, isEmpty);
  });

  testWidgets('submits the report through the repository', (tester) async {
    final repository = FakeLostReportRepository();
    await openScreen(tester, repository);

    await fillForm(tester);
    await tapSend(tester);

    expect(repository.submitted, hasLength(1));
    final draft = repository.submitted.single;
    expect(draft.title, 'Calculator');
    expect(draft.category, 'electronics');
    expect(draft.privateVerificationDetail, 'Name on the back');
  });

  testWidgets('private detail is optional and stays null when empty', (
    tester,
  ) async {
    final repository = FakeLostReportRepository();
    await openScreen(tester, repository);

    await fillForm(tester, withDetail: false);
    await tapSend(tester);

    expect(repository.submitted, hasLength(1));
    expect(repository.submitted.single.privateVerificationDetail, isNull);
  });

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    final repository = FakeLostReportRepository(failSubmit: true);
    await openScreen(tester, repository);

    await fillForm(tester);
    await tapSend(tester);

    expect(
      find.text('Unable to send the report. Please try again.'),
      findsOneWidget,
    );
  });
}
