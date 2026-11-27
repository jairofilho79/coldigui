import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../../../core/utils/material_id_kind.dart';

String readerOfflineExclusion(MaterialKind kind, String key) =>
    '${kind.name}:$key';

final readerOfflineExclusionsProvider =
    NotifierProvider<ReaderOfflineExclusions, Set<String>>(
      ReaderOfflineExclusions.new,
    );

class ReaderOfflineExclusions extends Notifier<Set<String>> {
  static const _preference = 'readerOfflineExclusions';

  @override
  Set<String> build() => Set.unmodifiable(
    ref.watch(sharedPreferencesProvider).getStringList(_preference) ?? [],
  );

  Future<void> exclude(String key) => _save({...state, key});

  Future<void> include(Iterable<String> keys) async {
    final next = state.difference(keys.toSet());
    if (next.length != state.length) await _save(next);
  }

  Future<void> _save(Set<String> next) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!await prefs.setStringList(_preference, next.toList())) {
      throw StateError('Could not persist reader offline exclusions');
    }
    state = Set.unmodifiable(next);
  }
}
