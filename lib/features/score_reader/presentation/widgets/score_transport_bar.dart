import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/score_document.dart';
import '../providers/score_reader_controller.dart';
import 'score_mixer_sheet.dart';
import 'score_sheet_view.dart';

const Key scoreReaderPlayKey = ValueKey('score-reader-play');
const Key scoreReaderStopKey = ValueKey('score-reader-stop');
const Key scoreReaderTransposeUpKey = ValueKey('score-reader-transpose-up');
const Key scoreReaderTransposeDownKey = ValueKey('score-reader-transpose-down');
const Key scoreReaderTempoKey = ValueKey('score-reader-tempo');
const Key scoreReaderLoopKey = ValueKey('score-reader-loop');
const Key scoreReaderMixerKey = ValueKey('score-reader-mixer');
const Key scoreReaderSoundKey = ValueKey('score-reader-sound');
const Key scoreReaderModeKey = ValueKey('score-reader-mode');

ButtonStyle _buttonStyle(Color color) => IconButton.styleFrom(
  foregroundColor: color,
  disabledForegroundColor: color.withValues(alpha: 0.38),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: const Size(44, 44),
);

/// Barra 3 do leitor de partitura: execução, tom, andamento, loop A-B,
/// mixer, zoom, modo de página e timbres.
class ScoreTransportBar extends ConsumerWidget {
  const ScoreTransportBar({
    required this.document,
    required this.mode,
    required this.onModeChanged,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.showTempo,
    required this.onToggleTempo,
    super.key,
  });

  final ScoreDocument document;
  final ScoreViewMode mode;
  final ValueChanged<ScoreViewMode> onModeChanged;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final bool showTempo;
  final VoidCallback onToggleTempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final provider = scoreReaderControllerProvider(document);
    final controller = ref.read(provider.notifier);
    final s = ref.watch(
      provider.select(
        (s) => (
          playing: s.playing,
          audio: s.audio,
          transpose: s.transpose,
          bpm: s.bpm.round(),
          loopStart: s.loopStart,
          loopEnd: s.loopEnd,
        ),
      ),
    );
    final style = _buttonStyle(colors.onSurface);
    final audioReady = s.audio == ScoreAudioStatus.ready;
    final transposeLabel = s.transpose > 0
        ? '+${s.transpose}'
        : '${s.transpose}';

    final String loopTooltip;
    if (s.loopStart == null) {
      loopTooltip = '${l10n.scoreReaderLoopStart}\n${l10n.scoreReaderLoopHint}';
    } else if (s.loopEnd == null) {
      loopTooltip = l10n.scoreReaderLoopEnd;
    } else {
      loopTooltip =
          '${l10n.scoreReaderLoopRange(s.loopStart! + 1, s.loopEnd! + 1)}\n'
          '${l10n.scoreReaderLoopClear}';
    }

    Widget divider() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: colors.outlineVariant,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            key: scoreReaderPlayKey,
            style: style,
            tooltip: s.playing ? l10n.scoreReaderPause : l10n.scoreReaderPlay,
            onPressed: audioReady ? controller.togglePlay : null,
            icon: Icon(s.playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            key: scoreReaderStopKey,
            style: style,
            tooltip: l10n.scoreReaderStop,
            onPressed: audioReady ? controller.stop : null,
            icon: const Icon(Icons.skip_previous),
          ),
          divider(),
          IconButton(
            key: scoreReaderTransposeDownKey,
            style: style,
            tooltip: l10n.scoreReaderTransposeDown,
            onPressed: s.transpose > -kScoreMaxTranspose
                ? () => controller.setTranspose(s.transpose - 1)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Tooltip(
            message: l10n.scoreReaderTransposeReset,
            child: InkWell(
              onTap: s.transpose == 0 ? null : () => controller.setTranspose(0),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 36,
                height: 44,
                child: Center(
                  child: Text(
                    transposeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s.transpose == 0 ? null : colors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: scoreReaderTransposeUpKey,
            style: style,
            tooltip: l10n.scoreReaderTransposeUp,
            onPressed: s.transpose < kScoreMaxTranspose
                ? () => controller.setTranspose(s.transpose + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
          divider(),
          TextButton.icon(
            key: scoreReaderTempoKey,
            onPressed: onToggleTempo,
            style: TextButton.styleFrom(
              foregroundColor: showTempo ? colors.primary : colors.onSurface,
              minimumSize: const Size(44, 44),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.speed),
            label: Text(l10n.scoreReaderBpm(s.bpm)),
          ),
          IconButton(
            key: scoreReaderLoopKey,
            style: style,
            tooltip: loopTooltip,
            isSelected: s.loopStart != null,
            color: s.loopStart != null ? colors.primary : null,
            onPressed: controller.cycleLoop,
            icon: Text(
              s.loopStart == null
                  ? 'A-B'
                  : s.loopEnd == null
                  ? 'A…'
                  : '${s.loopStart! + 1}-${s.loopEnd! + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: s.loopStart != null ? colors.primary : colors.onSurface,
              ),
            ),
          ),
          IconButton(
            key: scoreReaderMixerKey,
            style: style,
            tooltip: l10n.scoreReaderMixer,
            onPressed: () => showScoreMixerSheet(context, document),
            icon: const Icon(Icons.tune),
          ),
          divider(),
          IconButton(
            style: style,
            tooltip: l10n.scoreReaderZoomOut,
            onPressed: onZoomOut,
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            style: style,
            tooltip: l10n.scoreReaderZoomIn,
            onPressed: onZoomIn,
            icon: const Icon(Icons.zoom_in),
          ),
          IconButton(
            key: scoreReaderModeKey,
            style: style,
            tooltip: mode == ScoreViewMode.continuous
                ? l10n.scoreReaderModePages
                : l10n.scoreReaderModeContinuous,
            onPressed: () => onModeChanged(
              mode == ScoreViewMode.continuous
                  ? ScoreViewMode.pages
                  : ScoreViewMode.continuous,
            ),
            icon: Icon(
              mode == ScoreViewMode.continuous
                  ? Icons.auto_stories_outlined
                  : Icons.view_day_outlined,
            ),
          ),
          divider(),
          _SoundFontButton(document: document, style: style),
        ],
      ),
    );
  }
}

/// Estado dos timbres: som básico (toca já) → baixando → timbres reais.
class _SoundFontButton extends ConsumerWidget {
  const _SoundFontButton({required this.document, required this.style});

