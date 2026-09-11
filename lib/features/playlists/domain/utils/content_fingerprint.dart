import '../entities/playlist_entry.dart';

/// Fingerprint de **conteúdo** de uma playlist — usado só para dedupe de
/// import (spec C.2), nunca persistido.
///
/// `kind:id` por entrada, na ordem, separado por vírgula (ex.:
/// `'pdf:a,audio:b'`). Comparação é de string, sem hash: ordem e tipo de cada
/// entrada importam, o nome da lista não entra na conta.
String contentFingerprint(List<PlaylistEntry> entries) =>
    entries.map((e) => '${e.kind.name}:${e.id}').join(',');
