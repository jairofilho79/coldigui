// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'louvor_cache.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetLouvorCacheCollection on Isar {
  IsarCollection<int, LouvorCache> get louvorCaches => this.collection();
}

final LouvorCacheSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'LouvorCache',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'pdfId', type: IsarType.string),
      IsarPropertySchema(name: 'nome', type: IsarType.string),
      IsarPropertySchema(name: 'numero', type: IsarType.string),
      IsarPropertySchema(name: 'categoria', type: IsarType.string),
      IsarPropertySchema(name: 'classificacao', type: IsarType.string),
      IsarPropertySchema(name: 'pdf', type: IsarType.string),
      IsarPropertySchema(name: 'groupId', type: IsarType.string),
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
  converter: IsarObjectConverter<int, LouvorCache>(
    serialize: serializeLouvorCache,
    deserialize: deserializeLouvorCache,
    deserializeProperty: deserializeLouvorCacheProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeLouvorCache(IsarWriter writer, LouvorCache object) {
  IsarCore.writeString(writer, 1, object.pdfId);
  IsarCore.writeString(writer, 2, object.nome);
  IsarCore.writeString(writer, 3, object.numero);
  IsarCore.writeString(writer, 4, object.categoria);
  IsarCore.writeString(writer, 5, object.classificacao);
  IsarCore.writeString(writer, 6, object.pdf);
  IsarCore.writeString(writer, 7, object.groupId);
  return object.id;
}

@isarProtected
LouvorCache deserializeLouvorCache(IsarReader reader) {
  final object = LouvorCache();
  object.id = IsarCore.readId(reader);
  object.pdfId = IsarCore.readString(reader, 1) ?? '';
  object.nome = IsarCore.readString(reader, 2) ?? '';
  object.numero = IsarCore.readString(reader, 3) ?? '';
  object.categoria = IsarCore.readString(reader, 4) ?? '';
  object.classificacao = IsarCore.readString(reader, 5) ?? '';
  object.pdf = IsarCore.readString(reader, 6) ?? '';
  object.groupId = IsarCore.readString(reader, 7) ?? '';
  return object;
}

@isarProtected
dynamic deserializeLouvorCacheProp(IsarReader reader, int property) {
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
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _LouvorCacheUpdate {
  bool call({
    required int id,
    String? pdfId,
    String? nome,
    String? numero,
    String? categoria,
    String? classificacao,
    String? pdf,
    String? groupId,
  });
}

class _LouvorCacheUpdateImpl implements _LouvorCacheUpdate {
  const _LouvorCacheUpdateImpl(this.collection);

  final IsarCollection<int, LouvorCache> collection;

  @override
  bool call({
    required int id,
    Object? pdfId = ignore,
    Object? nome = ignore,
    Object? numero = ignore,
    Object? categoria = ignore,
    Object? classificacao = ignore,
    Object? pdf = ignore,
    Object? groupId = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (pdfId != ignore) 1: pdfId as String?,
            if (nome != ignore) 2: nome as String?,
            if (numero != ignore) 3: numero as String?,
            if (categoria != ignore) 4: categoria as String?,
            if (classificacao != ignore) 5: classificacao as String?,
            if (pdf != ignore) 6: pdf as String?,
            if (groupId != ignore) 7: groupId as String?,
          },
        ) >
        0;
  }
}

sealed class _LouvorCacheUpdateAll {
  int call({
    required List<int> id,
    String? pdfId,
    String? nome,
    String? numero,
    String? categoria,
    String? classificacao,
    String? pdf,
    String? groupId,
  });
}

class _LouvorCacheUpdateAllImpl implements _LouvorCacheUpdateAll {
  const _LouvorCacheUpdateAllImpl(this.collection);

  final IsarCollection<int, LouvorCache> collection;

  @override
  int call({
    required List<int> id,
    Object? pdfId = ignore,
    Object? nome = ignore,
    Object? numero = ignore,
    Object? categoria = ignore,
    Object? classificacao = ignore,
    Object? pdf = ignore,
    Object? groupId = ignore,
  }) {
    return collection.updateProperties(id, {
      if (pdfId != ignore) 1: pdfId as String?,
      if (nome != ignore) 2: nome as String?,
      if (numero != ignore) 3: numero as String?,
      if (categoria != ignore) 4: categoria as String?,
      if (classificacao != ignore) 5: classificacao as String?,
      if (pdf != ignore) 6: pdf as String?,
      if (groupId != ignore) 7: groupId as String?,
    });
  }
}

extension LouvorCacheUpdate on IsarCollection<int, LouvorCache> {
  _LouvorCacheUpdate get update => _LouvorCacheUpdateImpl(this);

  _LouvorCacheUpdateAll get updateAll => _LouvorCacheUpdateAllImpl(this);
}

sealed class _LouvorCacheQueryUpdate {
  int call({
    String? pdfId,
    String? nome,
    String? numero,
    String? categoria,
    String? classificacao,
    String? pdf,
    String? groupId,
  });
}

class _LouvorCacheQueryUpdateImpl implements _LouvorCacheQueryUpdate {
  const _LouvorCacheQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<LouvorCache> query;
  final int? limit;

  @override
  int call({
    Object? pdfId = ignore,
    Object? nome = ignore,
    Object? numero = ignore,
    Object? categoria = ignore,
    Object? classificacao = ignore,
    Object? pdf = ignore,
    Object? groupId = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (pdfId != ignore) 1: pdfId as String?,
      if (nome != ignore) 2: nome as String?,
      if (numero != ignore) 3: numero as String?,
      if (categoria != ignore) 4: categoria as String?,
      if (classificacao != ignore) 5: classificacao as String?,
      if (pdf != ignore) 6: pdf as String?,
      if (groupId != ignore) 7: groupId as String?,
    });
  }
}

