import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/claim_repository.dart';

class FirestoreClaimRepository implements ClaimRepository {
  FirestoreClaimRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Future<ClaimSubmitResult> submit(ClaimDraft draft) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('You need to sign in to claim an item.');

    // The answer goes to claimPrivate so other students never see it; staff
    // compares it with the private characteristics of the found item.
    final batch = _firestore.batch()
      ..set(_firestore.collection('claims').doc(draft.claimId), {
        'reportId': draft.reportId,
        'foundItemId': draft.foundItemId,
        'claimantUid': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_firestore.collection('claimPrivate').doc(draft.claimId), {
        'ownershipAnswer': draft.ownershipAnswer.trim(),
        'claimantUid': uid,
      });

    try {
      await batch.commit();
      return ClaimSubmitResult.submitted;
    } on FirebaseException catch (error) {
      // Claims cannot be updated, so writing the same id again is denied.
      if (error.code == 'permission-denied' && await _exists(draft.claimId)) {
        return ClaimSubmitResult.alreadyClaimed;
      }
      rethrow;
    }
  }

  Future<bool> _exists(String claimId) async {
    try {
      final doc = await _firestore.collection('claims').doc(claimId).get();
      return doc.exists;
    } on FirebaseException {
      return false;
    }
  }
}
