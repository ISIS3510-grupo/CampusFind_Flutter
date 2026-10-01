import 'package:campusfind_flutter/DAOs/item_dao.dart';
import 'package:campusfind_flutter/core/data/found_item_repository.dart';
import 'package:campusfind_flutter/core/data/lost_report_repository.dart';
import 'package:campusfind_flutter/features/analytics/services/report_registration_performance_tracker.dart';
import 'package:campusfind_flutter/models/item_model.dart';
import 'package:campusfind_flutter/services/location_service.dart';
import 'package:campusfind_flutter/viewmodels/item_viewmodel.dart';
import 'package:campusfind_flutter/views/report_item_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'support/auth_fakes.dart';
import 'support/firestore_fakes.dart';
import 'support/registration_time_fakes.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  for (final type in ['found', 'lost']) {
    test(
      '$type registration writes the exact shared schema and uses the real tracker',
      () async {
        final database = FakeFirestore(
          documents: {
            'appConfig/general': {'currentSemesterId': '2027-1'},
          },
        );
        final metrics = FakeRegistrationMetricRepository();
        final clock = Stopwatch();
        final gps = _Location(onGet: () => expect(clock.isRunning, isTrue));
        final model = _model(database, metrics, gps, clock: clock);
        addTearDown(model.dispose);
        expect(
          await model.reportItem(
            reportType: type,
            title: 'Calculator',
            description: 'Black calculator',
            category: 'electronics',
          ),
          isTrue,
        );
        expect(clock.isRunning, isFalse);
        expect(model.isLoading, isFalse);
        expect(metrics.records, [
          {'reportType': type, 'durationMs': clock.elapsedMilliseconds},
        ]);

        final collection = type == 'found' ? 'foundItems' : 'lostReports';
        final expected = <String, dynamic>{
          'category': 'electronics',
          'title': 'Calculator',
          'locationName': 'Current location',
          'latitude': 4.6014,
          'longitude': -74.0661,
          if (type == 'found') ...{
            'reporterUid': 'student-1',
            'publicDescription': 'Black calculator',
            'status': 'available',
            'semesterId': '2027-1',
            'donationEligible': false,
            'donationStatus': 'not_eligible',
            'createdAt': FieldValue.serverTimestamp(),
          } else ...{
            'ownerUid': 'student-1',
            'description': 'Black calculator',
            'status': 'reported',
            'reportedAt': FieldValue.serverTimestamp(),
            'statusChangedAt': FieldValue.serverTimestamp(),
          },
        };
        expect(database.documentWrites, [
          {'path': '$collection/auto-1', 'data': expected},
        ]);
        expect(
          database.documentReads,
          type == 'found' ? ['appConfig/general'] : isEmpty,
        );

        // Simulate server timestamp resolution, then use the existing read repository.
        final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 1));
        database.documents['$collection/auto-1'] = expected.map(
          (key, value) =>
              MapEntry(key, value is FieldValue ? timestamp : value),
        );
        if (type == 'found') {
          final item = (await FoundItemRepository(
            firestore: database,
          ).getAvailableItems()).single;
          expect(item.reporterUid, 'student-1');
          expect(item.publicDescription, 'Black calculator');
          expect(item.imageUrl, isNull);
        } else {
          final report = await LostReportRepository(firestore: database)
              .getActiveReport('student-1');
          expect(report!.status, 'reported');
          expect(report.statusChangedAt, timestamp.toDate());
          expect(report.foundAt, isNull);
        }
        expect(
          database.documents.keys.any((path) => path.startsWith('items/')),
          isFalse,
        );
      },
    );
  }

  test('missing auth, invalid type, GPS and write failures create no successful metric', () async {
    for (final failure in ['auth', 'type', 'gps', 'write']) {
      final database = FakeFirestore(
        writeErrors: failure == 'write'
            ? {'lostReports/auto-1': StateError('write failed')}
            : {},
      );
      final metrics = FakeRegistrationMetricRepository();
      final gps = _Location(
        error: failure == 'gps' ? StateError('GPS failed') : null,
      );
      final model = _model(
        database,
        metrics,
        gps,
        authenticated: failure != 'auth',
      );
      addTearDown(model.dispose);
      expect(
        await model.reportItem(
          reportType: failure == 'type' ? 'invalid' : 'lost',
          title: 'Calculator',
          description: 'Black',
          category: 'electronics',
        ),
        isFalse,
        reason: failure,
      );
      expect(model.errorMessage, isNotEmpty, reason: failure);
      expect(model.isLoading, isFalse);
      expect(metrics.records, isEmpty, reason: failure);
      expect(database.documents, isEmpty, reason: failure);
      if (failure == 'auth' || failure == 'type') expect(gps.calls, 0);
    }
    final database = FakeFirestore();
    await expectLater(
      ItemDao(firestore: database)
          .insertItem(_item(), reportType: 'invalid', userUid: 'student-1'),
      throwsArgumentError,
    );
    expect(database.documentWrites, isEmpty);
  });

  test('found semester falls back when config is missing or invalid', () async {
    for (final value in [null, '', 'invalid', '2026-3', 2026]) {
      final database = FakeFirestore(
        documents: {
          if (value != null) 'appConfig/general': {'currentSemesterId': value},
        },
      );
      await ItemDao(firestore: database)
          .insertItem(_item(), reportType: 'found', userUid: 'student-1');
      expect(database.documents['foundItems/auto-1']!['semesterId'], '2026-2');
    }
  });

  testWidgets(
    'form has no email, validates before submission and passes lost type',
    (tester) async {
      final database = FakeFirestore();
      final metrics = FakeRegistrationMetricRepository();
      final model = _model(database, metrics, _Location());
      addTearDown(model.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: ReportItemScreen(reportType: 'lost')),
        ),
      );
      expect(find.text('Report Lost Item'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Correo Uniandes'), findsNothing);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(database.documentWrites, isEmpty);
      expect(metrics.records, isEmpty);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Calculator');
      await tester.enterText(fields.at(1), 'Black');
      await tester.enterText(fields.at(2), 'electronics');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(database.documentWrites.single['path'], 'lostReports/auto-1');
      expect(metrics.records.single['reportType'], 'lost');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

ItemModel _item() => ItemModel(
  title: 'Calculator',
  description: 'Black',
  category: 'electronics',
  location: const GeoPoint(4.6014, -74.0661),
);

ItemViewModel _model(
  FakeFirestore database,
  FakeRegistrationMetricRepository metrics,
  _Location gps, {
  bool authenticated = true,
  Stopwatch? clock,
}) {
  final user = FakeFirebaseUser(uid: 'student-1');
  final auth = FakeFirebaseAuthClient(signInUser: user)
    ..currentUser = authenticated ? user : null;
  return ItemViewModel(
    itemDao: ItemDao(firestore: database),
    firebaseAuth: auth,
    locationService: gps,
    tracker: ReportRegistrationPerformanceTracker(
      repository: metrics,
      createStopwatch: () => clock ?? Stopwatch(),
    ),
  );
}

class _Location extends LocationService {
  _Location({this.onGet, this.error});
  final VoidCallback? onGet;
  final Object? error;
  int calls = 0;
  @override
  Future<Position> getCurrentLocation() async {
    calls++;
    onGet?.call();
    if (error != null) throw error!;
    return _Position();
  }
}

class _Position extends Fake implements Position {
  @override
  double get latitude => 4.6014;
  @override
  double get longitude => -74.0661;
}
