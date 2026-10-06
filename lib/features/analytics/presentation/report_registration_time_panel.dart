import 'package:flutter/material.dart';

import '../analytics_dependencies.dart';
import '../viewmodel/report_registration_time_view_model.dart';

class ReportRegistrationTimePanel extends StatefulWidget {
  const ReportRegistrationTimePanel({super.key, this.viewModel});

  // The caller owns an injected ViewModel; the panel owns its default instance.
  final ReportRegistrationTimeViewModel? viewModel;

  @override
  State<ReportRegistrationTimePanel> createState() =>
      _ReportRegistrationTimePanelState();
}

class _ReportRegistrationTimePanelState
    extends State<ReportRegistrationTimePanel> {
  late ReportRegistrationTimeViewModel _viewModel;
  late bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();
  }

  void _initializeViewModel() {
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? createReportRegistrationTimeViewModel();
    _viewModel.load();
  }

  @override
  void didUpdateWidget(covariant ReportRegistrationTimePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      if (_ownsViewModel) _viewModel.dispose();
      _initializeViewModel();
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _viewModel,
    builder: (context, child) {
      final summary = _viewModel.summary;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2DEDE)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Report registration time',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            if (_viewModel.isLoading)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                    semanticsLabel: 'Loading registration time analytics',
                  ),
                ),
              ),
            if (summary != null && !summary.hasData)
              const Text('No registration measurements yet'),
            if (summary != null && summary.hasData) ...[
              const Text(
                'Average registration time',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 6),
              Text(
                _seconds(summary.averageMs!),
                key: const ValueKey('registration-average'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 32, color: Color(0xFFE2DEDE)),
              _group('Lost reports', summary.lostAverageMs, summary.lostCount),
              const SizedBox(height: 20),
              _group(
                'Found reports',
                summary.foundAverageMs,
                summary.foundCount,
              ),
              const SizedBox(height: 20),
              Text(
                'Based on ${summary.sampleCount} successful '
                '${summary.sampleCount == 1 ? 'registration' : 'registrations'}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ],
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _viewModel.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _viewModel.isLoading || _viewModel.isRefreshing
                  ? null
                  : _viewModel.refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _viewModel.isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                        semanticsLabel:
                            'Refreshing registration time analytics',
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh analytics'),
            ),
          ],
        ),
      );
    },
  );

  static String _seconds(double milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(2)} s';

  Widget _group(String label, double? averageMs, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Text(
        averageMs == null ? 'No measurements yet' : _seconds(averageMs),
        style: const TextStyle(fontSize: 18),
      ),
      Text(
        '$count ${count == 1 ? 'sample' : 'samples'}',
        style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
      ),
    ],
  );
}
