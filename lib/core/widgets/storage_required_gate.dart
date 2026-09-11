import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../database/isar_provider.dart';
import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Bloqueia [child] enquanto o Isar não está pronto.
///
/// Com o app montado durante a abertura (A8), [IsarStatus.opening] passou a ser
/// um estado visível: mostra spinner em vez do aviso de indisponível, que
/// mentiria durante os segundos de WASM + OPFS de um boot web frio.
class StorageRequiredGate extends ConsumerWidget {
  const StorageRequiredGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    switch (ref.watch(isarStatusProvider)) {
      case IsarStatus.available:
        return child;
      case IsarStatus.opening:
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text(
                    l10n.storagePreparing,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case IsarStatus.unavailable:
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storage_outlined,
                    color: AppColors.gold,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.storageUnavailableTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.headline.copyWith(
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.storageUnavailableBody,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => ref.invalidate(isarInitializerProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
