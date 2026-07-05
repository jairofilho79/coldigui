import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/isar_provider.dart';
import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Banner persistente quando o armazenamento local (Isar) está indisponível.
///
/// Catálogo online e leitor continuam funcionando; playlists/offline ficam
/// bloqueados até o usuário tentar reabrir o storage.
class DegradedStorageBanner extends ConsumerWidget {
  const DegradedStorageBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarInitializerProvider);
    if (!isarAsync.hasError) return const SizedBox.shrink();

    return Material(
      color: AppColors.gold.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.storage_outlined, color: AppColors.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Armazenamento local indisponível. O catálogo online continua '
                'funcionando; listas e offline ficam desativados.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => ref.invalidate(isarInitializerProvider),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
