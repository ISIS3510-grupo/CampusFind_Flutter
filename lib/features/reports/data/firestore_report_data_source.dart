import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:campusfind_flutter/features/reports/domain/lost_report.dart';

// Talks to Firestore using the shared data contract (Proyecto/firebase/schema.md).
class FirestoreReportDataSource {
  FirestoreReportDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _fallbackCategories = [
    'electronics',
    'documents',
    'keys',
    'bags',
    'clothing',
    'accessories',
    'other',
  ];

  String get currentUid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    return user.uid;
  }

  // Generated on the device, so a retried upload reuses the same document.
  String newReportId() => _firestore.collection('lostReports').doc().id;

  Future<List<String>> fetchCategories() async {
    try {
      final config = await _firestore.doc('appConfig/general').get();
      final categories = config.data()?['categories'];
      if (categories is List && categories.isNotEmpty) {
        return categories.cast<String>();
      }
    } catch (_) {
      // Uses the default list when the config cannot be read (e.g. offline).
    }
    return _fallbackCategories;
  }

  Future<List<LostReport>> fetchMyReports() async {
    final snapshot = await _firestore
        .collection('lostReports')
        .where('ownerUid', isEqualTo: currentUid)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return LostReport(
        id: doc.id,
        title: data['title'] as String? ?? '',
        category: data['category'] as String? ?? 'other',
        description: data['description'] as String? ?? '',
        status: data['status'] as String? ?? 'reported',
        locationName: data['locationName'] as String?,
        photoPath: data['photoPath'] as String?,
        reportedAt: (data['reportedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  // The public report and its optional private detail are written in one batch:
  // the security rules check that the report exists when the private doc is created.
  Future<void> createReport(
    String reportId,
    LostReportDraft draft, {
    String? photoPath,
  }) async {
    final uid = currentUid;
    final batch = _firestore.batch();

    batch.set(_firestore.collection('lostReports').doc(reportId), {
      'ownerUid': uid,
      'category': draft.category,
      'title': draft.title,
      'description': draft.description,
      'status': 'reported',
      'locationName': draft.locationName,
      'photoPath': ?photoPath,
      'reportedAt': FieldValue.serverTimestamp(),
      'statusChangedAt': FieldValue.serverTimestamp(),
    });

    final privateDetail = draft.privateVerificationDetail;
    if (privateDetail != null) {
      batch.set(_firestore.collection('lostReportPrivate').doc(reportId), {
        'ownerUid': uid,
        'privateVerificationDetail': privateDetail,
      });
    }

    await batch.commit();
  }

  // Uses the local cache too, so a report still waiting in Firestore's own
  // offline queue is not created twice.
  Future<bool> reportExists(String reportId) async {
    final doc = await _firestore.collection('lostReports').doc(reportId).get();
    return doc.exists;
  }

  // The owner adds the photo after the upload, so Storage could check the owner.
  Future<void> attachPhoto(String reportId, String photoPath) {
    return _firestore.collection('lostReports').doc(reportId).update({
      'photoPath': photoPath,
    });
  }
}
