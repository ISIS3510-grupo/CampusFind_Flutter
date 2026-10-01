import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_model.dart';

class ItemDao {
  const ItemDao({this.firestore});

  final FirebaseFirestore? firestore;

  /// Inserta un nuevo objeto reportado en Firestore
  Future<void> insertItem(
    ItemModel item, {
    required String reportType,
    required String userUid,
  }) async {
    if (reportType != 'found' && reportType != 'lost') {
      throw ArgumentError.value(
        reportType,
        'reportType',
        'Expected found or lost',
      );
    }
    if (userUid.trim().isEmpty) throw ArgumentError('A user UID is required.');

    final database = firestore ?? FirebaseFirestore.instance;
    final fields = <String, dynamic>{
      'category': item.category,
      'title': item.title,
      'locationName': 'Current location',
      'latitude': item.location.latitude,
      'longitude': item.location.longitude,
    };
    if (reportType == 'found') {
      await database.collection('foundItems').add({
        ...fields,
        'reporterUid': userUid,
        'publicDescription': item.description,
        'status': 'available',
        'semesterId': await _currentSemesterId(database),
        'donationEligible': false,
        'donationStatus': 'not_eligible',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await database.collection('lostReports').add({
        ...fields,
        'ownerUid': userUid,
        'description': item.description,
        'status': 'reported',
        'reportedAt': FieldValue.serverTimestamp(),
        'statusChangedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String> _currentSemesterId(FirebaseFirestore database) async {
    final config = await database.collection('appConfig').doc('general').get();
    final semester = config.data()?['currentSemesterId'];
    return semester is String && RegExp(r'^\d{4}-[12]$').hasMatch(semester)
        ? semester
        : '2026-2';
  }
}
