// One measured recovery: the time from the moment the connection came back
// until the last report that was waiting offline reached the backend.
class OfflineSyncSample {
  const OfflineSyncSample({
    required this.durationMs,
    required this.reportCount,
    required this.recordedAt,
    this.offlineDurationMs,
  });

  // Elapsed time of the whole recovery, including the retries.
  final int durationMs;

  // How many reports were waiting in the offline queue when it started.
  final int reportCount;

  final DateTime recordedAt;

  // How long the device had been offline. Null when the app did not see the
  // connection drop (for example, it was opened without a connection).
  final int? offlineDurationMs;
}
