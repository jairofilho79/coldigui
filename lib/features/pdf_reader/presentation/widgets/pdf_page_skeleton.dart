import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Placeholder A4 com shimmer enquanto [pdfReaderSessionProvider] carrega.
///
/// Simula uma página PDF (proporção 210:297) sobre o fundo escuro do leitor.
class PdfPageSkeleton extends StatefulWidget {
  const PdfPageSkeleton({super.key});

  static const double a4AspectRatio = 210 / 297;

  static const Color _pageBase = Color(0xFFD4CCC0);
  static const Color _pageHighlight = Color(0xFFF5F0E8);

  @override
  State<PdfPageSkeleton> createState() => _PdfPageSkeletonState();
}

class _PdfPageSkeletonState extends State<PdfPageSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _shimmerController;

  @override
  void initState() {
    super.initState();
    if (!_animationsDisabled) {
      _shimmerController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  bool get _animationsDisabled {
    final dispatcher = SchedulerBinding.instance.platformDispatcher;
    if (dispatcher.accessibilityFeatures.disableAnimations) return true;
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgets');
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: PdfPageSkeleton.a4AspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PdfPageSkeleton._pageBase,
              borderRadius: BorderRadius.circular(2),
              boxShadow: AppColors.shadowMd,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _shimmerController == null
                  ? const SizedBox.expand()
                  : AnimatedBuilder(
                      animation: _shimmerController!,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _PdfPageShimmerPainter(
                            progress: _shimmerController!.value,
                            baseColor: PdfPageSkeleton._pageBase,
                            highlightColor: PdfPageSkeleton._pageHighlight,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfPageShimmerPainter extends CustomPainter {
  const _PdfPageShimmerPainter({
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  final double progress;
  final Color baseColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment(-1 + progress * 2, 0),
      end: Alignment(progress * 2, 0),
      colors: [
        baseColor,
        highlightColor,
        baseColor,
      ],
      stops: const [0.35, 0.5, 0.65],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_PdfPageShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
