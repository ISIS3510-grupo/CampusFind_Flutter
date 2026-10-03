import 'package:campusfind_flutter/features/claims/domain/claim_repository.dart';
import 'package:campusfind_flutter/features/claims/presentation/claim_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClaimRepository implements ClaimRepository {
  _FakeClaimRepository({this.result = ClaimSubmitResult.submitted});

  final ClaimSubmitResult result;
  final drafts = <ClaimDraft>[];
  bool fail = false;

  @override
  Future<ClaimSubmitResult> submit(ClaimDraft draft) async {
    drafts.add(draft);
    if (fail) throw Exception('offline');
    return result;
  }
}

Future<void> _pumpForm(WidgetTester tester, ClaimRepository repository) {
  return tester.pumpWidget(
    MaterialApp(
      home: ClaimFormScreen(
        reportId: 'report-1',
        foundItemId: 'found-9',
        itemTitle: 'Black Calculator',
        repository: repository,
      ),
    ),
  );
}

final _answerField = find.byKey(const Key('ownershipAnswerField'));

void main() {
  test('claim id joins the report and the found item', () {
    const draft = ClaimDraft(
      reportId: 'report-1',
      foundItemId: 'found-9',
      ownershipAnswer: 'x',
    );
    expect(draft.claimId, 'report-1_found-9');
  });

  testWidgets('empty or short answers are not sent', (tester) async {
    final repository = _FakeClaimRepository();
    await _pumpForm(tester, repository);

    await tester.tap(find.text('Send claim'));
    await tester.pump();
    expect(
      find.text('Describe something only the owner would know.'),
      findsOneWidget,
    );

    await tester.enterText(_answerField, 'red');
    await tester.tap(find.text('Send claim'));
    await tester.pump();
    expect(find.textContaining('at least 10 characters'), findsOneWidget);
    expect(repository.drafts, isEmpty);
  });

  testWidgets('valid answer sends a claim for this match', (tester) async {
    final repository = _FakeClaimRepository();
    await _pumpForm(tester, repository);

    await tester.enterText(_answerField, 'Sticker of a cat on the back');
    await tester.tap(find.text('Send claim'));
    await tester.pumpAndSettle();

    expect(repository.drafts, hasLength(1));
    expect(repository.drafts.single.reportId, 'report-1');
    expect(repository.drafts.single.foundItemId, 'found-9');
    expect(
      repository.drafts.single.ownershipAnswer,
      'Sticker of a cat on the back',
    );
    expect(find.text('Claim sent'), findsOneWidget);
  });

  testWidgets('a repeated claim is reported as already sent', (tester) async {
    final repository = _FakeClaimRepository(
      result: ClaimSubmitResult.alreadyClaimed,
    );
    await _pumpForm(tester, repository);

    await tester.enterText(_answerField, 'Sticker of a cat on the back');
    await tester.tap(find.text('Send claim'));
    await tester.pumpAndSettle();

    expect(find.text('You already claimed this item'), findsOneWidget);
  });

  testWidgets('a failed send keeps the answer so the user can retry', (
    tester,
  ) async {
    final repository = _FakeClaimRepository()..fail = true;
    await _pumpForm(tester, repository);

    await tester.enterText(_answerField, 'Sticker of a cat on the back');
    await tester.tap(find.text('Send claim'));
    await tester.pumpAndSettle();

    expect(find.text('Could not send your claim. Try again.'), findsOneWidget);
    expect(find.text('Sticker of a cat on the back'), findsOneWidget);
    expect(find.text('Send claim'), findsOneWidget);
  });
}
