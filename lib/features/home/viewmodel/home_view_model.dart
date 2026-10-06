import 'package:flutter/foundation.dart';

import '../../../core/data/found_item_repository.dart';
import '../../../core/data/lost_report_repository.dart';
import '../../../core/models/lost_report.dart';
import '../../auth/data/auth_service.dart';
import '../../matching/data/matching_config_repository.dart';
import '../../matching/domain/match_result.dart';
import '../../matching/services/basic_matching_strategy.dart';
import '../../matching/services/matching_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    this.authService = const AuthService(),
    this.lostReportRepository = const LostReportRepository(),
    this.foundItemRepository = const FoundItemRepository(),
    this.matchingConfigRepository = const MatchingConfigRepository(),
    MatchingService Function(double threshold)? createMatchingService,
  }) : createMatchingService = createMatchingService ?? _defaultMatchingService;

  final AuthService authService;
  final LostReportRepository lostReportRepository;
  final FoundItemRepository foundItemRepository;
  final MatchingConfigRepository matchingConfigRepository;
  // The service needs the threshold loaded from configuration.
  final MatchingService Function(double threshold) createMatchingService;

  LostReport? _activeReport;
  MatchResult? _bestMatch;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSigningOut = false;
  String? _signOutError;
  bool _disposed = false;

  LostReport? get activeReport => _activeReport;
  MatchResult? get bestMatch => _bestMatch;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSigningOut => _isSigningOut;
  String? get signOutError => _signOutError;

  static MatchingService _defaultMatchingService(double threshold) {
    return MatchingService(
      strategy: const BasicMatchingStrategy(),
      threshold: threshold,
    );
  }

  Future<void> loadHome() async {
    if (_isLoading || _isSigningOut || _disposed) return;
    _isLoading = true;
    _activeReport = null;
    _bestMatch = null;
    _errorMessage = null;
    notifyListeners();

    String? userId;
    LostReport? report;
    MatchResult? bestMatch;
    String? error;
    try {
      userId = authService.currentUserId;
      if (userId == null || userId.isEmpty) return;

      report = await lostReportRepository.getActiveReport(userId);
      if (_disposed || authService.currentUserId != userId) return;
      if (report == null) return;

      final foundItems = await foundItemRepository.getAvailableItems();
      if (_disposed || authService.currentUserId != userId) return;
      final threshold = await matchingConfigRepository.getMatchingThreshold();
      if (_disposed || authService.currentUserId != userId) return;

      final service = createMatchingService(threshold);
      final results = service.findPossibleMatches(report, foundItems);
      bestMatch = results.isEmpty ? null : results.first;
    } catch (_) {
      error = report == null
          ? 'Unable to load your active report.'
          : 'Unable to check possible matches.';
    } finally {
      _isLoading = false;
      if (!_disposed) {
        final sameUser = userId != null && authService.currentUserId == userId;
        _activeReport = sameUser ? report : null;
        _bestMatch = sameUser ? bestMatch : null;
        _errorMessage = error;
        notifyListeners();
      }
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
      _activeReport = null;
      _bestMatch = null;
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
