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
