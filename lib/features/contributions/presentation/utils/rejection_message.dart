import '../../../../l10n/app_localizations.dart';

/// Traduz o `error` cru devolvido pelo coldigom-api num `400`/`413` (spec
/// §4.3) para uma mensagem de gente — sem isto a tela mostrava o código de
/// fio (`file_too_large`) direto, que não diz nada pra quem enviou.
///
/// Código desconhecido cai no genérico (`contributeErrorRejected`) com o
/// próprio código, em vez de travar numa mensagem errada.
String rejectionMessage(AppLocalizations l10n, String error, String? file) {
  final message = switch (error) {
    'file_too_large' => l10n.contributeAttachmentTooLarge,
    'file_type_not_allowed' ||
    'file_type_mismatch' => l10n.contributeAttachmentTypeNotAllowed,
    'too_many_files' => l10n.contributeAttachmentTooMany,
    'link_host_not_allowed' => l10n.contributeLinkNotAllowed,
    'too_many_links' => l10n.contributeTooManyLinks,
    'request_too_large' ||
    'payload_too_large' => l10n.contributeAttachmentTotalTooLarge,
    'device_required' => l10n.contributeSameDeviceQuestion,
    _ => l10n.contributeErrorRejected(error),
  };
  return file == null ? message : '$message ($file)';
}
