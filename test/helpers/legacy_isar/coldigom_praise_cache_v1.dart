// Cópia congelada do schema de ColdigomPraiseCache ANTES da fase 3 (com
// `category`), para o teste de migração. Não editar: é o que está gravado
// nos navegadores até o próximo sync.
// ignore_for_file: type=lint, invalid_use_of_protected_member, deprecated_member_use

import 'package:isar_plus/isar_plus.dart';

/// Cache local Isar do catálogo Coldigom (~1690 louvores) — spec offline
/// Coldigom §4.1 (O3).
///
/// Uma linha por praise; os materiais vão serializados em JSON na própria
/// linha ([materialsJson]) porque são lidos sempre em bloco (hidratação no
/// boot, enumeração do download) e nunca um a um. Substituição total por
/// sync numa transação.
// `@Collection()` tirado de propósito: o schema já está gerado abaixo e a
// anotação faria o build_runner tentar gerar um `.g.dart` para este ficheiro.
class ColdigomPraiseCacheV1 {
  int id = 0;

  /// `praise.id` do Worker — também o `groupId` das entidades Coldigom.
  @Index(unique: true)
  late String praiseId;

  /// Número como o Worker manda (`'001'`); pode ser vazio.
  late String number;

  late String name;
  late String author;
  late String rhythm;
  late String tonality;
  late String category;

  /// Nomes das tags (`tag_names`), sem ids.
  late List<String> tags;

  /// Letra; `''` quando não há (o dump omite o campo).
  late String lyrics;

  /// JSON array de `{id, kind, kindName, type, r2, size?, url?}` — ver
  /// `ColdigomPraiseCacheV1Mapper`.
  late String materialsJson;

  /// Tokens normalizados (nome + número + tags + autor) separados por
  /// espaço — insumo do `ColdigomSearchIndex`, calculado uma vez no sync.
  late String searchTokens;

  /// `shortId` do praise (hex `[0-9a-f]{3,8}`) — chave do link de lista por
  /// louvor (spec fim-fonte §4). Nulo em linhas gravadas por um app que
  /// ainda não lia o campo — mesmo que o dump já o trouxesse, e com o ETag
  /// desse dump guardado. Por isso o ETag sozinho não regrava nada: o
  /// `SyncColdigomCatalog` ignora o ETag enquanto nenhuma linha tiver
  /// `shortId` e o dump inteiro substitui as linhas.
  /// Propriedade aditiva, sem migração.
  String? shortId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetColdigomPraiseCacheV1Collection on Isar {
  IsarCollection<int, ColdigomPraiseCacheV1> get coldigomPraiseCacheV1s =>
      this.collection();
}

final ColdigomPraiseCacheV1Schema = IsarGeneratedSchema(
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
      IsarPropertySchema(name: 'shortId', type: IsarType.string),
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
  converter: IsarObjectConverter<int, ColdigomPraiseCacheV1>(
    serialize: serializeColdigomPraiseCacheV1,
    deserialize: deserializeColdigomPraiseCacheV1,
    deserializeProperty: deserializeColdigomPraiseCacheV1Prop,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeColdigomPraiseCacheV1(
  IsarWriter writer,
  ColdigomPraiseCacheV1 object,
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
  {
    final value = object.shortId;
    if (value == null) {
      IsarCore.writeNull(writer, 12);
    } else {
      IsarCore.writeString(writer, 12, value);
    }
  }
  return object.id;
}

@isarProtected
ColdigomPraiseCacheV1 deserializeColdigomPraiseCacheV1(IsarReader reader) {
  final object = ColdigomPraiseCacheV1();
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
  object.shortId = IsarCore.readString(reader, 12);
  return object;
}

@isarProtected
dynamic deserializeColdigomPraiseCacheV1Prop(IsarReader reader, int property) {
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
    case 12:
      return IsarCore.readString(reader, 12);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _ColdigomPraiseCacheV1Update {
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
    String? shortId,
  });
}

class _ColdigomPraiseCacheV1UpdateImpl implements _ColdigomPraiseCacheV1Update {
  const _ColdigomPraiseCacheV1UpdateImpl(this.collection);

  final IsarCollection<int, ColdigomPraiseCacheV1> collection;

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
    Object? shortId = ignore,
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
            if (shortId != ignore) 12: shortId as String?,
          },
        ) >
        0;
  }
}

sealed class _ColdigomPraiseCacheV1UpdateAll {
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
    String? shortId,
  });
}

class _ColdigomPraiseCacheV1UpdateAllImpl
    implements _ColdigomPraiseCacheV1UpdateAll {
  const _ColdigomPraiseCacheV1UpdateAllImpl(this.collection);

  final IsarCollection<int, ColdigomPraiseCacheV1> collection;

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
    Object? shortId = ignore,
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
      if (shortId != ignore) 12: shortId as String?,
    });
  }
}

extension ColdigomPraiseCacheV1Update
    on IsarCollection<int, ColdigomPraiseCacheV1> {
  _ColdigomPraiseCacheV1Update get update =>
      _ColdigomPraiseCacheV1UpdateImpl(this);

  _ColdigomPraiseCacheV1UpdateAll get updateAll =>
      _ColdigomPraiseCacheV1UpdateAllImpl(this);
}

sealed class _ColdigomPraiseCacheV1QueryUpdate {
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
    String? shortId,
  });
}

class _ColdigomPraiseCacheV1QueryUpdateImpl
    implements _ColdigomPraiseCacheV1QueryUpdate {
  const _ColdigomPraiseCacheV1QueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<ColdigomPraiseCacheV1> query;
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
    Object? shortId = ignore,
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
      if (shortId != ignore) 12: shortId as String?,
    });
  }
}