extension LouvorCacheQueryUpdate on IsarQuery<LouvorCache> {
  _LouvorCacheQueryUpdate get updateFirst =>
      _LouvorCacheQueryUpdateImpl(this, limit: 1);

  _LouvorCacheQueryUpdate get updateAll => _LouvorCacheQueryUpdateImpl(this);
}

class _LouvorCacheQueryBuilderUpdateImpl implements _LouvorCacheQueryUpdate {
  const _LouvorCacheQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<LouvorCache, LouvorCache, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? pdfId = ignore,
    Object? nome = ignore,
    Object? numero = ignore,
    Object? categoria = ignore,
    Object? classificacao = ignore,
    Object? pdf = ignore,
    Object? groupId = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (pdfId != ignore) 1: pdfId as String?,
        if (nome != ignore) 2: nome as String?,
        if (numero != ignore) 3: numero as String?,
        if (categoria != ignore) 4: categoria as String?,
        if (classificacao != ignore) 5: classificacao as String?,
        if (pdf != ignore) 6: pdf as String?,
        if (groupId != ignore) 7: groupId as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension LouvorCacheQueryBuilderUpdate
    on QueryBuilder<LouvorCache, LouvorCache, QOperations> {
  _LouvorCacheQueryUpdate get updateFirst =>
      _LouvorCacheQueryBuilderUpdateImpl(this, limit: 1);

  _LouvorCacheQueryUpdate get updateAll =>
      _LouvorCacheQueryBuilderUpdateImpl(this);
}

extension LouvorCacheQueryFilter
    on QueryBuilder<LouvorCache, LouvorCache, QFilterCondition> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdBetween(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdStartsWith(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdEndsWith(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdContains(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdMatches(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  pdfIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeGreaterThan(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  nomeLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeBetween(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeStartsWith(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeEndsWith(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeContains(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeMatches(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  nomeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  numeroGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  numeroGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  numeroLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroBetween(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  numeroStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroEndsWith(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroContains(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroMatches(
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  numeroIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  numeroIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  categoriaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  classificacaoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  pdfGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  pdfLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  pdfIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  groupIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  groupIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> groupIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  groupIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> groupIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  groupIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> groupIdContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> groupIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }
}

extension LouvorCacheQueryObject
    on QueryBuilder<LouvorCache, LouvorCache, QFilterCondition> {}

extension LouvorCacheQuerySortBy
    on QueryBuilder<LouvorCache, LouvorCache, QSortBy> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdfIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNome({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNomeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNumero({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNumeroDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByCategoria({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByCategoriaDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByClassificacao({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByClassificacaoDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdf({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdfDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByGroupIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension LouvorCacheQuerySortThenBy
    on QueryBuilder<LouvorCache, LouvorCache, QSortThenBy> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdfIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNome({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNomeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNumero({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNumeroDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByCategoria({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByCategoriaDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByClassificacao({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByClassificacaoDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdf({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdfDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByGroupIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension LouvorCacheQueryWhereDistinct
    on QueryBuilder<LouvorCache, LouvorCache, QDistinct> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct> distinctByPdfId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct> distinctByNome({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct> distinctByNumero({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct> distinctByCategoria({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct>
  distinctByClassificacao({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct> distinctByPdf({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterDistinct> distinctByGroupId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }
}

extension LouvorCacheQueryProperty1
    on QueryBuilder<LouvorCache, LouvorCache, QProperty> {
  QueryBuilder<LouvorCache, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> numeroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> categoriaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> classificacaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> pdfProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<LouvorCache, String, QAfterProperty> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }
}

extension LouvorCacheQueryProperty2<R>
    on QueryBuilder<LouvorCache, R, QAfterProperty> {
  QueryBuilder<LouvorCache, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty> numeroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty> categoriaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty>
  classificacaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty> pdfProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<LouvorCache, (R, String), QAfterProperty> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }
}

extension LouvorCacheQueryProperty3<R1, R2>
    on QueryBuilder<LouvorCache, (R1, R2), QAfterProperty> {
  QueryBuilder<LouvorCache, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations> numeroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations> categoriaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations>
  classificacaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations> pdfProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<LouvorCache, (R1, R2, String), QOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }
}
