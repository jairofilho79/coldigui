// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coldigom_praise_cache.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetColdigomPraiseCacheCollection on Isar {
  IsarCollection<int, ColdigomPraiseCache> get coldigomPraiseCaches =>
      this.collection();
}

final ColdigomPraiseCacheSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'ColdigomPraiseCache',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'praiseId', type: IsarType.string),
      IsarPropertySchema(name: 'number', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'author', type: IsarType.string),
      IsarPropertySchema(name: 'rhythm', type: IsarType.string),
      IsarPropertySchema(name: 'tonality', type: IsarType.string),
      IsarPropertySchema(name: 'category', type: IsarType.string),
      IsarPropertySchema(name: 'tags', type: IsarType.stringList),
      IsarPropertySchema(name: 'lyrics', type: IsarType.string),
      IsarPropertySchema(name: 'materialsJson', type: IsarType.string),
      IsarPropertySchema(name: 'searchTokens', type: IsarType.string),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'praiseId',
        properties: ["praiseId"],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, ColdigomPraiseCache>(
    serialize: serializeColdigomPraiseCache,
    deserialize: deserializeColdigomPraiseCache,
    deserializeProperty: deserializeColdigomPraiseCacheProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeColdigomPraiseCache(
  IsarWriter writer,
  ColdigomPraiseCache object,
) {
  IsarCore.writeString(writer, 1, object.praiseId);
  IsarCore.writeString(writer, 2, object.number);
  IsarCore.writeString(writer, 3, object.name);
  IsarCore.writeString(writer, 4, object.author);
  IsarCore.writeString(writer, 5, object.rhythm);
  IsarCore.writeString(writer, 6, object.tonality);
  IsarCore.writeString(writer, 7, object.category);
  {
    final list = object.tags;
    final listWriter = IsarCore.beginList(writer, 8, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  IsarCore.writeString(writer, 9, object.lyrics);
  IsarCore.writeString(writer, 10, object.materialsJson);
  IsarCore.writeString(writer, 11, object.searchTokens);
  return object.id;
}

@isarProtected
ColdigomPraiseCache deserializeColdigomPraiseCache(IsarReader reader) {
  final object = ColdigomPraiseCache();
  object.id = IsarCore.readId(reader);
  object.praiseId = IsarCore.readString(reader, 1) ?? '';
  object.number = IsarCore.readString(reader, 2) ?? '';
  object.name = IsarCore.readString(reader, 3) ?? '';
  object.author = IsarCore.readString(reader, 4) ?? '';
  object.rhythm = IsarCore.readString(reader, 5) ?? '';
  object.tonality = IsarCore.readString(reader, 6) ?? '';
  object.category = IsarCore.readString(reader, 7) ?? '';
  {
    final length = IsarCore.readList(reader, 8, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        object.tags = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        object.tags = list;
      }
    }
  }
  object.lyrics = IsarCore.readString(reader, 9) ?? '';
  object.materialsJson = IsarCore.readString(reader, 10) ?? '';
  object.searchTokens = IsarCore.readString(reader, 11) ?? '';
  return object;
}

@isarProtected
dynamic deserializeColdigomPraiseCacheProp(IsarReader reader, int property) {
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
      return IsarCore.readString(reader, 4) ?? '';
    case 5:
      return IsarCore.readString(reader, 5) ?? '';
    case 6:
      return IsarCore.readString(reader, 6) ?? '';
    case 7:
      return IsarCore.readString(reader, 7) ?? '';
    case 8:
      {
        final length = IsarCore.readList(reader, 8, IsarCore.readerPtrPtr);
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
    case 9:
      return IsarCore.readString(reader, 9) ?? '';
    case 10:
      return IsarCore.readString(reader, 10) ?? '';
    case 11:
      return IsarCore.readString(reader, 11) ?? '';
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _ColdigomPraiseCacheUpdate {
  bool call({
    required int id,
    String? praiseId,
    String? number,
    String? name,
    String? author,
    String? rhythm,
    String? tonality,
    String? category,
    String? lyrics,
    String? materialsJson,
    String? searchTokens,
  });
}

class _ColdigomPraiseCacheUpdateImpl implements _ColdigomPraiseCacheUpdate {
  const _ColdigomPraiseCacheUpdateImpl(this.collection);

  final IsarCollection<int, ColdigomPraiseCache> collection;

  @override
  bool call({
    required int id,
    Object? praiseId = ignore,
    Object? number = ignore,
    Object? name = ignore,
    Object? author = ignore,
    Object? rhythm = ignore,
    Object? tonality = ignore,
    Object? category = ignore,
    Object? lyrics = ignore,
    Object? materialsJson = ignore,
    Object? searchTokens = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (praiseId != ignore) 1: praiseId as String?,
            if (number != ignore) 2: number as String?,
            if (name != ignore) 3: name as String?,
            if (author != ignore) 4: author as String?,
            if (rhythm != ignore) 5: rhythm as String?,
            if (tonality != ignore) 6: tonality as String?,
            if (category != ignore) 7: category as String?,
            if (lyrics != ignore) 9: lyrics as String?,
            if (materialsJson != ignore) 10: materialsJson as String?,
            if (searchTokens != ignore) 11: searchTokens as String?,
          },
        ) >
        0;
  }
}

sealed class _ColdigomPraiseCacheUpdateAll {
  int call({
    required List<int> id,
    String? praiseId,
    String? number,
    String? name,
    String? author,
    String? rhythm,
    String? tonality,
    String? category,
    String? lyrics,
    String? materialsJson,
    String? searchTokens,
  });
}

class _ColdigomPraiseCacheUpdateAllImpl
    implements _ColdigomPraiseCacheUpdateAll {
  const _ColdigomPraiseCacheUpdateAllImpl(this.collection);

  final IsarCollection<int, ColdigomPraiseCache> collection;

  @override
  int call({
    required List<int> id,
    Object? praiseId = ignore,
    Object? number = ignore,
    Object? name = ignore,
    Object? author = ignore,
    Object? rhythm = ignore,
    Object? tonality = ignore,
    Object? category = ignore,
    Object? lyrics = ignore,
    Object? materialsJson = ignore,
    Object? searchTokens = ignore,
  }) {
    return collection.updateProperties(id, {
      if (praiseId != ignore) 1: praiseId as String?,
      if (number != ignore) 2: number as String?,
      if (name != ignore) 3: name as String?,
      if (author != ignore) 4: author as String?,
      if (rhythm != ignore) 5: rhythm as String?,
      if (tonality != ignore) 6: tonality as String?,
      if (category != ignore) 7: category as String?,
      if (lyrics != ignore) 9: lyrics as String?,
      if (materialsJson != ignore) 10: materialsJson as String?,
      if (searchTokens != ignore) 11: searchTokens as String?,
    });
  }
}

extension ColdigomPraiseCacheUpdate
    on IsarCollection<int, ColdigomPraiseCache> {
  _ColdigomPraiseCacheUpdate get update => _ColdigomPraiseCacheUpdateImpl(this);

  _ColdigomPraiseCacheUpdateAll get updateAll =>
      _ColdigomPraiseCacheUpdateAllImpl(this);
}

sealed class _ColdigomPraiseCacheQueryUpdate {
  int call({
    String? praiseId,
    String? number,
    String? name,
    String? author,
    String? rhythm,
    String? tonality,
    String? category,
    String? lyrics,
    String? materialsJson,
    String? searchTokens,
  });
}

class _ColdigomPraiseCacheQueryUpdateImpl
    implements _ColdigomPraiseCacheQueryUpdate {
  const _ColdigomPraiseCacheQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<ColdigomPraiseCache> query;
  final int? limit;

  @override
  int call({
    Object? praiseId = ignore,
    Object? number = ignore,
    Object? name = ignore,
    Object? author = ignore,
    Object? rhythm = ignore,
    Object? tonality = ignore,
    Object? category = ignore,
    Object? lyrics = ignore,
    Object? materialsJson = ignore,
    Object? searchTokens = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (praiseId != ignore) 1: praiseId as String?,
      if (number != ignore) 2: number as String?,
      if (name != ignore) 3: name as String?,
      if (author != ignore) 4: author as String?,
      if (rhythm != ignore) 5: rhythm as String?,
      if (tonality != ignore) 6: tonality as String?,
      if (category != ignore) 7: category as String?,
      if (lyrics != ignore) 9: lyrics as String?,
      if (materialsJson != ignore) 10: materialsJson as String?,
      if (searchTokens != ignore) 11: searchTokens as String?,
    });
  }
}

extension ColdigomPraiseCacheQueryUpdate on IsarQuery<ColdigomPraiseCache> {
  _ColdigomPraiseCacheQueryUpdate get updateFirst =>
      _ColdigomPraiseCacheQueryUpdateImpl(this, limit: 1);

  _ColdigomPraiseCacheQueryUpdate get updateAll =>
      _ColdigomPraiseCacheQueryUpdateImpl(this);
}

class _ColdigomPraiseCacheQueryBuilderUpdateImpl
    implements _ColdigomPraiseCacheQueryUpdate {
  const _ColdigomPraiseCacheQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QOperations>
  query;
  final int? limit;

  @override
  int call({
    Object? praiseId = ignore,
    Object? number = ignore,
    Object? name = ignore,
    Object? author = ignore,
    Object? rhythm = ignore,
    Object? tonality = ignore,
    Object? category = ignore,
    Object? lyrics = ignore,
    Object? materialsJson = ignore,
    Object? searchTokens = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (praiseId != ignore) 1: praiseId as String?,
        if (number != ignore) 2: number as String?,
        if (name != ignore) 3: name as String?,
        if (author != ignore) 4: author as String?,
        if (rhythm != ignore) 5: rhythm as String?,
        if (tonality != ignore) 6: tonality as String?,
        if (category != ignore) 7: category as String?,
        if (lyrics != ignore) 9: lyrics as String?,
        if (materialsJson != ignore) 10: materialsJson as String?,
        if (searchTokens != ignore) 11: searchTokens as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension ColdigomPraiseCacheQueryBuilderUpdate
    on QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QOperations> {
  _ColdigomPraiseCacheQueryUpdate get updateFirst =>
      _ColdigomPraiseCacheQueryBuilderUpdateImpl(this, limit: 1);

  _ColdigomPraiseCacheQueryUpdate get updateAll =>
      _ColdigomPraiseCacheQueryBuilderUpdateImpl(this);
}

extension ColdigomPraiseCacheQueryFilter
    on
        QueryBuilder<
          ColdigomPraiseCache,
          ColdigomPraiseCache,
          QFilterCondition
        > {
  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  praiseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  numberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  authorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  rhythmIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 6,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 6,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tonalityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 7,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 7,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 8,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 8,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 8,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsIsEmpty() {
    return not().tagsIsNotEmpty();
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 8, value: null),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 9, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 9,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 9,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 9,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 9, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  lyricsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 9, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 10, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 10,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 10,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 10, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  materialsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 10, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 11,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 11,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterFilterCondition>
  searchTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 11, value: ''),
      );
    });
  }
}

