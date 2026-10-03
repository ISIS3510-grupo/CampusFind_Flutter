import 'package:flutter/foundation.dart';

import '../domain/claim_repository.dart';

enum ClaimFormStatus { editing, sending, submitted, alreadyClaimed, failed }

class ClaimFormController extends ChangeNotifier {
  ClaimFormController({
    required this.repository,
    required this.reportId,
    required this.foundItemId,
  });

  static const minAnswerLength = 10;

  final ClaimRepository repository;
  final String reportId;
  final String foundItemId;

  ClaimFormStatus _status = ClaimFormStatus.editing;
  ClaimFormStatus get status => _status;

  static String? validateAnswer(String? value) {
    final answer = value?.trim() ?? '';
    if (answer.isEmpty) return 'Describe something only the owner would know.';
    if (answer.length < minAnswerLength) {
      return 'Add a bit more detail (at least $minAnswerLength characters).';
    }
    return null;
  }

  Future<void> submit(String answer) async {
    if (_status == ClaimFormStatus.sending) return;
    _setStatus(ClaimFormStatus.sending);
    try {
      final result = await repository.submit(
        ClaimDraft(
          reportId: reportId,
          foundItemId: foundItemId,
          ownershipAnswer: answer,
        ),
      );
      _setStatus(
        result == ClaimSubmitResult.submitted
            ? ClaimFormStatus.submitted
            : ClaimFormStatus.alreadyClaimed,
      );
    } catch (_) {
      _setStatus(ClaimFormStatus.failed);
    }
  }

  void _setStatus(ClaimFormStatus status) {
    _status = status;
    notifyListeners();
  }
}
