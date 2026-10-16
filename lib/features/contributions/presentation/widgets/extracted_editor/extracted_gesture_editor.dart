import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../../core/layout/breakpoints.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/widgets/golden_tagged_container.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../gestures/data/providers/gesture_providers.dart';
import '../../../../gestures/domain/entities/gesture_dictionary.dart';
import '../../../../gestures/domain/entities/gesture_document.dart';
import '../../../../gestures/presentation/theme/gesture_reader_theme.dart';
import '../../../../gestures/presentation/widgets/gesture_document_view.dart';
import '../../../../gestures/presentation/widgets/gesture_figure.dart';
import 'gesture_picker_modal.dart';

/// Editor amigável e simplificado para Gestos de CIAS.
///
/// Permite:
/// - Adicionar linha (com gesto ou texto)
/// - Remover linha
/// - Trocar gesto (via dicionário oficial)
/// - Ajustar gatilho e letra
/// - Pré-visualização ao vivo responsiva (lado a lado no desktop/tablet, abas no mobile).
class ExtractedGestureEditor extends ConsumerStatefulWidget {
  const ExtractedGestureEditor({
    required this.initialDocument,
    required this.onChanged,
    super.key,
  });

  final GestureDocument initialDocument;
  final ValueChanged<GestureDocument> onChanged;

  @override
  ConsumerState<ExtractedGestureEditor> createState() =>
      _ExtractedGestureEditorState();
}

class _ExtractedGestureEditorState extends ConsumerState<ExtractedGestureEditor> {
  late GestureDocument _document;
  int _selectedTab = 0; // 0 = editor, 1 = preview

  @override
  void initState() {
    super.initState();
    _document = widget.initialDocument;
  }

