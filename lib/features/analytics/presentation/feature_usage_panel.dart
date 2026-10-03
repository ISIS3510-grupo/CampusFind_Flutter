import 'package:flutter/material.dart';

import 'package:campusfind_flutter/features/analytics/data/feature_usage_repository.dart';
import 'package:campusfind_flutter/features/analytics/domain/feature_usage_summary.dart';
import 'package:campusfind_flutter/features/analytics/presentation/feature_usage_controller.dart';

// BQ (Type 3, Jhostin): "Which app features are used most frequently by
// students?". Designed to be added to the staff Analytics dashboard.
class FeatureUsagePanel extends StatefulWidget {
  const FeatureUsagePanel({super.key, this.repository});

  // Injected in tests; the app reads analytics/featureUsage from Firestore.
  final FeatureUsageRepository? repository;

  @override
  State<FeatureUsagePanel> createState() => _FeatureUsagePanelState();
}

class _FeatureUsagePanelState extends State<FeatureUsagePanel> {
  static const _yellow = Color(0xFFFEFD05);
  static const _border = Color(0xFFE2DEDE);
  static const _grey = Color(0xFF666666);

  late final FeatureUsageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FeatureUsageController(
      widget.repository ?? FirestoreFeatureUsageRepository(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final summary = _controller.summary;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Most used features',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Which app features do students use the most?',
                style: TextStyle(fontSize: 14, color: _grey),
              ),
              const SizedBox(height: 20),
              if (_controller.loading)
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
                ),
              if (summary != null) ..._content(summary),
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _controller.loading ? null : _controller.load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Reload'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _content(FeatureUsageSummary summary) {
    final mostUsed = summary.mostUsed;
    return [
      const Text('Most used', style: TextStyle(fontSize: 14, color: _grey)),
      const SizedBox(height: 6),
      Text(
        mostUsed?.feature.label ?? 'No usage yet',
        key: const ValueKey('feature-usage-most-used'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
      Text(
        '${summary.eventCount} events'
        '${summary.computedAt == null ? '' : ' · updated ${_time(summary.computedAt!)}'}',
        style: const TextStyle(fontSize: 13, color: _grey),
      ),
      const Divider(height: 32, color: _border),
      for (final item in summary.ranking)
        Padding(
          key: ValueKey('feature-usage-${item.feature.id}'),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.feature.label,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  Text(
                    '${item.count}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${(summary.shareOf(item) * 100).round()} %',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, color: _grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: summary.shareOf(item),
                  minHeight: 8,
                  color: Colors.black,
                  backgroundColor: _yellow.withValues(alpha: 0.35),
                ),
              ),
              if ((summary.last7Days[item.feature] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${summary.last7Days[item.feature]} in the last 7 days',
                    style: const TextStyle(fontSize: 12, color: _grey),
                  ),
                ),
            ],
          ),
        ),
      const Divider(height: 32, color: _border),
      Text(
        'By platform: '
        '${summary.byPlatform.entries.map((e) => '${e.key} ${e.value}').join(' · ')}',
        style: const TextStyle(fontSize: 13, color: _grey),
      ),
    ];
  }
}
