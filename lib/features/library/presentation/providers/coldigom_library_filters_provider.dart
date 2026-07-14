import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_view_settings_provider.dart';

/// Estado dos filtros Coldigom da Biblioteca (sempre enviados ao servidor).
class ColdigomLibraryFilterState {
  const ColdigomLibraryFilterState({
    required this.selectedTonalities,
    required this.selectedRhythms,
    required this.selectedCategories,
    required this.selectedTagIds,
    required this.selectedMaterialKindIds,
  });

  final Set<String> selectedTonalities;
  final Set<String> selectedRhythms;
  final Set<String> selectedCategories;
  final Set<String> selectedTagIds;
  final Set<String> selectedMaterialKindIds;

  factory ColdigomLibraryFilterState.empty() =>
      const ColdigomLibraryFilterState(
        selectedTonalities: {},
        selectedRhythms: {},
        selectedCategories: {},
        selectedTagIds: {},
        selectedMaterialKindIds: {},
      );

  ColdigomLibraryFilterState copyWith({
    Set<String>? selectedTonalities,
    Set<String>? selectedRhythms,
    Set<String>? selectedCategories,
    Set<String>? selectedTagIds,
    Set<String>? selectedMaterialKindIds,
  }) {
    return ColdigomLibraryFilterState(
      selectedTonalities: selectedTonalities ?? this.selectedTonalities,
      selectedRhythms: selectedRhythms ?? this.selectedRhythms,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      selectedMaterialKindIds:
          selectedMaterialKindIds ?? this.selectedMaterialKindIds,
    );
  }

  String? get tonalityUrlValue => _csvOrNull(selectedTonalities);
  String? get rhythmUrlValue => _csvOrNull(selectedRhythms);
  String? get categoryUrlValue => _csvOrNull(selectedCategories);
  String? get tagsUrlValue => _csvOrNull(selectedTagIds);
  String? get materialKindsUrlValue => _csvOrNull(selectedMaterialKindIds);

  static String? _csvOrNull(Set<String> values) {
    if (values.isEmpty) return null;
    final sorted = values.toList()..sort();
    return sorted.join(',');
  }

  static Set<String> parseCsv(String? raw) {
    if (raw == null || raw.trim().isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}

final coldigomLibraryFiltersProvider =
    NotifierProvider<
      ColdigomLibraryFiltersNotifier,
      ColdigomLibraryFilterState
    >(ColdigomLibraryFiltersNotifier.new);

class ColdigomLibraryFiltersNotifier
    extends Notifier<ColdigomLibraryFilterState> {
  @override
  ColdigomLibraryFilterState build() => ColdigomLibraryFilterState.empty();

  void hydrateFromUrl({
    String? tonality,
    String? rhythm,
    String? category,
    String? tags,
    String? materialKinds,
  }) {
    state = ColdigomLibraryFilterState(
      selectedTonalities: ColdigomLibraryFilterState.parseCsv(tonality),
      selectedRhythms: ColdigomLibraryFilterState.parseCsv(rhythm),
      selectedCategories: ColdigomLibraryFilterState.parseCsv(category),
      selectedTagIds: ColdigomLibraryFilterState.parseCsv(tags),
      selectedMaterialKindIds: ColdigomLibraryFilterState.parseCsv(
        materialKinds,
      ),
    );
  }

  void clear() {
    state = ColdigomLibraryFilterState.empty();
  }

  void toggleTonality(String value) => _applyToggle(
    selectedTonalities: _toggle(state.selectedTonalities, value),
  );

  void toggleRhythm(String value) =>
      _applyToggle(selectedRhythms: _toggle(state.selectedRhythms, value));

  void toggleCategory(String value) => _applyToggle(
    selectedCategories: _toggle(state.selectedCategories, value),
  );

  void toggleTag(String id) =>
      _applyToggle(selectedTagIds: _toggle(state.selectedTagIds, id));

  void toggleMaterialKind(String id) => _applyToggle(
    selectedMaterialKindIds: _toggle(state.selectedMaterialKindIds, id),
  );

  void _applyToggle({
    Set<String>? selectedTonalities,
    Set<String>? selectedRhythms,
    Set<String>? selectedCategories,
    Set<String>? selectedTagIds,
    Set<String>? selectedMaterialKindIds,
  }) {
    state = state.copyWith(
      selectedTonalities: selectedTonalities,
      selectedRhythms: selectedRhythms,
      selectedCategories: selectedCategories,
      selectedTagIds: selectedTagIds,
      selectedMaterialKindIds: selectedMaterialKindIds,
    );
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }

  static Set<String> _toggle(Set<String> current, String value) {
    final next = Set<String>.from(current);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }
}
