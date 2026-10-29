import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shimmer animado reutilizável para placeholders de loading.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    required this.baseColor,
    required this.highlightColor,
    required this.child,
    super.key,
  });

  final Color baseColor;
  final Color highlightColor;
  final Widget child;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
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
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgets',
    );
  }

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.baseColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _shimmerController == null
            ? widget.child
            : AnimatedBuilder(
                animation: _shimmerController!,
                builder: (context, child) {
                  return CustomPaint(
                    foregroundPainter: _ShimmerPainter(
                      progress: _shimmerController!.value,
                      baseColor: widget.baseColor,
                      highlightColor: widget.highlightColor,
                    ),
                    child: child,
                  );
                },
                child: widget.child,
              ),
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({
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
      colors: [baseColor, highlightColor, baseColor],
      stops: const [0.35, 0.5, 0.65],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
