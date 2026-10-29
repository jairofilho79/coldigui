// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chord_content_cache.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetChordContentCacheCollection on Isar {
  IsarCollection<int, ChordContentCache> get chordContentCaches =>
      this.collection();
}

final ChordContentCacheSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'ChordContentCache',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'r2Key', type: IsarType.string),
      IsarPropertySchema(name: 'content', type: IsarType.string),
      IsarPropertySchema(name: 'fetchedAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'r2Key',
        properties: ["r2Key"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, ChordContentCache>(
    serialize: serializeChordContentCache,
    deserialize: deserializeChordContentCache,
    deserializeProperty: deserializeChordContentCacheProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeChordContentCache(IsarWriter writer, ChordContentCache object) {
  IsarCore.writeString(writer, 1, object.r2Key);
  IsarCore.writeString(writer, 2, object.content);
  IsarCore.writeLong(
    writer,
    3,
    object.fetchedAt.toUtc().microsecondsSinceEpoch,
  );
  return object.id;
}

@isarProtected
ChordContentCache deserializeChordContentCache(IsarReader reader) {
  final object = ChordContentCache();
  object.id = IsarCore.readId(reader);
  object.r2Key = IsarCore.readString(reader, 1) ?? '';
  object.content = IsarCore.readString(reader, 2) ?? '';
  {
    final value = IsarCore.readLong(reader, 3);
    if (value == -9223372036854775808) {
      object.fetchedAt = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      object.fetchedAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  return object;
}

@isarProtected
dynamic deserializeChordContentCacheProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      {
        final value = IsarCore.readLong(reader, 3);
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

sealed class _ChordContentCacheUpdate {
  bool call({
    required int id,
    String? r2Key,
    String? content,
    DateTime? fetchedAt,
  });
}

class _ChordContentCacheUpdateImpl implements _ChordContentCacheUpdate {
  const _ChordContentCacheUpdateImpl(this.collection);

  final IsarCollection<int, ChordContentCache> collection;

  @override
  bool call({
    required int id,
    Object? r2Key = ignore,
    Object? content = ignore,
    Object? fetchedAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (r2Key != ignore) 1: r2Key as String?,
            if (content != ignore) 2: content as String?,
            if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _ChordContentCacheUpdateAll {
  int call({
    required List<int> id,
    String? r2Key,
    String? content,
    DateTime? fetchedAt,
  });
}

class _ChordContentCacheUpdateAllImpl implements _ChordContentCacheUpdateAll {
  const _ChordContentCacheUpdateAllImpl(this.collection);

  final IsarCollection<int, ChordContentCache> collection;

  @override
  int call({
    required List<int> id,
    Object? r2Key = ignore,
    Object? content = ignore,
    Object? fetchedAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (r2Key != ignore) 1: r2Key as String?,
      if (content != ignore) 2: content as String?,
      if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
    });
  }
}

extension ChordContentCacheUpdate on IsarCollection<int, ChordContentCache> {
  _ChordContentCacheUpdate get update => _ChordContentCacheUpdateImpl(this);

  _ChordContentCacheUpdateAll get updateAll =>
      _ChordContentCacheUpdateAllImpl(this);
}

sealed class _ChordContentCacheQueryUpdate {
  int call({String? r2Key, String? content, DateTime? fetchedAt});
}

class _ChordContentCacheQueryUpdateImpl
    implements _ChordContentCacheQueryUpdate {
  const _ChordContentCacheQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<ChordContentCache> query;
  final int? limit;

  @override
  int call({
    Object? r2Key = ignore,
    Object? content = ignore,
    Object? fetchedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (r2Key != ignore) 1: r2Key as String?,
      if (content != ignore) 2: content as String?,
      if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
    });
  }
}

extension ChordContentCacheQueryUpdate on IsarQuery<ChordContentCache> {
  _ChordContentCacheQueryUpdate get updateFirst =>
      _ChordContentCacheQueryUpdateImpl(this, limit: 1);

  _ChordContentCacheQueryUpdate get updateAll =>
      _ChordContentCacheQueryUpdateImpl(this);
}

class _ChordContentCacheQueryBuilderUpdateImpl
    implements _ChordContentCacheQueryUpdate {
  const _ChordContentCacheQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<ChordContentCache, ChordContentCache, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? r2Key = ignore,
    Object? content = ignore,
    Object? fetchedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (r2Key != ignore) 1: r2Key as String?,
        if (content != ignore) 2: content as String?,
        if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension ChordContentCacheQueryBuilderUpdate
    on QueryBuilder<ChordContentCache, ChordContentCache, QOperations> {
  _ChordContentCacheQueryUpdate get updateFirst =>
      _ChordContentCacheQueryBuilderUpdateImpl(this, limit: 1);

  _ChordContentCacheQueryUpdate get updateAll =>
      _ChordContentCacheQueryBuilderUpdateImpl(this);
}

extension ChordContentCacheQueryFilter
    on QueryBuilder<ChordContentCache, ChordContentCache, QFilterCondition> {
  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  r2KeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  fetchedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  fetchedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  fetchedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  fetchedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 3, value: value));
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  fetchedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterFilterCondition>
  fetchedAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 3, lower: lower, upper: upper),
      );
    });
  }
}

extension ChordContentCacheQueryObject
    on QueryBuilder<ChordContentCache, ChordContentCache, QFilterCondition> {}

extension ChordContentCacheQuerySortBy
    on QueryBuilder<ChordContentCache, ChordContentCache, QSortBy> {
  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy> sortByR2Key({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  sortByR2KeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  sortByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  sortByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  sortByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  sortByFetchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension ChordContentCacheQuerySortThenBy
    on QueryBuilder<ChordContentCache, ChordContentCache, QSortThenBy> {
  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy> thenByR2Key({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  thenByR2KeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  thenByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  thenByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  thenByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterSortBy>
  thenByFetchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension ChordContentCacheQueryWhereDistinct
    on QueryBuilder<ChordContentCache, ChordContentCache, QDistinct> {
  QueryBuilder<ChordContentCache, ChordContentCache, QAfterDistinct>
  distinctByR2Key({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterDistinct>
  distinctByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChordContentCache, ChordContentCache, QAfterDistinct>
  distinctByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }
}

extension ChordContentCacheQueryProperty1
    on QueryBuilder<ChordContentCache, ChordContentCache, QProperty> {
  QueryBuilder<ChordContentCache, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ChordContentCache, String, QAfterProperty> r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ChordContentCache, String, QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ChordContentCache, DateTime, QAfterProperty>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension ChordContentCacheQueryProperty2<R>
    on QueryBuilder<ChordContentCache, R, QAfterProperty> {
  QueryBuilder<ChordContentCache, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ChordContentCache, (R, String), QAfterProperty> r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ChordContentCache, (R, String), QAfterProperty>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ChordContentCache, (R, DateTime), QAfterProperty>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension ChordContentCacheQueryProperty3<R1, R2>
    on QueryBuilder<ChordContentCache, (R1, R2), QAfterProperty> {
  QueryBuilder<ChordContentCache, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ChordContentCache, (R1, R2, String), QOperations>
  r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ChordContentCache, (R1, R2, String), QOperations>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ChordContentCache, (R1, R2, DateTime), QOperations>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}
