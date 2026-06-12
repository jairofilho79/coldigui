import 'dart:math';

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
