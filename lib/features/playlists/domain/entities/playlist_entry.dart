import '../../../../core/utils/material_id_kind.dart';

export '../../../../core/utils/material_id_kind.dart' show MaterialKind;

/// Uma entrada da ordem única de uma playlist: um id **mais** o seu tipo.
///
/// O tipo deixa de ser inferido pela extensão em toda leitura (o remendo
/// `declaredAudioIds` da fatia 1) e passa a ser gravado junto com o id, no Isar
/// (`Playlist.itemKinds`) e no wire (`items: [{id, kind}]`). A extensão continua
/// sendo a heurística que **classifica** um id que chega sem tipo — nunca a que
/// desfaz um tipo já declarado (A8).
final class PlaylistEntry {
  const PlaylistEntry({required this.id, required this.kind});

  /// Classifica [id] pela extensão. Um id vindo de `pdfIds` legado **nunca**
  /// vira [MaterialKind.audio] por engano: [materialIdKindOf] só devolve
  /// `audio` para as extensões de [kAudioMaterialExtensions].
  factory PlaylistEntry.classified(String id) =>
      PlaylistEntry(id: id, kind: materialIdKindOf(id));

  /// Declara [id] como áudio, independentemente da extensão — é o veredito de
  /// quem gravou a lista (campo `type` do Worker), não o do `r2_key`.
  factory PlaylistEntry.audio(String id) =>
      PlaylistEntry(id: id, kind: MaterialKind.audio);

  /// Lê uma entrada do wire.
  ///
  /// Aceita o objeto v2 (`{'id': …, 'kind': …}`) e a `String` solta do rascunho
  /// v2 da fatia 1 (que só existiu em Isar local). Para a `String`,
  /// [declaredAudio] é o conjunto `audioIds` do mesmo payload — o veredito de
  /// áudio de quem gravou.
  ///
  /// **O `kind` do wire não é preservado literalmente**: um nome fora do enum
  /// (`'video'`) vira [MaterialKind.unknown], e todo `kind` — inclusive o
  /// `unknown` recém-criado — passa por [resolveWireKind], que refina
  /// `pdf`/`unknown` pela extensão do id. Ou seja, `{'kind': 'video'}` num id
  /// `.chord` devolve [MaterialKind.chord], **não** `unknown`. Só
  /// [MaterialKind.audio] atravessa intocado.
  factory PlaylistEntry.fromJson(
    Object raw, {
    Set<String> declaredAudio = const {},
  }) {
    if (raw is String) return _fromLooseId(raw, declaredAudio);
    if (raw is Map) {
      final id = raw['id'];
      if (id is! String || id.isEmpty) {
        throw FormatException('PlaylistEntry sem id: $raw');
      }
      final rawKind = raw['kind'];
      if (rawKind is! String) return _fromLooseId(id, declaredAudio);
      return PlaylistEntry(
        id: id,
        kind: resolveWireKind(materialKindFromName(rawKind), id),
      );
    }
    throw FormatException('PlaylistEntry inválida: $raw');
  }

  static PlaylistEntry _fromLooseId(String id, Set<String> declaredAudio) {
    if (id.isEmpty) throw FormatException('PlaylistEntry sem id: $id');
    return declaredAudio.contains(id)
        ? PlaylistEntry.audio(id)
        : PlaylistEntry.classified(id);
  }

  /// Id do material (mesmo espaço de ids do carousel/manifest).
  final String id;

  /// Tipo do material — fonte da verdade da face em que a entrada aparece.
  final MaterialKind kind;

  /// `true` se a entrada pertence à face de áudio.
  ///
  /// Face de partituras = tudo que não é áudio (PDF, cifra, gesto, YouTube e
  /// ids legados `unknown`), para que nenhuma família suma das duas faces (A7).
  bool get isAudio => kind == MaterialKind.audio;

  Map<String, Object?> toJson() => {'id': id, 'kind': kind.name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistEntry && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'PlaylistEntry($id, ${kind.name})';
}

/// Normaliza o `kind` que veio do wire/Isar contra a extensão de [id].
///
/// - [MaterialKind.audio] é intocável: é o veredito de quem gravou (A8).
/// - `pdf`/`unknown` são genéricos — quando a extensão diz `chord` ou `gesture`
///   (mais específico), a extensão ganha. Um Worker que derive `items` das duas
///   listas v1 marca toda cifra como `pdf`; esta regra a recupera.
/// - Os demais (`chord`, `gesture`, `youtube`) ficam como vieram.
///
/// **`unknown` não é preservado literalmente.** Ele é tratado como "o wire não
/// sabe", não como "o material é de tipo desconhecido": num id `.chord` ou
/// `.gest` a extensão o substitui. É por aí que um `kind` inválido do wire
/// (`'video'`, que [materialKindFromName] já reduziu a `unknown`) acaba
/// devolvido como `chord`/`gesture` em vez de `unknown` — quem precisar do
/// valor cru do wire tem que lê-lo antes de chamar esta função.
MaterialKind resolveWireKind(MaterialKind wireKind, String id) {
  if (wireKind != MaterialKind.pdf && wireKind != MaterialKind.unknown) {
    return wireKind;
  }
  final byExtension = materialIdKindOf(id);
  if (byExtension == MaterialKind.chord ||
      byExtension == MaterialKind.gesture) {
    return byExtension;
  }
  return wireKind;
}

/// Converte o `MaterialKind.name` gravado no Isar/wire de volta no enum.
///
/// Nome ausente ou fora do enum vira [MaterialKind.unknown] — nunca lança, para
/// que um payload de uma versão futura não derrube a leitura da lista.
MaterialKind materialKindFromName(String? name) {
  if (name == null) return MaterialKind.unknown;
  for (final kind in MaterialKind.values) {
    if (kind.name == name) return kind;
  }
  return MaterialKind.unknown;
}
