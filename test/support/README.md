# test/support

Infra de teste compartilhada (E10): `pump_app.dart` (`pumpApp` — `ProviderScope` + `MaterialApp` com a l10n real + `Scaffold`) e `test_overrides.dart` (`standardTestOverrides` — Isar/prefs/carrossel/plataforma sem tocar no real) para todo teste de widget/provider. `fakes/` tem as fakes de `PlaylistsNotifier`, `Isar`, `ActivePlaylistEditor`, `CatalogRepository` e `AuthRemoteDatasource` mais duplicadas do repo — use-as em vez de recriar uma `_FakeX` local. Sem goldens aqui (variam por plataforma de CI).