extension ColdigomPraiseCacheQueryObject
    on
        QueryBuilder<
          ColdigomPraiseCache,
          ColdigomPraiseCache,
          QFilterCondition
        > {}

extension ColdigomPraiseCacheQuerySortBy
    on QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QSortBy> {
  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByPraiseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByPraiseIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByNumberDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByAuthorDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByRhythm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByRhythmDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByTonality({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByTonalityDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByCategoryDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByLyrics({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByLyricsDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByMaterialsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortByMaterialsJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortBySearchTokens({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  sortBySearchTokensDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension ColdigomPraiseCacheQuerySortThenBy
    on QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QSortThenBy> {
  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByPraiseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByPraiseIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByNumberDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByAuthorDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByRhythm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByRhythmDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByTonality({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByTonalityDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByCategoryDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByLyrics({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByLyricsDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByMaterialsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenByMaterialsJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenBySearchTokens({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterSortBy>
  thenBySearchTokensDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension ColdigomPraiseCacheQueryWhereDistinct
    on QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QDistinct> {
  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByPraiseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByRhythm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByTonality({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByLyrics({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctByMaterialsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QAfterDistinct>
  distinctBySearchTokens({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11, caseSensitive: caseSensitive);
    });
  }
}

extension ColdigomPraiseCacheQueryProperty1
    on QueryBuilder<ColdigomPraiseCache, ColdigomPraiseCache, QProperty> {
  QueryBuilder<ColdigomPraiseCache, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> praiseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> numberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> rhythmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> tonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ColdigomPraiseCache, List<String>, QAfterProperty>
  tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty> lyricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty>
  materialsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<ColdigomPraiseCache, String, QAfterProperty>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}

extension ColdigomPraiseCacheQueryProperty2<R>
    on QueryBuilder<ColdigomPraiseCache, R, QAfterProperty> {
  QueryBuilder<ColdigomPraiseCache, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  praiseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  numberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  rhythmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  tonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, List<String>), QAfterProperty>
  tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  lyricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  materialsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R, String), QAfterProperty>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}

extension ColdigomPraiseCacheQueryProperty3<R1, R2>
    on QueryBuilder<ColdigomPraiseCache, (R1, R2), QAfterProperty> {
  QueryBuilder<ColdigomPraiseCache, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  praiseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  numberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  rhythmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  tonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, List<String>), QOperations>
  tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  lyricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  materialsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<ColdigomPraiseCache, (R1, R2, String), QOperations>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }
}
