import 'dart:async';

import 'package:campusfind_flutter/features/analytics/data/report_registration_metric_repository_impl.dart';
import 'package:campusfind_flutter/features/analytics/services/report_registration_performance_tracker.dart';
import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';
import 'package:campusfind_flutter/features/reports/viewmodel/report_lost_item_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';
import '../../support/firestore_fakes.dart';
import 'fake_lost_report_repository.dart';

void main() {
  const draft = LostReportDraft(
    title: 'Calculator',
    category: 'electronics',
    description: 'Black Casio',
    locationName: 'ML building',
  );

  test(
    'metric retains submitting UID when auth changes during upload',
    () async {
      final repository = _PendingRepository();
      final database = FakeFirestore();
      final user = FakeFirebaseUser(uid: 'original');
      final auth = FakeFirebaseAuthClient(signInUser: user)..currentUser = user;
      final model = ReportLostItemViewModel(
        repository,
        tracker: ReportRegistrationPerformanceTracker(
          repository: ReportRegistrationMetricRepositoryImpl(
            firestore: database,
            firebaseAuth: auth,
          ),
        ),
      );
      addTearDown(model.dispose);
      final pending = model.submit(draft);
      auth.currentUser = FakeFirebaseUser(uid: 'replacement');
      repository.pending.complete(
        const SubmitResult('report-1', SubmitStatus.submitted),
      );
      await pending;
      expect(
        (database.documentWrites.single['data'] as Map)['uid'],
        'original',
      );
    },
  );

  for (final outcome in ['submitted', 'queued', 'failure']) {
    test(
      '$outcome preserves submission behavior and records only on success',
      () async {
        final repository = _PendingRepository();
        final database = FakeFirestore();
        final user = FakeFirebaseUser(uid: 'student-1');
        final auth = FakeFirebaseAuthClient(signInUser: user)
          ..currentUser = user;
        final stopwatch = Stopwatch();
        final controller = ReportLostItemViewModel(
          repository,
          tracker: ReportRegistrationPerformanceTracker(
            repository: ReportRegistrationMetricRepositoryImpl(
              firestore: database,
              firebaseAuth: auth,
            ),
            createStopwatch: () => stopwatch,
          ),
        );
        addTearDown(controller.dispose);
        final states = <bool>[];
        controller.addListener(() => states.add(controller.submitting));
        controller.errorMessage = 'Previous error';

        final submission = controller.submit(draft);
        expect(controller.submitting, isTrue);
        expect(controller.errorMessage, isNull);
        expect(stopwatch.isRunning, isTrue);
        expect(database.documentWrites, isEmpty);
        expect(await controller.submit(draft), isNull);
        expect(repository.calls, 1);
        expect(repository.received, same(draft));

        if (outcome == 'failure') {
          repository.pending.completeError(StateError('Submission failed'));
          expect(await submission, isNull);
          expect(
            controller.errorMessage,
            'Unable to send the report. Please try again.',
          );
          expect(database.documentWrites, isEmpty);
        } else {
          final result = SubmitResult(
            'report-1',
            outcome == 'queued'
                ? SubmitStatus.queuedOffline
                : SubmitStatus.submitted,
            photoFailed: outcome == 'queued',
          );
          repository.pending.complete(result);
          expect(await submission, same(result));
          expect(controller.errorMessage, isNull);
          if (outcome == 'queued') {
            expect(database.documentWrites, isEmpty);
          } else {
            expect(database.documentWrites.single, {
              'path': 'performanceMetrics/auto-1',
              'data': {
                'metricType': 'report_registration',
                'uid': 'student-1',
                'reportType': 'lost',
                'platform': 'flutter',
                'durationMs': stopwatch.elapsedMilliseconds,
                'recordedAt': FieldValue.serverTimestamp(),
              },
            });
          }
        }
        expect(repository.calls, 1);
        expect(stopwatch.isRunning, isFalse);
        expect(controller.submitting, isFalse);
        expect(states, [true, false]);
      },
    );
  }
}

class _PendingRepository extends FakeLostReportRepository {
  final pending = Completer<SubmitResult>();
  int calls = 0;
  LostReportDraft? received;

  @override
  Future<SubmitResult> submit(LostReportDraft draft) {
    calls++;
    received = draft;
    return pending.future;
  }
}
