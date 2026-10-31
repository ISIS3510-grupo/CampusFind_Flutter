import 'package:flutter/material.dart';

import 'package:campusfind_flutter/features/analytics/domain/offline_sync_summary.dart';
import 'package:campusfind_flutter/features/analytics/viewmodel/offline_sync_time_view_model.dart';

// Staff dashboard card: how long the app takes to send the reports saved
// offline after the connection comes back.
class OfflineSyncTimePanel extends StatefulWidget {
  const OfflineSyncTimePanel({super.key, this.viewModel});

  // The caller owns an injected ViewModel; the panel owns its default one.
  final OfflineSyncTimeViewModel? viewModel;

  @override
  State<OfflineSyncTimePanel> createState() => _OfflineSyncTimePanelState();
}

class _OfflineSyncTimePanelState extends State<OfflineSyncTimePanel> {
  late OfflineSyncTimeViewModel _viewModel;
  late bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();
  }

  void _initializeViewModel() {
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? OfflineSyncTimeViewModel();
    _viewModel.load();
  }

  @override
  void didUpdateWidget(covariant OfflineSyncTimePanel oldWidget) {
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
              'Sync time after offline',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            if (_viewModel.isLoading && summary == null)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                    semanticsLabel: 'Loading offline sync analytics',
                  ),
                ),
              ),
            if (summary != null && !summary.hasData)
              const Text('No offline recoveries measured yet'),
            if (summary != null && summary.hasData) ..._details(summary),
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
              onPressed: _viewModel.isLoading ? null : _viewModel.load,
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
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Refresh analytics'),
            ),
          ],
        ),
      );
    },
  );

  List<Widget> _details(OfflineSyncSummary summary) => [
    const Text(
      'Average sync time',
      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
    ),
    const SizedBox(height: 6),
    Text(
      _seconds(summary.averageMs),
      key: const ValueKey('offline-sync-average'),
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
    ),
    const Divider(height: 32, color: Color(0xFFE2DEDE)),
    _row('Median', _seconds(summary.medianMs)),
    _row('95th percentile', _seconds(summary.p95Ms)),
    _row('Time per report', '${summary.msPerReport.toStringAsFixed(0)} ms'),
    _row(
      'Trend',
      summary.sampleCount < 2 ? 'Not enough data' : _trend(summary),
    ),
    const SizedBox(height: 12),
    Text(
      'Based on ${summary.sampleCount} '
      '${summary.sampleCount == 1 ? 'recovery' : 'recoveries'}',
      style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
    ),
  ];

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  static String _seconds(double milliseconds) =>
      '${(milliseconds / 1000).toStringAsFixed(2)} s';

  static String _trend(OfflineSyncSummary summary) {
    final slope = summary.trendMsPerSample;
    final label = slope > 0
        ? 'Slower'
        : slope < 0
        ? 'Faster'
        : 'Stable';
    return '$label (${slope >= 0 ? '+' : ''}${slope.toStringAsFixed(0)} ms/sync)';
  }
}
