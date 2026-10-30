import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/found_item_repository.dart';
import '../../../core/data/lost_report_repository.dart';
import '../../auth/data/auth_service.dart';
import '../../matching/data/persisted_match_repository.dart';
import '../../matching/domain/match_result.dart';
import '../data/home_cache_repository.dart';
import 'active_report_item.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    this.cacheRepository = const HomeCacheRepository(),
    this.authService = const AuthService(),
    this.lostReportRepository = const LostReportRepository(),
    this.foundItemRepository = const FoundItemRepository(),
    this.persistedMatchRepository = const PersistedMatchRepository(),
  });

  final HomeCacheRepository cacheRepository;
  final AuthService authService;
  final LostReportRepository lostReportRepository;
  final FoundItemRepository foundItemRepository;
  final PersistedMatchRepository persistedMatchRepository;

  List<ActiveReportItem> _activeReports = const [];
  final Set<String> _openingMatches = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSigningOut = false;
  String? _signOutError;
  bool _disposed = false;

  List<ActiveReportItem> get activeReports => _activeReports;
  bool isOpeningMatch(String reportId) => _openingMatches.contains(reportId);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSigningOut => _isSigningOut;
  String? get signOutError => _signOutError;

  bool _isShowingCachedData = false;
  bool _isOffline = false;
  HomeCacheSnapshot? _snapshot;
  String? _dataUserId;
  Future<void>? _pendingLoad;
  bool get isShowingCachedData => _isShowingCachedData;
  bool get isOffline => _isOffline;
  bool get isCacheExpired =>
      _isShowingCachedData && (_snapshot?.isExpired(DateTime.now()) ?? false);

  // A gesture during an existing load waits, then forces a new server request.
  Future<void> refresh() async {
    await _pendingLoad;
    await loadHome();
  }

  Future<void> loadHome() {
    if (_disposed || _isSigningOut) return Future.value();
    return _pendingLoad ??= _loadHome().whenComplete(() => _pendingLoad = null);
  }

  bool _sameUser(String uid) =>
      !_disposed && !_isSigningOut && authService.currentUserId == uid;
  bool _connectivityError(Object error) =>
      error is FirebaseException &&
      const [
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      ].contains(error.code);

  void _clearData() {
    _activeReports = const [];
    _snapshot = null;
    _isShowingCachedData = false;
    _isOffline = false;
    _errorMessage = null;
  }

  Future<void> _loadHome() async {
    final uid = authService.currentUserId;
    if (_dataUserId != uid) _clearData();
    _dataUserId = uid;
    _errorMessage = null;
    if (uid == null || uid.isEmpty) {
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final cached = await cacheRepository.load(uid);
      if (!_sameUser(uid)) return;
      // Retain the last successful in-memory snapshot if persistence failed.
      if (cached != null &&
          (_snapshot == null ||
              !cached.cachedAt.isBefore(_snapshot!.cachedAt))) {
        _snapshot = cached;
      }
      if (_snapshot != null) {
        _activeReports = _snapshot!.items;
        _isShowingCachedData = true;
        notifyListeners();
      }
      final reports = await lostReportRepository.getActiveReports(uid);
      if (!_sameUser(uid)) return;
      final visible =
          reports
              .where((r) => r.ownerUid == uid && r.status != 'closed')
              .toList()
            ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
      if (_snapshot == null) {
        _activeReports = List.unmodifiable(
          visible.take(5).map((r) => ActiveReportItem(report: r)),
        );
        notifyListeners();
      }
      // Publish and cache a complete snapshot only after all reads succeed.
      final fresh = await Future.wait(
        visible.take(5).map((report) async {
          final match = await persistedMatchRepository.getBestMatch(
            uid,
            report.id,
          );
          final found = match == null
              ? null
              : await foundItemRepository.getById(match.foundItemId);
          return ActiveReportItem(
            report: report,
            possibleMatch: match,
            foundItem: found,
          );
        }),
      );
      if (!_sameUser(uid)) return;
      final snapshot = HomeCacheSnapshot(
        items: fresh,
        cachedAt: DateTime.now(),
      );
      _snapshot = snapshot;
      _activeReports = snapshot.items;
      _isShowingCachedData = false;
      _isOffline = false;
      notifyListeners();
      try {
        await cacheRepository.save(uid, snapshot);
      } catch (error) {
        debugPrint('Home cache could not be saved: $error');
      }
    } catch (error) {
      if (!_sameUser(uid)) return;
      _isOffline = _connectivityError(error) && _snapshot != null;
      if (!_isOffline) _errorMessage = 'Unable to load your active reports.';
    } finally {
      _isLoading = false;
      if (!_disposed) {
        if (!_sameUser(uid)) _clearData();
        notifyListeners();
      }
    }
  }

  Future<MatchResult?> openPossibleMatch(ActiveReportItem item) async {
    final uid = authService.currentUserId;
    final match = item.possibleMatch;
    if (_disposed ||
        _isSigningOut ||
        uid == null ||
        item.report.ownerUid != uid ||
        match == null ||
        !_activeReports.contains(item) ||
        !_openingMatches.add(item.report.id)) {
      return null;
    }
    notifyListeners();
    try {
      final found = isOffline && item.foundItem != null
          ? item.foundItem
          : await foundItemRepository.getById(match.foundItemId);
      if (_disposed ||
          _isSigningOut ||
          authService.currentUserId != uid ||
          !_activeReports.contains(item) ||
          found == null) {
        return null;
      }
      return MatchResult(foundItem: found, score: match.score);
    } catch (error) {
      if (_connectivityError(error) &&
          _sameUser(uid) &&
          _activeReports.contains(item) &&
          item.foundItem != null) {
        _isShowingCachedData = true;
        _isOffline = true;
        return MatchResult(foundItem: item.foundItem!, score: match.score);
      }
      debugPrint('Possible match item could not be loaded: $error');
      return null;
    } finally {
      _openingMatches.remove(item.report.id);
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> signOut() async {
    if (_isSigningOut || _disposed) return false;
    _isSigningOut = true;
    _signOutError = null;
    notifyListeners();
    try {
      await authService.signOut();
      if (_disposed) return false;
      _activeReports = const [];
      return true;
    } catch (_) {
      if (!_disposed) _signOutError = 'Unable to sign out. Please try again.';
      return false;
    } finally {
      _isSigningOut = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
