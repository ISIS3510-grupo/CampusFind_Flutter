import 'dart:async';

import 'package:campusfind_flutter/core/data/found_item_repository.dart';
import 'package:campusfind_flutter/core/data/lost_report_repository.dart';
import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/auth/presentation/login_screen.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:campusfind_flutter/features/home/viewmodel/home_view_model.dart';
import 'package:campusfind_flutter/features/matching/data/matching_config_repository.dart';
import 'package:campusfind_flutter/features/matching/presentation/match_alert_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firestore_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets(
    'no report hides the entire section and skips candidates and config',
    (tester) async {
      final database = FakeFirestore();
      await _pumpHome(tester, database);
      await tester.pumpAndSettle();

      expect(find.text('My active report'), findsNothing);
      expect(find.byIcon(Icons.image), findsNothing);
      expect(find.text('Scientific calculator'), findsNothing);
      expect(find.text('Possible match'), findsNothing);
      expect(find.text('Search found items'), findsOneWidget);
      expect(find.text('I found an item'), findsOneWidget);
      expect(database.queries.single['collection'], 'lostReports');
      expect(database.documentReads, isEmpty);
    },
  );

  testWidgets('no UID issues no Firestore reads', (tester) async {
    final database = FakeFirestore();
    await _pumpHome(tester, database, auth: _HomeAuth(null));
    await tester.pumpAndSettle();

    expect(find.text('My active report'), findsNothing);
    expect(database.queries, isEmpty);
    expect(database.documentReads, isEmpty);
  });

  testWidgets(
    'real title, location, age and neutral image appear without a match',
    (tester) async {
      final database = FakeFirestore(
        documents: {
          'lostReports/arbitrary-report': lostReportData(
            title: 'My missing Casio',
          ),
        },
      );
      await _pumpHome(tester, database);
      await tester.pumpAndSettle();

      expect(find.text('My active report'), findsOneWidget);
      expect(find.text('My missing Casio'), findsOneWidget);
      expect(find.text('Lost in Mario Laserna · Today'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.text('Possible match'), findsNothing);
      expect(find.text('Scientific calculator'), findsNothing);
      await tester.tap(find.text('My missing Casio'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchAlertScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the engine shows a possible match without a numeric score', (
    tester,
  ) async {
    final database = FakeFirestore(
      documents: {
        'lostReports/arbitrary-report': lostReportData(),
        'foundItems/arbitrary-item': foundItemData(),
        'appConfig/general': {'matchingThreshold': 0.70},
      },
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();

    expect(find.text('Possible match'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('0.97'), findsNothing);
    expect(
      database.documents['lostReports/arbitrary-report']!['status'],
      'reported',
    );
    expect(database.queries.map((query) => query['collection']), [
      'lostReports',
      'foundItems',
    ]);
    expect(database.documentReads, ['appConfig/general']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the badge passes the stored best match and every back action preserves the session',
    (tester) async {
      final database = FakeFirestore(
        documents: {
          'lostReports/report': lostReportData(),
          'foundItems/weaker': foundItemData(),
          'foundItems/best': {
            ...foundItemData(),
            'publicDescription': 'Black Casio scientific calculator',
          },
        },
      );
      final auth = _HomeAuth('student-1');
      await _pumpHome(tester, database, auth: auth);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Possible match'));
      await tester.pumpAndSettle();

      final firstScreen = tester.widget<MatchAlertScreen>(
        find.byType(MatchAlertScreen),
      );
      expect(firstScreen.lostReport.id, 'report');
      expect(firstScreen.matchResult.foundItem.id, 'best');
      expect(firstScreen.matchResult.score, 1.0);

      for (final action in ['Back', 'Not mine', 'system back']) {
        final screen = tester.widget<MatchAlertScreen>(
          find.byType(MatchAlertScreen),
        );
        expect(screen.lostReport, same(firstScreen.lostReport));
        expect(screen.matchResult, same(firstScreen.matchResult));

        if (action == 'Back') {
          await tester.tap(find.byTooltip('Back'));
        } else if (action == 'Not mine') {
          await tester.tap(find.text('Not mine'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.text('Possible match'), findsOneWidget);
        expect(auth.signOutCalls, 0);
        expect(auth.currentUserId, 'student-1');
        expect(database.queries, hasLength(2));
        expect(database.documentReads, ['appConfig/general']);
        expect(database.documents['lostReports/report']!['status'], 'reported');
        if (action != 'system back') {
          await tester.tap(find.text('Possible match'));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a loaded threshold of 1 excludes a near-identical candidate', (
    tester,
  ) async {
    final database = FakeFirestore(
      documents: {
        'lostReports/report': lostReportData(),
        'foundItems/item': foundItemData(),
        'appConfig/general': {'matchingThreshold': 1},
      },
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();
    expect(find.text('Black Calculator'), findsOneWidget);
    expect(find.text('Possible match'), findsNothing);
  });

  testWidgets('closed reports and reports from another user are hidden', (
    tester,
  ) async {
    final database = FakeFirestore(
      documents: {
        'lostReports/closed': lostReportData(status: 'closed'),
        'lostReports/other': lostReportData(ownerUid: 'other-user'),
      },
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();

    expect(find.text('My active report'), findsNothing);
    expect(database.queries.single['isEqualTo'], 'student-1');
    expect(database.documentReads, isEmpty);
  });

  testWidgets('selects the newest nonclosed report for the current student', (
    tester,
  ) async {
    final database = FakeFirestore(
      documents: {
        'lostReports/older': lostReportData(
          title: 'Older report',
          reportedAt: DateTime(2026, 9, 1),
        ),
        'lostReports/newer': lostReportData(
          title: 'Newest active report',
          reportedAt: DateTime(2026, 9, 20),
        ),
        'lostReports/closed': lostReportData(
          title: 'Closed report',
          status: 'closed',
          reportedAt: DateTime(2026, 9, 30),
        ),
      },
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();

    expect(find.text('Newest active report'), findsOneWidget);
    expect(find.text('Older report'), findsNothing);
    expect(find.text('Closed report'), findsNothing);
  });

  testWidgets('blank location displays the age without awkward location text', (
    tester,
  ) async {
    final database = FakeFirestore(
      documents: {'lostReports/report': lostReportData(locationName: ' ')},
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('Lost in'), findsNothing);
  });

  testWidgets('uses the report image URL and handles image load failure', (
    tester,
  ) async {
    final database = FakeFirestore(
      documents: {
        'lostReports/report': lostReportData(
          imageUrl: 'https://example.com/report.jpg',
        ),
      },
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://example.com/report.jpg');
    expect(image.errorBuilder, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading shows no placeholder report and handles disposal', (
    tester,
  ) async {
    final pending = Completer<void>();
    final database = FakeFirestore(beforeRead: pending.future);
    await _pumpHome(tester, database);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('My active report'), findsNothing);
    expect(find.text('Scientific calculator'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a report read failure shows an error and keeps Home usable', (
    tester,
  ) async {
    final database = FakeFirestore(
      errors: {
        'lostReports': FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      },
    );
    await _pumpHome(tester, database);
    await tester.pumpAndSettle();

    expect(find.text('Unable to load your active report.'), findsOneWidget);
    expect(find.text('My active report'), findsNothing);
    expect(find.text('Scientific calculator'), findsNothing);
    expect(find.text('Possible match'), findsNothing);
    await tester.tap(find.text('Search found items'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a candidate read failure keeps the real report without a match',
    (tester) async {
      final database = FakeFirestore(
        documents: {'lostReports/report': lostReportData()},
        errors: {'foundItems': StateError('Offline')},
      );
      await _pumpHome(tester, database);
      await tester.pumpAndSettle();

      expect(find.text('Black Calculator'), findsOneWidget);
      expect(find.text('Unable to check possible matches.'), findsOneWidget);
      expect(find.text('Possible match'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'config failure uses 0.70 with real data and never invents a report',
    (tester) async {
      final database = FakeFirestore(
        documents: {
          'lostReports/report': lostReportData(),
          'foundItems/item': foundItemData(),
        },
        errors: {'appConfig/general': StateError('Offline')},
      );
      await _pumpHome(tester, database);
      await tester.pumpAndSettle();

      expect(find.text('Black Calculator'), findsOneWidget);
      expect(find.text('Possible match'), findsOneWidget);
      expect(find.text('Scientific calculator'), findsNothing);
      expect(find.textContaining('Unable'), findsNothing);
    },
  );

  testWidgets(
    'a changed user cannot receive a pending report from the old user',
    (tester) async {
      final pending = Completer<void>();
      final auth = _HomeAuth('student-1');
      final database = FakeFirestore(
        beforeRead: pending.future,
        documents: {'lostReports/report': lostReportData()},
      );
      await _pumpHome(tester, database, auth: auth);
      auth.userId = 'student-2';
      pending.complete();
      await tester.pumpAndSettle();

      expect(find.text('My active report'), findsNothing);
      expect(find.text('Black Calculator'), findsNothing);
      expect(database.queries, hasLength(1));
    },
  );

  testWidgets(
    'long report content fits a small viewport with a possible match',
    (tester) async {
      final database = FakeFirestore(
        documents: {
          'lostReports/report': lostReportData(
            title:
                'Black scientific calculator with a protective carrying case',
            locationName: 'Mario Laserna building, third floor, study room',
          ),
          'foundItems/item': foundItemData(),
        },
      );
      await _pumpHome(tester, database);
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Possible match'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  FakeFirestore database, {
  _HomeAuth? auth,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final viewModel = HomeViewModel(
    authService: auth ?? _HomeAuth('student-1'),
    lostReportRepository: LostReportRepository(firestore: database),
    foundItemRepository: FoundItemRepository(firestore: database),
    matchingConfigRepository: MatchingConfigRepository(firestore: database),
  );
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: HomeScreen(viewModel: viewModel),
    ),
  );
}

class _HomeAuth extends AuthService {
  _HomeAuth(this.userId);

  String? userId;
  int signOutCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  bool get hasCurrentUser => userId != null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    userId = null;
  }
}
