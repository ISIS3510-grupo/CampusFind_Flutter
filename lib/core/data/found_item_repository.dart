import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/found_item.dart';

class FoundItemRepository {
  const FoundItemRepository({this.firestore});

  final FirebaseFirestore? firestore;

  Future<FoundItem?> getById(String foundItemId) async {
    if (foundItemId.trim().isEmpty) return null;
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('foundItems')
        .doc(foundItemId)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    return data == null ? null : FoundItem.fromFirestore(foundItemId, data);
  }

  Future<List<FoundItem>> getAvailableItems() async {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('foundItems')
        .where('status', isEqualTo: 'available')
        .get();
    return snapshot.docs
        .map((doc) => FoundItem.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
