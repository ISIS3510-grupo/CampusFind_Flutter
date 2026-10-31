class PersistedMatch {
  const PersistedMatch({
    required this.reportId,
    required this.foundItemId,
    required this.score,
  });

  factory PersistedMatch.fromFirestore(Map<String, dynamic> data) {
    final reportId = data['reportId'];
    final foundItemId = data['foundItemId'];
    final score = data['score'];
    if (reportId is! String ||
        reportId.isEmpty ||
        foundItemId is! String ||
        foundItemId.isEmpty ||
        score is! num ||
        !score.isFinite ||
        score < 0 ||
        score > 1) {
      throw const FormatException('Invalid persisted match');
    }
    return PersistedMatch(
      reportId: reportId,
      foundItemId: foundItemId,
      score: score.toDouble(),
    );
  }

  final String reportId;
  final String foundItemId;
  final double score;
}
