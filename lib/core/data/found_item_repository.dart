import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/found_item.dart';

class FoundItemRepository {
  const FoundItemRepository({this.firestore});

  final FirebaseFirestore? firestore;

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
