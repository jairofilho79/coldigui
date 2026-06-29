// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_pdf_index.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetOfflinePdfIndexCollection on Isar {
  IsarCollection<int, OfflinePdfIndex> get offlinePdfIndexs =>
      this.collection();
}

final OfflinePdfIndexSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'OfflinePdfIndex',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'pdfId', type: IsarType.string),
      IsarPropertySchema(name: 'storagePath', type: IsarType.string),
      IsarPropertySchema(name: 'category', type: IsarType.string),
      IsarPropertySchema(name: 'fileSize', type: IsarType.long),
      IsarPropertySchema(name: 'downloadedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'lastAccessedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'isPersistent', type: IsarType.bool),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'pdfId',
        properties: ["pdfId"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, OfflinePdfIndex>(
    serialize: serializeOfflinePdfIndex,
    deserialize: deserializeOfflinePdfIndex,
    deserializeProperty: deserializeOfflinePdfIndexProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeOfflinePdfIndex(IsarWriter writer, OfflinePdfIndex object) {
  IsarCore.writeString(writer, 1, object.pdfId);
  IsarCore.writeString(writer, 2, object.storagePath);
  IsarCore.writeString(writer, 3, object.category);
  IsarCore.writeLong(writer, 4, object.fileSize);
  IsarCore.writeLong(
    writer,
    5,
    object.downloadedAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(
    writer,
    6,
    object.lastAccessedAt?.toUtc().microsecondsSinceEpoch ??
        -9223372036854775808,
  );
  IsarCore.writeBool(writer, 7, value: object.isPersistent);
  return object.id;
}

@isarProtected
OfflinePdfIndex deserializeOfflinePdfIndex(IsarReader reader) {
  final object = OfflinePdfIndex();
  object.id = IsarCore.readId(reader);
  object.pdfId = IsarCore.readString(reader, 1) ?? '';
  object.storagePath = IsarCore.readString(reader, 2) ?? '';
  object.category = IsarCore.readString(reader, 3) ?? '';
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
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      object.lastAccessedAt = null;
    } else {
      object.lastAccessedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  object.isPersistent = IsarCore.readBool(reader, 7);
  return object;
}

@isarProtected
dynamic deserializeOfflinePdfIndexProp(IsarReader reader, int property) {
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
      return IsarCore.readBool(reader, 7);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _OfflinePdfIndexUpdate {
  bool call({
    required int id,
    String? pdfId,
    String? storagePath,
    String? category,
    int? fileSize,
    DateTime? downloadedAt,
    DateTime? lastAccessedAt,
    bool? isPersistent,
  });
}

class _OfflinePdfIndexUpdateImpl implements _OfflinePdfIndexUpdate {
  const _OfflinePdfIndexUpdateImpl(this.collection);

  final IsarCollection<int, OfflinePdfIndex> collection;

  @override
  bool call({
    required int id,
    Object? pdfId = ignore,
    Object? storagePath = ignore,
    Object? category = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
    Object? lastAccessedAt = ignore,
    Object? isPersistent = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (pdfId != ignore) 1: pdfId as String?,
            if (storagePath != ignore) 2: storagePath as String?,
            if (category != ignore) 3: category as String?,
            if (fileSize != ignore) 4: fileSize as int?,
            if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
            if (lastAccessedAt != ignore) 6: lastAccessedAt as DateTime?,
            if (isPersistent != ignore) 7: isPersistent as bool?,
          },
        ) >
        0;
  }
}

sealed class _OfflinePdfIndexUpdateAll {
  int call({
    required List<int> id,
    String? pdfId,
    String? storagePath,
    String? category,
    int? fileSize,
    DateTime? downloadedAt,
    DateTime? lastAccessedAt,
    bool? isPersistent,
  });
}

class _OfflinePdfIndexUpdateAllImpl implements _OfflinePdfIndexUpdateAll {
  const _OfflinePdfIndexUpdateAllImpl(this.collection);

  final IsarCollection<int, OfflinePdfIndex> collection;

  @override
  int call({
    required List<int> id,
    Object? pdfId = ignore,
    Object? storagePath = ignore,
    Object? category = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
    Object? lastAccessedAt = ignore,
    Object? isPersistent = ignore,
  }) {
    return collection.updateProperties(id, {
      if (pdfId != ignore) 1: pdfId as String?,
      if (storagePath != ignore) 2: storagePath as String?,
      if (category != ignore) 3: category as String?,
      if (fileSize != ignore) 4: fileSize as int?,
      if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
      if (lastAccessedAt != ignore) 6: lastAccessedAt as DateTime?,
      if (isPersistent != ignore) 7: isPersistent as bool?,
    });
  }
}

extension OfflinePdfIndexUpdate on IsarCollection<int, OfflinePdfIndex> {
  _OfflinePdfIndexUpdate get update => _OfflinePdfIndexUpdateImpl(this);

  _OfflinePdfIndexUpdateAll get updateAll =>
      _OfflinePdfIndexUpdateAllImpl(this);
}

sealed class _OfflinePdfIndexQueryUpdate {
  int call({
    String? pdfId,
    String? storagePath,
    String? category,
    int? fileSize,
    DateTime? downloadedAt,
    DateTime? lastAccessedAt,
    bool? isPersistent,
  });
}

class _OfflinePdfIndexQueryUpdateImpl implements _OfflinePdfIndexQueryUpdate {
  const _OfflinePdfIndexQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<OfflinePdfIndex> query;
  final int? limit;

  @override
  int call({
    Object? pdfId = ignore,
    Object? storagePath = ignore,
    Object? category = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
    Object? lastAccessedAt = ignore,
    Object? isPersistent = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (pdfId != ignore) 1: pdfId as String?,
      if (storagePath != ignore) 2: storagePath as String?,
      if (category != ignore) 3: category as String?,
      if (fileSize != ignore) 4: fileSize as int?,
      if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
      if (lastAccessedAt != ignore) 6: lastAccessedAt as DateTime?,
      if (isPersistent != ignore) 7: isPersistent as bool?,
    });
  }
}

extension OfflinePdfIndexQueryUpdate on IsarQuery<OfflinePdfIndex> {
  _OfflinePdfIndexQueryUpdate get updateFirst =>
      _OfflinePdfIndexQueryUpdateImpl(this, limit: 1);

  _OfflinePdfIndexQueryUpdate get updateAll =>
      _OfflinePdfIndexQueryUpdateImpl(this);
}

class _OfflinePdfIndexQueryBuilderUpdateImpl
    implements _OfflinePdfIndexQueryUpdate {
  const _OfflinePdfIndexQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? pdfId = ignore,
    Object? storagePath = ignore,
    Object? category = ignore,
    Object? fileSize = ignore,
    Object? downloadedAt = ignore,
    Object? lastAccessedAt = ignore,
    Object? isPersistent = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (pdfId != ignore) 1: pdfId as String?,
        if (storagePath != ignore) 2: storagePath as String?,
        if (category != ignore) 3: category as String?,
        if (fileSize != ignore) 4: fileSize as int?,
        if (downloadedAt != ignore) 5: downloadedAt as DateTime?,
        if (lastAccessedAt != ignore) 6: lastAccessedAt as DateTime?,
        if (isPersistent != ignore) 7: isPersistent as bool?,
      });
    } finally {
      q.close();
    }
  }
}

