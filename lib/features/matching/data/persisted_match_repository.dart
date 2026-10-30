import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/persisted_match.dart';

class PersistedMatchRepository {
  const PersistedMatchRepository({this.firestore});

  final FirebaseFirestore? firestore;

  Future<PersistedMatch?> getBestMatch(String ownerUid, String reportId) async {
    if (ownerUid.trim().isEmpty || reportId.trim().isEmpty) return null;
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('matches')
        .where('ownerUid', isEqualTo: ownerUid)
        .where('reportId', isEqualTo: reportId)
        .orderBy('score', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.isEmpty
        ? null
        : PersistedMatch.fromFirestore(snapshot.docs.first.data());
  }
}
