// test/support/test_overrides.dart
//
// Overrides padrão (E10) para testes que não querem tocar em Isar/prefs/
// plataforma de verdade. Reúne o que `active_playlist_editor_test.dart` (e
// vários outros) já montavam override a override.
import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/platform/platform_capabilities.dart';
import 'package:coldigui/core/platform/platform_capabilities_provider.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/data/datasources/carousel_local_datasource.dart';
import 'package:coldigui/features/carousel/data/providers/carousel_providers.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/legacy_ids_normalizer_test_helpers.dart';

/// Abridor de Isar que nunca abre de verdade: falha na hora em vez de
/// esperar o timeout real de 15 s ([isarOpenTimeout]) — para quando algum
/// provider lê `isarInitializerProvider`/`isarOpenerProvider` direto, sem
/// passar por `isarStatusProvider`.
Future<Isar> _unavailableIsarOpener() => Future<Isar>.error(
  StateError('Isar indisponível em teste (standardTestOverrides)'),
);

/// Overrides padrão para testes que não precisam de Isar/prefs reais (nem da
/// normalização dos ids legados — ver [noOpLegacyMaterialIdsNormalizerOverride]).
///
/// [prefs] deve vir de `SharedPreferences.setMockInitialValues({})` seguido
/// de `await SharedPreferences.getInstance()` — quando omitido, o override
/// de `sharedPreferencesProvider` fica de fora da lista (nenhum teste que usa
/// `standardTestOverrides()` sem [prefs] lê esse provider).
List<Override> standardTestOverrides({
  SharedPreferences? prefs,
  PlatformCapabilities capabilities = PlatformCapabilities.native,
}) {
  return [
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
    isarStatusProvider.overrideWithValue(IsarStatus.unavailable),
    isarOpenerProvider.overrideWithValue(_unavailableIsarOpener),
    carouselLocalDatasourceProvider.overrideWithValue(
      const CarouselLocalDatasource.unavailable(),
    ),
    platformCapabilitiesProvider.overrideWithValue(capabilities),
    // Hidratar a sessão de playlists pede a normalização dos ids legados:
    // aqui ela não monta stores nem pergunta ao crosswalk.
    noOpLegacyMaterialIdsNormalizerOverride(),
  ];
}
