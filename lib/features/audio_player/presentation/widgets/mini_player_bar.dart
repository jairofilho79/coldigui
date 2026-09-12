import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/audio_player_position_provider.dart';
import '../providers/audio_player_session_provider.dart';
import 'mini_player_bar_metrics.dart';

/// Mini-player persistente (D5) — 44 px: título, transporte e progresso finos.
///
/// Vive no `ShellScaffold`, fora da face de áudio (que já mostra estes
/// controles — [CarouselAudioFaceBar]) e sobrevive ao fullscreen do leitor
/// como overlay translúcido ([overlay] = `true`) sobre o `navigationShell`.
///
/// Controles próprios (não reaproveita `AudioTransportControls`, que outra
/// tarefa da onda edita em paralelo): faixa anterior / play-pausa / próxima,
/// ligados a [AudioPlayerSessionNotifier.skipToPrevious]/`playPause`/
/// `skipToNext`.
///
/// Sem faixa tocando ([AudioPlayerSessionState.currentTrack] nulo), não
/// desenha nada (`SizedBox.shrink`).
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({this.overlay = false, super.key});

  /// `true`: versão translúcida (fullscreen) — some no repouso e volta ao
  /// normal no hover/toque, como o FAB de sair do leitor.
  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      audioPlayerSessionProvider.select((s) => s.currentTrack),
    );
    if (track == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final playing = ref.watch(
      audioPlayerSessionProvider.select((s) => s.playing),
    );
    final buffering = ref.watch(
      audioPlayerSessionProvider.select((s) => s.buffering),
    );
    final hasPrevious = ref.watch(
      audioPlayerSessionProvider.select((s) => s.hasPrevious),
    );
    final hasNext = ref.watch(
      audioPlayerSessionProvider.select((s) => s.hasNext),
    );
    final errorMessage = ref.watch(
      audioPlayerSessionProvider.select((s) => s.errorMessage),
    );
    final progress = ref.watch(
      audioPlayerPositionProvider.select((p) => p.progress),
    );

    final fg = overlay ? AppColors.textLight : AppColors.title;
    final title = track.numero.isNotEmpty
        ? '${track.numero} — ${track.nome}'
        : track.nome;
    final iconButtonStyle = IconButton.styleFrom(
      foregroundColor: fg,
      disabledForegroundColor: fg.withValues(alpha: 0.35),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final bar = Material(
      color: overlay ? Colors.black.withValues(alpha: 0.72) : AppColors.card,
      child: SizedBox(
        height: kMiniPlayerBarHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: fg.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (errorMessage != null)
                      Tooltip(
                        message: l10n.audioPlaybackError,
                        child: Icon(
                          Icons.error_outline,
                          color: AppColors.offlineMissing,
                          size: 18,
                        ),
                      ),
                    IconButton(
                      tooltip: l10n.miniPlayerPrevious,
                      iconSize: 20,
                      style: iconButtonStyle,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: hasPrevious
                          ? () => ref
                                .read(audioPlayerSessionProvider.notifier)
                                .skipToPrevious()
                          : null,
                    ),
                    IconButton(
                      tooltip: playing ? l10n.audioPause : l10n.audioPlay,
                      iconSize: 24,
                      style: iconButtonStyle,
                      icon: buffering
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: fg,
                              ),
                            )
                          : Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: buffering
                          ? null
                          : () => ref
                                .read(audioPlayerSessionProvider.notifier)
                                .playPause(),
                    ),
                    IconButton(
                      tooltip: l10n.miniPlayerNext,
                      iconSize: 20,
                      style: iconButtonStyle,
                      icon: const Icon(Icons.skip_next),
                      onPressed: hasNext
                          ? () => ref
                                .read(audioPlayerSessionProvider.notifier)
                                .skipToNext()
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!overlay) return bar;
    return _HoverFade(child: bar);
  }
}

/// Opacidade 0.35 em repouso, 1 no hover (mouse) ou toque — mesmo padrão do
/// FAB de sair do leitor (`pdf_reader_screen.dart`), para o overlay não
/// atrapalhar a leitura da partitura por baixo.
class _HoverFade extends StatefulWidget {
  const _HoverFade({required this.child});

  final Widget child;

  @override
  State<_HoverFade> createState() => _HoverFadeState();
}

class _HoverFadeState extends State<_HoverFade> {
  var _active = false;

  void _setActive(bool value) {
    if (_active == value) return;
    setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // Fix wave onda 4 (Important 3): não-opaca — o padrão (`true`) fazia
      // esta `MouseRegion` absorver qualquer toque dentro dos seus limites,
      // mesmo em área em branco da faixa, e o leitor por baixo (no overlay
      // de tela cheia do `shell_scaffold.dart`) nunca via o toque. Com
      // `opaque: false` e o `Listener` abaixo em `translucent`, só uma área
      // com controle de verdade (os botões) continua exclusiva; o resto
      // passa pro que está por baixo.
      opaque: false,
      onEnter: (_) => _setActive(true),
      onExit: (_) => _setActive(false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setActive(true),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _active ? 1 : 0.35,
          child: widget.child,
        ),
      ),
    );
  }
}
