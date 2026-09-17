import '../entities/contribution_kind.dart';

/// Espelho das regras do servidor (spec §4.2). O servidor revalida tudo — isto
/// só evita uma ida à rede para receber um 400 previsível.
const int kMaxAttachmentBytes = 32 * 1024 * 1024;
const int kMaxAttachments = 5;
const int kMaxLinks = 5;
const int kMaxTitleLength = 120;
const int kMaxBodyLength = 4000;

const Set<String> kAllowedExtensions = {
  'pdf',
  'mp3',
  'jpg',
  'jpeg',
  'png',
  'txt',
  'chordpro',
};
const Set<String> kImageExtensions = {'jpg', 'jpeg', 'png'};
const Set<String> kAllowedLinkHosts = {
  'youtube.com',
  'www.youtube.com',
  'youtu.be',
  'drive.google.com',
  'docs.google.com',
};

enum AttachmentError { tooLarge, typeNotAllowed, tooMany }

String _extensionOf(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

/// `null` = anexo aceito. `bug` só aceita imagem (screenshot) — o resto das
/// extensões fica para os outros kinds.
AttachmentError? validateAttachment({
  required String name,
  required int size,
  required ContributionKind kind,
  required int currentCount,
}) {
  if (currentCount >= kMaxAttachments) return AttachmentError.tooMany;
  final ext = _extensionOf(name);
  final allowed = kind == ContributionKind.bug
      ? kImageExtensions
      : kAllowedExtensions;
  if (!allowed.contains(ext)) return AttachmentError.typeNotAllowed;
  if (size > kMaxAttachmentBytes) return AttachmentError.tooLarge;
  return null;
}

/// Só https e host da lista — evita anexar links arbitrários como "material".
bool isAllowedLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https') return false;
  return kAllowedLinkHosts.contains(uri.host);
}
