import 'dart:math';
import 'dart:ui';

final _random = Random();

/// Gera [playlistId] compatível com a PWA: timestamp base36 + sufixo aleatório.
String generatePlaylistId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final suffix = _random.nextInt(0xFFFFFF).toRadixString(36);
  return '$timestamp$suffix';
}

/// Nome default na criação: `lista dd/MM/yyyy HH:mm:ss`.
String defaultPlaylistName([DateTime? now]) {
  final date = now ?? DateTime.now();
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  final s = date.second.toString().padLeft(2, '0');
  return 'lista $d/$m/${date.year} $h:$min:$s';
}

/// Sufixo do nome da cópia local, por idioma suportado.
///
/// O primeiro é o default: um idioma fora da lista cai no português, como o
/// resto do domínio (ver [defaultPlaylistName]).
const Map<String, String> _conflictCopySuffixes = {
  'pt': ' (cópia local)',
  'en': ' (local copy)',
};

/// Nome da lista que guarda as edições locais perdidas num `409` (spec A.3).
///
/// Nasce no domínio, como [defaultPlaylistName]: sem `BuildContext` e sem ARB —
/// o nome vira **dado** gravado no Isar, não um rótulo re-traduzido a cada
/// build. O idioma vem da plataforma; [languageCode] existe para o teste (e
/// para quem já tem um `Locale` em mãos) fixar o resultado.
String conflictCopyName(String nome, [String? languageCode]) {
  final code = languageCode ?? PlatformDispatcher.instance.locale.languageCode;
  return '$nome${_conflictCopySuffixes[code] ?? _conflictCopySuffixes['pt']!}';
}

/// Inverso exato de [conflictCopyName] — o nome original dentro de [copyName].
///
/// A UI precisa das duas metades da frase «Edições locais de «X» guardadas em
/// «X (cópia local)»» e só carrega o nome da cópia. Qualquer sufixo conhecido
/// serve, não só o do idioma atual: a cópia pode ter sido criada antes de o
/// aparelho mudar de idioma. Sem sufixo reconhecido, [copyName] volta inteiro.
String conflictCopySourceName(String copyName) {
  for (final suffix in _conflictCopySuffixes.values) {
    if (copyName.endsWith(suffix)) {
      return copyName.substring(0, copyName.length - suffix.length);
    }
  }
  return copyName;
}
