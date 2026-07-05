import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/pdf_reader/data/pdfrx_bootstrap.dart';
import 'app.dart';
import 'core/database/isar_provider.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/color_extensions.dart';

/// Aguarda [isarInitializerProvider] e monta [ColdiguiApp] quando Isar estiver pronto.
///
/// Permite `runApp` imediato no cold start web enquanto WASM Isar carrega em background.
class BootstrapApp extends ConsumerWidget {
  const BootstrapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarInitializerProvider);

    return isarAsync.when(
      loading: () => MaterialApp(
        title: 'PLPCG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
        ),
      ),
      error: (error, stackTrace) => MaterialApp(
        title: 'PLPCG',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Não foi possível abrir o banco local.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(isarInitializerProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (isar) => ProviderScope(
        overrides: [isarProvider.overrideWithValue(isar)],
        child: const PdfrxIdlePreloader(child: ColdiguiApp()),
      ),
    );
  }
}
