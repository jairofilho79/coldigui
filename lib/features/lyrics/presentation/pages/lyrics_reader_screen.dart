import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../autoscroll/domain/entities/autoscroll_adjustment.dart';
import '../../../autoscroll/presentation/providers/autoscroll_telemetry_providers.dart';
import '../../../autoscroll/presentation/widgets/autoscroll_speed_slider_bar.dart';
import '../../../coldigom/presentation/providers/coldigom_catalog_providers.dart';
import '../../../contributions/domain/entities/contribution_kind.dart';
import '../../../contributions/domain/entities/contribution_target.dart';
import '../../../contributions/presentation/utils/open_contribute.dart';
import '../../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../domain/entities/lyrics_reader_font_size.dart';
import '../providers/lyrics_autoscroll_provider.dart';
import '../providers/lyrics_reader_font_size_provider.dart';

const Key lyricsReaderAutoscrollKey = Key('lyricsReaderAutoscroll');
const Key lyricsReaderSpeedKey = Key('lyricsReaderSpeed');
const Key lyricsReaderFullscreenKey = Key('lyricsReaderFullscreen');

/// Leitor de letra Coldigom (`/letra?praiseId=`) — O6.
///
/// Lê o texto da linha do catálogo ([coldigomCatalogRowProvider]: Isar, ou
/// as linhas em memória sem Isar), nunca da rede: a letra vem inteira no
/// dump do catálogo e está sempre offline.
/// Conta com player e controle magnético de autoscroll unificado.
class LyricsReaderScreen extends ConsumerStatefulWidget {
  const LyricsReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<LyricsReaderScreen> createState() => _LyricsReaderScreenState();
}

