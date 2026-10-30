import 'persisted_match.dart';

abstract interface class PersistedMatchRepository {
  Future<PersistedMatch?> getBestMatch(String ownerUid, String reportId);
}
