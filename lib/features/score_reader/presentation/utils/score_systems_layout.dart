import 'package:crisp_notation/crisp_notation.dart'
    hide Interval, Key, PageMetrics;
// `textWidthFor` é o mesmo medidor de texto que os widgets do crisp usam no
// layout; sem ele as sílabas da letra colidem.
// ignore: implementation_imports
import 'package:crisp_notation/src/rendering/text_metrics.dart';

/// Margem à esquerda do sistema (em espaços de pauta) — cabe a chave/colchete
/// do grupo de vozes.
const double kScoreSystemMarginLeft = 2.6;
const double kScoreSystemMarginRight = 1;

/// Respiro vertical acima e abaixo de cada sistema, em espaços de pauta.
const double kScoreSystemPadding = 2.5;

/// Partitura quebrada em sistemas (linhas) para uma largura.
///
/// Calculada uma vez por (partitura, largura, zoom): a lista pinta cada
/// sistema isoladamente e sabe a altura de todos sem medir.
class ScoreSystemsLayout {
  ScoreSystemsLayout._(this.systems, this._systemOfMeasure, this._ids);

  /// Quebra [score] em sistemas de [widthSpaces] espaços de largura (margens
  /// incluídas). Precisa da fonte musical carregada (`Bravura.load()`).
  factory ScoreSystemsLayout.of(
    MultiPartScore score, {
    required double widthSpaces,
    CrispNotationTheme theme = CrispNotationTheme.standard,
  }) {
    final metadata = MusicFonts.metadataOrNull(theme.musicFont);
    if (metadata == null) {
      throw StateError('Fonte musical não carregada');
    }
    final maxWidth =
        widthSpaces - kScoreSystemMarginLeft - kScoreSystemMarginRight;
    final wrapped = layoutStaffSystemSystems(
      score.toStaffSystem(),
      LayoutSettings(
        metadata: metadata,
        fingeringPlacement: theme.fingeringPlacement,
        textWidth: textWidthFor(theme.textFontFamily),
      ),
      maxWidth: maxWidth < 10 ? 10 : maxWidth,
    );
    final systemOfMeasure = <int, int>{};
    final ids = <Set<String>>[];
    for (final (index, system) in wrapped.systems.indexed) {
      for (var m = system.firstMeasure; m <= system.lastMeasure; m++) {
        systemOfMeasure.putIfAbsent(m, () => index);
      }
      ids.add({
        for (final staff in system.layout.staves)
          for (final region in staff.regions) region.elementId,
      });
    }
    return ScoreSystemsLayout._(wrapped.systems, systemOfMeasure, ids);
  }

  final List<StaffSystemSystem> systems;
  final Map<int, int> _systemOfMeasure;
  final List<Set<String>> _ids;

  /// Altura do sistema [index] com o respiro, em espaços de pauta.
  double heightOf(int index) =>
      systems[index].layout.height + 2 * kScoreSystemPadding;

  int? systemOfMeasure(int measure) => _systemOfMeasure[measure];

  /// Os ids de [ids] que estão desenhados no sistema [index] — o que cada
  /// sistema recebe para destacar, para só repintar os que mudaram.
  Set<String> visibleIn(int index, Set<String> ids) {
    if (ids.isEmpty) return const {};
    final own = _ids[index];
    final out = <String>{
      for (final id in ids)
        if (own.contains(id)) id,
    };
    return out.isEmpty ? const {} : out;
  }
}
