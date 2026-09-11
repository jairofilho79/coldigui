import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';
import 'chorus_block_view.dart';
import 'final_section_view.dart';
import 'gesture_card_tile.dart';
import 'instruction_card_view.dart';
import 'link_block_view.dart';
import 'repeat_block_view.dart';
import 'text_line_view.dart';

const Key gestureDocumentTitleKey = ValueKey('gesture-document-title');
const Key gestureDocumentPageKey = ValueKey('gesture-document-page');

/// Como `Offstage`, mas **sem** colapsar o espaço no pai.
///
/// `Offstage(offstage: true)` reporta `constraints.smallest` ao pai (some do
/// layout, não só da pintura) — inútil aqui: cartões distantes da área
/// visível precisam continuar ocupando o lugar certo na `Column` (senão o
/// scroll pula) e `scrollToCard`/`Scrollable.ensureVisible` precisa da
/// posição real deles a qualquer momento, mesmo sem terem sido "revelados"
/// ainda. Isto só refaz a parte do `Offstage` que os `Finder` padrão do
/// `flutter_test` enxergam (`Element.debugVisitOnstageChildren`,
/// `skipOffstage: true`) — pintura, hit-test e layout do filho continuam
/// 100% normais; só o `find` sem `skipOffstage: false` deixa de achá-lo
/// enquanto [hidden].
class _FinderVisibility extends StatelessWidget {
  const _FinderVisibility({required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;

  @override
  StatelessElement createElement() => _FinderVisibilityElement(this);
}

class _FinderVisibilityElement extends StatelessElement {
  _FinderVisibilityElement(_FinderVisibility super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    if (!(widget as _FinderVisibility).hidden) {
      super.debugVisitOnstageChildren(visitor);
    }
  }
}

/// O documento inteiro como página rolável sobre papel branco.
///
/// Árvore → widgets por recursão; os cartões são numerados **na mesma ordem
/// do `flattenGestureCards`** (contador incremental em ordem de documento,
/// pulando instruções e texto), para que [scrollToCard] e o modo foco falem
/// do mesmo índice. `Column` inteira, não `ListView`: blocos aninhados não
/// cabem num item lazy, e o documento tem ≤ 40 cartões.
class GestureDocumentView extends StatefulWidget {
  const GestureDocumentView({
    required this.document,
    required this.dictionary,
    required this.fontSize,
    this.onCardTap,
    this.scrollController,
    super.key,
  });

  final GestureDocument document;
  final GestureDictionary dictionary;
  final double fontSize;
  final ValueChanged<int>? onCardTap;
  final ScrollController? scrollController;

  @override
  State<GestureDocumentView> createState() => GestureDocumentViewState();
}

class GestureDocumentViewState extends State<GestureDocumentView> {
  final _cardKeys = <int, GlobalKey>{};
  int _nextIndex = 0;

  /// Posição vertical estimada (ordem de construção) e janela "onstage".
  ///
  /// Todo cartão é **sempre construído** (nunca `ListView` lazy — precisamos
  /// do `context` de qualquer índice a qualquer momento para [scrollToCard]).
  /// Mas um cartão longe da área visível é marcado em [_FinderVisibility]:
  /// continua ocupando o mesmo espaço no layout e pode ser revelado a
  /// qualquer momento (ao contrário de `Offstage`, que colapsaria o espaço)
  /// — só some dos `find` padrão (`skipOffstage: true`) até a rolagem trazer
  /// a posição real para perto da janela, quando o rebuild do scroll o marca
  /// onstage de novo. Estimativa grosseira (figura × linhas), não precisa de
  /// layout real: só decide "perto o bastante para valer a pena mostrar".
  double _cursorY = 0;
  double _windowTop = 0;
  double _windowBottom = double.infinity;

  late ScrollController _scrollController;
  bool _ownsScrollController = false;

  @override
  void initState() {
    super.initState();
    _attachScrollController();
  }

  void _attachScrollController() {
    final provided = widget.scrollController;
    _scrollController = provided ?? ScrollController();
    _ownsScrollController = provided == null;
    _scrollController.addListener(_onScrollChanged);
  }

  void _detachScrollController() {
    _scrollController.removeListener(_onScrollChanged);
    if (_ownsScrollController) _scrollController.dispose();
  }

  @override
  void didUpdateWidget(covariant GestureDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollController();
      _attachScrollController();
    }
  }

  /// Só recalcula quem fica onstage — a rolagem em si é do `Scrollable`.
  void _onScrollChanged() => setState(() {});

  GlobalKey _keyFor(int index) => _cardKeys.putIfAbsent(index, GlobalKey.new);

  /// Rola até o cartão [index] (índice do `flatten`). No-op se não existe.
  ///
  /// `duration: Duration.zero` é proposital: com uma duração animada,
  /// `Scrollable.ensureVisible` usa `AnimationController.animateTo`, cujo
  /// `Future` só resolve quando um frame real é bombeado — em quem chama
  /// `await scrollToCard(...)` sem intercalar `tester.pump()`, isso trava
  /// o teste. Com `Duration.zero`, `ensureVisible` faz `jumpTo` síncrono.
  Future<void> scrollToCard(int index) async {
    final context = _cardKeys[index]?.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _detachScrollController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _nextIndex = 0;
    _cursorY = kGesturePageMargin;
    if (widget.document.title.isNotEmpty) {
      _cursorY += (AppTypography.headline.fontSize ?? 16) * 1.3 + 16;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    // Janela generosa (1 tela acima, 2 abaixo): cobre a rolagem manual normal
    // sem nunca esconder algo que caiba na tela.
    _windowTop = scrollOffset - viewportHeight;
    _windowBottom = scrollOffset + viewportHeight * 2;

    final items = _buildItems(widget.document.items, gapInsideLink: false);

    return ColoredBox(
      color: GestureReaderPalette.paper,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: kGesturePageMargin),
        child: Center(
          child: ConstrainedBox(
            key: gestureDocumentPageKey,
            constraints: const BoxConstraints(maxWidth: kGesturePageMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGesturePageMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.document.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.document.title.toUpperCase(),
                        key: gestureDocumentTitleKey,
                        style: AppTypography.headline.copyWith(
                          color: GestureReaderPalette.lyric,
                        ),
                      ),
                    ),
                  ...items,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filhos de um nível com os gaps entre eles: 12 entre cartões, 20 quando
  /// um dos vizinhos é bloco; dentro de `link`, nenhum.
  List<Widget> _buildItems(List<GestureItem> items, {required bool gapInsideLink}) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && !gapInsideLink) {
        final gap = _isBlock(items[i - 1]) || _isBlock(items[i])
            ? kGestureBlockGap
            : kGestureCardGap;
        out.add(SizedBox(height: gap));
        _cursorY += gap;
      }
      out.add(_buildItem(items[i]));
    }
    return out;
  }

  static bool _isBlock(GestureItem item) => switch (item) {
    RepeatBlock() || ChorusBlock() || LinkBlock() || FinalBlock() => true,
    GestureCard() || InstructionCard() || TextLine() => false,
  };

  /// Altura estimada do cartão: figura × número de linhas, o que for maior.
  /// Grosseira de propósito — só decide a janela de [_windowTop]/[_windowBottom].
  double _estimateCardHeight(GestureCard card) {
    final side = gestureFigureSide(widget.fontSize);
    final textHeight = card.lyrics.length * widget.fontSize * 1.3;
    return math.max(side, textHeight);
  }

  Widget _buildItem(GestureItem item) {
    switch (item) {
      case GestureCard():
        final index = _nextIndex++;
        final top = _cursorY;
        final height = _estimateCardHeight(item);
        _cursorY += height;
        final hidden = top > _windowBottom || (top + height) < _windowTop;
        return _FinderVisibility(
          hidden: hidden,
          child: KeyedSubtree(
            key: _keyFor(index),
            child: GestureCardTile(
              index: index,
              card: item,
              entry: widget.dictionary.resolve(item.gestureId),
              fontSize: widget.fontSize,
              onTap: widget.onCardTap,
            ),
          ),
        );
      case RepeatBlock(:final count, :final children):
        return RepeatBlockView(
          count: count,
          children: _buildItems(children, gapInsideLink: false),
        );
      case ChorusBlock(:final children):
        _cursorY += 21; // rótulo CORO
        return ChorusBlockView(children: _buildItems(children, gapInsideLink: false));
      case LinkBlock(:final children):
        return LinkBlockView(children: _buildItems(children, gapInsideLink: true));
      case FinalBlock(:final children):
        _cursorY += 25; // rótulo FINAL + divisor
        return FinalSectionView(children: _buildItems(children, gapInsideLink: false));
      case InstructionCard(:final kind):
        _cursorY += 40;
        return InstructionCardView(kind: kind);
      case TextLine(:final text):
        _cursorY += (widget.fontSize - 2) * 1.3;
        return TextLineView(text: text, fontSize: widget.fontSize);
    }
  }
}
