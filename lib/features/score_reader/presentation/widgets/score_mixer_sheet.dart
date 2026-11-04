import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/score_document.dart';
import '../providers/score_reader_controller.dart';

/// Mesa de som: instrumento GM, volume, silenciar e solo por pauta (voz).
Future<void> showScoreMixerSheet(BuildContext context, ScoreDocument document) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ScoreMixerSheet(document: document),
  );
}

class ScoreMixerSheet extends ConsumerWidget {
  const ScoreMixerSheet({required this.document, super.key});

  final ScoreDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = scoreReaderControllerProvider(document);
    final mix = ref.watch(provider.select((s) => s.mix));
    final sound = ref.watch(
      provider.select((s) => (font: s.soundFont, audio: s.audio)),
    );
    final controller = ref.read(provider.notifier);
    final anySolo = mix.any((m) => m.solo);
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.scoreReaderMixer,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (sound.font != ScoreSoundFontStatus.full)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  l10n.scoreReaderBasicInstruments,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: document.staves.length,
                itemBuilder: (context, i) {
                  final staff = document.staves[i];
                  final m = mix[i];
                  final audible = !m.muted && (!anySolo || m.solo);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 112,
                              child: Text(
                                staff.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: audible
                                      ? colors.onSurface
                                      : colors.onSurface.withValues(
                                          alpha: 0.45,
                                        ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: m.volume,
                                onChanged: (v) =>
                                    controller.setStaffVolume(i, v),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.scoreReaderMute,
                              isSelected: m.muted,
                              icon: const Icon(Icons.volume_up_outlined),
                              selectedIcon: const Icon(Icons.volume_off),
                              onPressed: () => controller.toggleStaffMute(i),
                            ),
                            IconButton(
                              tooltip: l10n.scoreReaderSolo,
                              isSelected: m.solo,
                              icon: const Icon(Icons.headphones_outlined),
                              selectedIcon: const Icon(Icons.headphones),
                              onPressed: () => controller.toggleStaffSolo(i),
                            ),
                          ],
                        ),
                        Semantics(
                          container: true,
                          label: staff.label,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.scoreReaderInstrument,
                              errorText: m.programFailed
                                  ? l10n.scoreReaderInstrumentFailed
                                  : null,
                              errorMaxLines: 3,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                key: ValueKey('score-reader-program-$i'),
                                value: m.program,
                                isExpanded: true,
                                isDense: true,
                                menuMaxHeight: 320,
                                icon: m.programChanging
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_drop_down),
                                items: [
                                  for (
                                    var program = 0;
                                    program < 128;
                                    program++
                                  )
                                    DropdownMenuItem(
                                      value: program,
                                      child: Text(
                                        'GM${(program + 1).toString().padLeft(3, '0')}',
                                      ),
                                    ),
                                ],
                                onChanged:
                                    m.programChanging ||
                                        sound.audio != ScoreAudioStatus.ready
                                    ? null
                                    : (program) {
                                        if (program != null) {
                                          controller.setStaffProgram(
                                            i,
                                            program,
                                          );
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
