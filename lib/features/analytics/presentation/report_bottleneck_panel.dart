import 'package:flutter/material.dart';

import '../analytics_dependencies.dart';
import '../viewmodel/report_bottleneck_view_model.dart';

class ReportBottleneckPanel extends StatefulWidget {
  const ReportBottleneckPanel({super.key, this.viewModel});

  // The caller owns an injected ViewModel; the panel owns its default instance.
  final ReportBottleneckViewModel? viewModel;

  @override
  State<ReportBottleneckPanel> createState() => _ReportBottleneckPanelState();
}

class _ReportBottleneckPanelState extends State<ReportBottleneckPanel> {
  static const _labels = {
    'reported': 'Reported',
    'found': 'Found',
    'ready_for_pickup': 'Ready for pickup',
    'claimed': 'Claimed',
  };

  late ReportBottleneckViewModel _viewModel;
  late bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _initializeViewModel();
  }

  void _initializeViewModel() {
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? createReportBottleneckViewModel();
    _viewModel.load();
  }

  @override
  void didUpdateWidget(covariant ReportBottleneckPanel oldWidget) {
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
  Widget build(BuildContext context) {
    return ListenableBuilder(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Report bottleneck',
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
                      semanticsLabel: 'Loading report analytics',
                    ),
                  ),
                ),
              if (summary != null) ...[
                for (final stage in _labels.entries)
                  Padding(
                    key: ValueKey('bottleneck-count-${stage.key}'),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            stage.value,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${summary.counts[stage.key]}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 32, color: Color(0xFFE2DEDE)),
                const Text(
                  'Most common bottleneck',
                  style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.hasStuckReports
                      ? summary.mostStuckStages
                            .map((stage) => _labels[stage]!)
                            .join(', ')
                      : 'No stuck reports',
                  key: const ValueKey('bottleneck-highest-stage'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _viewModel.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                          semanticsLabel: 'Refreshing analytics',
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
  }
}
