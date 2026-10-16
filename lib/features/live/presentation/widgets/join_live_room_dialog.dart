import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/tutorial/presentation/providers/tutorial_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/live_room_link.dart';

/// Diálogo para colar o link (ou só o código) de uma sala ao vivo — o par do
/// «Importar lista» para quem recebeu o link fora do app. Devolve o código
/// da sala, ou `null` se cancelou.
Future<String?> showJoinLiveRoomDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _JoinLiveRoomDialog(),
  );
}

class _JoinLiveRoomDialog extends StatefulWidget {
  const _JoinLiveRoomDialog();

  @override
  State<_JoinLiveRoomDialog> createState() =>
      _JoinLiveRoomDialogState();
}

class _JoinLiveRoomDialogState extends State<_JoinLiveRoomDialog> {
  final _portalController = SpotlightGuidePortalController();
  late final TextEditingController _controller;
  TutorialController? _tutorialController;
  var _invalidInput = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tutorialController == null) {
      try {
        _tutorialController = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(tutorialControllerProvider);
        _tutorialController?.pushPortalController(_portalController);
      } catch (_) {
        _tutorialController = null;
      }
    }
  }

  @override
  void dispose() {
    try {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      _tutorialController?.popPortalController(_portalController);
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = parseLiveRoomCodeFromUserInput(_controller.text);
    if (code == null) {
      setState(() => _invalidInput = true);
      return;
    }
    Navigator.of(context).pop(code);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    setState(() => _invalidInput = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SpotlightGuidePortal(
      controller: _portalController,
      autoStart: false,
      missingTargetBehavior: SpotlightGuideMissingTargetBehavior.wait,
      barrier: const SpotlightGuideBarrierStyle(
        color: Color(0x99000000),
        blurSigma: 0,
      ),
      barrierDismissBehavior: SpotlightGuideDismissBehavior.anytime,
      onBarrierTap: (c) => _tutorialController?.hide(),
      onFinish: () => _tutorialController?.resetTutorialState(),
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(l10n.liveJoinRoomTitle)),
            SpotlightGuideTarget(
              id: 'join-live-info',
              child: IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Como ingressar',
                onPressed: () => _tutorialController
                    ?.startJoinLiveRoomTutorial(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpotlightGuideTarget(
              id: 'join-live-input',
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.liveJoinRoomInputLabel,
                  errorText: _invalidInput ? l10n.liveJoinRoomInvalid : null,
                ),
                onChanged: (_) {
                  if (_invalidInput) setState(() => _invalidInput = false);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: SpotlightGuideTarget(
                id: 'join-live-paste',
                child: TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  label: Text(l10n.playlistImportPaste),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.playlistSaveCancel),
          ),
          SpotlightGuideTarget(
            id: 'join-live-confirm',
            child: TextButton(
              onPressed: _submit,
              child: Text(l10n.liveJoinRoomConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