extension ColdigomPraiseCacheV1QueryUpdate on IsarQuery<ColdigomPraiseCacheV1> {
  _ColdigomPraiseCacheV1QueryUpdate get updateFirst =>
      _ColdigomPraiseCacheV1QueryUpdateImpl(this, limit: 1);

  _ColdigomPraiseCacheV1QueryUpdate get updateAll =>
      _ColdigomPraiseCacheV1QueryUpdateImpl(this);
}

class _ColdigomPraiseCacheV1QueryBuilderUpdateImpl
    implements _ColdigomPraiseCacheV1QueryUpdate {
  const _ColdigomPraiseCacheV1QueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QOperations>
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
    Object? shortId = ignore,
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
        if (shortId != ignore) 12: shortId as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension ColdigomPraiseCacheV1QueryBuilderUpdate
    on QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QOperations> {
  _ColdigomPraiseCacheV1QueryUpdate get updateFirst =>
      _ColdigomPraiseCacheV1QueryBuilderUpdateImpl(this, limit: 1);

  _ColdigomPraiseCacheV1QueryUpdate get updateAll =>
      _ColdigomPraiseCacheV1QueryBuilderUpdateImpl(this);
}

extension ColdigomPraiseCacheV1QueryFilter
    on
        QueryBuilder<
          ColdigomPraiseCacheV1,
          ColdigomPraiseCacheV1,
          QFilterCondition
        > {
  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
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
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
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
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
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
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
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
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
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
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  praiseIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  praiseIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  praiseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  praiseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  numberEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  numberLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  numberIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  numberIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  nameLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  authorEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  authorLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  authorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  authorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  rhythmEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  rhythmLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  rhythmIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  rhythmIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tonalityEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tonalityLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tonalityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tonalityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  categoryEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  categoryLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tagsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tagsElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 8, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 8, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tagsIsEmpty() {
    return not().tagsIsNotEmpty();
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 8, value: null),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  lyricsEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  lyricsLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 9, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  lyricsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 9, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  lyricsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 9, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  materialsJsonLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 10, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  materialsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 10, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  materialsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 10, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  searchTokensLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
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

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  searchTokensIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  searchTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 12));
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 12));
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdGreaterThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdLessThan(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 12, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdBetween(String? lower, String? upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 12,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 12,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 12,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 12, value: ''),
      );
    });
  }

  QueryBuilder<
    ColdigomPraiseCacheV1,
    ColdigomPraiseCacheV1,
    QAfterFilterCondition
  >
  shortIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 12, value: ''),
      );
    });
  }
}

extension ColdigomPraiseCacheV1QueryObject
    on
        QueryBuilder<
          ColdigomPraiseCacheV1,
          ColdigomPraiseCacheV1,
          QFilterCondition
        > {}

extension ColdigomPraiseCacheV1QuerySortBy
    on QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QSortBy> {
  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByPraiseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByPraiseIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByNumberDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByAuthorDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByRhythm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByRhythmDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByTonality({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByTonalityDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByCategoryDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByLyrics({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByLyricsDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByMaterialsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByMaterialsJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortBySearchTokens({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortBySearchTokensDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByShortId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  sortByShortIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension ColdigomPraiseCacheV1QuerySortThenBy
    on QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QSortThenBy> {
  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByPraiseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByPraiseIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByNumberDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByAuthorDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByRhythm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByRhythmDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByTonality({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByTonalityDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByCategoryDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByLyrics({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByLyricsDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByMaterialsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByMaterialsJsonDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenBySearchTokens({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenBySearchTokensDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(11, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByShortId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterSortBy>
  thenByShortIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension ColdigomPraiseCacheV1QueryWhereDistinct
    on QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QDistinct> {
  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByPraiseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByNumber({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByAuthor({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByRhythm({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByTonality({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByLyrics({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByMaterialsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctBySearchTokens({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QAfterDistinct>
  distinctByShortId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(12, caseSensitive: caseSensitive);
    });
  }
}

extension ColdigomPraiseCacheV1QueryProperty1
    on QueryBuilder<ColdigomPraiseCacheV1, ColdigomPraiseCacheV1, QProperty> {
  QueryBuilder<ColdigomPraiseCacheV1, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty>
  praiseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty> numberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty> rhythmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty>
  tonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, List<String>, QAfterProperty>
  tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty> lyricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty>
  materialsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String, QAfterProperty>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, String?, QAfterProperty>
  shortIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }
}

extension ColdigomPraiseCacheV1QueryProperty2<R>
    on QueryBuilder<ColdigomPraiseCacheV1, R, QAfterProperty> {
  QueryBuilder<ColdigomPraiseCacheV1, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  praiseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  numberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  rhythmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  tonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, List<String>), QAfterProperty>
  tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  lyricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  materialsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String), QAfterProperty>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R, String?), QAfterProperty>
  shortIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }
}

extension ColdigomPraiseCacheV1QueryProperty3<R1, R2>
    on QueryBuilder<ColdigomPraiseCacheV1, (R1, R2), QAfterProperty> {
  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  praiseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  numberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  rhythmProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  tonalityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, List<String>), QOperations>
  tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  lyricsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  materialsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String), QOperations>
  searchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<ColdigomPraiseCacheV1, (R1, R2, String?), QOperations>
  shortIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }
}