  @override
  void didUpdateWidget(covariant ExtractedGestureEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDocument != widget.initialDocument &&
        _document == oldWidget.initialDocument) {
      _document = widget.initialDocument;
    }
  }

  void _updateDocument(GestureDocument newDoc) {
    setState(() => _document = newDoc);
    widget.onChanged(newDoc);
  }

  void _restoreOriginal() {
    _updateDocument(widget.initialDocument);
  }

  void _addGestureCard({List<GestureItem>? targetList}) {
    final defaultId = _findFirstActiveGestureId() ?? '5d3a00000000';
    final newCard = GestureCard(
      gestureId: defaultId,
      lyrics: const [LyricLine(trigger: '', text: '')],
    );

    if (targetList != null) {
      targetList.add(newCard);
      _updateDocument(_copyDocumentWithItems(_document.items));
    } else {
      final updated = List<GestureItem>.from(_document.items)..add(newCard);
      _updateDocument(_copyDocumentWithItems(updated));
    }
  }

  void _addTextLine({List<GestureItem>? targetList}) {
    const newLine = TextLine('');
    if (targetList != null) {
      targetList.add(newLine);
      _updateDocument(_copyDocumentWithItems(_document.items));
    } else {
      final updated = List<GestureItem>.from(_document.items)..add(newLine);
      _updateDocument(_copyDocumentWithItems(updated));
    }
  }

  String? _findFirstActiveGestureId() {
    final dict = ref.read(gestureDictionaryProvider).asData?.value;
    if (dict != null && dict.byId.isNotEmpty) {
      return dict.byId.values
          .where((e) => e.status == GestureStatus.active)
          .firstOrNull
          ?.id;
    }
    return null;
  }

  GestureDocument _copyDocumentWithItems(List<GestureItem> items) {
    return GestureDocument(
      schemaMajor: _document.schemaMajor,
      title: _document.title,
      dictionaryVersion: _document.dictionaryVersion,
      items: items,
    );
  }

  Future<void> _pickGestureForCard(
    GestureCard card,
    List<GestureItem> parentList,
    int index,
  ) async {
    final pickedId = await GesturePickerModal.show(
      context,
      currentGestureId: card.gestureId,
    );
    if (pickedId != null && mounted) {
      parentList[index] = GestureCard(
        gestureId: pickedId,
        lyrics: card.lyrics,
      );
      _updateDocument(_copyDocumentWithItems(_document.items));
    }
  }

  void _updateCardLyrics(
    GestureCard card,
    List<GestureItem> parentList,
    int index, {
    required String trigger,
    required String text,
  }) {
    parentList[index] = GestureCard(
      gestureId: card.gestureId,
      lyrics: [LyricLine(trigger: trigger, text: text)],
    );
    _updateDocument(_copyDocumentWithItems(_document.items));
  }

  void _removeItem(List<GestureItem> parentList, int index) {
    parentList.removeAt(index);
    _updateDocument(_copyDocumentWithItems(_document.items));
  }

  void _moveItem(List<GestureItem> parentList, int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= parentList.length) return;
    final item = parentList.removeAt(fromIndex);
    parentList.insert(toIndex, item);
    _updateDocument(_copyDocumentWithItems(_document.items));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dict = ref.watch(gestureDictionaryProvider).asData?.value ??
        GestureDictionary.empty;
    final wide = isWideLayout(context);
    final palette = GestureReaderMode.light.palette;

    final toolbar = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _addGestureCard(),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.contributeEditorAddGestureLine),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
            foregroundColor: AppColors.gold,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _addTextLine(),
          icon: const Icon(Icons.text_fields, size: 18),
          label: Text(l10n.contributeEditorAddTextLine),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textLight,
            side: const BorderSide(color: Color(0x55D4AF37)),
          ),
        ),
        if (_document != widget.initialDocument)
          TextButton.icon(
            onPressed: _restoreOriginal,
            icon: const Icon(Icons.restore, size: 18),
            label: Text(l10n.contributeEditorRestore),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
      ],
    );

    final editorWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpotlightGuideTarget(
          id: 'extracted-editor-toolbar',
          child: toolbar,
        ),
        const SizedBox(height: 12),
        SpotlightGuideTarget(
          id: 'extracted-editor-workspace',
          child: _document.items.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x33D4AF37)),
                  ),
                  child: Center(
                    child: Text(
                      'Nenhum item no documento. Adicione uma linha acima.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.title.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _document.items.length,
                  itemBuilder: (context, index) {
                    return _buildItemWidget(
                      _document.items[index],
                      _document.items,
                      index,
                      dict,
                      palette,
                      l10n,
                    );
                  },
                ),
        ),
      ],
    );

    final previewWidget = SpotlightGuideTarget(
      id: 'extracted-editor-preview',
      child: Container(
        height: wide ? 620 : 450,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33D4AF37)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 16, color: AppColors.title),
              const SizedBox(width: 6),
              Text(
                l10n.contributeEditorPreviewTab,
                style: AppTypography.headline.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.title,
                ),
              ),
              const Spacer(),
              Text(
                '${_document.items.length} blocos/linhas',
                style: AppTypography.label.copyWith(
                  fontSize: 12,
                  color: AppColors.title.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.gold, height: 16, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              child: GestureDocumentView(
                document: _document,
                dictionary: dict,
                fontSize: 15,
                palette: palette,
              ),
            ),
          ),
        ],
      ),
    ));

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: editorWidget),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: previewWidget),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: [
            ButtonSegment<int>(
              value: 0,
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.contributeEditorRawTab),
            ),
            ButtonSegment<int>(
              value: 1,
              icon: const Icon(Icons.preview),
              label: Text(l10n.contributeEditorPreviewTab),
            ),
          ],
          selected: {_selectedTab},
          onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.gold
                  : AppColors.textLight,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0x55D4AF37)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedTab == 0) editorWidget else previewWidget,
      ],
    );
  }

  Widget _buildItemWidget(
    GestureItem item,
    List<GestureItem> parentList,
    int index,
    GestureDictionary dict,
    dynamic palette,
    AppLocalizations l10n,
  ) {
    return switch (item) {
      GestureCard() => _buildGestureCardEditor(
          item,
          parentList,
          index,
          dict,
          palette,
          l10n,
        ),
      TextLine() => _buildTextLineEditor(
          item,
          parentList,
          index,
          l10n,
        ),
      ChorusBlock(:final children) => _buildBlockEditor(
          title: 'CORO',
          icon: Icons.groups_outlined,
          children: children,
          parentList: parentList,
          index: index,
          dict: dict,
          palette: palette,
          l10n: l10n,
        ),
      RepeatBlock(:final count, :final children) => _buildBlockEditor(
          title: 'REPETIÇÃO ${count}X',
          icon: Icons.repeat,
          children: children,
          parentList: parentList,
          index: index,
          dict: dict,
          palette: palette,
          l10n: l10n,
        ),
      LinkBlock(:final children) => _buildBlockEditor(
          title: 'LIGAÇÃO',
          icon: Icons.link,
          children: children,
          parentList: parentList,
          index: index,
          dict: dict,
          palette: palette,
          l10n: l10n,
        ),
      FinalBlock(:final children) => _buildBlockEditor(
          title: 'FINAL',
          icon: Icons.flag_outlined,
          children: children,
          parentList: parentList,
          index: index,
          dict: dict,
          palette: palette,
          l10n: l10n,
        ),
      InstructionCard(:final kind) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x22D4AF37)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Instrução: ${kind.name}',
                  style: AppTypography.body.copyWith(color: AppColors.title),
                ),
              ),
              IconButton(
                tooltip: l10n.contributeEditorRemoveLine,
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.title),
                onPressed: () => _removeItem(parentList, index),
              ),
            ],
          ),
        ),
      SectionLabel() => const SizedBox.shrink(),
    };
  }

  Widget _buildGestureCardEditor(
    GestureCard card,
    List<GestureItem> parentList,
    int index,
    GestureDictionary dict,
    dynamic palette,
    AppLocalizations l10n,
  ) {
    final entry = dict.resolve(card.gestureId);
    final trigger = card.lyrics.isNotEmpty ? card.lyrics.first.trigger : '';
    final text = card.lyrics.isNotEmpty ? card.lyrics.first.text : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureFigure(
                entry: entry,
                gestureId: card.gestureId,
                side: 44,
                palette: palette,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry?.name ?? 'Gesto desconhecido (${card.gestureId})',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.title,
                        fontSize: 14,
                      ),
                    ),
                    if (index == 0)
                      SpotlightGuideTarget(
                        id: 'extracted-gesture-picker',
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppColors.gold,
                          ),
                          onPressed: () => _pickGestureForCard(card, parentList, index),
                          icon: const Icon(Icons.swap_horiz, size: 16),
                          label: Text(l10n.contributeEditorChangeGesture),
                        ),
                      )
                    else
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.gold,
                        ),
                        onPressed: () => _pickGestureForCard(card, parentList, index),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: Text(l10n.contributeEditorChangeGesture),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.contributeEditorMoveUp,
                icon: const Icon(Icons.arrow_upward, size: 18, color: AppColors.title),
                onPressed: index > 0
                    ? () => _moveItem(parentList, index, index - 1)
                    : null,
              ),
              IconButton(
                tooltip: l10n.contributeEditorMoveDown,
                icon: const Icon(Icons.arrow_downward, size: 18, color: AppColors.title),
                onPressed: index < parentList.length - 1
                    ? () => _moveItem(parentList, index, index + 1)
                    : null,
              ),
              IconButton(
                tooltip: l10n.contributeEditorRemoveLine,
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.title),
                onPressed: () => _removeItem(parentList, index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: GoldenTaggedContainer(
                  label: l10n.contributeEditorTriggerLabel,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: TextFormField(
                    initialValue: trigger,
                    style: AppTypography.input.copyWith(
                      color: const Color(0xFFC8372D),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (newTrigger) => _updateCardLyrics(
                      card,
                      parentList,
                      index,
                      trigger: newTrigger,
                      text: text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: GoldenTaggedContainer(
                  label: l10n.contributeEditorLyricsLabel,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: TextFormField(
                    initialValue: text,
                    style: AppTypography.input.copyWith(
                      color: AppColors.textDark,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (newText) => _updateCardLyrics(
                      card,
                      parentList,
                      index,
                      trigger: trigger,
                      text: newText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextLineEditor(
    TextLine line,
    List<GestureItem> parentList,
    int index,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33D4AF37)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GoldenTaggedContainer(
              label: l10n.contributeEditorAddTextLine,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TextFormField(
                initialValue: line.text,
                style: AppTypography.input.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (newText) {
                  parentList[index] = TextLine(newText);
                  _updateDocument(_copyDocumentWithItems(_document.items));
                },
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.contributeEditorRemoveLine,
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.title),
            onPressed: () => _removeItem(parentList, index),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockEditor({
    required String title,
    required IconData icon,
    required List<GestureItem> children,
    required List<GestureItem> parentList,
    required int index,
    required GestureDictionary dict,
    required dynamic palette,
    required AppLocalizations l10n,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.headline.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: l10n.contributeEditorRemoveLine,
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.gold),
                onPressed: () => _removeItem(parentList, index),
              ),
            ],
          ),
          const Divider(color: Color(0x33D4AF37), height: 16),
          for (var i = 0; i < children.length; i++)
            _buildItemWidget(children[i], children, i, dict, palette, l10n),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.contributeEditorAddGestureLine),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                onPressed: () => _addGestureCard(targetList: children),
              ),
              TextButton.icon(
                icon: const Icon(Icons.text_fields, size: 16),
                label: Text(l10n.contributeEditorAddTextLine),
                style: TextButton.styleFrom(foregroundColor: AppColors.textLight),
                onPressed: () => _addTextLine(targetList: children),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
