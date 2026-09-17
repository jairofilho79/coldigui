import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/contribution_attachment.dart';
import '../../domain/entities/contribution_kind.dart';
import '../../domain/validators/attachment_rules.dart';
import '../utils/pick_files.dart';

/// «Anexos» (spec §6.2 item 8): botão de anexar (imagens só para bug), texto
/// do limite e a lista dos já anexados.
class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({
    required this.kind,
    required this.attachments,
    required this.pickFiles,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final ContributionKind kind;
  final List<ContributionAttachment> attachments;
  final PickFiles pickFiles;

  /// Devolve o erro de validação, ou `null` se o anexo foi aceito.
  final AttachmentError? Function(ContributionAttachment) onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.contributeAttachments,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => _addFiles(context, l10n),
          icon: const Icon(Icons.attach_file, size: 18),
          label: Text(l10n.contributeAddFile),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.contributeAttachmentTooLarge,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < attachments.length; i++)
                Chip(
                  label: Text(attachments[i].name),
                  onDeleted: () => onRemove(i),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _addFiles(BuildContext context, AppLocalizations l10n) async {
    final allowed = kind == ContributionKind.bug
        ? kImageExtensions
        : kAllowedExtensions;
    final files = await pickFiles(allowedExtensions: allowed);
    for (final file in files) {
      final Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } on Object catch (e) {
        debugPrint('[contributions] leitura de "${file.name}" falhou: $e');
        continue;
      }
      final error = onAdd(
        ContributionAttachment(
          name: file.name,
          size: file.lengthSync() ?? bytes.length,
          bytes: bytes,
        ),
      );
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_attachmentErrorMessage(l10n, error))),
        );
      }
    }
  }

  static String _attachmentErrorMessage(
    AppLocalizations l10n,
    AttachmentError error,
  ) => switch (error) {
    AttachmentError.tooLarge => l10n.contributeAttachmentTooLarge,
    AttachmentError.typeNotAllowed => l10n.contributeAttachmentTypeNotAllowed,
    AttachmentError.tooMany => l10n.contributeAttachmentTooMany,
  };
}
