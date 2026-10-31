import 'dart:async';

import 'package:campusfind_flutter/core/data/lost_report_repository.dart';
import 'package:campusfind_flutter/core/data/found_item_repository.dart';
import 'package:campusfind_flutter/core/models/lost_report.dart';
import 'package:campusfind_flutter/core/models/found_item.dart';
import 'package:campusfind_flutter/features/auth/data/auth_service.dart';
import 'package:campusfind_flutter/features/matching/domain/persisted_match.dart';
import 'package:campusfind_flutter/features/matching/domain/persisted_match_repository.dart';

LostReport report(String id, {String? title}) => LostReport(
  id: id,
  ownerUid: 'student-1',
  category: 'electronics',
  title: title ?? id,
  description: 'Calculator',
  status: 'reported',
  locationName: 'ML',
  reportedAt: DateTime(2026),
);
FoundItem foundItem(String id) => FoundItem(
  id: id,
  reporterUid: 'finder',
  category: 'electronics',
  title: 'Found calculator',
  publicDescription: 'Black calculator',
  status: 'found',
  locationName: 'ML',
  semesterId: '2026-2',
  donationEligible: false,
  donationStatus: 'none',
  createdAt: DateTime(2026),
);

class HomeAuth extends AuthService {
  String? uid = 'student-1';
  int signOutCalls = 0;
  @override
  String? get currentUserId => uid;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    uid = null;
  }
}

class HomeReports extends LostReportRepository {
  List<LostReport> data = [report('one'), report('two')];
  Object? error;
  Completer<List<LostReport>>? pending;
  int calls = 0;
  @override
  Future<List<LostReport>> getActiveReports(
    String ownerUid, {
    int limit = 5,
  }) async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? data : await pending!.future;
  }
}

class HomeMatches implements PersistedMatchRepository {
  final errors = <String, Object>{};
  bool enabled = true;
  @override
  Future<PersistedMatch?> getBestMatch(String uid, String reportId) async {
    if (errors.containsKey(reportId)) throw errors[reportId]!;
    return enabled
        ? PersistedMatch(
            reportId: reportId,
            foundItemId: 'found-$reportId',
            score: .9,
          )
        : null;
  }
}

class HomeFoundItems extends FoundItemRepository {
  final errors = <String, Object>{};
  final missing = <String>{};
  @override
  Future<FoundItem?> getById(String id) async {
    if (errors.containsKey(id)) throw errors[id]!;
    return missing.contains(id) ? null : foundItem(id);
  }
}
