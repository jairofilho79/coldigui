import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/isar_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/color_extensions.dart';

/// Aguarda [isarInitializerProvider] e monta [ColdiguiApp].
///
/// Em falha de Isar, abre [ColdiguiApp] em modo degradado (catálogo online).
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
      error: (_, _) => const ColdiguiApp(),
      data: (_) => const ColdiguiApp(),
    );
  }
}
