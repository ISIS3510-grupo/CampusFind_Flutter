import 'dart:async';

import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/drop_off/domain/office_location.dart';
import 'package:campusfind_flutter/features/drop_off/presentation/drop_off_instructions_screen.dart';
import 'package:campusfind_flutter/features/drop_off/viewmodel/drop_off_instructions_view_model.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_fakes.dart';
import 'support/drop_off_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  late FakeOfficeLocationRepository repository;
  late DropOffInstructionsViewModel model;
  late FakeMapsLauncherService mapsLauncher;
  setUp(() {
    repository = FakeOfficeLocationRepository();
    model = DropOffInstructionsViewModel(repository: repository);
    mapsLauncher = FakeMapsLauncherService();
  });
  tearDown(() => model.dispose());

  Future<void> pumpScreen(
    WidgetTester tester, {
    WidgetBuilder? homeBuilder,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DropOffInstructionsScreen(
          viewModel: model,
          mapsLauncher: mapsLauncher,
          homeBuilder: homeBuilder,
        ),
      ),
    );
  }

  testWidgets('shows initial loading without inventing an office', (
    tester,
  ) async {
    repository.pending = Completer<OfficeLocation?>();
    await pumpScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Mario Laserna'), findsNothing);
    expect(find.text('Drop-off instructions'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    repository.pending!.complete(repository.office);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders loaded office information in the yellow card', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text(repository.office!.name), findsOneWidget);
    expect(find.text('Lost & Found Office'), findsOneWidget);
    expect(find.text('Mario Laserna'), findsOneWidget);
    expect(
      tester
          .widget<DropOffInstructionsScreen>(
            find.byType(DropOffInstructionsScreen),
          )
          .officeId,
      'ml',
    );
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders fixed internal directions and opening hours', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Monday to Friday, 8:30 a.m. - 5:30 p.m.'),
      findsOneWidget,
    );
    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.text('Inside the building'), findsOneWidget);
    expect(
      find.text('Office 500, in front of the Davivienda ATM'),
      findsOneWidget,
    );
  });

  testWidgets('missing coordinates disable Maps without hiding instructions', (
    tester,
  ) async {
    repository.office = const OfficeLocation(
      id: 'office-test',
      name: 'Campus office',
    );
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.text('Campus office'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failure keeps instructions and navigation usable and supports retry',
    (tester) async {
      repository.error = StateError('Private backend failure');
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load office information. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Mario Laserna'), findsNothing);
      expect(find.text('Before you leave'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      repository.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Mario Laserna'), findsOneWidget);
      expect(
        find.text('Unable to load office information. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'missing office shows unavailable state instead of fallback information',
    (tester) async {
      repository.office = null;
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Office information is not available yet.'),
        findsOneWidget,
      );
      expect(find.text('Mario Laserna'), findsNothing);
    },
  );

  testWidgets(
    'instructions distinguish digital registration from physical delivery',
    (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Found item report registered successfully.'),
        findsOneWidget,
      );
      expect(
        find.text('Bring the found item to the Lost & Found office.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Tell staff that the item was already reported in CampusFind.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Staff will register the physical drop-off.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Reporting online does not complete the handoff. Staff must receive the physical item.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Item delivered'), findsNothing);
      expect(find.textContaining('Handoff complete'), findsNothing);
    },
  );

  testWidgets(
    'Open in Maps passes loaded coordinates to the injected launcher',
    (tester) async {
      repository.office = const OfficeLocation(
        id: 'other',
        name: 'Other office',
        latitude: 10.5,
        longitude: -20.25,
      );
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open in Maps'));
      await tester.tap(find.text('Open in Maps'));
      await tester.pumpAndSettle();
      expect(mapsLauncher.destinations, [(latitude: 10.5, longitude: -20.25)]);
    },
  );

  testWidgets('Open in Maps is enabled with valid coordinates', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Open in Maps is disabled when loading the office fails', (
    tester,
  ) async {
    repository.error = StateError('Offline');
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('Back to Home uses the existing Home screen and removes S12', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      homeBuilder: (context) => HomeScreen(authService: FakeAuthService()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Back to Home'));
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.byType(DropOffInstructionsScreen, skipOffstage: false),
      findsNothing,
    );
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  for (final coordinates in [
    (latitude: null, longitude: -74.0),
    (latitude: 4.0, longitude: null),
    (latitude: double.nan, longitude: -74.0),
    (latitude: 91.0, longitude: -74.0),
    (latitude: 4.0, longitude: 181.0),
  ]) {
    testWidgets('Maps is disabled for invalid coordinates $coordinates', (
      tester,
    ) async {
      repository.office = OfficeLocation(
        id: 'office-test',
        name: 'Mario Laserna',
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(mapsLauncher.destinations, isEmpty);
    });
  }

  for (final throwsError in [false, true]) {
    testWidgets(
      'Maps failure shows an error and allows retry (throws: $throwsError)',
      (tester) async {
        mapsLauncher.result = false;
        if (throwsError) mapsLauncher.error = StateError('Launch failed');
        await pumpScreen(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open in Maps'));
        await tester.pumpAndSettle();
        expect(find.text('Unable to open Google Maps.'), findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNotNull,
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
        mapsLauncher.error = null;
        mapsLauncher.result = true;
        await tester.tap(find.text('Open in Maps'));
        await tester.pumpAndSettle();
        expect(mapsLauncher.destinations, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending launch prevents duplicate taps and tolerates leaving S12',
    (tester) async {
      mapsLauncher.pending = Completer<bool>();
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in Maps'));
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(mapsLauncher.destinations, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      mapsLauncher.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back arrow returns to the previous flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => DropOffInstructionsScreen(
                    officeId: 'office-test',
                    viewModel: model,
                  ),
                ),
              ),
              child: const Text('Previous flow'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Previous flow'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Previous flow'), findsOneWidget);
    expect(find.byType(DropOffInstructionsScreen), findsNothing);
  });

  testWidgets(
    'narrow screen with long office text and large font scrolls without overflow',
    (tester) async {
      repository.office = const OfficeLocation(
        id: 'office-test',
        name: 'University Lost and Found Student Services Office',
      );
      await pumpScreen(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Back to Home'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rebuilds do not reload and the caller retains its ViewModel', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 850);
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    await tester.pumpWidget(const SizedBox());
    await model.load();
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });
}
