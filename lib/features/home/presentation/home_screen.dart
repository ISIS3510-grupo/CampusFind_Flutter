import 'package:flutter/material.dart';

import '../../../core/data/found_item_repository.dart';
import '../../../core/data/lost_report_repository.dart';
import '../../../core/models/lost_report.dart';
import '../../../core/utils/report_age.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../matching/data/matching_config_repository.dart';
import '../../matching/presentation/match_alert_screen.dart';
import '../../matching/services/matching_service.dart';
import '../viewmodel/home_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.authService = const AuthService(),
    this.lostReportRepository = const LostReportRepository(),
    this.foundItemRepository = const FoundItemRepository(),
    this.matchingConfigRepository = const MatchingConfigRepository(),
    this.createMatchingService,
    this.viewModel,
  });

  final AuthService authService;
  final LostReportRepository lostReportRepository;
  final FoundItemRepository foundItemRepository;
  final MatchingConfigRepository matchingConfigRepository;
  final MatchingService Function(double threshold)? createMatchingService;
  // Injected ViewModels remain owned by the caller.
  final HomeViewModel? viewModel;

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
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFE2DEDE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          height: 122,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(
                                    Icons.search,
                                    size: 31,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 23),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Search found items',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Check if something similar has already been registered.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w300,
                                          color: Color(0xFF999798),
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: const Color(0xFFFEFD05),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(10),
                        child: const SizedBox(
                          height: 104,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 20, 20, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Icon(
                                    Icons.add,
                                    size: 28,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'I found an item',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Report it and see where to deliver it.',
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
                              ],
                            ),
                          ),
                        ),
                      ),
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
              onTap: (_) {},
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

  Widget _buildActiveReportSection(LostReport report) {
    final location = report.locationName.trim();
    final age = reportAge(report.reportedAt);
    final subtitle = location.isEmpty ? age : 'Lost in $location · $age';
    final imageUrl = report.imageUrl?.trim();
    const placeholder = Center(
      child: Icon(Icons.image, size: 26, color: Color(0xFF999798)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 36),
        const Text(
          'My active report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 13),
        Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2DEDE)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 92,
                  height: 96,
                  color: const Color(0xFFE2DEDE),
                  child: imageUrl == null || imageUrl.isEmpty
                      ? placeholder
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              placeholder,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF999798),
                        height: 1.2,
                      ),
                    ),
                    if (_viewModel.bestMatch != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        button: true,
                        child: Material(
                          color: const Color(0xFFFEFD05),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Color(0xFFE2DEDE)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: _openMatchAlert,
                            borderRadius: BorderRadius.circular(10),
                            child: const SizedBox(
                              width: 120,
                              height: 28,
                              child: Center(
                                child: Text(
                                  'Possible match',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