extension OfflinePdfIndexQueryBuilderUpdate
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QOperations> {
  _OfflinePdfIndexQueryUpdate get updateFirst =>
      _OfflinePdfIndexQueryBuilderUpdateImpl(this, limit: 1);

  _OfflinePdfIndexQueryUpdate get updateAll =>
      _OfflinePdfIndexQueryBuilderUpdateImpl(this);
}

extension OfflinePdfIndexQueryFilter
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QFilterCondition> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  pdfIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  storagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  fileSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  fileSizeGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  fileSizeGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  fileSizeLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 4, value: value));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  fileSizeLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  fileSizeBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 4, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  downloadedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  downloadedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  downloadedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  downloadedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  downloadedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  downloadedAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 6));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtGreaterThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtGreaterThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtLessThan(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtLessThanOrEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  lastAccessedAtBetween(DateTime? lower, DateTime? upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterFilterCondition>
  isPersistentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value),
      );
    });
  }
}

extension OfflinePdfIndexQueryObject
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QFilterCondition> {}

extension OfflinePdfIndexQuerySortBy
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QSortBy> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> sortByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> sortByPdfIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByStoragePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByStoragePathDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> sortByCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByCategoryDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByLastAccessedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByIsPersistent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  sortByIsPersistentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }
}

extension OfflinePdfIndexQuerySortThenBy
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QSortThenBy> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenByPdfIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByStoragePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByStoragePathDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy> thenByCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByCategoryDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByDownloadedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByLastAccessedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByIsPersistent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterSortBy>
  thenByIsPersistentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }
}

extension OfflinePdfIndexQueryWhereDistinct
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QDistinct> {
  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByPdfId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByStoragePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByDownloadedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByLastAccessedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QAfterDistinct>
  distinctByIsPersistent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }
}

extension OfflinePdfIndexQueryProperty1
    on QueryBuilder<OfflinePdfIndex, OfflinePdfIndex, QProperty> {
  QueryBuilder<OfflinePdfIndex, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<OfflinePdfIndex, String, QAfterProperty> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<OfflinePdfIndex, String, QAfterProperty> storagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<OfflinePdfIndex, String, QAfterProperty> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<OfflinePdfIndex, int, QAfterProperty> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<OfflinePdfIndex, DateTime, QAfterProperty>
  downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<OfflinePdfIndex, DateTime?, QAfterProperty>
  lastAccessedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<OfflinePdfIndex, bool, QAfterProperty> isPersistentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }
}

extension OfflinePdfIndexQueryProperty2<R>
    on QueryBuilder<OfflinePdfIndex, R, QAfterProperty> {
  QueryBuilder<OfflinePdfIndex, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, String), QAfterProperty> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, String), QAfterProperty>
  storagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, String), QAfterProperty>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, int), QAfterProperty> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, DateTime), QAfterProperty>
  downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, DateTime?), QAfterProperty>
  lastAccessedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R, bool), QAfterProperty>
  isPersistentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }
}

extension OfflinePdfIndexQueryProperty3<R1, R2>
    on QueryBuilder<OfflinePdfIndex, (R1, R2), QAfterProperty> {
  QueryBuilder<OfflinePdfIndex, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, String), QOperations> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, String), QOperations>
  storagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, String), QOperations>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, int), QOperations> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, DateTime), QOperations>
  downloadedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, DateTime?), QOperations>
  lastAccessedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<OfflinePdfIndex, (R1, R2, bool), QOperations>
  isPersistentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }
}
