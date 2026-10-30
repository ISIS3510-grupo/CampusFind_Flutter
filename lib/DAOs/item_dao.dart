import 'package:cloud_firestore/cloud_firestore.dart';
 
import '../models/item_model.dart';
 
// class DAO that communicates with firebase to report objects in charge of persistence since it interacts constantly with DB. 
// view  -> viewmodel -> itemmodel -> item dao
class ItemDao {
  const ItemDao({this.firestore});
 
  final FirebaseFirestore? firestore;
 
  void insertItem(
    ItemModel item, {
    required String reportType,
    required String userUid,
    String? locationName,
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) {
    if (reportType != 'found' && reportType != 'lost') {
      onError('Expected found or lost');
      return;
    }
    if (userUid.trim().isEmpty) { //.trim delete spaces soy a string full of spaces is read as empty
      onError('A user UID is required.');
      return;
    }
 //Maping: takes internal properties of items and transforms them into fields.
    final database = firestore ?? FirebaseFirestore.instance; //instance of Firebase that DAO uses
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
                value is String && RegExp(r'^\d{4}-[12]$').hasMatch(value) //compares semester
                ? value
                : '2026-2';
            return database.collection('foundItems').add({ //adds to the collection the correspondant element
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
 
