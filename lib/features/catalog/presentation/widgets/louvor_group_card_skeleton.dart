import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:coldigui/core/widgets/shimmer_placeholder.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_louvor_chip.dart';
import 'package:flutter/material.dart';

/// Placeholder de [LouvorGroupCard] com shimmer durante carregamento do manifest.
class LouvorGroupCardSkeleton extends StatelessWidget {
  const LouvorGroupCardSkeleton({super.key});

  static const Color _chipBase = Color(0xFF6B3A38);
  static const Color _lineBase = Color(0xFF5A3533);
  static const Color _lineHighlight = Color(0xFF7A4540);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: carouselChipTopBarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _chipBase,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ShimmerPlaceholder(
                  baseColor: _lineBase,
                  highlightColor: _lineHighlight,
                  child: SizedBox(width: double.infinity, height: 14),
                ),
                const SizedBox(height: 6),
                ShimmerPlaceholder(
                  baseColor: _lineBase,
                  highlightColor: _lineHighlight,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.45,
                    height: 12,
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

/// Sliver de skeletons do catálogo — Home e Biblioteca (Fase G).
class CatalogLoadingSliver extends StatelessWidget {
  const CatalogLoadingSliver({this.itemCount = 7, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => const LouvorGroupCardSkeleton(),
        childCount: itemCount,
      ),
    );
  }
}
