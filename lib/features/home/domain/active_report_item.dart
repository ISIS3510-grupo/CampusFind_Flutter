import '../../../core/models/found_item.dart';
import '../../../core/models/lost_report.dart';
import '../../matching/domain/persisted_match.dart';

class ActiveReportItem {
  const ActiveReportItem({
    required this.report,
    this.possibleMatch,
    this.foundItem,
  });

  final LostReport report;
  final PersistedMatch? possibleMatch;
  final FoundItem? foundItem;

  String get statusLabel => switch (report.status) {
    'reported' => 'Reported',
    'found' => 'Found',
    'ready_for_pickup' => 'Ready for pickup',
    'claimed' => 'Claimed',
    final value => value.replaceAll('_', ' '),
  };
}
