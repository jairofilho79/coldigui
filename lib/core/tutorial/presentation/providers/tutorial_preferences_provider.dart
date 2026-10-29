import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/storage_keys.dart';
import '../../../providers/shared_prefs_provider.dart';
import '../../../routing/route_paths.dart';

/// Rotas que possuem suporte à inicialização automática de tutorial no primeiro acesso.
const Set<String> kDefaultAutoTriggerRoutes = {
  RoutePaths.home,
  RoutePaths.reader,
};

/// Estado imutável das preferências de tutoriais e onboarding.
class TutorialPreferencesState {
  const TutorialPreferencesState({
    this.dismissAll = false,
    this.seenTutorials = const {},
    this.hasSeenWelcomeHero = false,
  });

  /// Se o usuário optou por não exibir mais nenhum tutorial automaticamente ("Não mostrar novamente").
  final bool dismissAll;

  /// Conjunto de identificadores de rotas ou modais cujos tutoriais já foram visualizados.
  final Set<String> seenTutorials;

  /// Se o diálogo de boas-vindas do primeiro acesso já foi visualizado ou dispensado.
  final bool hasSeenWelcomeHero;

  /// Retorna se o tutorial especificado já foi visualizado.
  bool hasSeen(String tutorialId) => seenTutorials.contains(tutorialId);

  /// Retorna se o tutorial deve ser iniciado automaticamente no primeiro acesso da rota.
  bool shouldAutoTrigger(String tutorialId, {bool forceAllowedRoute = false}) {
    if (dismissAll) return false;
    if (!forceAllowedRoute && !kDefaultAutoTriggerRoutes.contains(tutorialId)) {
      return false;
    }
    return !hasSeen(tutorialId);
  }

  TutorialPreferencesState copyWith({
    bool? dismissAll,
    Set<String>? seenTutorials,
    bool? hasSeenWelcomeHero,
  }) {
    return TutorialPreferencesState(
      dismissAll: dismissAll ?? this.dismissAll,
      seenTutorials: seenTutorials ?? this.seenTutorials,
      hasSeenWelcomeHero: hasSeenWelcomeHero ?? this.hasSeenWelcomeHero,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TutorialPreferencesState &&
          other.dismissAll == dismissAll &&
          other.hasSeenWelcomeHero == hasSeenWelcomeHero &&
          setEquals(other.seenTutorials, seenTutorials);

  @override
  int get hashCode => Object.hash(
        dismissAll,
        hasSeenWelcomeHero,
        Object.hashAll(seenTutorials),
      );
}

/// Notifier que gerencia a persistência de preferências de tutorial em [SharedPreferences].
class TutorialPreferencesNotifier extends Notifier<TutorialPreferencesState> {
  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  TutorialPreferencesState build() {
    final prefs = _prefs;
    if (prefs == null) {
      return const TutorialPreferencesState();
    }

    final dismissAll = prefs.getBool(StorageKeys.tutorialDismissAll) ?? false;
    final welcomeHeroSeen =
        prefs.getBool(StorageKeys.welcomeHeroSeen) ?? false;
    final seen = <String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(StorageKeys.tutorialSeenPrefix) &&
          prefs.getBool(key) == true) {
        final id = key.substring(StorageKeys.tutorialSeenPrefix.length);
        if (id.isNotEmpty) {
          seen.add(id);
        }
      }
    }

    return TutorialPreferencesState(
      dismissAll: dismissAll,
      seenTutorials: seen,
      hasSeenWelcomeHero: welcomeHeroSeen,
    );
  }

  /// Marca o tutorial especificado como visualizado e persiste em [SharedPreferences].
  Future<void> markSeen(String tutorialId) async {
    if (state.hasSeen(tutorialId)) return;
    final updated = {...state.seenTutorials, tutorialId};
    state = state.copyWith(seenTutorials: updated);

    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(
        '${StorageKeys.tutorialSeenPrefix}$tutorialId',
        true,
      );
    }
  }

  /// Marca o diálogo de boas-vindas do primeiro acesso como visto.
  Future<void> markWelcomeHeroSeen() async {
    if (state.hasSeenWelcomeHero) return;
    state = state.copyWith(hasSeenWelcomeHero: true);
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(StorageKeys.welcomeHeroSeen, true);
    }
  }

  /// Define se todos os tutoriais automáticos devem ser silenciados globalmente.
  Future<void> setDismissAll(bool value) async {
    state = state.copyWith(dismissAll: value);
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(StorageKeys.tutorialDismissAll, value);
    }
  }

  /// Redefine todas as preferências de tutoriais, permitindo que voltem a aparecer.
  Future<void> resetAll() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(StorageKeys.tutorialDismissAll);
      await prefs.remove(StorageKeys.welcomeHeroSeen);
      final keysToRemove = prefs
          .getKeys()
          .where((k) => k.startsWith(StorageKeys.tutorialSeenPrefix))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    }
    state = const TutorialPreferencesState();
  }
}

/// Provider das preferências de tutoriais e onboarding.
final tutorialPreferencesProvider =
    NotifierProvider<TutorialPreferencesNotifier, TutorialPreferencesState>(
  TutorialPreferencesNotifier.new,
);

/// Notifier que permite ligar ou desligar globalmente o auto-trigger de tutoriais (útil em testes).
class TutorialAutoTriggerNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// Provider para ligar/desligar auto-trigger de tutoriais.
final tutorialAutoTriggerEnabledProvider =
    NotifierProvider<TutorialAutoTriggerNotifier, bool>(
  TutorialAutoTriggerNotifier.new,
);
