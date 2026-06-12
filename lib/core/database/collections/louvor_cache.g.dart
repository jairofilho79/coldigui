// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'louvor_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLouvorCacheCollection on Isar {
  IsarCollection<LouvorCache> get louvorCaches => this.collection();
}

const LouvorCacheSchema = CollectionSchema(
  name: r'LouvorCache',
  id: -8211815552580714772,
  properties: {
    r'categoria': PropertySchema(
      id: 0,
      name: r'categoria',
      type: IsarType.string,
    ),
    r'classificacao': PropertySchema(
      id: 1,
      name: r'classificacao',
      type: IsarType.string,
    ),
    r'nome': PropertySchema(
      id: 2,
      name: r'nome',
      type: IsarType.string,
    ),
    r'numero': PropertySchema(
      id: 3,
      name: r'numero',
      type: IsarType.string,
    ),
    r'pdf': PropertySchema(
      id: 4,
      name: r'pdf',
      type: IsarType.string,
    ),
    r'pdfId': PropertySchema(
      id: 5,
      name: r'pdfId',
      type: IsarType.string,
    )
  },
  estimateSize: _louvorCacheEstimateSize,
  serialize: _louvorCacheSerialize,
  deserialize: _louvorCacheDeserialize,
  deserializeProp: _louvorCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'pdfId': IndexSchema(
      id: 5397193447447963901,
      name: r'pdfId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'pdfId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _louvorCacheGetId,
  getLinks: _louvorCacheGetLinks,
  attach: _louvorCacheAttach,
  version: '3.1.0+1',
);

int _louvorCacheEstimateSize(
  LouvorCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.categoria.length * 3;
  bytesCount += 3 + object.classificacao.length * 3;
  bytesCount += 3 + object.nome.length * 3;
  bytesCount += 3 + object.numero.length * 3;
  bytesCount += 3 + object.pdf.length * 3;
  bytesCount += 3 + object.pdfId.length * 3;
  return bytesCount;
}

void _louvorCacheSerialize(
  LouvorCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.categoria);
  writer.writeString(offsets[1], object.classificacao);
  writer.writeString(offsets[2], object.nome);
  writer.writeString(offsets[3], object.numero);
  writer.writeString(offsets[4], object.pdf);
  writer.writeString(offsets[5], object.pdfId);
}

LouvorCache _louvorCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LouvorCache();
  object.categoria = reader.readString(offsets[0]);
  object.classificacao = reader.readString(offsets[1]);
  object.id = id;
  object.nome = reader.readString(offsets[2]);
  object.numero = reader.readString(offsets[3]);
  object.pdf = reader.readString(offsets[4]);
  object.pdfId = reader.readString(offsets[5]);
  return object;
}

P _louvorCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _louvorCacheGetId(LouvorCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _louvorCacheGetLinks(LouvorCache object) {
  return [];
}

void _louvorCacheAttach(
    IsarCollection<dynamic> col, Id id, LouvorCache object) {
  object.id = id;
}

extension LouvorCacheByIndex on IsarCollection<LouvorCache> {
  Future<LouvorCache?> getByPdfId(String pdfId) {
    return getByIndex(r'pdfId', [pdfId]);
  }

  LouvorCache? getByPdfIdSync(String pdfId) {
    return getByIndexSync(r'pdfId', [pdfId]);
  }

  Future<bool> deleteByPdfId(String pdfId) {
    return deleteByIndex(r'pdfId', [pdfId]);
  }

  bool deleteByPdfIdSync(String pdfId) {
    return deleteByIndexSync(r'pdfId', [pdfId]);
  }

  Future<List<LouvorCache?>> getAllByPdfId(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'pdfId', values);
  }

  List<LouvorCache?> getAllByPdfIdSync(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'pdfId', values);
  }

  Future<int> deleteAllByPdfId(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'pdfId', values);
  }

  int deleteAllByPdfIdSync(List<String> pdfIdValues) {
    final values = pdfIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'pdfId', values);
  }

  Future<Id> putByPdfId(LouvorCache object) {
    return putByIndex(r'pdfId', object);
  }

  Id putByPdfIdSync(LouvorCache object, {bool saveLinks = true}) {
    return putByIndexSync(r'pdfId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPdfId(List<LouvorCache> objects) {
    return putAllByIndex(r'pdfId', objects);
  }

  List<Id> putAllByPdfIdSync(List<LouvorCache> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'pdfId', objects, saveLinks: saveLinks);
  }
}

