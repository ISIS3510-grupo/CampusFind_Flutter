// Repository pattern: the claim form only knows how to submit a claim; the
// Firestore layout (public claim + private answer) stays in the data layer.
abstract class ClaimRepository {
  Future<ClaimSubmitResult> submit(ClaimDraft draft);
}

class ClaimDraft {
  const ClaimDraft({
    required this.reportId,
    required this.foundItemId,
    required this.ownershipAnswer,
  });

  final String reportId;
  final String foundItemId;
  final String ownershipAnswer;

  // One claim per report and found item, so a second tap cannot duplicate it.
  String get claimId => '${reportId}_$foundItemId';
}

enum ClaimSubmitResult { submitted, alreadyClaimed }
