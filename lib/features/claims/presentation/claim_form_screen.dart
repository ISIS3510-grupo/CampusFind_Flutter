import 'package:flutter/material.dart';

import '../data/firestore_claim_repository.dart';
import '../domain/claim_repository.dart';
import 'claim_form_controller.dart';

class ClaimFormScreen extends StatefulWidget {
  const ClaimFormScreen({
    super.key,
    required this.reportId,
    required this.foundItemId,
    required this.itemTitle,
    this.repository,
  });

  final String reportId;
  final String foundItemId;
  final String itemTitle;
  final ClaimRepository? repository;

  @override
  State<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

class _ClaimFormScreenState extends State<ClaimFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _answer = TextEditingController();
  late final ClaimFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClaimFormController(
      repository: widget.repository ?? FirestoreClaimRepository(),
      reportId: widget.reportId,
      foundItemId: widget.foundItemId,
    )..addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onStatusChanged)
      ..dispose();
    _answer.dispose();
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted) return;
    setState(() {});
    final message = switch (_controller.status) {
      ClaimFormStatus.failed => 'Could not send your claim. Try again.',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _controller.submit(_answer.text);
  }

  @override
  Widget build(BuildContext context) {
    final status = _controller.status;
    final done =
        status == ClaimFormStatus.submitted ||
        status == ClaimFormStatus.alreadyClaimed;

    return Scaffold(
      appBar: AppBar(title: const Text('Claim this item')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: done ? _buildDone(status) : _buildForm(status),
        ),
      ),
    );
  }

  Widget _buildForm(ClaimFormStatus status) {
    final sending = status == ClaimFormStatus.sending;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.itemTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tell staff something only the owner would know: a mark, sticker, '
            'scratch, what is inside, the lock screen... Your answer is private '
            'and is only compared with the details the finder gave.',
            style: TextStyle(fontSize: 13, color: Color(0xFF999798)),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('ownershipAnswerField'),
            controller: _answer,
            enabled: !sending,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Private ownership detail',
              border: OutlineInputBorder(),
            ),
            validator: ClaimFormController.validateAnswer,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: sending ? null : _submit,
              child: sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send claim'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(ClaimFormStatus status) {
    final alreadyClaimed = status == ClaimFormStatus.alreadyClaimed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 64),
        const SizedBox(height: 16),
        Text(
          alreadyClaimed ? 'You already claimed this item' : 'Claim sent',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Staff will review your answer. Your claim stays pending until then.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF999798)),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
