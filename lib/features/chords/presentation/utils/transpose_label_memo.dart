import '../../domain/usecases/transpose_chord.dart';

/// Assinatura de [transposeChordLabel], usada por [TransposeLabelMemo] para
/// aceitar uma função injetada nos testes.
typedef ChordLabelTransposer =
    String Function(String label, int semitones, {required bool preferFlats});

/// Memoiza [transposeChordLabel] por `(acorde, semitons, bemóis)` (A14).
///
/// Sem isso, [transposeChordLabel] roda uma vez por célula por rebuild — toda
/// vez que o usuário transpõe ou muda o tamanho da fonte, a música inteira
/// recalcula cada rótulo de acorde do zero, mesmo os que já apareceram antes.
///
/// A política de teto é "limpa tudo ao estourar", não um LRU: mais simples, e
/// o pior caso é uma única rajada de recomputação depois da limpeza, não uma
/// substituição a cada inserção nova.
class TransposeLabelMemo {
  // Dart não aceita identificador privado como rótulo de parâmetro nomeado —
  // a forma sugerida pelo lint perderia o nome externo `transpose`.
  TransposeLabelMemo({
    this.maxEntries = 512,
    ChordLabelTransposer transpose = transposeChordLabel,
  })
    // ignore: prefer_initializing_formals
    : _transpose = transpose;

  /// Teto de entradas antes da limpeza total.
  final int maxEntries;

  final ChordLabelTransposer _transpose;

  final Map<(String, int, bool), String> _cache = {};

  /// Rótulo transposto de [chord], memoizado por `(chord, semitones,
  /// preferFlats)`.
  String label(String chord, int semitones, {required bool preferFlats}) {
    final key = (chord, semitones, preferFlats);
    final cached = _cache[key];
    if (cached != null) return cached;

    if (_cache.length >= maxEntries) _cache.clear();
    final value = _transpose(chord, semitones, preferFlats: preferFlats);
    _cache[key] = value;
    return value;
  }

  /// Número de entradas guardadas — só para inspeção/teste.
  int get size => _cache.length;
}
