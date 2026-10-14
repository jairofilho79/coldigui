import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/layout/breakpoints.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/theme/color_extensions.dart';
import '../../../../../core/utils/material_id_kind.dart';
import '../../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../../core/widgets/golden_tagged_container.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../../chords/data/providers/chord_providers.dart';
import '../../../../coldigom/data/providers/coldigom_catalog_source_provider.dart';
import '../../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../../gestures/data/providers/gesture_providers.dart';
import '../../../../gestures/domain/entities/gesture_document.dart';
import '../../../../gestures/domain/usecases/serialize_gesture_document.dart';
import '../../../domain/entities/contribution_attachment.dart';
import '../../../domain/entities/contribution_target.dart';
import '../../../domain/entities/device_snapshot.dart';
import '../../providers/contribute_form_provider.dart';
import '../sign_in_to_contribute.dart';
import 'extracted_chord_editor.dart';
import 'extracted_gesture_editor.dart';
import 'extracted_lyrics_editor.dart';

/// Componente orquestrador do editor simplificado de materiais extraídos
/// (Letra, Cifras Chord e Gestos CIAs).
class ExtractedMaterialEditorScaffold extends ConsumerStatefulWidget {
  const ExtractedMaterialEditorScaffold({
    required this.target,
    required this.materialKind,
    required this.onSwitchToGeneral,
    required this.onSend,
    required this.snapshot,
    this.formArgs,
    super.key,
  });

  final ContributionTarget target;
  final MaterialKind materialKind;
  final VoidCallback onSwitchToGeneral;
  final Future<void> Function(DeviceSnapshot? snapshot) onSend;
  final DeviceSnapshot? snapshot;
  final ContributeFormArgs? formArgs;

  @override
  ConsumerState<ExtractedMaterialEditorScaffold> createState() =>
      _ExtractedMaterialEditorScaffoldState();
}

