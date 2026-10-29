// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gesture_document_cache.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetGestureDocumentCacheCollection on Isar {
  IsarCollection<int, GestureDocumentCache> get gestureDocumentCaches =>
      this.collection();
}

final GestureDocumentCacheSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'GestureDocumentCache',
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
  converter: IsarObjectConverter<int, GestureDocumentCache>(
    serialize: serializeGestureDocumentCache,
    deserialize: deserializeGestureDocumentCache,
    deserializeProperty: deserializeGestureDocumentCacheProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeGestureDocumentCache(
  IsarWriter writer,
  GestureDocumentCache object,
) {
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
GestureDocumentCache deserializeGestureDocumentCache(IsarReader reader) {
  final object = GestureDocumentCache();
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
dynamic deserializeGestureDocumentCacheProp(IsarReader reader, int property) {
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

sealed class _GestureDocumentCacheUpdate {
  bool call({
    required int id,
    String? r2Key,
    String? content,
    DateTime? fetchedAt,
  });
}

class _GestureDocumentCacheUpdateImpl implements _GestureDocumentCacheUpdate {
  const _GestureDocumentCacheUpdateImpl(this.collection);

  final IsarCollection<int, GestureDocumentCache> collection;

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

sealed class _GestureDocumentCacheUpdateAll {
  int call({
    required List<int> id,
    String? r2Key,
    String? content,
    DateTime? fetchedAt,
  });
}

class _GestureDocumentCacheUpdateAllImpl
    implements _GestureDocumentCacheUpdateAll {
  const _GestureDocumentCacheUpdateAllImpl(this.collection);

  final IsarCollection<int, GestureDocumentCache> collection;

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

extension GestureDocumentCacheUpdate
    on IsarCollection<int, GestureDocumentCache> {
  _GestureDocumentCacheUpdate get update =>
      _GestureDocumentCacheUpdateImpl(this);

  _GestureDocumentCacheUpdateAll get updateAll =>
      _GestureDocumentCacheUpdateAllImpl(this);
}

sealed class _GestureDocumentCacheQueryUpdate {
  int call({String? r2Key, String? content, DateTime? fetchedAt});
}

class _GestureDocumentCacheQueryUpdateImpl
    implements _GestureDocumentCacheQueryUpdate {
  const _GestureDocumentCacheQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<GestureDocumentCache> query;
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

extension GestureDocumentCacheQueryUpdate on IsarQuery<GestureDocumentCache> {
  _GestureDocumentCacheQueryUpdate get updateFirst =>
      _GestureDocumentCacheQueryUpdateImpl(this, limit: 1);

  _GestureDocumentCacheQueryUpdate get updateAll =>
      _GestureDocumentCacheQueryUpdateImpl(this);
}

class _GestureDocumentCacheQueryBuilderUpdateImpl
    implements _GestureDocumentCacheQueryUpdate {
  const _GestureDocumentCacheQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<GestureDocumentCache, GestureDocumentCache, QOperations>
  query;
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

extension GestureDocumentCacheQueryBuilderUpdate
    on QueryBuilder<GestureDocumentCache, GestureDocumentCache, QOperations> {
  _GestureDocumentCacheQueryUpdate get updateFirst =>
      _GestureDocumentCacheQueryBuilderUpdateImpl(this, limit: 1);

  _GestureDocumentCacheQueryUpdate get updateAll =>
      _GestureDocumentCacheQueryBuilderUpdateImpl(this);
}

extension GestureDocumentCacheQueryFilter
    on
        QueryBuilder<
          GestureDocumentCache,
          GestureDocumentCache,
          QFilterCondition
        > {
  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  r2KeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  r2KeyLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  r2KeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  r2KeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  contentEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  contentLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  fetchedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  fetchedAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  fetchedAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  fetchedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 3, value: value));
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  fetchedAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<
    GestureDocumentCache,
    GestureDocumentCache,
    QAfterFilterCondition
  >
  fetchedAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 3, lower: lower, upper: upper),
      );
    });
  }
}

extension GestureDocumentCacheQueryObject
    on
        QueryBuilder<
          GestureDocumentCache,
          GestureDocumentCache,
          QFilterCondition
        > {}

extension GestureDocumentCacheQuerySortBy
    on QueryBuilder<GestureDocumentCache, GestureDocumentCache, QSortBy> {
  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByR2Key({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByR2KeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  sortByFetchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension GestureDocumentCacheQuerySortThenBy
    on QueryBuilder<GestureDocumentCache, GestureDocumentCache, QSortThenBy> {
  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByR2Key({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByR2KeyDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterSortBy>
  thenByFetchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension GestureDocumentCacheQueryWhereDistinct
    on QueryBuilder<GestureDocumentCache, GestureDocumentCache, QDistinct> {
  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterDistinct>
  distinctByR2Key({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterDistinct>
  distinctByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDocumentCache, GestureDocumentCache, QAfterDistinct>
  distinctByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }
}

extension GestureDocumentCacheQueryProperty1
    on QueryBuilder<GestureDocumentCache, GestureDocumentCache, QProperty> {
  QueryBuilder<GestureDocumentCache, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<GestureDocumentCache, String, QAfterProperty> r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<GestureDocumentCache, String, QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<GestureDocumentCache, DateTime, QAfterProperty>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension GestureDocumentCacheQueryProperty2<R>
    on QueryBuilder<GestureDocumentCache, R, QAfterProperty> {
  QueryBuilder<GestureDocumentCache, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<GestureDocumentCache, (R, String), QAfterProperty>
  r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<GestureDocumentCache, (R, String), QAfterProperty>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<GestureDocumentCache, (R, DateTime), QAfterProperty>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension GestureDocumentCacheQueryProperty3<R1, R2>
    on QueryBuilder<GestureDocumentCache, (R1, R2), QAfterProperty> {
  QueryBuilder<GestureDocumentCache, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<GestureDocumentCache, (R1, R2, String), QOperations>
  r2KeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<GestureDocumentCache, (R1, R2, String), QOperations>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<GestureDocumentCache, (R1, R2, DateTime), QOperations>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}
