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
      IsarPropertySchema(name: 'audioIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'salva', type: IsarType.bool),
      IsarPropertySchema(name: 'savedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favoritedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favorita', type: IsarType.bool),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'version', type: IsarType.long),
      IsarPropertySchema(name: 'syncStatusIndex', type: IsarType.long),
      IsarPropertySchema(name: 'deletedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'isPublished', type: IsarType.bool),
      IsarPropertySchema(name: 'publicationReachIndex', type: IsarType.long),
      IsarPropertySchema(name: 'publicationCategoryIndex', type: IsarType.long),
      IsarPropertySchema(name: 'publishedAt', type: IsarType.dateTime),
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
  {
    final list = object.audioIds;
    final listWriter = IsarCore.beginList(writer, 4, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  IsarCore.writeLong(
    writer,
    5,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeBool(writer, 6, value: object.salva);
  IsarCore.writeLong(
    writer,
    7,
    object.savedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  IsarCore.writeLong(
    writer,
    8,
    object.favoritedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  IsarCore.writeBool(writer, 9, value: object.favorita);
  IsarCore.writeLong(
    writer,
    10,
    object.updatedAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(writer, 11, object.version);
  IsarCore.writeLong(writer, 12, object.syncStatusIndex);
  IsarCore.writeLong(
    writer,
    13,
    object.deletedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  IsarCore.writeBool(writer, 14, value: object.isPublished);
  IsarCore.writeLong(
    writer,
    15,
    object.publicationReachIndex ?? -9223372036854775808,
  );
  IsarCore.writeLong(
    writer,
    16,
    object.publicationCategoryIndex ?? -9223372036854775808,
  );
  IsarCore.writeLong(
    writer,
    17,
    object.publishedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
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
    final length = IsarCore.readList(reader, 4, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        object.audioIds = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        object.audioIds = list;
      }
    }
  }
  {
    final value = IsarCore.readLong(reader, 5);
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
  object.salva = IsarCore.readBool(reader, 6);
  {
    final value = IsarCore.readLong(reader, 7);
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
    final value = IsarCore.readLong(reader, 8);
    if (value == -9223372036854775808) {
      object.favoritedAt = null;
    } else {
      object.favoritedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  object.favorita = IsarCore.readBool(reader, 9);
  {
    final value = IsarCore.readLong(reader, 10);
    if (value == -9223372036854775808) {
      object.updatedAt = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      object.updatedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  object.version = IsarCore.readLong(reader, 11);
  object.syncStatusIndex = IsarCore.readLong(reader, 12);
  {
    final value = IsarCore.readLong(reader, 13);
    if (value == -9223372036854775808) {
      object.deletedAt = null;
    } else {
      object.deletedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  object.isPublished = IsarCore.readBool(reader, 14);
  {
    final value = IsarCore.readLong(reader, 15);
    if (value == -9223372036854775808) {
      object.publicationReachIndex = null;
    } else {
      object.publicationReachIndex = value;
    }
  }
  {
    final value = IsarCore.readLong(reader, 16);
    if (value == -9223372036854775808) {
      object.publicationCategoryIndex = null;
    } else {
      object.publicationCategoryIndex = value;
    }
  }
  {
    final value = IsarCore.readLong(reader, 17);
    if (value == -9223372036854775808) {
      object.publishedAt = null;
    } else {
      object.publishedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
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
        final length = IsarCore.readList(reader, 4, IsarCore.readerPtrPtr);
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
    case 5:
      {
        final value = IsarCore.readLong(reader, 5);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 6:
      return IsarCore.readBool(reader, 6);
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
      {
        final value = IsarCore.readLong(reader, 8);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 9:
      return IsarCore.readBool(reader, 9);
    case 10:
      {
        final value = IsarCore.readLong(reader, 10);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 11:
      return IsarCore.readLong(reader, 11);
    case 12:
      return IsarCore.readLong(reader, 12);
    case 13:
      {
        final value = IsarCore.readLong(reader, 13);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 14:
      return IsarCore.readBool(reader, 14);
    case 15:
      {
        final value = IsarCore.readLong(reader, 15);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return value;
        }
      }
    case 16:
      {
        final value = IsarCore.readLong(reader, 16);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return value;
        }
      }
    case 17:
      {
        final value = IsarCore.readLong(reader, 17);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
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
    DateTime? updatedAt,
    int? version,
    int? syncStatusIndex,
    DateTime? deletedAt,
    bool? isPublished,
    int? publicationReachIndex,
    int? publicationCategoryIndex,
    DateTime? publishedAt,
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
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
    Object? isPublished = ignore,
    Object? publicationReachIndex = ignore,
    Object? publicationCategoryIndex = ignore,
    Object? publishedAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (playlistId != ignore) 1: playlistId as String?,
            if (nome != ignore) 2: nome as String?,
            if (createdAt != ignore) 5: createdAt as DateTime?,
            if (salva != ignore) 6: salva as bool?,
            if (savedAt != ignore) 7: savedAt as DateTime?,
            if (favoritedAt != ignore) 8: favoritedAt as DateTime?,
            if (favorita != ignore) 9: favorita as bool?,
            if (updatedAt != ignore) 10: updatedAt as DateTime?,
            if (version != ignore) 11: version as int?,
            if (syncStatusIndex != ignore) 12: syncStatusIndex as int?,
            if (deletedAt != ignore) 13: deletedAt as DateTime?,
            if (isPublished != ignore) 14: isPublished as bool?,
            if (publicationReachIndex != ignore)
              15: publicationReachIndex as int?,
            if (publicationCategoryIndex != ignore)
              16: publicationCategoryIndex as int?,
            if (publishedAt != ignore) 17: publishedAt as DateTime?,
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
    DateTime? updatedAt,
    int? version,
    int? syncStatusIndex,
    DateTime? deletedAt,
    bool? isPublished,
    int? publicationReachIndex,
    int? publicationCategoryIndex,
    DateTime? publishedAt,
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
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
    Object? isPublished = ignore,
    Object? publicationReachIndex = ignore,
    Object? publicationCategoryIndex = ignore,
    Object? publishedAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (playlistId != ignore) 1: playlistId as String?,
      if (nome != ignore) 2: nome as String?,
      if (createdAt != ignore) 5: createdAt as DateTime?,
      if (salva != ignore) 6: salva as bool?,
      if (savedAt != ignore) 7: savedAt as DateTime?,
      if (favoritedAt != ignore) 8: favoritedAt as DateTime?,
      if (favorita != ignore) 9: favorita as bool?,
      if (updatedAt != ignore) 10: updatedAt as DateTime?,
      if (version != ignore) 11: version as int?,
      if (syncStatusIndex != ignore) 12: syncStatusIndex as int?,
      if (deletedAt != ignore) 13: deletedAt as DateTime?,
      if (isPublished != ignore) 14: isPublished as bool?,
      if (publicationReachIndex != ignore) 15: publicationReachIndex as int?,
      if (publicationCategoryIndex != ignore)
        16: publicationCategoryIndex as int?,
      if (publishedAt != ignore) 17: publishedAt as DateTime?,
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
    DateTime? updatedAt,
    int? version,
    int? syncStatusIndex,
    DateTime? deletedAt,
    bool? isPublished,
    int? publicationReachIndex,
    int? publicationCategoryIndex,
    DateTime? publishedAt,
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
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
    Object? isPublished = ignore,
    Object? publicationReachIndex = ignore,
    Object? publicationCategoryIndex = ignore,
    Object? publishedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (playlistId != ignore) 1: playlistId as String?,
      if (nome != ignore) 2: nome as String?,
      if (createdAt != ignore) 5: createdAt as DateTime?,
      if (salva != ignore) 6: salva as bool?,
      if (savedAt != ignore) 7: savedAt as DateTime?,
      if (favoritedAt != ignore) 8: favoritedAt as DateTime?,
      if (favorita != ignore) 9: favorita as bool?,
      if (updatedAt != ignore) 10: updatedAt as DateTime?,
      if (version != ignore) 11: version as int?,
      if (syncStatusIndex != ignore) 12: syncStatusIndex as int?,
      if (deletedAt != ignore) 13: deletedAt as DateTime?,
      if (isPublished != ignore) 14: isPublished as bool?,
      if (publicationReachIndex != ignore) 15: publicationReachIndex as int?,
      if (publicationCategoryIndex != ignore)
        16: publicationCategoryIndex as int?,
      if (publishedAt != ignore) 17: publishedAt as DateTime?,
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
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
    Object? isPublished = ignore,
    Object? publicationReachIndex = ignore,
    Object? publicationCategoryIndex = ignore,
    Object? publishedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (playlistId != ignore) 1: playlistId as String?,
        if (nome != ignore) 2: nome as String?,
        if (createdAt != ignore) 5: createdAt as DateTime?,
        if (salva != ignore) 6: salva as bool?,
        if (savedAt != ignore) 7: savedAt as DateTime?,
        if (favoritedAt != ignore) 8: favoritedAt as DateTime?,
        if (favorita != ignore) 9: favorita as bool?,
        if (updatedAt != ignore) 10: updatedAt as DateTime?,
        if (version != ignore) 11: version as int?,
        if (syncStatusIndex != ignore) 12: syncStatusIndex as int?,
        if (deletedAt != ignore) 13: deletedAt as DateTime?,
        if (isPublished != ignore) 14: isPublished as bool?,
        if (publicationReachIndex != ignore) 15: publicationReachIndex as int?,
        if (publicationCategoryIndex != ignore)
          16: publicationCategoryIndex as int?,
        if (publishedAt != ignore) 17: publishedAt as DateTime?,
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

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  audioIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> audioIdsIsEmpty() {
    return not().audioIdsIsNotEmpty();
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> audioIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 4, value: null),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> salvaEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 7));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtGreaterThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  savedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 7, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  savedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> savedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 7, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 8));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  favoritedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> favoritaEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  updatedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> updatedAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  updatedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 10, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 10, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> versionEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> versionGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  versionGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> versionLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  versionLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 11, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> versionBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 11, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  syncStatusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  syncStatusIndexGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  syncStatusIndexGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  syncStatusIndexLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  syncStatusIndexLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  syncStatusIndexBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 12, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 13));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> deletedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 13));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> deletedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 13, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> deletedAtGreaterThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 13, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  deletedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 13, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> deletedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 13, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  deletedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 13, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> deletedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 13, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> isPublishedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 14, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 15));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 15));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 15, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexGreaterThan(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 15, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexGreaterThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 15, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexLessThan(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 15, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexLessThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 15, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationReachIndexBetween(int? lower, int? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 15, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 16));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 16));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 16, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexGreaterThan(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 16, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexGreaterThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 16, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexLessThan(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 16, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexLessThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 16, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publicationCategoryIndexBetween(int? lower, int? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 16, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> publishedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 17));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publishedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 17));
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> publishedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 17, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publishedAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 17, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publishedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 17, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> publishedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 17, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition>
  publishedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 17, value: value),
      );
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterFilterCondition> publishedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 17, lower: lower, upper: upper),
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
      return query.addSortBy(5);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySalva() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySalvaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavoritedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavorita() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByFavoritaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySyncStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortBySyncStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByIsPublished() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByIsPublishedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByPublicationReachIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(15);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy>
  sortByPublicationReachIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(15, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy>
  sortByPublicationCategoryIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(16);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy>
  sortByPublicationCategoryIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(16, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(17);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> sortByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(17, sort: Sort.desc);
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
      return query.addSortBy(5);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySalva() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySalvaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavoritedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavorita() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByFavoritaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySyncStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenBySyncStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByIsPublished() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByIsPublishedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByPublicationReachIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(15);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy>
  thenByPublicationReachIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(15, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy>
  thenByPublicationCategoryIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(16);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy>
  thenByPublicationCategoryIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(16, sort: Sort.desc);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(17);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterSortBy> thenByPublishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(17, sort: Sort.desc);
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

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByAudioIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctBySalva() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByFavoritedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByFavorita() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctBySyncStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(12);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(13);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByIsPublished() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(14);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct>
  distinctByPublicationReachIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(15);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct>
  distinctByPublicationCategoryIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(16);
    });
  }

  QueryBuilder<Playlist, Playlist, QAfterDistinct> distinctByPublishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(17);
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

  QueryBuilder<Playlist, List<String>, QAfterProperty> audioIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Playlist, DateTime, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Playlist, bool, QAfterProperty> salvaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Playlist, DateTime?, QAfterProperty> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Playlist, DateTime?, QAfterProperty> favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<Playlist, bool, QAfterProperty> favoritaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<Playlist, DateTime, QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<Playlist, int, QAfterProperty> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<Playlist, int, QAfterProperty> syncStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<Playlist, DateTime?, QAfterProperty> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }

  QueryBuilder<Playlist, bool, QAfterProperty> isPublishedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(14);
    });
  }

  QueryBuilder<Playlist, int?, QAfterProperty> publicationReachIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(15);
    });
  }

  QueryBuilder<Playlist, int?, QAfterProperty>
  publicationCategoryIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(16);
    });
  }

  QueryBuilder<Playlist, DateTime?, QAfterProperty> publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(17);
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

  QueryBuilder<Playlist, (R, List<String>), QAfterProperty> audioIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Playlist, (R, DateTime), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Playlist, (R, bool), QAfterProperty> salvaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Playlist, (R, DateTime?), QAfterProperty> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Playlist, (R, DateTime?), QAfterProperty> favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<Playlist, (R, bool), QAfterProperty> favoritaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<Playlist, (R, DateTime), QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<Playlist, (R, int), QAfterProperty> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<Playlist, (R, int), QAfterProperty> syncStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<Playlist, (R, DateTime?), QAfterProperty> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }

  QueryBuilder<Playlist, (R, bool), QAfterProperty> isPublishedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(14);
    });
  }

  QueryBuilder<Playlist, (R, int?), QAfterProperty>
  publicationReachIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(15);
    });
  }

  QueryBuilder<Playlist, (R, int?), QAfterProperty>
  publicationCategoryIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(16);
    });
  }

  QueryBuilder<Playlist, (R, DateTime?), QAfterProperty> publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(17);
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

  QueryBuilder<Playlist, (R1, R2, List<String>), QOperations>
  audioIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime), QOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<Playlist, (R1, R2, bool), QOperations> salvaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime?), QOperations> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime?), QOperations>
  favoritedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<Playlist, (R1, R2, bool), QOperations> favoritaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime), QOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<Playlist, (R1, R2, int), QOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<Playlist, (R1, R2, int), QOperations> syncStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime?), QOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }

  QueryBuilder<Playlist, (R1, R2, bool), QOperations> isPublishedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(14);
    });
  }

  QueryBuilder<Playlist, (R1, R2, int?), QOperations>
  publicationReachIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(15);
    });
  }

  QueryBuilder<Playlist, (R1, R2, int?), QOperations>
  publicationCategoryIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(16);
    });
  }

  QueryBuilder<Playlist, (R1, R2, DateTime?), QOperations>
  publishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(17);
    });
  }
}
