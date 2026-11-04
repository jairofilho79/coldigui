import 'dart:async';

import 'package:crisp_notation/crisp_notation.dart'
    hide Interval, Key, PageMetrics;
// ignore: implementation_imports
import 'package:crisp_notation/src/rendering/layout_painter.dart';
import 'package:flutter/material.dart' hide Interval;
import 'package:flutter/rendering.dart';

import '../utils/score_systems_layout.dart';
import 'score_system_view.dart';

/// Como a partitura se distribui na tela.
enum ScoreViewMode {
  /// Sistemas empilhados numa rolagem vertical contínua.
  continuous,

  /// Páginas do tamanho da tela, viradas na horizontal.
  pages,
}

/// Tempo sem rolar à mão para a rolagem automática voltar a seguir o cursor.
const Duration kScoreFollowResumeDelay = Duration(seconds: 3);

/// Fração da altura da tela onde o sistema ativo fica ao rolar sozinho.
const double _followAnchor = 0.12;

/// A partitura inteira, preguiçosa por sistema, com destaque, loop A-B,
/// toque em nota e rolagem/virada de página automática pelo cursor.
class ScoreSheetView extends StatefulWidget {
  const ScoreSheetView({
    required this.score,
    required this.staffSpace,
    this.mode = ScoreViewMode.continuous,
    this.highlightedIds = const {},
    this.activeMeasure,
    this.follow = false,
    this.loopMeasures,
    this.theme = CrispNotationTheme.standard,
    this.onElementTap,
    this.onMeasureLongPress,
    this.onStaffSpaceChanged,
    super.key,
  });

  final MultiPartScore score;

  /// Pixels por espaço de pauta — o zoom.
  final double staffSpace;
  final ScoreViewMode mode;
  final Set<String> highlightedIds;
  final int? activeMeasure;

  /// Seguir [activeMeasure] rolando/virando a página (durante a execução).
  final bool follow;
  final ({int first, int last})? loopMeasures;
  final CrispNotationTheme theme;
  final ValueChanged<String>? onElementTap;
  final ValueChanged<int>? onMeasureLongPress;

  /// Publica o zoom efetivo ao fim do pinch para sincronizar os botões.
  final ValueChanged<double>? onStaffSpaceChanged;

  @override
  State<ScoreSheetView> createState() => _ScoreSheetViewState();
}

class _ScoreSheetViewState extends State<ScoreSheetView> {
  final _scroll = ScrollController();
  PageController? _pages;
  late double _staffSpace = widget.staffSpace;
  double _pinchStartStaffSpace = 0;
  late LayoutPainter _painter = LayoutPainter(
    theme: widget.theme,
    scale: _staffSpace,
  );

  ScoreSystemsLayout? _layout;
  Object? _layoutError;
  ({
    MultiPartScore score,
    double width,
    double staffSpace,
    CrispNotationTheme theme,
  })?
  _layoutKey;
  bool _layoutScheduled = false;

  /// Topo de cada sistema na rolagem contínua (px), mais o total no fim.
  List<double> _offsets = const [];

  /// Primeiro sistema de cada página no modo página.
  List<int> _pageStarts = const [];
  double _viewportHeight = 0;
  Timer? _followResumeTimer;

  @override
  void didUpdateWidget(ScoreSheetView old) {
    super.didUpdateWidget(old);
    if (old.theme != widget.theme) {
      _painter.dispose();
      _painter = LayoutPainter(theme: widget.theme, scale: _staffSpace);
    }
    if (old.staffSpace != widget.staffSpace) {
      _staffSpace = widget.staffSpace;
      _painter.clearCache();
    }
    if (widget.follow &&
        widget.activeMeasure != null &&
        (widget.activeMeasure != old.activeMeasure ||
            !old.follow ||
            widget.mode != old.mode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followActive());
    }
  }

  @override
  void dispose() {
    _followResumeTimer?.cancel();
    _scroll.dispose();
    _pages?.dispose();
    _painter.dispose();
    super.dispose();
  }

