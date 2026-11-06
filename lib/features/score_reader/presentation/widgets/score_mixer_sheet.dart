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
    final state = ref.watch(
      provider.select(
        (s) => (
          mix: s.mix,
          chordMix: s.chordMix,
          chordEnabled: s.chordAccompanimentEnabled,
          chordSource: s.chordSourceStaffIndex,
          selectedStaves: s.selectedStaffIndices,
          maximumStaves: s.maximumPlayableStaffCount,
          capacityExceeded: s.exceedsPlaybackCapacity,
          audio: s.audio,
        ),
      ),
    );
    final sound = ref.watch(
      provider.select((s) => (font: s.soundFont, audio: s.audio)),
    );
    final controller = ref.read(provider.notifier);
    final anySolo =
        state.mix.indexed.any(
          (entry) => state.selectedStaves.contains(entry.$1) && entry.$2.solo,
        ) ||
        (state.chordEnabled && state.chordMix.solo);
    final colors = Theme.of(context).colorScheme;
    final showStaffSelection = document.staves.length > 14;

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
                itemCount: document.staves.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showStaffSelection)
                            _StaffCapacityWarning(
                              selected: state.selectedStaves.length,
                              total: document.staves.length,
                              maximum: state.maximumStaves,
                              exceeded: state.capacityExceeded,
                            ),
                          if (document.chordSymbolCount > 0)
                            _ChordMixerControls(
                              document: document,
                              mix: state.chordMix,
                              enabled: state.chordEnabled,
                              sourceStaffIndex: state.chordSource,
                              audio: state.audio,
                              maximumStaffCount: state.maximumStaves,
                              controller: controller,
                            ),
                        ],
                      ),
                    );
                  }
                  final staffIndex = i - 1;
                  final staff = document.staves[staffIndex];
                  final m = state.mix[staffIndex];
                  final selected = state.selectedStaves.contains(staffIndex);
                  final audible = selected && !m.muted && (!anySolo || m.solo);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        if (showStaffSelection)
                          Semantics(
                            label: l10n.scoreReaderPlayStaff(staff.label),
                            child: CheckboxListTile(
                              key: ValueKey(
                                'score-reader-play-staff-$staffIndex',
                              ),
                              contentPadding: EdgeInsets.zero,
                              title: Text(staff.label),
                              value: selected,
                              onChanged: (value) {
                                if (value != null) {
                                  controller.setStaffSelected(
                                    staffIndex,
                                    value,
                                  );
                                }
                              },
                            ),
                          ),
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
                              child: Semantics(
                                label: staff.label,
                                child: Slider(
                                  key: ValueKey(
                                    'score-reader-staff-volume-$staffIndex',
                                  ),
                                  value: m.volume,
                                  onChanged: (v) =>
                                      controller.setStaffVolume(staffIndex, v),
                                ),
                              ),
                            ),
                            IconButton(
                              key: ValueKey(
                                'score-reader-staff-mute-$staffIndex',
                              ),
                              tooltip: l10n.scoreReaderMute,
                              isSelected: m.muted,
                              icon: const Icon(Icons.volume_up_outlined),
                              selectedIcon: const Icon(Icons.volume_off),
                              onPressed: () =>
                                  controller.toggleStaffMute(staffIndex),
                            ),
                            IconButton(
                              key: ValueKey(
                                'score-reader-staff-solo-$staffIndex',
                              ),
                              tooltip: l10n.scoreReaderSolo,
                              isSelected: m.solo,
                              icon: const Icon(Icons.headphones_outlined),
                              selectedIcon: const Icon(Icons.headphones),
                              onPressed: () =>
                                  controller.toggleStaffSolo(staffIndex),
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
                                key: ValueKey(
                                  'score-reader-program-$staffIndex',
                                ),
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
                                        sound.audio ==
                                            ScoreAudioStatus.loading ||
                                        sound.audio == ScoreAudioStatus.failed
                                    ? null
                                    : (program) {
                                        if (program != null) {
                                          controller.setStaffProgram(
                                            staffIndex,
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

class _StaffCapacityWarning extends StatelessWidget {
  const _StaffCapacityWarning({
    required this.selected,
    required this.total,
    required this.maximum,
    required this.exceeded,
  });

  final int selected;
  final int total;
  final int maximum;
  final bool exceeded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final message = [
      l10n.scoreReaderStaffCapacityWarning,
      l10n.scoreReaderStaffCapacityLimit(maximum),
      l10n.scoreReaderSelectedStaffCount(selected, total),
    ].join(' ');
    return Semantics(
      key: const ValueKey('score-reader-capacity-warning'),
      container: true,
      liveRegion: true,
      label: message,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: exceeded
              ? colors.errorContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: exceeded ? colors.onErrorContainer : colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: exceeded ? colors.onErrorContainer : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChordMixerControls extends StatelessWidget {
  const _ChordMixerControls({
    required this.document,
    required this.mix,
    required this.enabled,
    required this.sourceStaffIndex,
    required this.audio,
    required this.maximumStaffCount,
    required this.controller,
  });

  final ScoreDocument document;
  final ScoreChordMix mix;
  final bool enabled;
  final int? sourceStaffIndex;
  final ScoreAudioStatus audio;
  final int maximumStaffCount;
  final ScoreReaderController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chordStaves = document.score.parts.indexed
        .where((entry) => entry.$2.chordSymbols.isNotEmpty)
        .map((entry) => entry.$1)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('score-reader-chord-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.scoreReaderChordAccompaniment),
          subtitle: document.staves.length > 14
              ? Text(l10n.scoreReaderStaffCapacityLimit(maximumStaffCount))
              : null,
          value: enabled,
          onChanged: controller.setChordAccompanimentEnabled,
        ),
        if (sourceStaffIndex != null)
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.scoreReaderChordSource),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const ValueKey('score-reader-chord-source'),
                value: sourceStaffIndex,
                isExpanded: true,
                items: [
                  for (final staffIndex in chordStaves)
                    DropdownMenuItem(
                      value: staffIndex,
                      child: Text(document.staves[staffIndex].label),
                    ),
                ],
                onChanged: (staff) {
                  if (staff != null) controller.setChordSource(staff);
                },
              ),
            ),
          ),
        Row(
          children: [
            SizedBox(
              width: 112,
              child: Text(
                l10n.scoreReaderChordVolume,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Semantics(
                label: l10n.scoreReaderChordVolume,
                child: Slider(
                  key: const ValueKey('score-reader-chord-volume'),
                  value: mix.volume,
                  onChanged: controller.setChordVolume,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('score-reader-chord-mute'),
              tooltip: l10n.scoreReaderChordMute,
              isSelected: mix.muted,
              icon: const Icon(Icons.volume_up_outlined),
              selectedIcon: const Icon(Icons.volume_off),
              onPressed: controller.toggleChordMute,
            ),
            IconButton(
              key: const ValueKey('score-reader-chord-solo'),
              tooltip: l10n.scoreReaderChordSolo,
              isSelected: mix.solo,
              icon: const Icon(Icons.headphones_outlined),
              selectedIcon: const Icon(Icons.headphones),
              onPressed: controller.toggleChordSolo,
            ),
          ],
        ),
        Semantics(
          container: true,
          label: l10n.scoreReaderChordAccompaniment,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.scoreReaderChordInstrument,
              errorText: mix.programFailed
                  ? l10n.scoreReaderChordInstrumentFailed
                  : null,
              errorMaxLines: 3,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                key: const ValueKey('score-reader-chord-program'),
                value: mix.program,
                isExpanded: true,
                isDense: true,
                menuMaxHeight: 320,
                icon: mix.programChanging
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_drop_down),
                items: [
                  for (var program = 0; program < 128; program++)
                    DropdownMenuItem(
                      value: program,
                      child: Text(
                        'GM${(program + 1).toString().padLeft(3, '0')}',
                      ),
                    ),
                ],
                onChanged:
                    mix.programChanging ||
                        audio == ScoreAudioStatus.loading ||
                        audio == ScoreAudioStatus.failed
                    ? null
                    : (program) {
                        if (program != null) {
                          controller.setChordProgram(program);
                        }
                      },
              ),
            ),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }
}
