import 'active_report_item.dart';

class HomeCacheSnapshot {
  HomeCacheSnapshot({
    required List<ActiveReportItem> items,
    required this.cachedAt,
  }) : items = List.unmodifiable(items);
  static const ttl = Duration(minutes: 5);
  final List<ActiveReportItem> items;
  final DateTime cachedAt;
  bool isExpired(DateTime now) => !now.isBefore(cachedAt.add(ttl));
}
