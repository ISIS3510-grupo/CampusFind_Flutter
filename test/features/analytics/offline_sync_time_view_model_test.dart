import 'dart:async';

import 'package:campusfind_flutter/features/analytics/domain/offline_sync_sample.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/offline_sync_time_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/offline_sync_fakes.dart';

void main() {
  late FakeOfflineSyncMetricRepository repository;
  late OfflineSyncTimeViewModel viewModel;

  setUp(() {
    repository = FakeOfflineSyncMetricRepository();
    viewModel = OfflineSyncTimeViewModel(repository: repository);
  });

  tearDown(() => viewModel.dispose());

  test('loads the samples and exposes the summary', () async {
    repository.samples = [syncSample(0, 1000), syncSample(1, 3000)];

    await viewModel.load();

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.summary!.sampleCount, 2);
    expect(viewModel.summary!.averageMs, 2000);
  });

  test('no samples gives a summary without data', () async {
    await viewModel.load();

    expect(viewModel.summary!.hasData, isFalse);
  });

  test('ignores a second load while one is running', () async {
    final pending = Completer<List<OfflineSyncSample>>();
    repository.pendingFetch = pending;

    final first = viewModel.load();
    await viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(repository.fetchCalls, 1);

    pending.complete([syncSample(0, 100)]);
    await first;
    expect(viewModel.isLoading, isFalse);
  });

  test('shows a message and keeps the last summary when it fails', () async {
    repository.samples = [syncSample(0, 1000)];
    await viewModel.load();

    repository.fetchError = StateError('network');
    await viewModel.load();

    expect(viewModel.errorMessage, isNotNull);
    expect(viewModel.summary!.sampleCount, 1);
    expect(viewModel.isLoading, isFalse);
  });

  test('a later successful load clears the error', () async {
    repository.fetchError = StateError('network');
    await viewModel.load();
    repository.fetchError = null;

    await viewModel.load();

    expect(viewModel.errorMessage, isNull);
  });
}
