import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/lost_report.dart';
import '../../../core/models/found_item.dart';
import '../../matching/domain/persisted_match.dart';
import '../viewmodel/active_report_item.dart';

class HomeCacheSnapshot {
  HomeCacheSnapshot({
    required List<ActiveReportItem> items,
    required this.cachedAt,
  }) : items = List.unmodifiable(items);
  static const ttl = Duration(minutes: 5);
  final List<ActiveReportItem> items;
  final DateTime cachedAt;
  bool isExpired(DateTime now) => !now.isBefore(cachedAt.add(ttl));
}

/// Versioned per-account snapshots. Expiry never deletes offline fallback data.
/// Photo references are stored; image bytes are not downloaded by this cache.
class HomeCacheRepository {
  const HomeCacheRepository();
  String _key(String uid) => 'home_cache_v1_$uid';
  Future<HomeCacheSnapshot?> load(String uid) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key(uid));
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((entry) {
            final report = _decodeLostReport(entry['report']);
            final match = entry['match'] == null
                ? null
                : PersistedMatch.fromFirestore(entry['match']);
            final found = entry['found'] == null
                ? null
                : _decodeFoundItem(entry['found']);
            if (report.ownerUid != uid ||
                (match != null && match.reportId != report.id) ||
                (found != null && found.id != match?.foundItemId)) {
              throw const FormatException(
                'Invalid Home cache ownership or reference',
              );
            }
            return ActiveReportItem(
              report: report,
              possibleMatch: match,
              foundItem: found,
            );
          })
          .where((item) => item.report.status != 'closed')
          .take(5)
          .toList();
      return HomeCacheSnapshot(
        items: items,
        cachedAt: DateTime.parse(data['cachedAt']),
      );
    } catch (_) {
      return null; // Corrupt or unavailable storage must not block Firestore.
    }
  }

  Future<void> save(String uid, HomeCacheSnapshot snapshot) async {
    final data = {
      'cachedAt': snapshot.cachedAt.toIso8601String(),
      'items': snapshot.items
          .map(
            (item) => {
              'report': _encodeLostReport(item.report),
              'match': item.possibleMatch == null
                  ? null
                  : {
                      'reportId': item.possibleMatch!.reportId,
                      'foundItemId': item.possibleMatch!.foundItemId,
                      'score': item.possibleMatch!.score,
                    },
              'found': item.foundItem == null
                  ? null
                  : _encodeFoundItem(item.foundItem!),
            },
          )
          .toList(),
    };
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key(uid),
      jsonEncode(data),
    );
    if (!saved) throw StateError('Home cache could not be saved');
  }

  Future<void> clear(String uid) async {
    await (await SharedPreferences.getInstance()).remove(_key(uid));
  }
}

Map<String, dynamic> _encodeLostReport(LostReport value) => {
  'id': value.id,
  'ownerUid': value.ownerUid,
  'category': value.category,
  'title': value.title,
  'description': value.description,
  'status': value.status,
  'locationName': value.locationName,
  'latitude': value.latitude,
  'longitude': value.longitude,
  'photoPath': value.photoPath,
  'reportedAt': value.reportedAt.toIso8601String(),
  'statusChangedAt': value.statusChangedAt?.toIso8601String(),
  'foundAt': value.foundAt?.toIso8601String(),
  'readyForPickupAt': value.readyForPickupAt?.toIso8601String(),
  'claimedAt': value.claimedAt?.toIso8601String(),
  'closedAt': value.closedAt?.toIso8601String(),
};
LostReport _decodeLostReport(Map<String, dynamic> data) => LostReport(
  id: data['id'] as String,
  ownerUid: data['ownerUid'] as String,
  category: data['category'] as String,
  title: data['title'] as String,
  description: data['description'] as String,
  status: data['status'] as String,
  locationName: data['locationName'] as String,
  latitude: (data['latitude'] as num?)?.toDouble(),
  longitude: (data['longitude'] as num?)?.toDouble(),
  photoPath: data['photoPath'] as String?,
  reportedAt: DateTime.parse(data['reportedAt'] as String),
  statusChangedAt: data['statusChangedAt'] == null
      ? null
      : DateTime.parse(data['statusChangedAt'] as String),
  foundAt: data['foundAt'] == null
      ? null
      : DateTime.parse(data['foundAt'] as String),
  readyForPickupAt: data['readyForPickupAt'] == null
      ? null
      : DateTime.parse(data['readyForPickupAt'] as String),
  claimedAt: data['claimedAt'] == null
      ? null
      : DateTime.parse(data['claimedAt'] as String),
  closedAt: data['closedAt'] == null
      ? null
      : DateTime.parse(data['closedAt'] as String),
);

Map<String, dynamic> _encodeFoundItem(FoundItem value) => {
  'id': value.id,
  'reporterUid': value.reporterUid,
  'category': value.category,
  'title': value.title,
  'publicDescription': value.publicDescription,
  'status': value.status,
  'locationName': value.locationName,
  'latitude': value.latitude,
  'longitude': value.longitude,
  'photoPath': value.photoPath,
  'semesterId': value.semesterId,
  'donationEligible': value.donationEligible,
  'donationStatus': value.donationStatus,
  'createdAt': value.createdAt.toIso8601String(),
};
FoundItem _decodeFoundItem(Map<String, dynamic> data) => FoundItem(
  id: data['id'] as String,
  reporterUid: data['reporterUid'] as String,
  category: data['category'] as String,
  title: data['title'] as String,
  publicDescription: data['publicDescription'] as String,
  status: data['status'] as String,
  locationName: data['locationName'] as String,
  latitude: (data['latitude'] as num?)?.toDouble(),
  longitude: (data['longitude'] as num?)?.toDouble(),
  photoPath: data['photoPath'] as String?,
  semesterId: data['semesterId'] as String,
  donationEligible: data['donationEligible'] as bool,
  donationStatus: data['donationStatus'] as String,
  createdAt: DateTime.parse(data['createdAt'] as String),
);
