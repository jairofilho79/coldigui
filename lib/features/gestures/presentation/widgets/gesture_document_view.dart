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
import 'section_label_view.dart';
import 'text_line_view.dart';

const Key gestureDocumentTitleKey = ValueKey('gesture-document-title');
const Key gestureDocumentPageKey = ValueKey('gesture-document-page');

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
    required this.palette,
    this.onCardTap,
    this.scrollController,
    super.key,
  });

  final GestureDocument document;
  final GestureDictionary dictionary;
  final double fontSize;
  final GestureReaderPalette palette;
  final ValueChanged<int>? onCardTap;
  final ScrollController? scrollController;

  @override
  State<GestureDocumentView> createState() => GestureDocumentViewState();
}

class GestureDocumentViewState extends State<GestureDocumentView> {
  final _cardKeys = <int, GlobalKey>{};
  int _nextIndex = 0;

  GlobalKey _keyFor(int index) => _cardKeys.putIfAbsent(index, GlobalKey.new);

  /// Rola até o cartão [index] (índice do `flatten`). No-op se não existe.
  Future<void> scrollToCard(int index) async {
    final context = _cardKeys[index]?.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    _nextIndex = 0;
    final items = _buildItems(widget.document.items, gapInsideLink: false);

    return ColoredBox(
      color: widget.palette.paper,
      child: SingleChildScrollView(
        controller: widget.scrollController,
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
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        widget.document.title.toUpperCase(),
                        key: gestureDocumentTitleKey,
                        style: AppTypography.headline.copyWith(
                          color: widget.palette.lyric,
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

  /// Filhos de um nível com os gaps entre eles: 4 entre cartões, 16 quando
  /// um dos vizinhos é bloco; dentro de `link`, nenhum.
  List<Widget> _buildItems(List<GestureItem> items, {required bool gapInsideLink}) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && !gapInsideLink) {
        final gap = _isBlock(items[i - 1]) || _isBlock(items[i])
            ? kGestureBlockGap
            : kGestureCardGap;
        out.add(SizedBox(height: gap));
      }
      out.add(_buildItem(items[i]));
    }
    return out;
  }

  static bool _isBlock(GestureItem item) => switch (item) {
    RepeatBlock() || ChorusBlock() || LinkBlock() || FinalBlock() => true,
    GestureCard() || InstructionCard() || TextLine() || SectionLabel() => false,
  };

  Widget _buildItem(GestureItem item) {
    switch (item) {
      case GestureCard():
        final index = _nextIndex++;
        return KeyedSubtree(
          key: _keyFor(index),
          child: GestureCardTile(
            index: index,
            card: item,
            entry: widget.dictionary.resolve(item.gestureId),
            fontSize: widget.fontSize,
            palette: widget.palette,
            onTap: widget.onCardTap,
          ),
        );
      case RepeatBlock(:final count, :final children):
        return RepeatBlockView(
          count: count,
          palette: widget.palette,
          children: _buildItems(children, gapInsideLink: false),
        );
      case ChorusBlock(:final children):
        return ChorusBlockView(
          palette: widget.palette,
          children: _buildItems(children, gapInsideLink: false),
        );
      case LinkBlock(:final children):
        return LinkBlockView(
          palette: widget.palette,
          children: _buildItems(children, gapInsideLink: true),
        );
      case FinalBlock(:final children):
        return FinalSectionView(
          palette: widget.palette,
          children: _buildItems(children, gapInsideLink: false),
        );
      case InstructionCard(:final kind):
        return InstructionCardView(kind: kind, palette: widget.palette);
      case TextLine(:final text):
        return TextLineView(text: text, fontSize: widget.fontSize, palette: widget.palette);
      case SectionLabel():
        return SectionLabelView(
          label: item,
          fontSize: widget.fontSize,
          palette: widget.palette,
        );
    }
  }
}
