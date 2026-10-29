import 'package:flutter/material.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../../core/layout/breakpoints.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/widgets/golden_tagged_container.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../chords/domain/usecases/parse_chordpro.dart';
import '../../../../chords/presentation/theme/chord_reader_theme.dart';
import '../../../../chords/presentation/widgets/chord_header.dart';
import '../../../../chords/presentation/widgets/chordpro_view.dart';

/// Editor amigável e simplificado para Cifras (ChordPro), com alteração do raw e preview live responsivo.
class ExtractedChordEditor extends StatefulWidget {
  const ExtractedChordEditor({
    required this.initialChordPro,
    required this.onChanged,
    super.key,
  });

  final String initialChordPro;
  final ValueChanged<String> onChanged;

  @override
  State<ExtractedChordEditor> createState() => _ExtractedChordEditorState();
}

class _ExtractedChordEditorState extends State<ExtractedChordEditor> {
  late final TextEditingController _controller;
  int _selectedTab = 0; // 0 = editor, 1 = preview

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialChordPro);
  }

  @override
  void didUpdateWidget(covariant ExtractedChordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialChordPro != widget.initialChordPro &&
        _controller.text.isEmpty) {
      _controller.text = widget.initialChordPro;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertAtCursor(String insertion) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, insertion);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
    widget.onChanged(newText);
    setState(() {});
  }

  void _addLine() {
    final text = _controller.text;
    final newText = text.isEmpty ? '\n' : (text.endsWith('\n') ? '$text\n' : '$text\n\n');
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newText.length);
    widget.onChanged(newText);
    setState(() {});
  }

  void _removeLine() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final lines = text.split('\n');
    if (lines.isNotEmpty) {
      lines.removeLast();
      final newText = lines.join('\n');
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: newText.length);
      widget.onChanged(newText);
      setState(() {});
    }
  }

  void _restoreOriginal() {
    _controller.text = widget.initialChordPro;
    _controller.selection = TextSelection.collapsed(offset: widget.initialChordPro.length);
    widget.onChanged(widget.initialChordPro);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wide = isWideLayout(context);
    final currentText = _controller.text;
    final song = parseChordPro(currentText);

    final toolbar = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: _addLine,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.contributeEditorAddLine),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
            foregroundColor: AppColors.gold,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _removeLine,
          icon: const Icon(Icons.remove, size: 18),
          label: Text(l10n.contributeEditorRemoveLine),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textLight,
            side: const BorderSide(color: Color(0x55D4AF37)),
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.music_note, size: 16, color: AppColors.gold),
          label: Text(l10n.contributeEditorInsertChord),
          backgroundColor: AppColors.card,
          side: const BorderSide(color: Color(0x33D4AF37)),
          labelStyle: AppTypography.label.copyWith(color: AppColors.title),
          onPressed: () => _insertAtCursor('[C]'),
        ),
        ActionChip(
          avatar: const Icon(Icons.comment_outlined, size: 16, color: AppColors.gold),
          label: Text(l10n.contributeEditorInsertComment),
          backgroundColor: AppColors.card,
          side: const BorderSide(color: Color(0x33D4AF37)),
          labelStyle: AppTypography.label.copyWith(color: AppColors.title),
          onPressed: () => _insertAtCursor('{comment: Coro}\n'),
        ),
        if (currentText != widget.initialChordPro)
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
          child: GoldenTaggedContainer(
            label: l10n.contributeEditorRawTab,
            contentPadding: const EdgeInsets.all(12),
            child: TextFormField(
              controller: _controller,
              minLines: 10,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: AppTypography.input.copyWith(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: l10n.contributeEditorChordProExampleHint,
                hintStyle: AppTypography.hint(italic: true),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                widget.onChanged(val);
                setState(() {});
              },
            ),
          ),
        ),
      ],
    );

    final previewWidget = SpotlightGuideTarget(
      id: 'extracted-editor-preview',
      child: Container(
        height: wide ? 520 : 400,
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
                l10n.contributeEditorLinesCount(song.lines.length),
                style: AppTypography.label.copyWith(
                  fontSize: 12,
                  color: AppColors.title.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.gold, height: 16, thickness: 1),
          Expanded(
            child: currentText.trim().isEmpty
                ? Center(
                    child: Text(
                      l10n.lyricsReaderEmpty,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      if (song.title.isNotEmpty ||
                          song.subtitle.isNotEmpty ||
                          song.key.isNotEmpty ||
                          song.rhythm.isNotEmpty ||
                          song.artist.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ChordHeader(
                              song: song,
                              semitones: 0,
                              palette: ChordReaderMode.light.palette,
                            ),
                          ),
                        ),
                      ChordProView(
                        song: song,
                        palette: ChordReaderMode.light.palette,
                        fontSize: 15,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ));

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: editorWidget),
          const SizedBox(width: 16),
          Expanded(child: previewWidget),
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
}