extension LouvorCacheQueryWhereSort
    on QueryBuilder<LouvorCache, LouvorCache, QWhere> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LouvorCacheQueryWhere
    on QueryBuilder<LouvorCache, LouvorCache, QWhereClause> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> pdfIdEqualTo(
      String pdfId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'pdfId',
        value: [pdfId],
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterWhereClause> pdfIdNotEqualTo(
      String pdfId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [],
              upper: [pdfId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [pdfId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [pdfId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'pdfId',
              lower: [],
              upper: [pdfId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension LouvorCacheQueryFilter
    on QueryBuilder<LouvorCache, LouvorCache, QFilterCondition> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categoria',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'categoria',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'categoria',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'categoria',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'categoria',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'categoria',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'categoria',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'categoria',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categoria',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      categoriaIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'categoria',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'classificacao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'classificacao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'classificacao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'classificacao',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'classificacao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'classificacao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'classificacao',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'classificacao',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'classificacao',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      classificacaoIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'classificacao',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nome',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'nome',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'nome',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> nomeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nome',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      nomeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'nome',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'numero',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      numeroGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'numero',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'numero',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'numero',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      numeroStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'numero',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'numero',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'numero',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> numeroMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'numero',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      numeroIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'numero',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      numeroIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'numero',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pdf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pdf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pdf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pdf',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pdf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pdf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pdf',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pdf',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pdf',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      pdfIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pdf',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      pdfIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pdfId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'pdfId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'pdfId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition> pdfIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pdfId',
        value: '',
      ));
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterFilterCondition>
      pdfIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'pdfId',
        value: '',
      ));
    });
  }
}

extension LouvorCacheQueryObject
    on QueryBuilder<LouvorCache, LouvorCache, QFilterCondition> {}

extension LouvorCacheQueryLinks
    on QueryBuilder<LouvorCache, LouvorCache, QFilterCondition> {}

extension LouvorCacheQuerySortBy
    on QueryBuilder<LouvorCache, LouvorCache, QSortBy> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByCategoria() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByCategoriaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByClassificacao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classificacao', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy>
      sortByClassificacaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classificacao', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numero', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByNumeroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numero', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdf() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdf', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdfDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdf', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdfId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> sortByPdfIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.desc);
    });
  }
}

extension LouvorCacheQuerySortThenBy
    on QueryBuilder<LouvorCache, LouvorCache, QSortThenBy> {
  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByCategoria() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByCategoriaDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoria', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByClassificacao() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classificacao', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy>
      thenByClassificacaoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classificacao', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNome() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNomeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nome', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNumero() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numero', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByNumeroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numero', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdf() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdf', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdfDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdf', Sort.desc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdfId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.asc);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QAfterSortBy> thenByPdfIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pdfId', Sort.desc);
    });
  }
}

extension LouvorCacheQueryWhereDistinct
    on QueryBuilder<LouvorCache, LouvorCache, QDistinct> {
  QueryBuilder<LouvorCache, LouvorCache, QDistinct> distinctByCategoria(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoria', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QDistinct> distinctByClassificacao(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'classificacao',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QDistinct> distinctByNome(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nome', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QDistinct> distinctByNumero(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'numero', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QDistinct> distinctByPdf(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pdf', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LouvorCache, LouvorCache, QDistinct> distinctByPdfId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pdfId', caseSensitive: caseSensitive);
    });
  }
}

extension LouvorCacheQueryProperty
    on QueryBuilder<LouvorCache, LouvorCache, QQueryProperty> {
  QueryBuilder<LouvorCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LouvorCache, String, QQueryOperations> categoriaProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoria');
    });
  }

  QueryBuilder<LouvorCache, String, QQueryOperations> classificacaoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'classificacao');
    });
  }

  QueryBuilder<LouvorCache, String, QQueryOperations> nomeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nome');
    });
  }

  QueryBuilder<LouvorCache, String, QQueryOperations> numeroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'numero');
    });
  }

  QueryBuilder<LouvorCache, String, QQueryOperations> pdfProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pdf');
    });
  }

  QueryBuilder<LouvorCache, String, QQueryOperations> pdfIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pdfId');
    });
  }
}
