// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_flag.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetAudioFlagCollection on Isar {
  IsarCollection<int, AudioFlag> get audioFlags => this.collection();
}

final AudioFlagSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'AudioFlag',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'flagId', type: IsarType.string),
      IsarPropertySchema(name: 'audioId', type: IsarType.string),
      IsarPropertySchema(name: 'positionMs', type: IsarType.long),
      IsarPropertySchema(name: 'label', type: IsarType.string),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'version', type: IsarType.long),
      IsarPropertySchema(name: 'syncStatusIndex', type: IsarType.long),
      IsarPropertySchema(name: 'deletedAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'flagId',
        properties: ["flagId"],
        unique: true,
        hash: false,
      ),
      IsarIndexSchema(
        name: 'audioId',
        properties: ["audioId"],
        unique: false,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, AudioFlag>(
    serialize: serializeAudioFlag,
    deserialize: deserializeAudioFlag,
    deserializeProperty: deserializeAudioFlagProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeAudioFlag(IsarWriter writer, AudioFlag object) {
  IsarCore.writeString(writer, 1, object.flagId);
  IsarCore.writeString(writer, 2, object.audioId);
  IsarCore.writeLong(writer, 3, object.positionMs);
  IsarCore.writeString(writer, 4, object.label);
  IsarCore.writeLong(
    writer,
    5,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(
    writer,
    6,
    object.updatedAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(writer, 7, object.version);
  IsarCore.writeLong(writer, 8, object.syncStatusIndex);
  IsarCore.writeLong(
    writer,
    9,
    object.deletedAt?.toUtc().microsecondsSinceEpoch ?? -9223372036854775808,
  );
  return object.id;
}

@isarProtected
AudioFlag deserializeAudioFlag(IsarReader reader) {
  final object = AudioFlag();
  object.id = IsarCore.readId(reader);
  object.flagId = IsarCore.readString(reader, 1) ?? '';
  object.audioId = IsarCore.readString(reader, 2) ?? '';
  object.positionMs = IsarCore.readLong(reader, 3);
  object.label = IsarCore.readString(reader, 4) ?? '';
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
  {
    final value = IsarCore.readLong(reader, 6);
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
  object.version = IsarCore.readLong(reader, 7);
  object.syncStatusIndex = IsarCore.readLong(reader, 8);
  {
    final value = IsarCore.readLong(reader, 9);
    if (value == -9223372036854775808) {
      object.deletedAt = null;
    } else {
      object.deletedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  return object;
}

@isarProtected
dynamic deserializeAudioFlagProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readLong(reader, 3);
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
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
      {
        final value = IsarCore.readLong(reader, 6);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 7:
      return IsarCore.readLong(reader, 7);
    case 8:
      return IsarCore.readLong(reader, 8);
    case 9:
      {
        final value = IsarCore.readLong(reader, 9);
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

sealed class _AudioFlagUpdate {
  bool call({
    required int id,
    String? flagId,
    String? audioId,
    int? positionMs,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    int? syncStatusIndex,
    DateTime? deletedAt,
  });
}

class _AudioFlagUpdateImpl implements _AudioFlagUpdate {
  const _AudioFlagUpdateImpl(this.collection);

  final IsarCollection<int, AudioFlag> collection;

  @override
  bool call({
    required int id,
    Object? flagId = ignore,
    Object? audioId = ignore,
    Object? positionMs = ignore,
    Object? label = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (flagId != ignore) 1: flagId as String?,
            if (audioId != ignore) 2: audioId as String?,
            if (positionMs != ignore) 3: positionMs as int?,
            if (label != ignore) 4: label as String?,
            if (createdAt != ignore) 5: createdAt as DateTime?,
            if (updatedAt != ignore) 6: updatedAt as DateTime?,
            if (version != ignore) 7: version as int?,
            if (syncStatusIndex != ignore) 8: syncStatusIndex as int?,
            if (deletedAt != ignore) 9: deletedAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _AudioFlagUpdateAll {
  int call({
    required List<int> id,
    String? flagId,
    String? audioId,
    int? positionMs,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    int? syncStatusIndex,
    DateTime? deletedAt,
  });
}

class _AudioFlagUpdateAllImpl implements _AudioFlagUpdateAll {
  const _AudioFlagUpdateAllImpl(this.collection);

  final IsarCollection<int, AudioFlag> collection;

  @override
  int call({
    required List<int> id,
    Object? flagId = ignore,
    Object? audioId = ignore,
    Object? positionMs = ignore,
    Object? label = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (flagId != ignore) 1: flagId as String?,
      if (audioId != ignore) 2: audioId as String?,
      if (positionMs != ignore) 3: positionMs as int?,
      if (label != ignore) 4: label as String?,
      if (createdAt != ignore) 5: createdAt as DateTime?,
      if (updatedAt != ignore) 6: updatedAt as DateTime?,
      if (version != ignore) 7: version as int?,
      if (syncStatusIndex != ignore) 8: syncStatusIndex as int?,
      if (deletedAt != ignore) 9: deletedAt as DateTime?,
    });
  }
}

extension AudioFlagUpdate on IsarCollection<int, AudioFlag> {
  _AudioFlagUpdate get update => _AudioFlagUpdateImpl(this);

  _AudioFlagUpdateAll get updateAll => _AudioFlagUpdateAllImpl(this);
}

sealed class _AudioFlagQueryUpdate {
  int call({
    String? flagId,
    String? audioId,
    int? positionMs,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    int? syncStatusIndex,
    DateTime? deletedAt,
  });
}

class _AudioFlagQueryUpdateImpl implements _AudioFlagQueryUpdate {
  const _AudioFlagQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<AudioFlag> query;
  final int? limit;

  @override
  int call({
    Object? flagId = ignore,
    Object? audioId = ignore,
    Object? positionMs = ignore,
    Object? label = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (flagId != ignore) 1: flagId as String?,
      if (audioId != ignore) 2: audioId as String?,
      if (positionMs != ignore) 3: positionMs as int?,
      if (label != ignore) 4: label as String?,
      if (createdAt != ignore) 5: createdAt as DateTime?,
      if (updatedAt != ignore) 6: updatedAt as DateTime?,
      if (version != ignore) 7: version as int?,
      if (syncStatusIndex != ignore) 8: syncStatusIndex as int?,
      if (deletedAt != ignore) 9: deletedAt as DateTime?,
    });
  }
}

extension AudioFlagQueryUpdate on IsarQuery<AudioFlag> {
  _AudioFlagQueryUpdate get updateFirst =>
      _AudioFlagQueryUpdateImpl(this, limit: 1);

  _AudioFlagQueryUpdate get updateAll => _AudioFlagQueryUpdateImpl(this);
}

class _AudioFlagQueryBuilderUpdateImpl implements _AudioFlagQueryUpdate {
  const _AudioFlagQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<AudioFlag, AudioFlag, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? flagId = ignore,
    Object? audioId = ignore,
    Object? positionMs = ignore,
    Object? label = ignore,
    Object? createdAt = ignore,
    Object? updatedAt = ignore,
    Object? version = ignore,
    Object? syncStatusIndex = ignore,
    Object? deletedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (flagId != ignore) 1: flagId as String?,
        if (audioId != ignore) 2: audioId as String?,
        if (positionMs != ignore) 3: positionMs as int?,
        if (label != ignore) 4: label as String?,
        if (createdAt != ignore) 5: createdAt as DateTime?,
        if (updatedAt != ignore) 6: updatedAt as DateTime?,
        if (version != ignore) 7: version as int?,
        if (syncStatusIndex != ignore) 8: syncStatusIndex as int?,
        if (deletedAt != ignore) 9: deletedAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension AudioFlagQueryBuilderUpdate
    on QueryBuilder<AudioFlag, AudioFlag, QOperations> {
  _AudioFlagQueryUpdate get updateFirst =>
      _AudioFlagQueryBuilderUpdateImpl(this, limit: 1);

  _AudioFlagQueryUpdate get updateAll => _AudioFlagQueryBuilderUpdateImpl(this);
}

extension AudioFlagQueryFilter
    on QueryBuilder<AudioFlag, AudioFlag, QFilterCondition> {
  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdGreaterThan(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  flagIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  flagIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdBetween(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdStartsWith(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdEndsWith(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdContains(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdMatches(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> flagIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdGreaterThan(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  audioIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  audioIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdBetween(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdStartsWith(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdEndsWith(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdContains(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdMatches(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> audioIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  audioIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> positionMsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  positionMsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  positionMsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> positionMsLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 3, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  positionMsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> positionMsBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 3, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  labelGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  labelLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelBetween(
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> createdAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  updatedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  updatedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> updatedAtLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  updatedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> versionEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> versionGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  versionGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> versionLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 7, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  versionLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 7, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> versionBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 7, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  syncStatusIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  syncStatusIndexGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  syncStatusIndexGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  syncStatusIndexLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  syncStatusIndexLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  syncStatusIndexBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  deletedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 9));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> deletedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  deletedAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  deletedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> deletedAtLessThan(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition>
  deletedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterFilterCondition> deletedAtBetween(
    DateTime? lower,
    DateTime? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }
}

extension AudioFlagQueryObject
    on QueryBuilder<AudioFlag, AudioFlag, QFilterCondition> {}

extension AudioFlagQuerySortBy on QueryBuilder<AudioFlag, AudioFlag, QSortBy> {
  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByFlagId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByFlagIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByAudioId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByAudioIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByPositionMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByPositionMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByLabel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByLabelDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortBySyncStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortBySyncStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }
}

extension AudioFlagQuerySortThenBy
    on QueryBuilder<AudioFlag, AudioFlag, QSortThenBy> {
  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByFlagId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByFlagIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByAudioId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByAudioIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByPositionMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByPositionMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByLabel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByLabelDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenBySyncStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenBySyncStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }
}

extension AudioFlagQueryWhereDistinct
    on QueryBuilder<AudioFlag, AudioFlag, QDistinct> {
  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByFlagId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByAudioId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByPositionMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByLabel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct>
  distinctBySyncStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<AudioFlag, AudioFlag, QAfterDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }
}

extension AudioFlagQueryProperty1
    on QueryBuilder<AudioFlag, AudioFlag, QProperty> {
  QueryBuilder<AudioFlag, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<AudioFlag, String, QAfterProperty> flagIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AudioFlag, String, QAfterProperty> audioIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AudioFlag, int, QAfterProperty> positionMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<AudioFlag, String, QAfterProperty> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<AudioFlag, DateTime, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<AudioFlag, DateTime, QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<AudioFlag, int, QAfterProperty> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<AudioFlag, int, QAfterProperty> syncStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<AudioFlag, DateTime?, QAfterProperty> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension AudioFlagQueryProperty2<R>
    on QueryBuilder<AudioFlag, R, QAfterProperty> {
  QueryBuilder<AudioFlag, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<AudioFlag, (R, String), QAfterProperty> flagIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AudioFlag, (R, String), QAfterProperty> audioIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AudioFlag, (R, int), QAfterProperty> positionMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<AudioFlag, (R, String), QAfterProperty> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<AudioFlag, (R, DateTime), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<AudioFlag, (R, DateTime), QAfterProperty> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<AudioFlag, (R, int), QAfterProperty> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<AudioFlag, (R, int), QAfterProperty> syncStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<AudioFlag, (R, DateTime?), QAfterProperty> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension AudioFlagQueryProperty3<R1, R2>
    on QueryBuilder<AudioFlag, (R1, R2), QAfterProperty> {
  QueryBuilder<AudioFlag, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, String), QOperations> flagIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, String), QOperations> audioIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, int), QOperations> positionMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, String), QOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, DateTime), QOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, DateTime), QOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, int), QOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, int), QOperations>
  syncStatusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<AudioFlag, (R1, R2, DateTime?), QOperations>
  deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}
