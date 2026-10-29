/// Alcance de publicidade de uma lista publicada.
enum PlaylistReach { pontual, usual }

/// Categoria pedida somente na publicação.
enum PlaylistCategory { evangelizacao, aprendizado, medleys, cultoEspecial }

extension PlaylistReachWire on PlaylistReach {
  String get wireValue => name;

  static PlaylistReach? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in PlaylistReach.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

extension PlaylistCategoryWire on PlaylistCategory {
  String get wireValue => name;

  static PlaylistCategory? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in PlaylistCategory.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
