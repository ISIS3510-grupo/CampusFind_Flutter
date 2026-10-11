String reportAge(DateTime reportedAt, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  final reported = reportedAt.toLocal();
  // Compare local calendar dates without daylight-saving offsets.
  final days = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(reported.year, reported.month, reported.day))
      .inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day ago';
  return '$days days ago';
}
