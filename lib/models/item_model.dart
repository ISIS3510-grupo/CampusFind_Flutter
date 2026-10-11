// ignore_for_file: unused_import

import 'package:cloud_firestore/cloud_firestore.dart';

class ItemModel {
  final String? id;
  final String title;
  final String description;
  final String category;
  final GeoPoint location;
  final DateTime? createdAt;

  ItemModel({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.createdAt,
  });

  /// Convierte el objeto en un mapa para guardarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// Crea una instancia de ItemModel a partir de un documento de Firestore
  factory ItemModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ItemModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      location: data['location'] as GeoPoint,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
