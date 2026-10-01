import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item_model.dart';

class ItemDao {
  // Referencia a la colección 'items' en Firestore
  final CollectionReference _itemsCollection =
      FirebaseFirestore.instance.collection('items');

  /// Inserta un nuevo objeto reportado en Firestore
  Future<void> insertItem(ItemModel item) async {
    await _itemsCollection.add(item.toMap());
  }

  /// Obtiene todos los objetos reportados como un Stream en tiempo real
  Stream<List<ItemModel>> getAllItems() {
    return _itemsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ItemModel.fromSnapshot(doc)).toList();
    });
  }
}