/// Sanitiza nomes de arquivo PDF para share/save (UC-04 OpSec).
abstract final class PdfFileNameSanitizer {
  static const String defaultName = 'louvor.pdf';

  /// Remove separadores de path e caracteres de controle; garante sufixo `.pdf`.
  static String sanitize(String? rawName) {
    var name = (rawName ?? '').trim();
    if (name.isEmpty) {
      return defaultName;
    }

    name = _basename(name);
    name = name.replaceAll(RegExp(r'[/\\<>:"|?*]'), '_');
    name = name.replaceAll('..', '_');

    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }

    return name.isEmpty ? defaultName : name;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll(r'\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }
}
