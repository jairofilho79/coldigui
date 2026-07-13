import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_remote_datasource.dart';
import '../../domain/username_rules.dart';
import '../providers/auth_state_provider.dart';

/// Modal para cadastrar username único.
Future<bool> showCreateUsernameDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _CreateUsernameDialog(),
  );
  return result == true;
}

class _CreateUsernameDialog extends ConsumerStatefulWidget {
  const _CreateUsernameDialog();

  @override
  ConsumerState<_CreateUsernameDialog> createState() =>
      _CreateUsernameDialogState();
}

class _CreateUsernameDialogState extends ConsumerState<_CreateUsernameDialog> {
  final _controller = TextEditingController();
  var _submitting = false;
  String? _fieldError;
  String? _serverError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _mapServerError(AppLocalizations l10n, String code) {
    return switch (code) {
      'username taken' => l10n.usernameErrorTaken,
      'username already set' => l10n.usernameErrorAlreadySet,
      'invalid username' || 'username required' => l10n.usernameErrorInvalid,
      _ => l10n.usernameErrorGeneric,
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _controller.text;
    final validation = UsernameRules.validate(raw);
    if (validation != null) {
      setState(() {
        _fieldError = l10n.usernameErrorInvalid;
        _serverError = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _fieldError = null;
      _serverError = null;
    });

    try {
      await ref
          .read(authStateProvider.notifier)
          .setUsername(UsernameRules.normalize(raw));
      if (mounted) Navigator.of(context).pop(true);
    } on UsernameException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverError = _mapServerError(l10n, e.code);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverError = l10n.usernameErrorGeneric;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.usernameCreateTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.usernameCreateMessage),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.usernameFieldLabel,
                hintText: l10n.usernameFieldHint,
                errorText: _fieldError,
              ),
              onChanged: (_) {
                if (_fieldError != null || _serverError != null) {
                  setState(() {
                    _fieldError = null;
                    _serverError = null;
                  });
                }
              },
              onSubmitted: (_) {
                if (!_submitting) _submit();
              },
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 8),
              Text(
                _serverError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.usernameCreateCancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.usernameCreateConfirm),
        ),
      ],
    );
  }
}
