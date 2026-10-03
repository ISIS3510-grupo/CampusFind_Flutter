import 'package:campusfind_flutter/core/models/found_item.dart';
import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/matching/domain/match_result.dart';
import 'package:campusfind_flutter/features/matching/presentation/match_alert_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('displays found-item data and explanatory text without a score', (
    tester,
  ) async {
    await _pumpAlert(tester);

    expect(find.text('Black Calculator'), findsOneWidget);
    expect(find.text('Found in Mario Laserna · Today'), findsOneWidget);
    expect(find.text('Possible match'), findsNWidgets(2));
    expect(find.text('We found an item that may be yours'), findsOneWidget);
    expect(
      find.text(
        'Review the public details. Ownership is confirmed later with staff.',
      ),
      findsOneWidget,
    );
    expect(find.text('Review this match'), findsOneWidget);
    expect(find.text('Not mine'), findsOneWidget);
    expect(find.text('My lost calculator'), findsNothing);
    expect(find.text('Scientific calculator'), findsNothing);
    expect(find.textContaining(RegExp(r'0\.95|95%|confidence')), findsNothing);
    expect(find.text('9:41'), findsNothing);
    expect(find.byType(SafeArea), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final days in [0, 1, 2, 5]) {
    testWidgets('shows the found-item age for $days days', (tester) async {
      final today = DateTime.now();
      final date = DateTime(today.year, today.month, today.day - days, 12);
      await _pumpAlert(tester, foundItem: _foundItem(createdAt: date));
      final age = days == 0
          ? 'Today'
          : days == 1
          ? '1 day ago'
          : '$days days ago';
      expect(find.text('Found in Mario Laserna · $age'), findsOneWidget);
    });
  }

  for (final imageUrl in <String?>[null, '', '   ']) {
    testWidgets('missing image "$imageUrl" uses the neutral placeholder', (
      tester,
    ) async {
      await _pumpAlert(tester, foundItem: _foundItem(imageUrl: imageUrl));
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a malformed image URL displays the fallback without crashing', (
    tester,
  ) async {
    await _pumpAlert(tester, foundItem: _foundItem(imageUrl: 'http://['));
    expect(find.byIcon(Icons.image), findsOneWidget);
    expect(find.text('Black Calculator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the dynamic network image URL with an error handler', (
    tester,
  ) async {
    await _pumpAlert(
      tester,
      foundItem: _foundItem(imageUrl: 'https://example.com/found.jpg'),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://example.com/found.jpg');
    expect(image.errorBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty location uses a clean found-date label', (tester) async {
    await _pumpAlert(tester, foundItem: _foundItem(locationName: ' '));
    expect(find.text('Found · Today'), findsOneWidget);
    expect(find.textContaining('Found in'), findsNothing);
  });

  for (final action in ['Back', 'Not mine', 'system back']) {
    testWidgets('$action returns to the previous route', (tester) async {
      await _pumpAlert(tester);

      if (action == 'system back') {
        await tester.binding.handlePopRoute();
      } else if (action == 'Back') {
        await tester.tap(find.byTooltip('Back'));
      } else {
        await tester.tap(find.text('Not mine'));
      }
      await tester.pumpAndSettle();

      expect(find.byType(MatchAlertScreen), findsNothing);
      expect(find.text('Previous screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Review this match opens the claim form', (tester) async {
    await _pumpAlert(
      tester,
      claimFormBuilder: (context) => const Scaffold(body: Text('Claim form')),
    );
    await tester.tap(find.text('Review this match'));
    await tester.pumpAndSettle();

    expect(find.text('Claim form'), findsOneWidget);
    expect(find.byType(MatchAlertScreen), findsNothing);
  });

  testWidgets(
    'Alerts remains selected and missing tab destinations stay inactive',
    (tester) async {
      await _pumpAlert(tester);
      for (final label in ['Home', 'Search', 'Alerts', 'Profile']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(MatchAlertScreen), findsOneWidget);
        expect(
          tester
              .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
              .currentIndex,
          2,
        );
      }
    },
  );

  testWidgets('long content scrolls on a small screen without overflowing', (
    tester,
  ) async {
    await _pumpAlert(
      tester,
      size: const Size(360, 640),
      foundItem: _foundItem(
        title: 'Black scientific calculator with a protective carrying case',
        locationName: 'Mario Laserna building, third floor, study room',
      ),
    );
    await tester.ensureVisible(find.text('Not mine'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Not mine'));
    await tester.pumpAndSettle();
    expect(find.text('Previous screen'), findsOneWidget);
  });
}

Future<void> _pumpAlert(
  WidgetTester tester, {
  FoundItem? foundItem,
  Size size = const Size(390, 844),
  WidgetBuilder? claimFormBuilder,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 42);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  final lost = LostReport(
    id: 'lost-report',
    ownerUid: 'student-1',
    category: 'electronics',
    title: 'My lost calculator',
    description: 'Black calculator',
    status: 'reported',
    locationName: 'Different location',
    reportedAt: DateTime.now().subtract(const Duration(days: 30)),
  );
  final match = MatchResult(foundItem: foundItem ?? _foundItem(), score: 0.95);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('Previous screen'),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => MatchAlertScreen(
                      lostReport: lost,
                      matchResult: match,
                      claimFormBuilder: claimFormBuilder,
                    ),
                  ),
                ),
                child: const Text('Open S08'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open S08'));
  await tester.pumpAndSettle();
}

FoundItem _foundItem({
  String title = 'Black Calculator',
  String locationName = 'Mario Laserna',
  DateTime? createdAt,
  String? imageUrl,
}) => FoundItem(
  id: 'found-item',
  reporterUid: 'student-2',
  category: 'electronics',
  title: title,
  publicDescription: 'Black Casio scientific calculator found',
  status: 'available',
  locationName: locationName,
  imageUrl: imageUrl,
  semesterId: '2026-2',
  donationEligible: false,
  donationStatus: 'not_eligible',
  createdAt: createdAt ?? DateTime.now(),
);
