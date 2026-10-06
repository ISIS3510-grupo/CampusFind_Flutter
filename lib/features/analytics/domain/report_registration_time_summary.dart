class ReportRegistrationTimeSummary {
  ReportRegistrationTimeSummary({
    required this.sampleCount,
    required this.averageMs,
    required this.lostCount,
    required this.lostAverageMs,
    required this.foundCount,
    required this.foundAverageMs,
  }) {
    if (sampleCount != lostCount + foundCount) {
      throw const FormatException(
        'Registration sample counts are inconsistent.',
      );
    }
    _validateAverage(sampleCount, averageMs);
    _validateAverage(lostCount, lostAverageMs);
    _validateAverage(foundCount, foundAverageMs);
  }

  final int sampleCount;
  final double? averageMs;
  final int lostCount;
  final double? lostAverageMs;
  final int foundCount;
  final double? foundAverageMs;

  bool get hasData => sampleCount > 0;

  factory ReportRegistrationTimeSummary.fromMap(Map<String, dynamic> data) {
    int count(String key) {
      final value = data[key];
      if (value is! int) throw FormatException('Invalid $key');
      return value;
    }

    double? average(String key) {
      if (!data.containsKey(key)) throw FormatException('Missing $key');
      final value = data[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0) {
        throw FormatException('Invalid $key');
      }
      return value.toDouble();
    }

    return ReportRegistrationTimeSummary(
      sampleCount: count('sampleCount'),
      averageMs: average('averageMs'),
      lostCount: count('lostCount'),
      lostAverageMs: average('lostAverageMs'),
      foundCount: count('foundCount'),
      foundAverageMs: average('foundAverageMs'),
    );
  }

  Map<String, dynamic> toMap() => {
    'sampleCount': sampleCount,
    'averageMs': averageMs,
    'lostCount': lostCount,
    'lostAverageMs': lostAverageMs,
    'foundCount': foundCount,
    'foundAverageMs': foundAverageMs,
  };

  static void _validateAverage(int count, double? average) {
    if (count < 0 ||
        (count == 0 && average != null) ||
        (count > 0 && (average == null || !average.isFinite || average < 0))) {
      throw const FormatException('Invalid registration count or average.');
    }
  }
}
