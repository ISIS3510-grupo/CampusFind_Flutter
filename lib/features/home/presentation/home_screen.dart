import 'package:flutter/material.dart';

import '../../../core/data/found_item_repository.dart';
import '../../../core/data/lost_report_repository.dart';
import '../../../core/models/lost_report.dart';
import '../../../core/utils/report_age.dart';
import '../../../views/report_item_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../drop_off/presentation/drop_off_instructions_screen.dart';
import '../../matching/data/matching_config_repository.dart';
import '../../matching/presentation/match_alert_screen.dart';
import '../../matching/services/matching_service.dart';
import '../viewmodel/home_view_model.dart';
import '../../analytics/data/firestore_feature_usage_tracker.dart';
import '../../analytics/domain/app_feature.dart';
import '../../analytics/domain/feature_usage_tracker.dart';
import '../../reports/presentation/report_lost_item_screen.dart';
import '../../../views/notification_screen.dart';
import 'widgets/home_action_card.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.authService = const AuthService(),
    this.lostReportRepository = const LostReportRepository(),
    this.foundItemRepository = const FoundItemRepository(),
    this.matchingConfigRepository = const MatchingConfigRepository(),
    this.createMatchingService,
    this.viewModel,
    this.dropOffBuilder,
    this.featureUsageTracker = const FirestoreFeatureUsageTracker(),
    this.foundItemScreenBuilder = _defaultFoundItemScreen,
  });

  final AuthService authService;
  final LostReportRepository lostReportRepository;
  final FoundItemRepository foundItemRepository;
  final MatchingConfigRepository matchingConfigRepository;
  final MatchingService Function(double threshold)? createMatchingService;
  // Injected ViewModels remain owned by the caller.
  final HomeViewModel? viewModel;
  // Receives the same Home configuration for S12's Back to Home action.
  final Widget Function(BuildContext context, WidgetBuilder homeBuilder)?
  dropOffBuilder;
  final FeatureUsageTracker featureUsageTracker;

  // Screen opened by "I found an item"; tests replace it to avoid Firebase.
  final WidgetBuilder foundItemScreenBuilder;

  static Widget _defaultFoundItemScreen(BuildContext context) =>
      const ReportItemScreen(reportType: 'found');

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel =
        widget.viewModel ??
        HomeViewModel(
          authService: widget.authService,
          lostReportRepository: widget.lostReportRepository,
          foundItemRepository: widget.foundItemRepository,
          matchingConfigRepository: widget.matchingConfigRepository,
          createMatchingService: widget.createMatchingService,
        );
    _viewModel.loadHome();
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  void _openMatchAlert() {
    final report = _viewModel.activeReport;
    final match = _viewModel.bestMatch;
    if (report == null || match == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            MatchAlertScreen(lostReport: report, matchResult: match),
      ),
    );
  }

  void _openDropOff() {
    final home = HomeScreen(
      authService: _viewModel.authService,
      lostReportRepository: _viewModel.lostReportRepository,
      foundItemRepository: _viewModel.foundItemRepository,
      matchingConfigRepository: _viewModel.matchingConfigRepository,
      createMatchingService: _viewModel.createMatchingService,
      dropOffBuilder: widget.dropOffBuilder,
    );
    Widget homeBuilder(BuildContext context) => home;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.dropOffBuilder?.call(context, homeBuilder) ??
            DropOffInstructionsScreen(homeBuilder: homeBuilder),
      ),
    );
  }

  Future<void> _signOut() async {
    final signedOut = await _viewModel.signOut();
    if (!mounted) return;
    if (signedOut) {
      final authService = _viewModel.authService;
      final lostReportRepository = _viewModel.lostReportRepository;
      final foundItemRepository = _viewModel.foundItemRepository;
      final matchingConfigRepository = _viewModel.matchingConfigRepository;
      final createMatchingService = _viewModel.createMatchingService;
      // Removes Home so the back button cannot reopen the signed-out session.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (context) => LoginScreen(
            authService: authService,
            homeBuilder: (context) => HomeScreen(
              authService: authService,
              lostReportRepository: lostReportRepository,
              foundItemRepository: foundItemRepository,
              matchingConfigRepository: matchingConfigRepository,
              createMatchingService: createMatchingService,
            ),
          ),
        ),
        (route) => false,
      );
    } else if (_viewModel.signOutError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_viewModel.signOutError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) => _buildHome(context),
    );
  }

  Widget _buildHome(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Yellow header from the Figma design
              Container(
                height: 92,
                color: const Color(0xFFFEFD05),
                padding: const EdgeInsets.only(left: 22, right: 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'uniandes',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Lost & Found',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Find or return an item',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _viewModel.isSigningOut ? null : _signOut,
                      tooltip: 'Sign out',
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 28,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'What do you need?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    HomeActionCard(
                      icon: Icons.search,
                      title: 'Search found items',
                      subtitle: 'Check if something similar has already been registered.',
                      large: true,
                      onTap: () => widget.featureUsageTracker.track(
                        AppFeature.searchFoundItems,
                      ),
                    ),
                    const SizedBox(height: 16),
                    HomeActionCard(
                      icon: Icons.report_outlined,
                      title: 'I lost an item',
                      subtitle: 'Report it and get notified if it is found.',
                      onTap: () {
                        widget.featureUsageTracker.track(
                          AppFeature.reportLostItem,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ReportLostItemScreen(
                              featureUsageTracker: widget.featureUsageTracker,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    HomeActionCard(
                      icon: Icons.add,
                      title: 'I found an item',
                      subtitle: 'Report it and see where to deliver it.',
                      highlighted: true,
                      onTap: () {
                        widget.featureUsageTracker.track(
                          AppFeature.reportFoundItem,
                        );
                        // Report screen with the GPS location of the item.
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: widget.foundItemScreenBuilder,
                          ),
                        );
                      },
                    ),
                    if (_viewModel.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 36),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Loading active report',
                            ),
                          ),
                        ),
                      ),
                    if (_viewModel.activeReport != null)
                      _buildActiveReportSection(_viewModel.activeReport!),
                    if (_viewModel.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _viewModel.errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999798),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2DEDE))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 61,
            child: BottomNavigationBar(
              currentIndex: 0,
              onTap: (index) {
                // Alerts tab: notifications sent by the backend (Sofia).
                if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                }
                // Temporary Sprint testing entry point for S12 (Emilio).
                if (index == 3) _openDropOff();
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: Colors.black,
              unselectedItemColor: const Color(0xFF999798),
              selectedFontSize: 10,
              unselectedFontSize: 10,
              iconSize: 22,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
