import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/office_location.dart';

class OfficeLocationRepository {
  const OfficeLocationRepository({this.officeId = 'ml', this.firestore});

  final String officeId;
  final FirebaseFirestore? firestore;

  Future<OfficeLocation?> getOfficeLocation() async {
    if (officeId.trim().isEmpty || officeId.contains('/')) {
      throw ArgumentError.value(
        officeId,
        'officeId',
        'Expected an office document ID.',
      );
    }
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('officeLocations')
        .doc(officeId)
        .get();
    final data = snapshot.data();
    return data == null ? null : OfficeLocation.fromFirestore(officeId, data);
  }
}
