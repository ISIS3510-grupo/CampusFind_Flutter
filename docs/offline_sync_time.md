# Sync time after recovering from offline

Business question (Type 1): **How does the application's report synchronization
time behave after recovering from an offline state?**

## Measurement boundary

`PendingReportSync` already sends the offline queue when the connection comes
back. `OfflineSyncTimeTracker` times that work:

- **Starts** when the "connection is back" event arrives (a `Stopwatch`, so it
  is monotonic and immune to clock changes).
- **Stops** when the last waiting report has reached the backend. The retries
  made while the network is still unstable are part of the time.
- A recovery with no waiting reports, one that does not finish (still offline,
  signed out) and a sync triggered only by signing in record nothing.
- Writing the sample is best effort and never delays the sync.

## Firestore schema

`performanceMetrics/{autoId}`:

| Field | Value/type |
| --- | --- |
| metricType | `offline_sync` |
| uid | Student that sent the reports |
| platform | `flutter` |
| durationMs | Elapsed milliseconds of the recovery |
| reportCount | Reports waiting when the recovery started (>= 1) |
| offlineDurationMs | How long the device was offline (omitted when unknown) |
| recordedAt | `FieldValue.serverTimestamp()` |

The security rules must allow students to create this metric type and staff to
read it, like they do for `report_registration`.

## Statistics and multithreading

The dashboard reads every sample from the server and
`OfflineSyncStatsService` calculates the summary in a separate isolate
(`Isolate.run`): average, median, 95th percentile (nearest rank), time per
report and the trend (least squares slope of the sync time over the recoveries
in order; positive means each recovery tends to be slower).

Uploads are not moved to isolates: Firestore I/O is already asynchronous and
does not block the UI thread, and its plugins need the main isolate.
