import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_typography.dart';
import '../theme/color_extensions.dart';

/// Carrega uma biblioteca deferred e monta [builder] com fallback de loading/erro.
class DeferredRouteLoader extends StatefulWidget {
  const DeferredRouteLoader({
    required this.load,
    required this.builder,
    this.loadingMessage,
    super.key,
  });

  final Future<void> Function() load;
  final Widget Function() builder;

  /// Mensagem exibida durante o carregamento; usa [AppLocalizations] quando
  /// omitida.
  final String? loadingMessage;

  @override
  State<DeferredRouteLoader> createState() => _DeferredRouteLoaderState();
}

class _DeferredRouteLoaderState extends State<DeferredRouteLoader> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _ready = false;
    });

    try {
      await widget.load();
      if (!mounted) return;
      setState(() => _ready = true);
    } on Object catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('DeferredRouteLoader: $error\n$stackTrace');
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.deferredLoaderError,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _load,
                  child: Text(l10n.deferredLoaderRetry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 16),
              Text(
                widget.loadingMessage ?? l10n.deferredLoaderLoading,
                style: AppTypography.body.copyWith(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      );
    }

    return widget.builder();
  }
}
