import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/pdf_path_normalizer.dart';
import '../../../../core/utils/url_sync_params.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_shell/presentation/widgets/app_shortcuts.dart';
import '../../../pdf_reader/domain/entities/carousel_reader_position.dart';
import '../../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import '../../data/providers/score_providers.dart';
import '../../domain/entities/score_document.dart';
import '../providers/score_music_font_provider.dart';
import '../providers/score_reader_controller.dart';
import '../widgets/score_sheet_view.dart';
import '../widgets/score_transport_bar.dart';

const Key scoreReaderRetryKey = ValueKey('score-reader-retry');

const double _minStaffSpace = 4;
const double _maxStaffSpace = 16;
const double _zoomStep = 1.25;

/// Leitor de partituras digitais (`.mscz`, `.mxl`, `.musicxml`) — rota
/// `/partitura`, filha do [ShellScaffold].
///
/// Mesmo contrato de rota do leitor de gestos: [UrlSyncParams.pdfId] é o id
/// do material (o `r2Key` codificado), publicado em
/// [readerRouteParamsProvider] para o carrossel sincronizar o chip.
class ScoreReaderScreen extends ConsumerStatefulWidget {
  const ScoreReaderScreen({required this.queryParams, super.key});

  final Map<String, String> queryParams;

  @override
  ConsumerState<ScoreReaderScreen> createState() => _ScoreReaderScreenState();
}

class _ScoreReaderScreenState extends ConsumerState<ScoreReaderScreen> {
  late final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'scoreReaderKeys',
  );
  var _louvorNavigationInProgress = false;

  @override
  void initState() {
    super.initState();
    clearSnackbarsOnEnter(context);
    _schedulePublishRouteParams();
  }

  @override
  void didUpdateWidget(ScoreReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mapEquals(widget.queryParams, oldWidget.queryParams)) return;
    _schedulePublishRouteParams();
  }

  void _schedulePublishRouteParams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readerRouteParamsProvider.notifier).update(widget.queryParams);
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  String get _r2Key {
    final id = widget.queryParams[UrlSyncParams.pdfId] ?? '';
    if (id.isEmpty) return '';
    try {
      return PdfPathNormalizer.getPdfRelPath(id);
    } on Object {
      return '';
    }
  }

  Future<void> _navigateLouvor(CarouselReaderDirection direction) async {
    if (_louvorNavigationInProgress) return;
    _louvorNavigationInProgress = true;
    try {
      await navigateReaderCarouselByKeyboard(
        ref: ref,
        context: context,
        currentPdfId: widget.queryParams[UrlSyncParams.pdfId],
        direction: direction,
      );
    } finally {
      _louvorNavigationInProgress = false;
    }
  }

  /// `Ctrl+←/→` troca de louvor (como nos outros leitores); `Espaço`
  /// toca/pausa fora de campos de texto.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      if (key == LogicalKeyboardKey.arrowRight) {
        unawaited(_navigateLouvor(CarouselReaderDirection.next));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        unawaited(_navigateLouvor(CarouselReaderDirection.previous));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.space && !keyboardFocusIsInsideTextField()) {
      final document = ref.read(scoreDocumentProvider(_r2Key)).asData?.value;
      if (document == null) return KeyEventResult.ignored;
      unawaited(
        ref.read(scoreReaderControllerProvider(document).notifier).togglePlay(),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final r2Key = _r2Key;
    final docAsync = ref.watch(scoreDocumentProvider(r2Key));
    final fontAsync = ref.watch(scoreMusicFontProvider);

    Widget message(String text, {VoidCallback? onTap, Key? key}) => Center(
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );

    final Widget body;
    if (docAsync.hasError || fontAsync.hasError) {
      body = message(
        l10n.scoreReaderUnavailable,
        key: scoreReaderRetryKey,
        onTap: () {
          ref.invalidate(scoreDocumentProvider(r2Key));
          if (fontAsync.hasError) ref.invalidate(scoreMusicFontProvider);
        },
      );
    } else if (docAsync.isLoading || fontAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final document = docAsync.value;
      body = document == null
          ? message(l10n.scoreReaderEmpty)
          : _ScoreReaderBody(key: ValueKey(document), document: document);
    }

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: (_) => _keyboardFocusNode.requestFocus(),
        child: Material(
          color: colors.surface,
          child: SafeArea(child: body),
        ),
      ),
    );
  }
}

class _ScoreReaderBody extends ConsumerStatefulWidget {
  const _ScoreReaderBody({required this.document, super.key});

  final ScoreDocument document;

  @override
  ConsumerState<_ScoreReaderBody> createState() => _ScoreReaderBodyState();
}

class _ScoreReaderBodyState extends ConsumerState<_ScoreReaderBody> {
  ScoreViewMode _mode = ScoreViewMode.continuous;
  double? _staffSpace;
  var _showTempo = false;

  /// Zoom inicial: ~7 px por espaço no celular, mais na tela grande.
  double _defaultStaffSpace(double width) =>
      (width / 90).clamp(6.0, 10.0).toDouble();

  void _zoom(double factor, double current) {
    setState(() {
      _staffSpace = (current * factor)
          .clamp(_minStaffSpace, _maxStaffSpace)
          .toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final provider = scoreReaderControllerProvider(document);
    final controller = ref.read(provider.notifier);
    final view = ref.watch(
      provider.select(
        (s) => (
          displayed: s.displayed,
          activeIds: s.activeIds,
          activeMeasure: s.activeMeasure,
          playing: s.playing,
          loopStart: s.loopStart,
          loopEnd: s.loopEnd,
        ),
      ),
    );
    final loop = view.loopStart == null
        ? null
        : (first: view.loopStart!, last: view.loopEnd ?? view.loopStart!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final staffSpace =
            _staffSpace ?? _defaultStaffSpace(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScoreTransportBar(
              document: document,
              mode: _mode,
              onModeChanged: (mode) => setState(() => _mode = mode),
              onZoomIn: staffSpace < _maxStaffSpace
                  ? () => _zoom(_zoomStep, staffSpace)
                  : null,
              onZoomOut: staffSpace > _minStaffSpace
                  ? () => _zoom(1 / _zoomStep, staffSpace)
                  : null,
              showTempo: _showTempo,
              onToggleTempo: () => setState(() => _showTempo = !_showTempo),
            ),
            if (_showTempo) ScoreTempoBar(document: document),
            const Divider(height: 1),
            Expanded(
              child: ScoreSheetView(
                score: view.displayed,
                staffSpace: staffSpace,
                onStaffSpaceChanged: (value) => setState(() {
                  _staffSpace = value
                      .clamp(_minStaffSpace, _maxStaffSpace)
                      .toDouble();
                }),
                mode: _mode,
                highlightedIds: view.activeIds,
                activeMeasure: view.activeMeasure,
                follow: view.playing,
                loopMeasures: loop,
                onElementTap: controller.onElementTap,
                onMeasureLongPress: (measure) async {
                  await controller.seekToMeasure(measure);
                  controller.cycleLoop();
                },
              ),
            ),
            const Divider(height: 1),
            ScoreProgressBar(document: document),
          ],
        );
      },
    );
  }
}
