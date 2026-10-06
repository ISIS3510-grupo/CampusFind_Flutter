import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../data/office_location_repository.dart';
import '../domain/office_location.dart';
import '../services/maps_launcher_service.dart';
import '../viewmodel/drop_off_instructions_view_model.dart';

// Open after a successful found-item submission; this screen never submits a report.
class DropOffInstructionsScreen extends StatefulWidget {
  const DropOffInstructionsScreen({
    super.key,
    this.officeId = 'ml',
    this.viewModel,
    this.homeBuilder,
    this.mapsLauncher = const MapsLauncherService(),
  });

  final String officeId;
  // The caller retains ownership of an injected ViewModel.
  final DropOffInstructionsViewModel? viewModel;
  final WidgetBuilder? homeBuilder;
  final MapsLauncherService mapsLauncher;

  @override
  State<DropOffInstructionsScreen> createState() =>
      _DropOffInstructionsScreenState();
}

class _DropOffInstructionsScreenState extends State<DropOffInstructionsScreen> {
  late DropOffInstructionsViewModel _viewModel;
  late bool _ownsViewModel;
  bool _openingMaps = false;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();
  }

  void _initializeViewModel() {
    _ownsViewModel = widget.viewModel == null;
    _viewModel =
        widget.viewModel ??
        DropOffInstructionsViewModel(
          repository: OfficeLocationRepository(officeId: widget.officeId),
        );
    _viewModel.load();
  }

  @override
  void didUpdateWidget(covariant DropOffInstructionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel ||
        (widget.viewModel == null && oldWidget.officeId != widget.officeId)) {
      if (_ownsViewModel) _viewModel.dispose();
      _initializeViewModel();
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  void _backToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: widget.homeBuilder ?? (context) => const HomeScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _openMaps(OfficeLocation office) async {
    if (_openingMaps || !office.hasCoordinates) return;
    setState(() => _openingMaps = true);
    var opened = false;
    try {
      opened = await widget.mapsLauncher.openDirections(
        latitude: office.latitude!,
        longitude: office.longitude!,
      );
    } catch (_) {
      // An injected launcher may also throw; keep the screen usable.
    }
    if (!mounted) return;
    setState(() => _openingMaps = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, child) {
            final office = _viewModel.officeLocation;
            return CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Text(
                                'Drop-off instructions',
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              tooltip: 'Back',
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Found item report registered successfully.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_viewModel.isLoading)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                  semanticsLabel: 'Loading office information',
                                ),
                              ),
                            ),
                          ),
                        if (office != null) _officeCard(office),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed:
                              office != null &&
                                  office.hasCoordinates &&
                                  !_openingMaps
                              ? () => _openMaps(office)
                              : null,
                          icon: const Icon(Icons.map_outlined, size: 20),
                          label: const Text('Open in Maps'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Inside the building',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Office 500, in front of the Davivienda ATM',
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Opening hours',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Monday to Friday, 8:30 a.m. - 5:30 p.m.'),
                        if (_viewModel.errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE2DEDE),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _viewModel.errorMessage!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _viewModel.load,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 28),
                        const Text(
                          'Before you leave',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _instruction(
                          1,
                          'Bring the found item to the Lost & Found office.',
                        ),
                        const SizedBox(height: 12),
                        _instruction(
                          2,
                          'Tell staff that the item was already reported in CampusFind.',
                        ),
                        const SizedBox(height: 12),
                        _instruction(
                          3,
                          'Staff will register the physical drop-off.',
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Reporting online does not complete the handoff. Staff must receive the physical item.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _backToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            'Back to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _officeCard(OfficeLocation office) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFD05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent, size: 28, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lost & Found Office',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  office.name,
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instruction(int number, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2DEDE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number.',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