  final ScoreDocument document;
  final ButtonStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final provider = scoreReaderControllerProvider(document);
    final s = ref.watch(
      provider.select(
        (s) =>
            (audio: s.audio, sound: s.soundFont, progress: s.soundFontProgress),
      ),
    );
    final controller = ref.read(provider.notifier);

    if (s.audio == ScoreAudioStatus.failed) {
      return IconButton(
        key: scoreReaderSoundKey,
        style: style,
        tooltip: l10n.scoreReaderAudioUnavailable,
        onPressed: null,
        icon: const Icon(Icons.volume_off_outlined),
      );
    }
    switch (s.sound) {
      case ScoreSoundFontStatus.downloading:
        final progress = s.progress;
        return Tooltip(
          key: scoreReaderSoundKey,
          message: progress == null
              ? l10n.scoreReaderSoundDownloading
              : l10n.scoreReaderSoundDownloadingPercent(
                  (progress * 100).round(),
                ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  value: progress,
                ),
              ),
            ),
          ),
        );
      case ScoreSoundFontStatus.full:
        return IconButton(
          key: scoreReaderSoundKey,
          style: style,
          tooltip: l10n.scoreReaderSoundFull,
          onPressed: null,
          icon: Icon(Icons.piano, color: colors.primary),
        );
      case ScoreSoundFontStatus.failed:
        return IconButton(
          key: scoreReaderSoundKey,
          style: style,
          tooltip: l10n.scoreReaderSoundFailed,
          onPressed: s.audio == ScoreAudioStatus.ready
              ? controller.downloadFullSoundFont
              : null,
          icon: Icon(Icons.sync_problem, color: colors.error),
        );
      case ScoreSoundFontStatus.minimal:
        return IconButton(
          key: scoreReaderSoundKey,
          style: style,
          tooltip: l10n.scoreReaderSoundMinimal,
          onPressed: s.audio == ScoreAudioStatus.ready
              ? controller.downloadFullSoundFont
              : null,
          icon: const Icon(Icons.download_for_offline_outlined),
        );
    }
  }
}

/// Andamento em bpm (semínima), de ¼ ao dobro do original.
class ScoreTempoBar extends ConsumerWidget {
  const ScoreTempoBar({required this.document, super.key});

  final ScoreDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = scoreReaderControllerProvider(document);
    final speed = ref.watch(provider.select((s) => s.speed));
    final controller = ref.read(provider.notifier);
    final base = document.quarterBpm;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 20),
          Expanded(
            child: Slider(
              min: kScoreMinSpeed,
              max: kScoreMaxSpeed,
              value: speed,
              label: l10n.scoreReaderBpm((base * speed).round()),
              divisions: ((kScoreMaxSpeed - kScoreMinSpeed) / 0.05).round(),
              onChanged: controller.setSpeed,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              l10n.scoreReaderBpm((base * speed).round()),
              textAlign: TextAlign.end,
            ),
          ),
          IconButton(
            tooltip: l10n.scoreReaderTempoReset,
            onPressed: speed == 1 ? null : () => controller.setSpeed(1),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
    );
  }
}

/// Barra de progresso com busca, abaixo da partitura.
class ScoreProgressBar extends ConsumerStatefulWidget {
  const ScoreProgressBar({required this.document, super.key});

  final ScoreDocument document;

  @override
  ConsumerState<ScoreProgressBar> createState() => _ScoreProgressBarState();
}

class _ScoreProgressBarState extends ConsumerState<ScoreProgressBar> {
  double? _dragging;

  static String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final provider = scoreReaderControllerProvider(widget.document);
    final s = ref.watch(
      provider.select((s) => (position: s.position, duration: s.duration)),
    );
    final total = s.duration.inMilliseconds;
    if (total <= 0) return const SizedBox.shrink();
    final value =
        _dragging ?? (s.position.inMilliseconds / total).clamp(0.0, 1.0);
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(_format(s.position), style: textStyle),
          Expanded(
            child: Slider(
              value: value,
              onChanged: (v) => setState(() => _dragging = v),
              onChangeEnd: (v) {
                setState(() => _dragging = null);
                ref
                    .read(provider.notifier)
                    .seek(Duration(milliseconds: (v * total).round()));
              },
            ),
          ),
          Text(_format(s.duration), style: textStyle),
        ],
      ),
    );
  }
}
