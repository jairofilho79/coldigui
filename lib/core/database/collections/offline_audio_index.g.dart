// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_audio_index.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetOfflineAudioIndexCollection on Isar {
  IsarCollection<int, OfflineAudioIndex> get offlineAudioIndexs =>
      this.collection();
}

final OfflineAudioIndexSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'OfflineAudioIndex',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'audioId', type: IsarType.string),
      IsarPropertySchema(name: 'r2Key', type: IsarType.string),
      IsarPropertySchema(name: 'storageKey', type: IsarType.string),
      IsarPropertySchema(name: 'fileSize', type: IsarType.long),
      IsarPropertySchema(name: 'downloadedAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'audioId',
        properties: ["audioId"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, OfflineAudioIndex>(
    serialize: serializeOfflineAudioIndex,
    deserialize: deserializeOfflineAudioIndex,
    deserializeProperty: deserializeOfflineAudioIndexProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeOfflineAudioIndex(IsarWriter writer, OfflineAudioIndex object) {
  IsarCore.writeString(writer, 1, object.audioId);
  IsarCore.writeString(writer, 2, object.r2Key);
  IsarCore.writeString(writer, 3, object.storageKey);
  IsarCore.writeLong(writer, 4, object.fileSize);
  IsarCore.writeLong(
    writer,
    5,
    object.downloadedAt.toUtc().microsecondsSinceEpoch,
  );
  return object.id;
}

@isarProtected
OfflineAudioIndex deserializeOfflineAudioIndex(IsarReader reader) {
  final object = OfflineAudioIndex();
  object.id = IsarCore.readId(reader);
  object.audioId = IsarCore.readString(reader, 1) ?? '';
  object.r2Key = IsarCore.readString(reader, 2) ?? '';
  object.storageKey = IsarCore.readString(reader, 3) ?? '';
  object.fileSize = IsarCore.readLong(reader, 4);
  {
    final value = IsarCore.readLong(reader, 5);
    if (value == -9223372036854775808) {
      object.downloadedAt = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      object.downloadedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  return object;
}

@isarProtected
dynamic deserializeOfflineAudioIndexProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readLong(reader, 4);
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
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _OfflineAudioIndexUpdate {
  bool call({
    required int id,
    String? audioId,
    String? r2Key,
    String? storageKey,
    int? fileSize,
    DateTime? downloadedAt,
  });
}

class _OfflineAudioIndexUpdateImpl implements _OfflineAudioIndexUpdate {
  const _OfflineAudioIndexUpdateImpl(this.collection);

  final IsarCollection<int, OfflineAudioIndex> collection;

  @override
  bool call({
    required int id,
    Object? audioId = ignore,
    Object? r2Key = ignore,
    Object? storageKey = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (audioId != ignore) 1: audioId as String?,
            if (r2Key != ignore) 2: r2Key as String?,
            if (storageKey != ignore) 3: storageKey as String?,
            if (fileSize != ignore) 4: fileSize as int?,
            if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _OfflineAudioIndexUpdateAll {
  int call({
    required List<int> id,
    String? audioId,
    String? r2Key,
    String? storageKey,
    int? fileSize,
    DateTime? downloadedAt,
  });
}

class _OfflineAudioIndexUpdateAllImpl implements _OfflineAudioIndexUpdateAll {
  const _OfflineAudioIndexUpdateAllImpl(this.collection);

  final IsarCollection<int, OfflineAudioIndex> collection;

  @override
  int call({
    required List<int> id,
    Object? audioId = ignore,
    Object? r2Key = ignore,
    Object? storageKey = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (audioId != ignore) 1: audioId as String?,
      if (r2Key != ignore) 2: r2Key as String?,
      if (storageKey != ignore) 3: storageKey as String?,
      if (fileSize != ignore) 4: fileSize as int?,
      if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
    });
  }
}

extension OfflineAudioIndexUpdate on IsarCollection<int, OfflineAudioIndex> {
  _OfflineAudioIndexUpdate get update => _OfflineAudioIndexUpdateImpl(this);

  _OfflineAudioIndexUpdateAll get updateAll =>
      _OfflineAudioIndexUpdateAllImpl(this);
}

sealed class _OfflineAudioIndexQueryUpdate {
  int call({
    String? audioId,
    String? r2Key,
    String? storageKey,
    int? fileSize,
    DateTime? downloadedAt,
  });
}

class _OfflineAudioIndexQueryUpdateImpl
    implements _OfflineAudioIndexQueryUpdate {
  const _OfflineAudioIndexQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<OfflineAudioIndex> query;
  final int? limit;

  @override
  int call({
    Object? audioId = ignore,
    Object? r2Key = ignore,
    Object? storageKey = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (audioId != ignore) 1: audioId as String?,
      if (r2Key != ignore) 2: r2Key as String?,
      if (storageKey != ignore) 3: storageKey as String?,
      if (fileSize != ignore) 4: fileSize as int?,
      if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
    });
  }
}

extension OfflineAudioIndexQueryUpdate on IsarQuery<OfflineAudioIndex> {
  _OfflineAudioIndexQueryUpdate get updateFirst =>
      _OfflineAudioIndexQueryUpdateImpl(this, limit: 1);

  _OfflineAudioIndexQueryUpdate get updateAll =>
      _OfflineAudioIndexQueryUpdateImpl(this);
}

class _OfflineAudioIndexQueryBuilderUpdateImpl
    implements _OfflineAudioIndexQueryUpdate {
  const _OfflineAudioIndexQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? audioId = ignore,
    Object? r2Key = ignore,
    Object? storageKey = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (audioId != ignore) 1: audioId as String?,
        if (r2Key != ignore) 2: r2Key as String?,
        if (storageKey != ignore) 3: storageKey as String?,
        if (fileSize != ignore) 4: fileSize as int?,
        if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension OfflineAudioIndexQueryBuilderUpdate
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QOperations> {
  _OfflineAudioIndexQueryUpdate get updateFirst =>
      _OfflineAudioIndexQueryBuilderUpdateImpl(this, limit: 1);

  _OfflineAudioIndexQueryUpdate get updateAll =>
      _OfflineAudioIndexQueryBuilderUpdateImpl(this);
}

extension OfflineAudioIndexQueryFilter
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QFilterCondition> {
  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  audioIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  r2KeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  storageKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  fileSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  fileSizeGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  fileSizeGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  fileSizeLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 4, value: value));
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  fileSizeLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  fileSizeBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 4, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  downloadedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  downloadedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  downloadedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  downloadedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  downloadedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterFilterCondition>
  downloadedAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }
}

extension OfflineAudioIndexQueryObject
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QFilterCondition> {}

extension OfflineAudioIndexQuerySortBy
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QSortBy> {
  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByAudioId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByAudioIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy> sortByR2Key({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByR2KeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByStorageKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByStorageKeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  sortByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }
}

extension OfflineAudioIndexQuerySortThenBy
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QSortThenBy> {
  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByAudioId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByAudioIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy> thenByR2Key({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByR2KeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByStorageKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByStorageKeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterSortBy>
  thenByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }
}

extension OfflineAudioIndexQueryWhereDistinct
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QDistinct> {
  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterDistinct>
  distinctByAudioId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterDistinct>
  distinctByR2Key({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterDistinct>
  distinctByStorageKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterDistinct>
  distinctByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QAfterDistinct>
  distinctByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }
}

extension OfflineAudioIndexQueryProperty1
    on QueryBuilder<OfflineAudioIndex, OfflineAudioIndex, QProperty> {
  QueryBuilder<OfflineAudioIndex, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<OfflineAudioIndex, String, QAfterProperty> audioIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<OfflineAudioIndex, String, QAfterProperty> r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<OfflineAudioIndex, String, QAfterProperty> storageKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<OfflineAudioIndex, int, QAfterProperty> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<OfflineAudioIndex, DateTime, QAfterProperty>
  downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

extension OfflineAudioIndexQueryProperty2<R>
    on QueryBuilder<OfflineAudioIndex, R, QAfterProperty> {
  QueryBuilder<OfflineAudioIndex, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R, String), QAfterProperty>
  audioIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R, String), QAfterProperty> r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R, String), QAfterProperty>
  storageKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R, int), QAfterProperty> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R, DateTime), QAfterProperty>
  downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

extension OfflineAudioIndexQueryProperty3<R1, R2>
    on QueryBuilder<OfflineAudioIndex, (R1, R2), QAfterProperty> {
  QueryBuilder<OfflineAudioIndex, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R1, R2, String), QOperations>
  audioIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R1, R2, String), QOperations>
  r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R1, R2, String), QOperations>
  storageKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R1, R2, int), QOperations>
  fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<OfflineAudioIndex, (R1, R2, DateTime), QOperations>
  downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}
