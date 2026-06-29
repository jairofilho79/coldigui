// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetPlaylistCollection on Isar {
  IsarCollection<int, Playlist> get playlists => this.collection();
}

final PlaylistSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'Playlist',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'playlistId', type: IsarType.string),
      IsarPropertySchema(name: 'nome', type: IsarType.string),
      IsarPropertySchema(name: 'pdfIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'salva', type: IsarType.bool),
      IsarPropertySchema(name: 'savedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favoritedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favorita', type: IsarType.bool),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'playlistId',
        properties: ["playlistId"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, Playlist>(
    serialize: serializePlaylist,
    deserialize: deserializePlaylist,
    deserializeProperty: deserializePlaylistProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializePlaylist(IsarWriter writer, Playlist object) {
  IsarCore.writeString(writer, 1, object.playlistId);
  IsarCore.writeString(writer, 2, object.nome);
  {
    final list = object.pdfIds;
    final listWriter = IsarCore.beginList(writer, 3, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  IsarCore.writeLong(
    writer,
    4,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeBool(writer, 5, value: object.salva);
  IsarCore.writeLong(
    writer,
    6,
    object.savedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  IsarCore.writeLong(
    writer,
    7,
    object.favoritedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  IsarCore.writeBool(writer, 8, value: object.favorita);
  return object.id;
}

@isarProtected
Playlist deserializePlaylist(IsarReader reader) {
  final object = Playlist();
  object.id = IsarCore.readId(reader);
  object.playlistId = IsarCore.readString(reader, 1) ?? '';
  object.nome = IsarCore.readString(reader, 2) ?? '';
  {
    final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        object.pdfIds = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        object.pdfIds = list;
      }
    }
  }
  {
    final value = IsarCore.readLong(reader, 4);
    if (value == -9223372036854775808) {
      object.createdAt = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      object.createdAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  object.salva = IsarCore.readBool(reader, 5);
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      object.savedAt = null;
    } else {
      object.savedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  {
    final value = IsarCore.readLong(reader, 7);
    if (value == -9223372036854775808) {
      object.favoritedAt = null;
    } else {
      object.favoritedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  object.favorita = IsarCore.readBool(reader, 8);
  return object;
}

@isarProtected
dynamic deserializePlaylistProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      {
        final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
        {
          final reader = IsarCore.readerPtr;
          if (reader.isNull) {
            return const <String>[];
          } else {
            final list = List<String>.filled(length, '', growable: true);
            for (var i = 0; i < length; i++) {
              list[i] = IsarCore.readString(reader, i) ?? '';
            }
            IsarCore.freeReader(reader);
            return list;
          }
        }
      }
    case 4:
      {
        final value = IsarCore.readLong(reader, 4);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 5:
      return IsarCore.readBool(reader, 5);
    case 6:
      {
        final value = IsarCore.readLong(reader, 6);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 7:
      {
        final value = IsarCore.readLong(reader, 7);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 8:
      return IsarCore.readBool(reader, 8);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _PlaylistUpdate {
  bool call({
    required int id,
    String? playlistId,
    String? nome,
    DateTime? createdAt,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
  });
}

class _PlaylistUpdateImpl implements _PlaylistUpdate {
  const _PlaylistUpdateImpl(this.collection);

  final IsarCollection<int, Playlist> collection;

  @override
  bool call({
    required int id,
    Object? playlistId = ignore,
    Object? nome = ignore,
    Object? createdAt = ignore,
    Object? salva = ignore,
    Object? savedAt = ignore,
    Object? favoritedAt = ignore,
    Object? favorita = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (playlistId != ignore) 1: playlistId as String?,
            if (nome != ignore) 2: nome as String?,
            if (createdAt != ignore) 4: createdAt as DateTime?,
            if (salva != ignore) 5: salva as bool?,
            if (savedAt != ignore) 6: savedAt as DateTime?,
            if (favoritedAt != ignore) 7: favoritedAt as DateTime?,
            if (favorita != ignore) 8: favorita as bool?,
          },
        ) >
        0;
  }
}

sealed class _PlaylistUpdateAll {
  int call({
    required List<int> id,
    String? playlistId,
    String? nome,
    DateTime? createdAt,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
  });
}

class _PlaylistUpdateAllImpl implements _PlaylistUpdateAll {
  const _PlaylistUpdateAllImpl(this.collection);

  final IsarCollection<int, Playlist> collection;

  @override
  int call({
    required List<int> id,
    Object? playlistId = ignore,
    Object? nome = ignore,
    Object? createdAt = ignore,
    Object? salva = ignore,
    Object? savedAt = ignore,
    Object? favoritedAt = ignore,
    Object? favorita = ignore,
  }) {
    return collection.updateProperties(id, {
      if (playlistId != ignore) 1: playlistId as String?,
      if (nome != ignore) 2: nome as String?,
      if (createdAt != ignore) 4: createdAt as DateTime?,
      if (salva != ignore) 5: salva as bool?,
      if (savedAt != ignore) 6: savedAt as DateTime?,
      if (favoritedAt != ignore) 7: favoritedAt as DateTime?,
      if (favorita != ignore) 8: favorita as bool?,
    });
  }
}

extension PlaylistUpdate on IsarCollection<int, Playlist> {
  _PlaylistUpdate get update => _PlaylistUpdateImpl(this);

  _PlaylistUpdateAll get updateAll => _PlaylistUpdateAllImpl(this);
}

sealed class _PlaylistQueryUpdate {
  int call({
    String? playlistId,
    String? nome,
    DateTime? createdAt,
    bool? salva,
    DateTime? savedAt,
    DateTime? favoritedAt,
    bool? favorita,
  });
}

class _PlaylistQueryUpdateImpl implements _PlaylistQueryUpdate {
  const _PlaylistQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<Playlist> query;
  final int? limit;

  @override
  int call({
    Object? playlistId = ignore,
    Object? nome = ignore,
    Object? createdAt = ignore,
    Object? salva = ignore,
    Object? savedAt = ignore,
    Object? favoritedAt = ignore,
    Object? favorita = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (playlistId != ignore) 1: playlistId as String?,
      if (nome != ignore) 2: nome as String?,
      if (createdAt != ignore) 4: createdAt as DateTime?,
      if (salva != ignore) 5: salva as bool?,
      if (savedAt != ignore) 6: savedAt as DateTime?,
      if (favoritedAt != ignore) 7: favoritedAt as DateTime?,
      if (favorita != ignore) 8: favorita as bool?,
    });
  }
}

extension PlaylistQueryUpdate on IsarQuery<Playlist> {
  _PlaylistQueryUpdate get updateFirst =>
      _PlaylistQueryUpdateImpl(this, limit: 1);

  _PlaylistQueryUpdate get updateAll => _PlaylistQueryUpdateImpl(this);
}

class _PlaylistQueryBuilderUpdateImpl implements _PlaylistQueryUpdate {
  const _PlaylistQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<Playlist, Playlist, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? playlistId = ignore,
    Object? nome = ignore,
    Object? createdAt = ignore,
    Object? salva = ignore,
    Object? savedAt = ignore,
    Object? favoritedAt = ignore,
    Object? favorita = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (playlistId != ignore) 1: playlistId as String?,
        if (nome != ignore) 2: nome as String?,
        if (createdAt != ignore) 4: createdAt as DateTime?,
        if (salva != ignore) 5: salva as bool?,
        if (savedAt != ignore) 6: savedAt as DateTime?,
        if (favoritedAt != ignore) 7: favoritedAt as DateTime?,
        if (favorita != ignore) 8: favorita as bool?,
      });
    } finally {
      q.close();
    }
  }
}

extension PlaylistQueryBuilderUpdate
    on QueryBuilder<Playlist, Playlist, QOperations> {
  _PlaylistQueryUpdate get updateFirst =>
      _PlaylistQueryBuilderUpdateImpl(this, limit: 1);

  _PlaylistQueryUpdate get updateAll => _PlaylistQueryBuilderUpdateImpl(this);
}

extension PlaylistQueryFilter
    on QueryBuilder<Playlist, Playlist, QFilterCondition> {
  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  playlistIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  playlistIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> playlistIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  playlistIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  nomeGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 2,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 2,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> nomeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  pdfIdsElementGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  pdfIdsElementGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsElementLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  pdfIdsElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsElementBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  pdfIdsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsElementContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsElementMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  pdfIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  pdfIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsIsEmpty() {
    return not().pdfIdsIsNotEmpty();
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> pdfIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 3, value: null),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 4, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 4, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> salvaEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtGreaterThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  savedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  savedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 7, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 7, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritaEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }
}

extension PlaylistQueryObject
    on QueryBuilder<Playlist, Playlist, QFilterCondition> {}

extension PlaylistQuerySortBy on QueryBuilder<Playlist, Playlist, QSortBy> {
  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByPlaylistId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByPlaylistIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByNome({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByNomeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySalva() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySalvaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavoritedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavorita() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavoritaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }
}

extension PlaylistQuerySortThenBy
    on QueryBuilder<Playlist, Playlist, QSortThenBy> {
  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByPlaylistId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByPlaylistIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByNome({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByNomeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySalva() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySalvaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavoritedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavorita() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavoritaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }
}

extension PlaylistQueryWhereDistinct
    on QueryBuilder<Playlist, Playlist, QDistinct> {
  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByPlaylistId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByNome({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByPdfIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctBySalva() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByFavorita() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }
}

extension PlaylistQueryProperty1
    on QueryBuilder<Playlist, Playlist, QProperty> {
  QueryBuilder<Playlist, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<Playlist, String, QAfterProperty> playlistIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Playlist, String, QAfterProperty> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Playlist, List<String>, QAfterProperty> pdfIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Playlist, DateTime, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Playlist, bool, QAfterProperty> salvaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Playlist, DateTime?, QAfterProperty> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Playlist, DateTime?, QAfterProperty> favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Playlist, bool, QAfterProperty> favoritaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }
}

extension PlaylistQueryProperty2<R>
    on QueryBuilder<Playlist, R, QAfterProperty> {
  QueryBuilder<Playlist, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<Playlist, (R, String), QAfterProperty> playlistIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Playlist, (R, String), QAfterProperty> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Playlist, (R, List<String>), QAfterProperty> pdfIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Playlist, (R, DateTime), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Playlist, (R, bool), QAfterProperty> salvaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Playlist, (R, DateTime?), QAfterProperty> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Playlist, (R, DateTime?), QAfterProperty> favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Playlist, (R, bool), QAfterProperty> favoritaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }
}

extension PlaylistQueryProperty3<R1, R2>
    on QueryBuilder<Playlist, (R1, R2), QAfterProperty> {
  QueryBuilder<Playlist, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<Playlist, (R1, R2, String), QOperations> playlistIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Playlist, (R1, R2, String), QOperations> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Playlist, (R1, R2, List<String>), QOperations> pdfIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime), QOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Playlist, (R1, R2, bool), QOperations> salvaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime?), QOperations> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime?), QOperations>
  favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Playlist, (R1, R2, bool), QOperations> favoritaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }
}
