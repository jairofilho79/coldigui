/// Valida URL HTTPS de YouTube (`youtube.com`, subdomínios, `youtu.be`).
abstract final class YoutubeUrl {
  static bool isValid(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return host == 'youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com');
  }

  static Uri? tryParse(String? raw) {
    if (!isValid(raw)) return null;
    return Uri.parse(raw!.trim());
  }
}