class _LyricsReaderScreenState extends ConsumerState<LyricsReaderScreen>
    with SingleTickerProviderStateMixin {
  late final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'lyricsReaderKeys',
  );
  final ScrollController _scrollController = ScrollController();

  Ticker? _autoscrollTicker;
  Duration? _autoscrollLastTick;
  var _showSpeedSlider = false;

  String get _praiseId => widget.queryParams[UrlSyncParams.praiseId] ?? '';

  void _applySpeedRecommendation() {
    final praiseId = _praiseId;
    if (praiseId.isEmpty) return;
    final fontSize = ref.read(lyricsReaderFontSizeProvider);
    final rec = ref
        .read(autoscrollTelemetryDatasourceProvider)
        .getRecommendedSpeed(
          praiseId: praiseId,
          currentFontSize: fontSize,
          materialKind: 'lyrics',
        );
    if (rec != null) {
      ref.read(lyricsAutoscrollProvider.notifier).setSpeed(rec);
    }
  }

  void _onSpeedChanged(int speed) {
    ref.read(lyricsAutoscrollProvider.notifier).setSpeed(speed);
    final praiseId = _praiseId;
    if (praiseId.isNotEmpty) {
      final fontSize = ref.read(lyricsReaderFontSizeProvider);
      ref.read(autoscrollTelemetryDatasourceProvider).recordAdjustment(
            AutoscrollAdjustment(
              praiseId: praiseId,
              materialKind: 'lyrics',
              speed: speed,
              fontSize: fontSize,
              timestamp: DateTime.now(),
            ),
          );
    }
  }

  @override
  void initState() {
    super.initState();
    clearSnackbarsOnEnter(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applySpeedRecommendation();
    });
  }

  @override
  void didUpdateWidget(covariant LyricsReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.queryParams[UrlSyncParams.praiseId];
    final newId = widget.queryParams[UrlSyncParams.praiseId];
    if (oldId != newId) {
      _stopAutoscroll();
      _showSpeedSlider = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applySpeedRecommendation();
      });
    }
  }

  @override
  void dispose() {
    _autoscrollTicker?.dispose();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _ensureAutoscrollTicker() {
    _autoscrollTicker ??= createTicker(_onAutoscrollTick);
    if (!_autoscrollTicker!.isActive) {
      _autoscrollLastTick = null;
      _autoscrollTicker!.start();
    }
  }

  void _onAutoscrollTick(Duration elapsed) {
    final lastTick = _autoscrollLastTick;
    _autoscrollLastTick = elapsed;
    if (lastTick == null) return;

    if (!ref.read(lyricsAutoscrollProvider).running) {
      _autoscrollTicker?.stop();
      return;
    }
    if (!_scrollController.hasClients) return;

    final dtSeconds =
        (elapsed - lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    if (dtSeconds <= 0) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      ref.read(lyricsAutoscrollProvider.notifier).stop();
      return;
    }

    final speed = ref.read(lyricsAutoscrollProvider).speed;
    final delta = speed * kLyricsAutoscrollPxPerSecondPerSpeed * dtSeconds;
    final next = (position.pixels + delta).clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(next);

    if (next >= position.maxScrollExtent) {
      ref.read(lyricsAutoscrollProvider.notifier).stop();
    }
  }

  void _stopAutoscroll() {
    _autoscrollTicker?.stop();
    if (!ref.read(lyricsAutoscrollProvider).running) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lyricsAutoscrollProvider.notifier).stop();
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    final commandModifier = keyboard.isControlPressed || keyboard.isMetaPressed;
    final key = event.logicalKey;

    if (commandModifier) {
      if (key == LogicalKeyboardKey.arrowUp) {
        ref.read(lyricsReaderFontSizeProvider.notifier).increase();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        ref.read(lyricsReaderFontSizeProvider.notifier).decrease();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!keyboardFocusIsInsideTextField()) {
      if (key == LogicalKeyboardKey.keyS) {
        ref.read(lyricsAutoscrollProvider.notifier).toggle();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketRight) {
        final speed = ref.read(lyricsAutoscrollProvider).speed;
        _onSpeedChanged(speed + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.bracketLeft) {
        final speed = ref.read(lyricsAutoscrollProvider).speed;
        _onSpeedChanged(speed - 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape && _showSpeedSlider) {
        setState(() => _showSpeedSlider = false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = ref.watch(lyricsReaderFontSizeProvider);
    final autoscroll = ref.watch(lyricsAutoscrollProvider);
    final row = ref.watch(coldigomCatalogRowProvider(_praiseId));
    final title = widget.queryParams[UrlSyncParams.titulo] ?? row?.name ?? '';
    final text = row?.lyrics.trim() ?? '';

    ref.listen<LyricsAutoscrollState>(lyricsAutoscrollProvider, (previous, next) {
      if (next.running) {
        _ensureAutoscrollTicker();
      } else {
        _autoscrollTicker?.stop();
      }
    });

    ref.listen<double>(lyricsReaderFontSizeProvider, (previous, next) {
      if (previous == null || previous == next) return;
      final praiseId = _praiseId;
      if (praiseId.isEmpty) return;
      final rec = ref
          .read(autoscrollTelemetryDatasourceProvider)
          .getRecommendedSpeed(
            praiseId: praiseId,
            currentFontSize: next,
            materialKind: 'lyrics',
          );
      if (rec != null) {
        ref.read(lyricsAutoscrollProvider.notifier).setSpeed(rec);
      }
    });

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: (_) => _keyboardFocusNode.requestFocus(),
        child: ColoredBox(
          color: AppColors.card,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LyricsToolbar(
                  title: title,
                  fontSize: fontSize,
                  autoscroll: autoscroll,
                  showSpeedSlider: _showSpeedSlider,
                  onToggleSpeedSlider: () =>
                      setState(() => _showSpeedSlider = !_showSpeedSlider),
                  l10n: l10n,
                  praiseId: _praiseId,
                ),
                if (_showSpeedSlider)
                  AutoscrollSpeedSliderBar(
                    speed: autoscroll.speed,
                    onSpeedChanged: _onSpeedChanged,
                    onClose: () => setState(() => _showSpeedSlider = false),
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.textDark,
                    activeColor: AppColors.title,
                    inactiveColor: AppColors.textDark.withValues(alpha: 0.25),
                    dividerColor: AppColors.gold.withValues(alpha: 0.3),
                  ),
                const Divider(color: AppColors.gold, height: 1, thickness: 1.5),
                Expanded(
                  child: SpotlightGuideTarget(
                    id: 'lyrics-content-view',
                    child: text.isEmpty
                        ? Center(
                            child: Text(
                              l10n.lyricsReaderEmpty,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textDark.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : NotificationListener<UserScrollNotification>(
                            onNotification: (notification) {
                              if (notification.direction != ScrollDirection.idle) {
                                ref.read(lyricsAutoscrollProvider.notifier).stop();
                              }
                              return false;
                            },
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                              child: SelectableText(
                                text,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textDark,
                                  fontSize: fontSize,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título do louvor + A−/A+ + Autoscroll + Sugerir melhoria.
class _LyricsToolbar extends ConsumerWidget {
  const _LyricsToolbar({
    required this.title,
    required this.fontSize,
    required this.autoscroll,
    required this.showSpeedSlider,
    required this.onToggleSpeedSlider,
    required this.l10n,
    required this.praiseId,
  });

  final String title;
  final double fontSize;
  final LyricsAutoscrollState autoscroll;
  final bool showSpeedSlider;
  final VoidCallback onToggleSpeedSlider;
  final AppLocalizations l10n;
  final String praiseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.read(lyricsReaderFontSizeProvider.notifier);
    final autoscrollNotifier = ref.read(lyricsAutoscrollProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.isEmpty ? l10n.lyricsTitle : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headline.copyWith(
                color: AppColors.title,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SpotlightGuideTarget(
            id: 'lyrics-font-size-controls',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.lyricsReaderDecreaseFont,
                  icon: const Icon(Icons.text_decrease, color: AppColors.title),
                  onPressed: LyricsReaderFontSize.canDecrease(fontSize)
                      ? size.decrease
                      : null,
                ),
                IconButton(
                  tooltip: l10n.lyricsReaderIncreaseFont,
                  icon: const Icon(Icons.text_increase, color: AppColors.title),
                  onPressed: LyricsReaderFontSize.canIncrease(fontSize)
                      ? size.increase
                      : null,
                ),
              ],
            ),
          ),
          SpotlightGuideTarget(
            id: 'lyrics-autoscroll-controls',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: lyricsReaderAutoscrollKey,
                  tooltip: autoscroll.running
                      ? l10n.lyricsAutoscrollPause
                      : l10n.lyricsAutoscrollPlay,
                  icon: Icon(
                    autoscroll.running
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: AppColors.title,
                  ),
                  onPressed: autoscrollNotifier.toggle,
                ),
                IconButton(
                  key: lyricsReaderSpeedKey,
                  tooltip: l10n.autoscrollSpeedTooltip,
                  icon: Icon(
                    Icons.speed,
                    color: showSpeedSlider ? AppColors.gold : AppColors.title,
                  ),
                  onPressed: onToggleSpeedSlider,
                ),
              ],
            ),
          ),
          SpotlightGuideTarget(
            id: 'lyrics-fullscreen-button',
            child: IconButton(
              key: lyricsReaderFullscreenKey,
              tooltip: ref.watch(readerFullscreenProvider)
                  ? l10n.readerExitFullscreenTooltip
                  : l10n.readerFullscreenTooltip,
              icon: Icon(
                ref.watch(readerFullscreenProvider)
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                color: AppColors.title,
              ),
              onPressed: () => ref.read(toggleReaderFullscreenProvider).call(),
            ),
          ),
          IconButton(
            tooltip: l10n.contributeReportTooltip,
            icon: const Icon(Icons.handshake_outlined, color: AppColors.title),
            onPressed: praiseId.isEmpty
                ? null
                : () => openContribute(
                      context,
                      target: ContributionTarget(
                        source: ContributionSource.coldigom,
                        praiseId: praiseId,
                        materialId: 'lyrics:$praiseId',
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
