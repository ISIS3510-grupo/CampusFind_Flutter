import 'dart:async';

import 'package:campusfind_flutter/features/drop_off/domain/office_location.dart';
import 'package:campusfind_flutter/features/drop_off/viewmodel/drop_off_instructions_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/drop_off_fakes.dart';

void main() {
  late FakeOfficeLocationRepository repository;
  late DropOffInstructionsViewModel model;
  var disposed = false;
  setUp(() {
    repository = FakeOfficeLocationRepository();
    model = DropOffInstructionsViewModel(repository: repository);
    disposed = false;
  });
  tearDown(() {
    if (!disposed) model.dispose();
  });

  test('initial state is idle without office data or errors', () {
    expect(model.officeLocation, isNull);
    expect(model.isLoading, isFalse);
    expect(model.errorMessage, isNull);
  });

  test(
    'load notifies loading state and preserves the returned office',
    () async {
      repository.pending = Completer<OfficeLocation?>();
      final states = <bool>[];
      model.addListener(() => states.add(model.isLoading));
      final loading = model.load();
      expect(model.isLoading, isTrue);
      expect(model.officeLocation, isNull);
      repository.pending!.complete(repository.office);
      await loading;
      expect(model.officeLocation, same(repository.office));
      expect(model.errorMessage, isNull);
      expect(states, [true, false]);
    },
  );

  test(
    'backend failure exposes a safe error without fake office data',
    () async {
      repository.error = StateError('Backend details');
      await model.load();
      expect(model.isLoading, isFalse);
      expect(model.officeLocation, isNull);
      expect(
        model.errorMessage,
        'Unable to load office information. Please try again.',
      );
    },
  );

  test('missing office is reported as unavailable', () async {
    repository.office = null;
    await model.load();
    expect(model.officeLocation, isNull);
    expect(model.errorMessage, 'Office information is not available yet.');
  });

  test('successful retry clears the error', () async {
    repository.error = StateError('Offline');
    await model.load();
    repository.error = null;
    await model.load();
    expect(model.errorMessage, isNull);
    expect(model.officeLocation, same(repository.office));
  });

  test('overlapping loads do not duplicate requests', () async {
    repository.pending = Completer<OfficeLocation?>();
    final loading = model.load();
    await model.load();
    expect(repository.calls, 1);
    repository.pending!.complete(repository.office);
    await loading;
  });

  for (final fail in [false, true]) {
    test(
      'dispose prevents late ${fail ? 'error' : 'success'} notifications',
      () async {
        repository.pending = Completer<OfficeLocation?>();
        var notifications = 0;
        model.addListener(() => notifications++);
        final loading = model.load();
        model.dispose();
        disposed = true;
        if (fail) {
          repository.pending!.completeError(StateError('Offline'));
        } else {
          repository.pending!.complete(repository.office);
        }
        await loading;
        await model.load();
        expect(notifications, 1);
        expect(repository.calls, 1);
        expect(model.officeLocation, isNull);
      },
    );
  }
}
