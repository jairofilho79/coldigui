import 'dart:async';

import 'package:coldigui/features/catalog/domain/entities/louvores_manifest.dart';
import 'package:coldigui/features/catalog/presentation/providers/louvores_manifest_provider.dart';
import 'package:flutter_riverpod/misc.dart';

/// Override de [louvoresManifestProvider] para testes com manifest fixo.
Override louvoresManifestOverride(LouvoresManifest manifest) {
  return louvoresManifestProvider.overrideWith(
    () => _FixedLouvoresManifestNotifier(manifest),
  );
}

/// Override de [louvoresManifestProvider] que permanece em loading.
Override louvoresManifestLoadingOverride() {
  return louvoresManifestProvider.overrideWith(
    _LoadingLouvoresManifestNotifier.new,
  );
}

/// Override de [louvoresManifestProvider] que sempre falha — usado para
/// testar o estado de erro + retry (C.8). [onBuild] é chamado a cada
/// tentativa (inclusive a primeira), útil para contar quantas vezes o
/// provider foi (re)construído (`ref.invalidate` a cada retry).
Override louvoresManifestErrorOverride({void Function()? onBuild}) {
  return louvoresManifestProvider.overrideWith(
    () => _ErrorLouvoresManifestNotifier(onBuild),
  );
}

class _FixedLouvoresManifestNotifier extends LouvoresManifestNotifier {
  _FixedLouvoresManifestNotifier(this._manifest);

  final LouvoresManifest _manifest;

  @override
  Future<LouvoresManifest> build() async => _manifest;
}

class _LoadingLouvoresManifestNotifier extends LouvoresManifestNotifier {
  static final _never = Completer<LouvoresManifest>();

  @override
  Future<LouvoresManifest> build() => _never.future;
}

class _ErrorLouvoresManifestNotifier extends LouvoresManifestNotifier {
  _ErrorLouvoresManifestNotifier(this._onBuild);

  final void Function()? _onBuild;

  @override
  Future<LouvoresManifest> build() async {
    _onBuild?.call();
    // `StateError` (um `Error`, não `Exception`) evita o auto-retry padrão
    // do Riverpod 3 (`ProviderContainer.defaultRetry` só recua para
    // exceptions) — assim os testes de retry manual/reconexão (C.8) contam
    // builds determinísticos, sem ruído de um retry automático concorrente.
    throw StateError('catálogo indisponível (teste)');
  }
}
