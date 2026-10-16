import 'package:campusfind_flutter/features/reports/presentation/report_lost_item_screen.dart';

import 'dart:async';

import 'package:campusfind_flutter/features/reports/domain/photo_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_lost_report_repository.dart';
import 'fake_photo_labeler.dart';
import 'fake_photo_picker.dart';

void main() {
  Future<void> openScreen(
    WidgetTester tester,
    FakeLostReportRepository repository, {
    FakePhotoPicker? photoPicker,
    FakePhotoLabeler? photoLabeler,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportLostItemScreen(
          repository: repository,
          photoPicker: photoPicker ?? FakePhotoPicker(),
          photoLabeler: photoLabeler ?? FakePhotoLabeler(),
        ),
      ),
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

  Future<void> tapTakePhoto(WidgetTester tester) async {
    final button = find.text(
      'Take a photo of a similar item, its box or receipt',
    );
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('photo suggestion from Google Cloud Vision', () {
    const backpack = PhotoSuggestion(
      category: 'electronics',
      description: 'Black laptop',
      keywords: ['laptop'],
    );

    Future<void> scrollTo(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );

    testWidgets('fills the empty category and description', (tester) async {
      final repository = FakeLostReportRepository();
      final labeler = FakePhotoLabeler(
        suggestion: const PhotoSuggestion(
          category: 'keys',
          description: 'Silver keychain',
        ),
      );
      await openScreen(tester, repository, photoLabeler: labeler);

      await tapTakePhoto(tester);
      expect(labeler.requested, ['/photos/calculator.jpg']);
      expect(find.text('Suggested by Google Cloud Vision'), findsOneWidget);
      expect(find.text('Keys · Silver keychain'), findsOneWidget);

      await tester.ensureVisible(find.text('Use suggestion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use suggestion'));
      await tester.pumpAndSettle();
      expect(find.text('Suggested by Google Cloud Vision'), findsNothing);

      // The student only writes what the photo cannot tell.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'Item'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item'),
        'Keys',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Where did you lose it?'),
        'ML building',
      );
      await tapSend(tester);

      final draft = repository.submitted.single;
      expect(draft.category, 'keys');
      expect(draft.description, 'Silver keychain');
    });

    testWidgets('does not overwrite a description the student wrote', (
      tester,
    ) async {
      final repository = FakeLostReportRepository();
      await openScreen(
        tester,
        repository,
        photoLabeler: FakePhotoLabeler(suggestion: backpack),
      );
      await fillForm(tester);

      await tapTakePhoto(tester);
      await tester.ensureVisible(find.text('Use suggestion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use suggestion'));
      await tester.pumpAndSettle();
      await tapSend(tester);

      expect(repository.submitted.single.description, isNot('Black laptop'));
    });

    testWidgets('without an answer the form stays as it was', (tester) async {
      final repository = FakeLostReportRepository();
      await openScreen(tester, repository, photoLabeler: FakePhotoLabeler());

      await tapTakePhoto(tester);

      expect(find.text('Suggested by Google Cloud Vision'), findsNothing);
      expect(find.text('Analyzing the photo...'), findsNothing);
      expect(find.text('Photo added'), findsOneWidget);
    });

    testWidgets('removing the photo discards a late answer', (tester) async {
      final pending = Completer<PhotoSuggestion?>();
      final repository = FakeLostReportRepository();
      await openScreen(
        tester,
        repository,
        photoLabeler: FakePhotoLabeler(pending: pending),
      );

      final button = find.text(
        'Take a photo of a similar item, its box or receipt',
      );
      await scrollTo(tester, button);
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Analyzing the photo...'), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await tester.pump();
      pending.complete(backpack);
      await tester.pumpAndSettle();

      expect(find.text('Analyzing the photo...'), findsNothing);
      expect(find.text('Suggested by Google Cloud Vision'), findsNothing);
    });
  });

  testWidgets('sends a photo chosen from the gallery', (tester) async {
    final repository = FakeLostReportRepository();
    final picker = FakePhotoPicker();
    final labeler = FakePhotoLabeler();
    await openScreen(
      tester,
      repository,
      photoPicker: picker,
      photoLabeler: labeler,
    );

    await fillForm(tester);
    final button = find.text('Choose from gallery');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(picker.calls, 0);
    expect(labeler.requested, ['/gallery/calculator.jpg']);
    expect(find.text('Photo added'), findsOneWidget);

    await tapSend(tester);
    expect(repository.submitted.single.imagePath, '/gallery/calculator.jpg');
  });

  testWidgets('sends the photo taken with the camera', (tester) async {
    final repository = FakeLostReportRepository();
    final picker = FakePhotoPicker();
    await openScreen(tester, repository, photoPicker: picker);

    await fillForm(tester);
    await tapTakePhoto(tester);
    expect(picker.calls, 1);
    expect(find.text('Photo added'), findsOneWidget);

    await tapSend(tester);

    expect(repository.submitted.single.imagePath, '/photos/calculator.jpg');
  });

  testWidgets('a removed or cancelled photo is not sent', (tester) async {
    final repository = FakeLostReportRepository();
    await openScreen(tester, repository);

    await fillForm(tester);
    await tapTakePhoto(tester);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(
      find.text('Take a photo of a similar item, its box or receipt'),
      findsOneWidget,
    );

    await tapSend(tester);
    expect(repository.submitted.single.imagePath, isNull);
  });

  testWidgets('cancelling the camera keeps the form without a photo', (
    tester,
  ) async {
    final repository = FakeLostReportRepository();
    await openScreen(
      tester,
      repository,
      photoPicker: FakePhotoPicker(path: null),
    );

    await tapTakePhoto(tester);

    expect(find.text('Photo added'), findsNothing);
    expect(
      find.text('Take a photo of a similar item, its box or receipt'),
      findsOneWidget,
    );
  });

  testWidgets('tells the student when only the photo failed', (tester) async {
    final repository = FakeLostReportRepository(photoFailed: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportLostItemScreen(
                    repository: repository,
                    photoPicker: FakePhotoPicker(),
                    photoLabeler: FakePhotoLabeler(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await fillForm(tester);
    await tapTakePhoto(tester);
    await tapSend(tester);

    expect(
      find.text(
        'Report sent. The photo will be uploaded when the connection improves.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tells the student the report waits for the connection', (
    tester,
  ) async {
    final repository = FakeLostReportRepository(offline: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportLostItemScreen(repository: repository),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await fillForm(tester);
    await tapSend(tester);

    expect(
      find.text(
        'No connection. Your report is saved and will be sent automatically.',
      ),
      findsOneWidget,
    );
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
