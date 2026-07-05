import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/isar_provider.dart';
import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Bloqueia [child] quando Isar não está disponível (modo degradado).
class StorageRequiredGate extends ConsumerWidget {
  const StorageRequiredGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isarAvailableProvider)) return child;

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
                'Armazenamento local indisponível',
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(color: AppColors.title),
              ),
              const SizedBox(height: 12),
              Text(
                'Esta área precisa do banco local do app. O catálogo online e o '
                'leitor de PDF continuam disponíveis nas outras abas.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => ref.invalidate(isarInitializerProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
