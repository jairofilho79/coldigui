import '../../../../core/utils/material_id_kind.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import 'louvor.dart';
import 'youtube_material.dart';

/// Qualquer material abrível de um louvor — PDF, cifra, gestos, áudio ou
/// YouTube.
///
/// Fachada `sealed` sobre as entidades que já existem: nenhuma delas muda de
/// forma (Isar/JSON intactos), cada uma ganha um invólucro aqui. Isso dá ao app
/// um único vocabulário (`kind`) e um único ponto de abertura
/// (`openMaterialProvider`), sem ainda unificar as listas de [LouvorGroup].
///
/// `sealed` obriga o `switch` do opener a cobrir os cinco casos — um material
/// novo quebra a compilação em vez de cair num `else` silencioso.
sealed class CatalogMaterial {
  const CatalogMaterial();

  /// Id do material no espaço de ids da sua família (pdfId/chordId/audioId…).
  String get id;

  /// Tipo do material — vocabulário único do app.
  MaterialKind get kind;

  /// Louvor lógico ao qual o material pertence.
  String get groupId;

  /// Label do material exibida na UI (ex.: `Partitura`, `Cifra I`, `Áudio`).
  String get categoria;

  /// Id do `material_kind` Coldigom; `null` quando o acervo não o conhece.
  String? get materialKindId;
}

/// PDF (partitura, gestos…) — abre no leitor interno `/leitor`.
final class PdfMaterial extends CatalogMaterial {
  const PdfMaterial(this.louvor);

  final Louvor louvor;

  @override
  String get id => louvor.pdfId;

  @override
  MaterialKind get kind => MaterialKind.pdf;

  @override
  String get groupId => louvor.effectiveGroupId;

  @override
  String get categoria => louvor.categoria;

  @override
  String? get materialKindId => louvor.materialKindId;
}

/// Cifra ChordPro — abre em `/cifra`.
///
/// Invólucro (`Ref`) porque [ChordMaterial] vive em `features/chords` e uma
/// classe `sealed` só aceita subtipos da própria biblioteca.
final class ChordMaterialRef extends CatalogMaterial {
  const ChordMaterialRef(this.chord);

  final ChordMaterial chord;

  @override
  String get id => chord.chordId;

  @override
  MaterialKind get kind => MaterialKind.chord;

  @override
  String get groupId => chord.groupId;

  @override
  String get categoria => chord.categoria;

  @override
  String? get materialKindId => chord.materialKindId;
}

/// Documento de gestos CIAs — abre em `/gestos`.
final class GestureMaterialRef extends CatalogMaterial {
  const GestureMaterialRef(this.gesture);

  final GestureMaterial gesture;

  @override
  String get id => gesture.gestureId;

  @override
  MaterialKind get kind => MaterialKind.gesture;

  @override
  String get groupId => gesture.groupId;

  @override
  String get categoria => gesture.categoria;

  @override
  String? get materialKindId => gesture.materialKindId;
}

/// Faixa de áudio Coldigom — toca na sessão global e abre `/audio`.
final class AudioMaterial extends CatalogMaterial {
  const AudioMaterial(this.track);

  final AudioTrack track;

  @override
  String get id => track.audioId;

  @override
  MaterialKind get kind => MaterialKind.audio;

  @override
  String get groupId => track.groupId;

  @override
  String get categoria => track.categoria;

  @override
  String? get materialKindId => track.materialKindId;
}

/// Link YouTube — abre fora do app (app do YouTube ou navegador).
final class YoutubeMaterialRef extends CatalogMaterial {
  const YoutubeMaterialRef(this.material);

  final YoutubeMaterial material;

  @override
  String get id => material.id;

  @override
  MaterialKind get kind => MaterialKind.youtube;

  @override
  String get groupId => material.groupId;

  @override
  String get categoria => material.categoria;

  @override
  String? get materialKindId => material.materialKindId;
}