  /// O layout dos sistemas é caro (a grade de 16 vozes leva meio segundo):
  /// sai do build, depois de um quadro com o indicador de progresso.
  void _ensureLayout(double widthPx) {
    final width = (widthPx / _staffSpace * 4).roundToDouble() / 4;
    final key = (
      score: widget.score,
      width: width,
      staffSpace: _staffSpace,
      theme: widget.theme,
    );
    if (_layoutKey == key || _layoutScheduled) return;
    _layoutScheduled = true;
    Timer.run(() {
      if (!mounted) return;
      _layoutScheduled = false;
      try {
        final layout = ScoreSystemsLayout.of(
          widget.score,
          widthSpaces: width,
          theme: widget.theme,
        );
        setState(() {
          _layout = layout;
          _layoutError = null;
          _layoutKey = key;
          _offsets = _computeOffsets(layout);
          _pageStarts = const [];
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _followActive());
      } on Object catch (error) {
        setState(() {
          _layoutError = error;
          _layoutKey = key;
        });
      }
    });
  }

  List<double> _computeOffsets(ScoreSystemsLayout layout) {
    final out = <double>[0];
    for (var i = 0; i < layout.systems.length; i++) {
      out.add(out.last + layout.heightOf(i) * _staffSpace);
    }
    return out;
  }

  List<int> _paginate(ScoreSystemsLayout layout, double height) {
    final starts = <int>[0];
    var used = 0.0;
    for (var i = 0; i < layout.systems.length; i++) {
      final h = layout.heightOf(i) * _staffSpace;
      if (used > 0 && used + h > height) {
        starts.add(i);
        used = 0;
      }
      used += h;
    }
    return starts;
  }

  int _pageOfSystem(int system) {
    var page = 0;
    for (var p = 0; p < _pageStarts.length; p++) {
      if (_pageStarts[p] <= system) page = p;
    }
    return page;
  }

  void _followActive() {
    if (!mounted || !widget.follow) return;
    final layout = _layout;
    final measure = widget.activeMeasure;
    if (layout == null || measure == null) return;
    final system = layout.systemOfMeasure(measure);
    if (system == null) return;
    if (_followResumeTimer?.isActive ?? false) return;

    if (widget.mode == ScoreViewMode.pages) {
      final pages = _pages;
      if (pages == null || !pages.hasClients) return;
      final target = _pageOfSystem(system);
      if ((pages.page ?? 0).round() != target) {
        unawaited(
          pages.animateToPage(
            target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          ),
        );
      }
      return;
    }

    if (!_scroll.hasClients || system + 1 >= _offsets.length) return;
    final top = _offsets[system];
    final bottom = _offsets[system + 1];
    final view = _scroll.position;
    final visibleTop = view.pixels;
    final visibleBottom = view.pixels + view.viewportDimension;
    if (top >= visibleTop && bottom <= visibleBottom) return;
    final target = (top - view.viewportDimension * _followAnchor).clamp(
      0.0,
      view.maxScrollExtent,
    );
    unawaited(
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is UserScrollNotification && n.direction != ScrollDirection.idle) {
      _pauseFollow();
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      _pauseFollow();
    }
    return false;
  }

  void _pauseFollow() {
    _followResumeTimer?.cancel();
    _followResumeTimer = Timer(kScoreFollowResumeDelay, _followActive);
  }

  Widget _system(ScoreSystemsLayout layout, int index) => ScoreSystemView(
    key: ValueKey(index),
    system: layout.systems[index],
    painter: _painter,
    staffSpace: _staffSpace,
    highlightedIds: layout.visibleIn(index, widget.highlightedIds),
    loopMeasures: widget.loopMeasures,
    onElementTap: widget.onElementTap,
    onMeasureLongPress: widget.onMeasureLongPress,
  );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Papel: a partitura é sempre tinta preta sobre branco, também no tema
      // escuro (como o PDF).
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _ensureLayout(constraints.maxWidth);
          final layout = _layout;
          final key = _layoutKey;
          final fresh =
              key != null &&
              key.score == widget.score &&
              key.staffSpace == _staffSpace &&
              _layoutError == null;
          if (_layoutError != null && _layoutKey?.score == widget.score) {
            return Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
            );
          }
          if (layout == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_viewportHeight != constraints.maxHeight || _pageStarts.isEmpty) {
            _viewportHeight = constraints.maxHeight;
            _pageStarts = _paginate(layout, constraints.maxHeight);
          }
          final content = GestureDetector(
            onScaleStart: (_) => _pinchStartStaffSpace = _staffSpace,
            onScaleUpdate: (details) {
              if (details.pointerCount < 2) return;
              _pauseFollow();
              final next = (_pinchStartStaffSpace * details.scale).clamp(
                4.0,
                16.0,
              );
              if (next == _staffSpace) return;
              setState(() {
                _staffSpace = next;
                _painter.clearCache();
              });
            },
            onScaleEnd: (_) {
              if (_staffSpace != widget.staffSpace) {
                widget.onStaffSpaceChanged?.call(_staffSpace);
              }
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: widget.mode == ScoreViewMode.continuous
                  ? _buildContinuous(layout)
                  : _buildPages(layout),
            ),
          );
          // Relayout pendente (zoom, largura, transposição): mostra o layout
          // anterior esmaecido em vez de piscar o indicador.
          return Stack(
            children: [
              Opacity(opacity: fresh ? 1 : 0.4, child: content),
              if (!fresh) const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContinuous(ScoreSystemsLayout layout) {
    return Scrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        itemCount: layout.systems.length,
        itemExtentBuilder: (index, _) => index < layout.systems.length
            ? layout.heightOf(index) * _staffSpace
            : null,
        itemBuilder: (context, index) => _system(layout, index),
      ),
    );
  }

  Widget _buildPages(ScoreSystemsLayout layout) {
    final pages = _pages ??= PageController();
    final starts = _pageStarts;
    return PageView.builder(
      controller: pages,
      itemCount: starts.length,
      itemBuilder: (context, page) {
        final first = starts[page];
        final end = page + 1 < starts.length
            ? starts[page + 1]
            : layout.systems.length;
        // Rolável só para o sistema que sozinho passa da altura da tela.
        return SingleChildScrollView(
          child: Column(
            children: [
              for (var i = first; i < end; i++)
                SizedBox(
                  height: layout.heightOf(i) * _staffSpace,
                  child: _system(layout, i),
                ),
            ],
          ),
        );
      },
    );
  }
}
