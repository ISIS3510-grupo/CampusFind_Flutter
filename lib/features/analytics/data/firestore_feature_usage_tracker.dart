import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:campusfind_flutter/features/analytics/domain/app_feature.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_tracker.dart';

// Stores one document per use in featureUsageEvents. The write is not awaited,
// and Firestore keeps it in its offline queue when there is no connection.
class FirestoreFeatureUsageTracker implements FeatureUsageTracker {
  const FirestoreFeatureUsageTracker();

  // The Firestore rule accepts durationMs from 0 up to (not including) 10 minutes.
  static const maxDurationMs = 600000;

  // Milliseconds to store, or null when the use has no time or the time is out
  // of range: the use is still recorded, only without durationMs.
  @visibleForTesting
  static int? storedDurationMs(Duration? responseTime) {
    final ms = responseTime?.inMilliseconds;
    if (ms == null || ms < 0 || ms >= maxDurationMs) return null;
    return ms;
  }

  @override
  void track(AppFeature feature, {Duration? responseTime}) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final durationMs = storedDurationMs(responseTime);

      final write = FirebaseFirestore.instance
          .collection('featureUsageEvents')
          .add({
            'uid': uid,
            'feature': feature.id,
            'platform': 'flutter',
            'occurredAt': FieldValue.serverTimestamp(),
            'durationMs': ?durationMs,
          });
      unawaited(
        write.then<void>(
          (_) {},
          onError: (Object error) =>
              debugPrint('Feature usage not recorded: $error'),
        ),
      );
    } catch (error) {
      // Firebase not initialized (e.g. widget tests) or no signed-in user.
      debugPrint('Feature usage not recorded: $error');
    }
  }
}
