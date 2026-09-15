import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../domain/entities/flat_gesture_card.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../theme/gesture_reader_palette.dart';
import 'gesture_figure.dart';
import 'lyric_line_text.dart';

Key gestureFocusPageKey(int index) => ValueKey('gesture-focus-page-$index');
const Key gestureFocusNextKey = ValueKey('gesture-focus-next');
const Key gestureFocusCloseKey = ValueKey('gesture-focus-close');

/// Rótulo do chip de contexto de um bloco.
String blockContextLabel(AppLocalizations l10n, BlockContext context) =>
    switch (context) {
      RepeatContext(:final count) => l10n.gestureContextRepeat(count),
      ChorusContext() => l10n.gestureContextChorus,
      FinalContext() => l10n.gestureContextFinal,
      LinkContext() => l10n.gestureContextLink,
    };

/// Trigger do rodapé "próximo": a primeira linha de letra não vazia do
/// próximo cartão — uma linha de continuação chega com `trigger` vazio, então
/// cai para as seguintes; sem nenhum trigger, cai pro texto da primeira
/// linha. `''` só quando [next] é `null` ou não tem letra nenhuma.
String _footerTriggerOf(FlatGestureCard? next) {
  final lyrics = next?.card.lyrics ?? const [];
  for (final line in lyrics) {
    if (line.trigger.isNotEmpty) return line.trigger;
  }
  return lyrics.isEmpty ? '' : lyrics.first.text;
}

/// Abre o modo foco sobre a rota atual e devolve o índice do cartão em que o
/// regente estava ao fechar (`null` se fechou sem índice).
///
/// Overlay (`showGeneralDialog`), não rota: o shell, o wakelock e o carousel
/// continuam sendo os de `/gestos`.
Future<int?> showGestureFocus(
  BuildContext context, {
  required List<FlatGestureCard> cards,
  required GestureDictionary dictionary,
  required int initialIndex,
  required double fontSize,
  required GestureReaderPalette palette,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) => GestureFocusView(
      cards: cards,
      dictionary: dictionary,
      initialIndex: initialIndex,
      fontSize: fontSize,
      palette: palette,
    ),
  );
}

/// `PageView` sobre os cartões achatados, um por página.
class GestureFocusView extends ConsumerStatefulWidget {
  const GestureFocusView({
    required this.cards,
    required this.dictionary,
    required this.initialIndex,
    required this.fontSize,
    required this.palette,
    super.key,
  });

  final List<FlatGestureCard> cards;
  final GestureDictionary dictionary;
  final int initialIndex;
  final double fontSize;
  final GestureReaderPalette palette;

  @override
  ConsumerState<GestureFocusView> createState() => _GestureFocusViewState();
}

class _GestureFocusViewState extends ConsumerState<GestureFocusView> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex.clamp(0, widget.cards.length - 1),
  );
  late int _index = _controller.initialPage;
  final _focusNode = FocusNode(debugLabel: 'gestureFocusKeys');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.cards.length - 1);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _close() => Navigator.of(context).pop(_index);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      ref.read(toggleReaderFullscreenProvider).call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = widget.cards;
    final next = _index + 1 < cards.length ? cards[_index + 1] : null;
    final nextTrigger = _footerTriggerOf(next);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        color: widget.palette.paper,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: gestureFocusCloseKey,
                  tooltip: l10n.gestureFocusClose,
                  icon: Icon(Icons.close, color: widget.palette.lyric),
                  onPressed: _close,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _go(
                        details.localPosition.dx > constraints.maxWidth / 2
                            ? 1
                            : -1,
                      ),
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: cards.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _FocusPage(
                          key: gestureFocusPageKey(i),
                          flat: cards[i],
                          dictionary: widget.dictionary,
                          fontSize: widget.fontSize + 6,
                          maxWidth: constraints.maxWidth,
                          palette: widget.palette,
                        ),
                      ),
                    );
                  },
                ),
              ),
              _NextFooter(
                l10n: l10n,
                nextTrigger: next == null ? null : nextTrigger,
                palette: widget.palette,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusPage extends StatelessWidget {
  const _FocusPage({
    required this.flat,
    required this.dictionary,
    required this.fontSize,
    required this.maxWidth,
    required this.palette,
    super.key,
  });

  final FlatGestureCard flat;
  final GestureDictionary dictionary;
  final double fontSize;
  final double maxWidth;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final side = (maxWidth * 0.6).clamp(120.0, 480.0);
    final entry = dictionary.resolve(flat.card.gestureId);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (flat.contexts.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final ctx in flat.contexts)
                  Chip(
                    label: Text(blockContextLabel(l10n, ctx)),
                    labelStyle: TextStyle(
                      color: palette.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    side: BorderSide(color: palette.blue),
                    backgroundColor: palette.paper,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          const SizedBox(height: 8),
          GestureFigure(
            entry: entry,
            gestureId: flat.card.gestureId,
            side: side,
            preferGif: true,
            palette: palette,
          ),
          const SizedBox(height: 16),
          for (final line in flat.card.lyrics)
            Align(
              alignment: Alignment.centerLeft,
              child: LyricLineText(
                line: line,
                fontSize: fontSize,
                palette: palette,
              ),
            ),
        ],
      ),
    );
  }
}

/// Rodapé fixo: `próximo:` + gatilho seguinte em vermelho, ou `fim`.
class _NextFooter extends StatelessWidget {
  const _NextFooter({
    required this.l10n,
    required this.nextTrigger,
    required this.palette,
  });

  final AppLocalizations l10n;

  /// `null` no último cartão.
  final String? nextTrigger;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final trigger = nextTrigger;
    return Container(
      key: gestureFocusNextKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      child: trigger == null
          ? Text(
              l10n.gestureFocusEnd,
              style: TextStyle(color: palette.sectionLabel, fontSize: 16),
            )
          : Row(
              children: [
                Text(
                  '${l10n.gestureFocusNext} ',
                  style: TextStyle(color: palette.sectionLabel, fontSize: 16),
                ),
                Expanded(
                  child: Text(
                    trigger,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.trigger,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
