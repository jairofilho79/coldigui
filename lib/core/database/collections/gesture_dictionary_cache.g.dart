// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gesture_dictionary_cache.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetGestureDictionaryCacheCollection on Isar {
  IsarCollection<int, GestureDictionaryCache> get gestureDictionaryCaches =>
      this.collection();
}

final GestureDictionaryCacheSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'GestureDictionaryCache',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'content', type: IsarType.string),
      IsarPropertySchema(name: 'etag', type: IsarType.string),
      IsarPropertySchema(name: 'fetchedAt', type: IsarType.dateTime),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, GestureDictionaryCache>(
    serialize: serializeGestureDictionaryCache,
    deserialize: deserializeGestureDictionaryCache,
    deserializeProperty: deserializeGestureDictionaryCacheProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeGestureDictionaryCache(
  IsarWriter writer,
  GestureDictionaryCache object,
) {
  IsarCore.writeString(writer, 1, object.content);
  {
    final value = object.etag;
    if (value == null) {
      IsarCore.writeNull(writer, 2);
    } else {
      IsarCore.writeString(writer, 2, value);
    }
  }
  IsarCore.writeLong(
    writer,
    3,
    object.fetchedAt.toUtc().microsecondsSinceEpoch,
  );
  return object.id;
}

@isarProtected
GestureDictionaryCache deserializeGestureDictionaryCache(IsarReader reader) {
  final object = GestureDictionaryCache();
  object.id = IsarCore.readId(reader);
  object.content = IsarCore.readString(reader, 1) ?? '';
  object.etag = IsarCore.readString(reader, 2);
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
dynamic deserializeGestureDictionaryCacheProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2);
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

sealed class _GestureDictionaryCacheUpdate {
  bool call({
    required int id,
    String? content,
    String? etag,
    DateTime? fetchedAt,
  });
}

class _GestureDictionaryCacheUpdateImpl
    implements _GestureDictionaryCacheUpdate {
  const _GestureDictionaryCacheUpdateImpl(this.collection);

  final IsarCollection<int, GestureDictionaryCache> collection;

  @override
  bool call({
    required int id,
    Object? content = ignore,
    Object? etag = ignore,
    Object? fetchedAt = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (content != ignore) 1: content as String?,
            if (etag != ignore) 2: etag as String?,
            if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _GestureDictionaryCacheUpdateAll {
  int call({
    required List<int> id,
    String? content,
    String? etag,
    DateTime? fetchedAt,
  });
}

class _GestureDictionaryCacheUpdateAllImpl
    implements _GestureDictionaryCacheUpdateAll {
  const _GestureDictionaryCacheUpdateAllImpl(this.collection);

  final IsarCollection<int, GestureDictionaryCache> collection;

  @override
  int call({
    required List<int> id,
    Object? content = ignore,
    Object? etag = ignore,
    Object? fetchedAt = ignore,
  }) {
    return collection.updateProperties(id, {
      if (content != ignore) 1: content as String?,
      if (etag != ignore) 2: etag as String?,
      if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
    });
  }
}

extension GestureDictionaryCacheUpdate
    on IsarCollection<int, GestureDictionaryCache> {
  _GestureDictionaryCacheUpdate get update =>
      _GestureDictionaryCacheUpdateImpl(this);

  _GestureDictionaryCacheUpdateAll get updateAll =>
      _GestureDictionaryCacheUpdateAllImpl(this);
}

sealed class _GestureDictionaryCacheQueryUpdate {
  int call({String? content, String? etag, DateTime? fetchedAt});
}

class _GestureDictionaryCacheQueryUpdateImpl
    implements _GestureDictionaryCacheQueryUpdate {
  const _GestureDictionaryCacheQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<GestureDictionaryCache> query;
  final int? limit;

  @override
  int call({
    Object? content = ignore,
    Object? etag = ignore,
    Object? fetchedAt = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (content != ignore) 1: content as String?,
      if (etag != ignore) 2: etag as String?,
      if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
    });
  }
}

extension GestureDictionaryCacheQueryUpdate
    on IsarQuery<GestureDictionaryCache> {
  _GestureDictionaryCacheQueryUpdate get updateFirst =>
      _GestureDictionaryCacheQueryUpdateImpl(this, limit: 1);

  _GestureDictionaryCacheQueryUpdate get updateAll =>
      _GestureDictionaryCacheQueryUpdateImpl(this);
}

class _GestureDictionaryCacheQueryBuilderUpdateImpl
    implements _GestureDictionaryCacheQueryUpdate {
  const _GestureDictionaryCacheQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QOperations
  >
  query;
  final int? limit;

  @override
  int call({
    Object? content = ignore,
    Object? etag = ignore,
    Object? fetchedAt = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (content != ignore) 1: content as String?,
        if (etag != ignore) 2: etag as String?,
        if (fetchedAt != ignore) 3: fetchedAt as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension GestureDictionaryCacheQueryBuilderUpdate
    on
        QueryBuilder<
          GestureDictionaryCache,
          GestureDictionaryCache,
          QOperations
        > {
  _GestureDictionaryCacheQueryUpdate get updateFirst =>
      _GestureDictionaryCacheQueryBuilderUpdateImpl(this, limit: 1);

  _GestureDictionaryCacheQueryUpdate get updateAll =>
      _GestureDictionaryCacheQueryBuilderUpdateImpl(this);
}

extension GestureDictionaryCacheQueryFilter
    on
        QueryBuilder<
          GestureDictionaryCache,
          GestureDictionaryCache,
          QFilterCondition
        > {
  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentGreaterThan(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentBetween(String lower, String upper, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentStartsWith(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentEndsWith(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentContains(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentMatches(String pattern, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 2));
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 2));
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagGreaterThan(String? value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagBetween(String? lower, String? upper, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagStartsWith(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagEndsWith(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagContains(String value, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagMatches(String pattern, {bool caseSensitive = true}) {
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  etagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
    QAfterFilterCondition
  >
  fetchedAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 3, value: value));
    });
  }

  QueryBuilder<
    GestureDictionaryCache,
    GestureDictionaryCache,
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
    GestureDictionaryCache,
    GestureDictionaryCache,
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

extension GestureDictionaryCacheQueryObject
    on
        QueryBuilder<
          GestureDictionaryCache,
          GestureDictionaryCache,
          QFilterCondition
        > {}

extension GestureDictionaryCacheQuerySortBy
    on QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QSortBy> {
  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByEtag({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByEtagDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  sortByFetchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension GestureDictionaryCacheQuerySortThenBy
    on
        QueryBuilder<
          GestureDictionaryCache,
          GestureDictionaryCache,
          QSortThenBy
        > {
  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByEtag({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByEtagDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterSortBy>
  thenByFetchedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension GestureDictionaryCacheQueryWhereDistinct
    on QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QDistinct> {
  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterDistinct>
  distinctByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterDistinct>
  distinctByEtag({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QAfterDistinct>
  distinctByFetchedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }
}

extension GestureDictionaryCacheQueryProperty1
    on QueryBuilder<GestureDictionaryCache, GestureDictionaryCache, QProperty> {
  QueryBuilder<GestureDictionaryCache, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<GestureDictionaryCache, String, QAfterProperty>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<GestureDictionaryCache, String?, QAfterProperty> etagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<GestureDictionaryCache, DateTime, QAfterProperty>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension GestureDictionaryCacheQueryProperty2<R>
    on QueryBuilder<GestureDictionaryCache, R, QAfterProperty> {
  QueryBuilder<GestureDictionaryCache, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<GestureDictionaryCache, (R, String), QAfterProperty>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<GestureDictionaryCache, (R, String?), QAfterProperty>
  etagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<GestureDictionaryCache, (R, DateTime), QAfterProperty>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension GestureDictionaryCacheQueryProperty3<R1, R2>
    on QueryBuilder<GestureDictionaryCache, (R1, R2), QAfterProperty> {
  QueryBuilder<GestureDictionaryCache, (R1, R2, int), QOperations>
  idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<GestureDictionaryCache, (R1, R2, String), QOperations>
  contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<GestureDictionaryCache, (R1, R2, String?), QOperations>
  etagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<GestureDictionaryCache, (R1, R2, DateTime), QOperations>
  fetchedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}