class _ExtractedMaterialEditorScaffoldState
    extends ConsumerState<ExtractedMaterialEditorScaffold> {
  String _userNotes = '';
  String? _editedLyrics;
  String? _editedChordPro;
  GestureDocument? _editedGestureDoc;
  bool _initialized = false;

  String get _praiseId => widget.target.praiseId ?? '';
  String get _materialId => widget.target.materialId ?? '';

  String get _r2Key {
    if (_materialId.isEmpty) return '';
    final lower = _materialId.toLowerCase();
    if (lower.endsWith('.chord') ||
        lower.endsWith('.chordpro') ||
        lower.endsWith('.gestures')) {
      return _materialId;
    }
    try {
      return PdfPathNormalizer.getPdfRelPath(_materialId);
    } catch (_) {
      return _materialId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authStateProvider).asData?.value;
    final group = ref
            .watch(coldigomCatalogSourceProvider)
            .findGroupForMaterial(_materialId) ??
        ref.watch(coldigomCatalogSourceProvider).findGroupById(_praiseId);
    final row = ref.watch(coldigomCatalogRowProvider(_praiseId));
    final praiseTitle = group?.nome ??
        row?.name ??
        (row?.lyrics.isNotEmpty == true
            ? row!.lyrics.split('\n').first
            : _praiseId);

    final args = widget.formArgs ?? ContributeFormArgs(target: widget.target);
    final formState = ref.watch(contributeFormProvider(args));
    final notifier = ref.read(contributeFormProvider(args).notifier);
    final draft = formState.draft;

    final wide = isWideLayout(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 1100 : 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da edição do material
              _buildHeader(l10n, praiseTitle),
              const SizedBox(height: 16),

              // Editor específico conforme o tipo de material extraído
              _buildEditorContent(l10n, row?.lyrics),

              const SizedBox(height: 20),

              // Campo opcional de observações do usuário
              GoldenTaggedContainer(
                label: l10n.contributeEditorNotesLabel,
                contentPadding: const EdgeInsets.all(12),
                child: TextFormField(
                  initialValue: _userNotes,
                  minLines: 2,
                  maxLines: 4,
                  style: AppTypography.input,
                  decoration: InputDecoration(
                    hintText: l10n.contributeEditorNotesHint,
                    hintStyle: AppTypography.hint(italic: true),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) => _userNotes = val,
                ),
              ),

              const SizedBox(height: 12),

              // Consentimento do dispositivo
              InkWell(
                onTap: () => notifier.setSendDeviceData(!draft.sendDeviceData),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Checkbox(
                        value: draft.sendDeviceData,
                        onChanged: (val) =>
                            notifier.setSendDeviceData(val ?? true),
                        activeColor: AppColors.gold,
                        checkColor: AppColors.title,
                        side: const BorderSide(
                          color: Color(0x99D4AF37),
                          width: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.contributeSendDeviceData,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textLight.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (formState.submit case ContributeSending(:final progress))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                    value: progress,
                    color: AppColors.gold,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.25),
                  ),
                ),

              // Botão Enviar ou Login
              if (user == null)
                const Center(child: SignInToContribute())
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('contribute-send-extracted'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.title,
                      disabledBackgroundColor: AppColors.background,
                      disabledForegroundColor: const Color(0xFF351C1B),
                      side: const BorderSide(
                        color: AppColors.gold,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: formState.submit is! ContributeSending
                        ? () => _submitSuggestion(praiseTitle, notifier)
                        : null,
                    child: Text(
                      l10n.contributeSend,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.title,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Botão para alternar para o formulário padrão comum
              Center(
                child: TextButton.icon(
                  onPressed: widget.onSwitchToGeneral,
                  icon: const Icon(Icons.alt_route, size: 18, color: AppColors.gold),
                  label: Text(
                    l10n.contributeEditorSwitchToGeneral,
                    style: AppTypography.body.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, String praiseTitle) {
    final kindLabel = switch (widget.materialKind) {
      MaterialKind.lyrics => l10n.contributeEditorLyricsKind,
      MaterialKind.chord => l10n.contributeEditorChordKind,
      MaterialKind.gesture => l10n.contributeEditorGestureKind,
      _ => '',
    };

    final icon = switch (widget.materialKind) {
      MaterialKind.lyrics => Icons.article_outlined,
      MaterialKind.chord => Icons.music_note_outlined,
      MaterialKind.gesture => Icons.sign_language_outlined,
      _ => Icons.edit,
    };

    return Column(
      children: [
        Center(
          child: Text(
            l10n.contributeEditorTitle,
            style: AppTypography.headline.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  '$kindLabel: $praiseTitle',
                  style: AppTypography.label.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorContent(AppLocalizations l10n, String? catalogLyrics) {
    switch (widget.materialKind) {
      case MaterialKind.lyrics:
        final initialLyrics = catalogLyrics?.trim() ?? '';
        if (!_initialized) {
          _editedLyrics = initialLyrics;
          _initialized = true;
        }
        return ExtractedLyricsEditor(
          initialLyrics: _editedLyrics ?? initialLyrics,
          onChanged: (val) => _editedLyrics = val,
        );

      case MaterialKind.chord:
        final chordAsync = ref.watch(chordSongProvider(_r2Key));
        final rawContent = ref
            .watch(chordContentLocalDatasourceProvider)
            .read(_r2Key)
            ?.content;

        if (chordAsync.isLoading && rawContent == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final initialChordPro = rawContent ?? '';
        if (!_initialized) {
          _editedChordPro = initialChordPro;
          _initialized = true;
        }

        return ExtractedChordEditor(
          initialChordPro: _editedChordPro ?? initialChordPro,
          onChanged: (val) => _editedChordPro = val,
        );

      case MaterialKind.gesture:
        final gestureAsync = ref.watch(gestureDocumentProvider(_r2Key));
        final initialDoc = gestureAsync.asData?.value;

        if (gestureAsync.isLoading && initialDoc == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final docToEdit = _editedGestureDoc ??
            initialDoc ??
            const GestureDocument(
              schemaMajor: 1,
              title: '',
              dictionaryVersion: 1,
              items: [],
            );

        if (!_initialized && initialDoc != null) {
          _editedGestureDoc = initialDoc;
          _initialized = true;
        }

        return ExtractedGestureEditor(
          initialDocument: docToEdit,
          onChanged: (doc) => _editedGestureDoc = doc,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _submitSuggestion(
    String praiseTitle,
    ContributeFormNotifier notifier,
  ) async {
    final notes = _userNotes.trim();

    switch (widget.materialKind) {
      case MaterialKind.lyrics:
        final lyrics = _editedLyrics?.trim() ?? '';
        final bodyText = notes.isNotEmpty
            ? 'Observações:\n$notes\n\nLetra proposta:\n$lyrics'
            : 'Letra proposta:\n$lyrics';
        notifier.setTitle('Ajuste na Letra: $praiseTitle');
        notifier.setBody(bodyText);

        // Anexa como .txt
        if (lyrics.isNotEmpty) {
          final bytes = utf8.encode(lyrics);
          notifier.setAttachments([
            ContributionAttachment(
              name: 'letra_sugerida.txt',
              size: bytes.length,
              bytes: bytes,
            ),
          ]);
        }

      case MaterialKind.chord:
        final chordPro = _editedChordPro?.trim() ?? '';
        final bodyText = notes.isNotEmpty
            ? 'Observações:\n$notes\n\nCifra proposta (ChordPro):\n$chordPro'
            : 'Cifra proposta (ChordPro):\n$chordPro';
        notifier.setTitle('Ajuste na Cifra: $praiseTitle');
        notifier.setBody(bodyText);

        // Anexa como .chordpro
        if (chordPro.isNotEmpty) {
          final bytes = utf8.encode(chordPro);
          notifier.setAttachments([
            ContributionAttachment(
              name: 'cifra_sugerida.chordpro',
              size: bytes.length,
              bytes: bytes,
            ),
          ]);
        }

      case MaterialKind.gesture:
        final doc = _editedGestureDoc;
        final jsonString = doc != null ? serializeGestureDocument(doc) : '';
        final bodyText = notes.isNotEmpty
            ? 'Observações:\n$notes\n\nGestos sugeridos (${doc?.items.length ?? 0} itens)'
            : 'Gestos sugeridos (${doc?.items.length ?? 0} itens)';
        notifier.setTitle('Ajuste nos Gestos: $praiseTitle');
        notifier.setBody(bodyText);

        // Anexa como .txt
        if (jsonString.isNotEmpty) {
          final bytes = utf8.encode(jsonString);
          notifier.setAttachments([
            ContributionAttachment(
              name: 'gestos_sugeridos.txt',
              size: bytes.length,
              bytes: bytes,
            ),
          ]);
        }

      default:
        break;
    }

    await widget.onSend(widget.snapshot);
  }
}
