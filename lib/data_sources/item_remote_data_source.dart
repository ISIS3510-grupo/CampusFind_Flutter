import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/campus_locations.dart';
import '../models/item_model.dart';

// Remote data source that communicates with Firebase to report objects in charge of virtual/remote persistence.
// view -> viewmodel -> itemmodel -> item remote data source
class ItemRemoteDataSource {
  const ItemRemoteDataSource({
    this.firestore,
  }); // allows dependencies from Firestore BDs

  final FirebaseFirestore?
  firestore; // can be null because by default uses global instance.

  /// Consulta los edificios del campus desde la colección 'campusLocations' en Firestore.
  Future<List<CampusLocation>> getCampusLocations() async {
    final database = firestore ?? FirebaseFirestore.instance;
    final snapshot = await database.collection('campusLocations').get();
    if (snapshot.docs.isEmpty) {
      return defaultUniandesLocations;
    }
    return snapshot.docs.map(CampusLocation.fromFirestore).toList();
  }

  // a void function executes steps but doesn't return an object.
  void insertItem(
    // since the verification of fields at DB is asynchronous, stores the item and uses onError and onSuccess
    ItemModel item, {
    required String reportType,
    required String userUid,
    String? locationName,
    required void Function() onSuccess, // callback yes
    required void Function(String message) onError, // callback no
  }) {
    if (reportType != 'found' && reportType != 'lost') {
      onError('Expected found or lost');
      return;
    }
    if (userUid.trim().isEmpty) {
      // .trim deletes spaces so a string full of spaces is read as empty
      onError('A user UID is required.');
      return;
    }
    // Mapping: takes internal properties of items and transforms them into fields.
    final database =
        firestore ??
        FirebaseFirestore
            .instance; // instance of Firebase that the data source uses
    final fields = <String, dynamic>{
      'category': item.category.trim().toLowerCase(),
      'title': item.title,
      'locationName': locationName ?? 'Current location',
      'latitude': item.location.latitude,
      'longitude': item.location.longitude,
    };

    if (reportType == 'found') {
      database
          .collection('appConfig')
          .doc('general')
          .get()
          .then((config) {
            final value = config.data()?['currentSemesterId'];
            final semester =
                value is String &&
                    RegExp(r'^\d{4}-[12]$').hasMatch(value) // compares semester
                ? value
                : '2026-2';
            return database.collection('foundItems').add({
              // adds to the collection the corresponding element
              ...fields,
              'reporterUid': userUid,
              'publicDescription': item.description,
              'status': 'available',
              'semesterId': semester,
              'donationEligible': false,
              // The rules only accept 'none' when a found item is created.
              'donationStatus': 'none',
              'createdAt': FieldValue.serverTimestamp(),
            });
          })
          .then((_) {
            onSuccess();
          })
          .catchError((Object e) {
            onError(e.toString());
          });
    } else {
      database
          .collection('lostReports')
          .add({
            ...fields,
            'ownerUid': userUid,
            'description': item.description,
            'status': 'reported',
            'reportedAt': FieldValue.serverTimestamp(),
            'statusChangedAt': FieldValue.serverTimestamp(),
          })
          .then((_) {
            onSuccess();
          })
          .catchError((Object e) {
            onError(e.toString());
          });
    }
  }
}
