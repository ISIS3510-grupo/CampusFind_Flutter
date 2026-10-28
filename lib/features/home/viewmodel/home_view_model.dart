import 'package:flutter/foundation.dart';

import '../../../core/data/found_item_repository.dart';
import '../../../core/data/lost_report_repository.dart';
import '../../auth/data/auth_service.dart';
import '../../matching/data/persisted_match_repository.dart';
import '../../matching/domain/match_result.dart';
import 'active_report_item.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    this.authService = const AuthService(),
    this.lostReportRepository = const LostReportRepository(),
    this.foundItemRepository = const FoundItemRepository(),
    this.persistedMatchRepository = const PersistedMatchRepository(),
  });

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

  Future<void> loadHome() async {
    if (_isLoading || _isSigningOut || _disposed) return;
    _isLoading = true;
    _activeReports = const [];
    _errorMessage = null;
    notifyListeners();

    String? userId;
    try {
      userId = authService.currentUserId;
      if (userId == null || userId.isEmpty) return;

      final reports = await lostReportRepository.getActiveReports(userId);
      if (_disposed || authService.currentUserId != userId) return;
      // Defensive cap for injected repositories; production also limits reads.
      final visible =
          reports
              .where(
                (report) =>
                    report.ownerUid == userId && report.status != 'closed',
              )
              .toList()
            ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
      _activeReports = List.unmodifiable(
        visible.take(5).map((report) => ActiveReportItem(report: report)),
      );
      if (_activeReports.isEmpty) return;
      notifyListeners(); // Reports remain visible while match lookups finish.
      final matched = await Future.wait(
        _activeReports.map((item) async {
          try {
            final match = await persistedMatchRepository.getBestMatch(
              userId!,
              item.report.id,
            );
            return ActiveReportItem(report: item.report, possibleMatch: match);
          } catch (error) {
            debugPrint('Possible match lookup failed: $error');
            return item;
          }
        }),
      );
      if (_disposed || authService.currentUserId != userId) return;
      _activeReports = List.unmodifiable(matched);
    } catch (error) {
      debugPrint('Active reports could not be loaded: $error');
      if (!_disposed) {
        _errorMessage = 'Unable to load your active reports.';
      }
    } finally {
      _isLoading = false;
      if (!_disposed) {
        final sameUser = userId != null && authService.currentUserId == userId;
        if (!sameUser) {
          _activeReports = const [];
          _errorMessage = null;
        }
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
      final found = await foundItemRepository.getById(match.foundItemId);
      if (_disposed ||
          _isSigningOut ||
          authService.currentUserId != uid ||
          !_activeReports.contains(item) ||
          found == null) {
        return null;
      }
      return MatchResult(foundItem: found, score: match.score);
    } catch (error) {
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
